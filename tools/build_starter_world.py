#!/usr/bin/env python3
"""Generates the hand-authored Grassy Hills starter world as a Rojo-syncable .rbxmx.

Output: src/workspace/Worlds/GrassyHills.rbxmx (referenced from default.project.json).
Run `python3 tools/build_starter_world.py` after editing and rebuild with `rojo build`.

Everything is primitive parts (Part / WedgePart / SpawnLocation) with Roblox materials and
colours; the result is deterministic (fixed random seed) so rebuilding never churns the diff.
The layout mirrors the positions in src/shared/Config/Worlds.luau so the generated-defaults
fallback and this model agree about where things are.

Only the Python standard library is used.
"""

from __future__ import annotations

import base64
import math
import random
import struct
from dataclasses import dataclass, field
from pathlib import Path
from xml.sax.saxutils import escape

OUTPUT = Path(__file__).resolve().parent.parent / "src" / "workspace" / "Worlds" / "GrassyHills.rbxmx"

WORLD_ID = "GrassyHills"
PORTAL_TARGET = "CrystalCaverns"
EGG_ID = "MeadowEgg"

# Enum token values as serialised by Roblox (verified against a Rojo 7.4.4 build).
MATERIAL = {
    "Plastic": 256,
    "SmoothPlastic": 272,
    "Neon": 288,
    "Wood": 512,
    "WoodPlanks": 528,
    "Marble": 784,
    "Basalt": 788,
    "Slate": 800,
    "Concrete": 816,
    "Limestone": 820,
    "Granite": 832,
    "Brick": 848,
    "Pebble": 864,
    "Cobblestone": 880,
    "Rock": 896,
    "Sandstone": 912,
    "CorrodedMetal": 1040,
    "Metal": 1088,
    "Grass": 1280,
    "LeafyGrass": 1284,
    "Sand": 1296,
    "Fabric": 1312,
    "Mud": 1344,
    "Ground": 1360,
    "Glass": 1568,
}
SHAPE = {"Ball": 0, "Block": 1, "Cylinder": 2}
FACE = {"Right": 0, "Top": 1, "Back": 2, "Left": 3, "Bottom": 4, "Front": 5}
SURFACE_SMOOTH = 0
INT_PROPS = {"Duration"}

# Mirrors src/shared/Config/Ores.luau (colour, material, size) so vein and rock colours match.
ORES = {
    "Stone": ((140, 140, 140), "Slate", 4),
    "Coal": ((45, 45, 50), "Basalt", 4),
    "Copper": ((200, 120, 60), "CorrodedMetal", 4.5),
    "Gold": ((255, 205, 60), "Metal", 4.5),
    "Amethyst": ((170, 80, 230), "Glass", 5),
    "Diamond": ((150, 240, 255), "Glass", 5),
}

VEIN_TINT = 0.35  # keep in sync with MiningService.VEIN_TINT

# Mirrors Worlds.GrassyHills.oreSpawns.
ORE_SPAWNS = [
    ((-40, 0, -30), "Stone=10,Coal=4"),
    ((-48, 0, -22), "Stone=10,Coal=4"),
    ((-56, 0, -32), "Coal=5,Copper=2,Stone=8"),
    ((-44, 0, -42), "Coal=5,Copper=3,Stone=6"),
    ((-54, 0, -46), "Coal=5,Copper=3,Gold=1"),
    ((-62, 0, -40), "Copper=3,Gold=1"),
]

GRASS = (92, 160, 72)
DARK_GRASS = (72, 138, 58)
STONE = (120, 120, 120)
DARK_STONE = (86, 86, 92)
WOOD = (110, 72, 40)
PLANK = (160, 118, 72)
WATER = (50, 120, 220)
SAND = (214, 196, 150)
LEAF_A = (70, 140, 60)
LEAF_B = (96, 168, 72)
LAMP_WARM = (255, 220, 160)
COINS = (255, 205, 60)
SHARDS = (120, 220, 255)
EGG_COLOR = (200, 240, 160)

rng = random.Random(20261006)


# CFrame helpers ---------------------------------------------------------------------------


def rot_x(a: float) -> list[list[float]]:
    c, s = math.cos(a), math.sin(a)
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def rot_y(a: float) -> list[list[float]]:
    c, s = math.cos(a), math.sin(a)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def rot_z(a: float) -> list[list[float]]:
    c, s = math.cos(a), math.sin(a)
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


def mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def mat_vec(m, v):
    return tuple(sum(m[i][k] * v[k] for k in range(3)) for i in range(3))


IDENTITY = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]


def orientation(rx: float = 0, ry: float = 0, rz: float = 0):
    """Roblox Orientation semantics (degrees, applied Y * X * Z)."""
    return mat_mul(rot_y(math.radians(ry)), mat_mul(rot_x(math.radians(rx)), rot_z(math.radians(rz))))


UPRIGHT_CYLINDER = orientation(rz=90)  # cylinder axis is X; stand it on end


def yaw_facing(pos, target) -> float:
    """Yaw (degrees) that points a part's Front face (-Z) from pos toward target."""
    dx, dz = target[0] - pos[0], target[2] - pos[2]
    return math.degrees(math.atan2(-dx, -dz))


# Instance tree -----------------------------------------------------------------------------


@dataclass
class Inst:
    class_name: str
    name: str
    props: dict = field(default_factory=dict)
    attributes: dict = field(default_factory=dict)
    children: list["Inst"] = field(default_factory=list)
    primary: "Inst | None" = None
    ref: str = ""

    def add(self, child: "Inst") -> "Inst":
        self.children.append(child)
        return child


def model(name: str, *children: Inst, primary: Inst | None = None) -> Inst:
    m = Inst("Model", name, children=list(children))
    m.primary = primary or next((c for c in children if c.class_name in ("Part", "WedgePart", "SpawnLocation")), None)
    return m


def part(
    name: str,
    size,
    pos,
    color,
    material: str,
    *,
    shape: str = "Block",
    rot=None,
    transparency: float = 0,
    can_collide: bool = True,
    class_name: str = "Part",
    cast_shadow: bool = True,
) -> Inst:
    props = {
        "Anchored": True,
        "CanCollide": can_collide,
        "CastShadow": cast_shadow,
        "Size": tuple(float(v) for v in size),
        "CFrame": (tuple(float(v) for v in pos), rot or IDENTITY),
        "Color": color,
        "Material": material,
        "Transparency": float(transparency),
    }
    if class_name == "Part":
        props["Shape"] = shape
    return Inst(class_name, name, props)


def cylinder(name, diameter, height, pos, color, material, **kw) -> Inst:
    return part(name, (height, diameter, diameter), pos, color, material, shape="Cylinder", rot=UPRIGHT_CYLINDER, **kw)


def ball(name, diameter, pos, color, material, **kw) -> Inst:
    return part(name, (diameter, diameter, diameter), pos, color, material, shape="Ball", **kw)


def point_light(color=LAMP_WARM, brightness=1.5, range_=22) -> Inst:
    return Inst("PointLight", "Light", {"Brightness": brightness, "Range": range_, "Color": color, "Shadows": False})


def surface_label(text: str, face: str, color=(255, 255, 255)) -> Inst:
    gui = Inst("SurfaceGui", f"Label{face}", {"Face": face, "SizingMode": "PixelsPerStud", "PixelsPerStud": 40})
    gui.add(
        Inst(
            "TextLabel",
            "Text",
            {
                "Size": ((1, 0), (1, 0)),
                "BackgroundTransparency": 1.0,
                "Text": text,
                "TextScaled": True,
                "TextColor3": color,
                "TextStrokeTransparency": 0.5,
                "Font": "GothamBold",
            },
        )
    )
    return gui


def jitter(v: float) -> float:
    return rng.uniform(-v, v)


# World pieces -------------------------------------------------------------------------------


def build_ground() -> Inst:
    return part("Ground", (180, 4, 180), (0, -2, 0), GRASS, "Grass")


def build_spawn() -> Inst:
    spawn = part("Spawn", (12, 0.5, 12), (0, 0.75, 0), (235, 235, 235), "SmoothPlastic", class_name="SpawnLocation")
    spawn.props.update({"Duration": 0, "Neutral": True})
    return spawn


def build_plaza() -> Inst:
    plaza = cylinder("Pavement", 40, 0.5, (0, 0.25, 0), (150, 150, 145), "Cobblestone")
    ring = cylinder("InnerRing", 18, 0.1, (0, 0.55, 0), (190, 185, 175), "Marble")
    pieces = [plaza, ring]
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        x, z = 18.5 * math.cos(a), 18.5 * math.sin(a)
        planter = part(f"Planter{i + 1}", (3, 1.2, 3), (x, 0.6 + 0.5, z), (120, 85, 60), "Brick", rot=orientation(ry=-i * 45))
        bush = ball(f"Bush{i + 1}", 2.6, (x, 2.3, z), LEAF_B if i % 2 else LEAF_A, "LeafyGrass", can_collide=False)
        pieces += [planter, bush]
    return model("Plaza", *pieces, primary=plaza)


def path_segment(name: str, a, b, width: float = 6.0, color=(150, 150, 145), material="Cobblestone") -> Inst:
    dx, dz = b[0] - a[0], b[2] - a[2]
    length = math.hypot(dx, dz)
    yaw = math.degrees(math.atan2(dx, dz))
    mid = ((a[0] + b[0]) / 2, 0.15, (a[2] + b[2]) / 2)
    return part(name, (width, 0.3, length), mid, color, material, rot=orientation(ry=yaw))


def build_paths() -> Inst:
    segments = [
        path_segment("ToMine", (-16, 0, -10), (-32, 0, -20)),
        path_segment("ToPond", (16, 0, -10), (24, 0, -27)),
        path_segment("ToHatchery", (0, 0, -18), (0, 0, -39)),
        path_segment("ToPortal", (0, 0, 18), (0, 0, 55)),
        path_segment("ToRebirth", (-16, 0, 10), (-26, 0, 18), width=4),
        path_segment("MineFloor", (-72, 0, -34), (-30, 0, -34), width=40, color=(118, 96, 70), material="Ground"),
    ]
    return model("Paths", *segments, primary=segments[0])


def ore_node(index: int, pos, ores: str) -> Inst:
    dominant = max((entry.split("=") for entry in ores.split(",")), key=lambda e: float(e[1]))[0]
    color, material, size = ORES[dominant]
    yaw = rng.uniform(0, 360)
    tilt = orientation(rx=jitter(8), ry=yaw, rz=jitter(8))
    centre = (pos[0], size / 2 + 0.2, pos[2])
    node = part(f"OreNode{index}", (size, size, size), centre, color, material, rot=tilt)
    node.attributes["Ores"] = ores
    # Veins protrude from the rock so they stay visible at every ore size the server applies.
    # MiningService re-tints them (ore colour lerped 35% toward white) whenever the ore re-rolls.
    vein_color = tuple(c + (255 - c) * VEIN_TINT for c in color)
    offsets = [(0, 2.25, 0.4), (2.25, 0.4, -0.5), (-0.6, 0.2, 2.25)]
    for i, local in enumerate(offsets):
        world = mat_vec(tilt, local)
        vein_rot = mat_mul(tilt, orientation(ry=45 + i * 30, rx=jitter(15)))
        vein = part(
            f"Vein{i + 1}",
            (1.3, 1.0, 1.3),
            (centre[0] + world[0], centre[1] + world[1], centre[2] + world[2]),
            vein_color,
            material,
            rot=vein_rot,
            can_collide=False,
        )
        node.add(vein)
    return node


def build_ore_nodes() -> Inst:
    folder = Inst("Folder", "OreNodes")
    for i, (pos, ores) in enumerate(ORE_SPAWNS):
        folder.add(ore_node(i + 1, pos, ores))
    return folder


def build_mine() -> Inst:
    pieces = []
    # Back cliff along the north edge of the mine, then the west edge, as stepped Slate blocks.
    north = [(-74, -58), (-64, -60), (-54, -59), (-44, -61), (-34, -59)]
    for i, (x, z) in enumerate(north):
        h = 10 + (i % 3) * 3
        pieces.append(part(f"CliffN{i + 1}", (11, h, 8), (x, h / 2, z), DARK_STONE, "Slate", rot=orientation(ry=jitter(4))))
        pieces.append(part(f"CliffN{i + 1}Top", (8, 2.5, 6), (x + jitter(1.5), h + 1.2, z + jitter(1)), STONE, "Rock", rot=orientation(ry=jitter(12))))
    west = [(-76, -48), (-78, -38), (-76, -28), (-77, -18)]
    for i, (x, z) in enumerate(west):
        h = 9 + (i % 2) * 4
        pieces.append(part(f"CliffW{i + 1}", (8, h, 11), (x, h / 2, z), DARK_STONE, "Slate", rot=orientation(ry=jitter(4))))
    # Loose boulders around the ore nodes.
    boulders = [((-36, -48), 4.5), ((-66, -50), 5.5), ((-68, -26), 4), ((-50, -54), 3.5), ((-34, -40), 3)]
    for i, ((x, z), d) in enumerate(boulders):
        pieces.append(part(f"Boulder{i + 1}", (d, d * 0.8, d * 1.1), (x, d * 0.4, z), STONE, "Rock", rot=orientation(rx=jitter(10), ry=rng.uniform(0, 360), rz=jitter(10))))
    # Entrance arch where the path arrives, with the Mine sign on the lintel.
    left = part("ArchLeft", (2.5, 11, 2.5), (-30, 5.5, -16), DARK_STONE, "Granite", rot=orientation(ry=-30))
    right = part("ArchRight", (2.5, 11, 2.5), (-38, 5.5, -28), DARK_STONE, "Granite", rot=orientation(ry=-30))
    lintel_yaw = math.degrees(math.atan2(-38 - -30, -28 - -16))
    lintel = part("ArchLintel", (3, 2.5, 16), (-34, 11.75, -22), STONE, "Granite", rot=orientation(ry=lintel_yaw))
    lintel.add(surface_label("Mine", "Right", COINS))
    lintel.add(surface_label("Mine", "Left", COINS))
    pieces += [left, right, lintel]
    # Minecart rails and a cart as set dressing, tucked against the west cliff.
    rail_z = -19
    for i, dz in enumerate((-1.0, 1.0)):
        pieces.append(part(f"Rail{i + 1}", (18, 0.3, 0.3), (-63, 0.45, rail_z + dz), (90, 90, 95), "Metal", can_collide=False))
    for i in range(5):
        pieces.append(part(f"Sleeper{i + 1}", (0.8, 0.25, 3), (-70.5 + i * 3.75, 0.4, rail_z), WOOD, "Wood", can_collide=False))
    cart = part("Cart", (4.2, 2, 3.2), (-66, 1.6, rail_z), (75, 60, 50), "CorrodedMetal")
    cart_load = part("CartOre", (3.4, 0.8, 2.6), (-66, 2.8, rail_z), ORES["Coal"][0], "Basalt", can_collide=False)
    pieces += [cart, cart_load]
    return model("Mine", *pieces, primary=lintel)


def build_fishing_spots() -> Inst:
    folder = Inst("Folder", "FishingSpots")
    spot = part("GrassyPond", (18, 1.6, 16), (45, -0.45, -30), WATER, "Glass", transparency=0.3, can_collide=False)
    spot.attributes["SpotId"] = "GrassyPond"
    spot.attributes["Fish"] = "Bass=5,Koi=1,Minnow=10,Trout=3"
    folder.add(spot)
    return folder


def build_pond() -> Inst:
    water = part("Water", (46, 1.4, 34), (45, -0.6, -30), (60, 130, 225), "Glass", transparency=0.4, can_collide=False)
    pieces = [water]
    # Sandy shore on all four sides.
    shore = [
        ("ShoreN", (52, 0.2, 3), (45, 0.1, -48.5)),
        ("ShoreS", (52, 0.2, 3), (45, 0.1, -11.5)),
        ("ShoreW", (3, 0.2, 34), (20.5, 0.1, -30)),
        ("ShoreE", (3, 0.2, 34), (69.5, 0.1, -30)),
    ]
    for name, size, pos in shore:
        pieces.append(part(name, size, pos, SAND, "Sand"))
    # Wooden dock from the west shore out over the water.
    deck = part("DockDeck", (16, 0.5, 6), (30, 1.4, -30), PLANK, "WoodPlanks")
    pieces.append(deck)
    for i, x in enumerate((23, 30, 37)):
        for j, z in enumerate((-33.2, -26.8)):
            pieces.append(cylinder(f"DockPost{i * 2 + j + 1}", 0.9, 4.5, (x, 1.0, z), WOOD, "Wood"))
    for j, z in enumerate((-33.3, -26.7)):
        pieces.append(part(f"DockRail{j + 1}", (14.5, 0.25, 0.25), (30.5, 3.1, z), WOOD, "Wood", can_collide=False))
    pieces.append(part("DockEndRail", (0.25, 0.25, 6.6), (37.7, 3.1, -30), WOOD, "Wood", can_collide=False))
    pieces.append(part("DockSteps", (3, 0.9, 5), (21.5, 0.45, -30), PLANK, "WoodPlanks"))
    # Buoys mark the corners of the fishing spot.
    for i, (x, z) in enumerate(((36.5, -38), (36.5, -22), (53.5, -38), (53.5, -22))):
        buoy = ball(f"Buoy{i + 1}", 1.6, (x, 0.65, z), (220, 60, 50) if i % 2 == 0 else (240, 240, 240), "SmoothPlastic", can_collide=False)
        pieces.append(buoy)
    # Reeds and lily pads.
    for i in range(7):
        a = rng.uniform(0, 2 * math.pi)
        x, z = 45 + 21 * math.cos(a), -30 + 15 * math.sin(a)
        pieces.append(cylinder(f"Reed{i + 1}", 0.35, rng.uniform(2.4, 3.4), (x, 1.3, z), (110, 160, 70), "Grass", can_collide=False))
    for i in range(4):
        x, z = 45 + rng.uniform(-18, 18), -30 + rng.uniform(-12, 12)
        if abs(x - 45) < 10 and abs(z + 30) < 9:
            x += 12
        pieces.append(cylinder(f"LilyPad{i + 1}", 2.2, 0.15, (x, 0.22, z), (60, 150, 70), "SmoothPlastic", can_collide=False))
    return model("Pond", *pieces, primary=deck)


def build_egg_stands() -> Inst:
    folder = Inst("Folder", "EggStands")
    egg = ball(EGG_ID, 5, (0, 4.7, -45), EGG_COLOR, "SmoothPlastic")
    egg.attributes["EggId"] = EGG_ID
    folder.add(egg)
    return folder


def build_hatchery() -> Inst:
    floor = part("Floor", (18, 0.5, 16), (0, 0.25, -47), PLANK, "WoodPlanks")
    pieces = [floor]
    for i, (x, z) in enumerate(((-8, -40), (8, -40), (-8, -54), (8, -54))):
        pieces.append(part(f"Post{i + 1}", (1, 9, 1), (x, 5, z), WOOD, "Wood"))
    pieces.append(part("BeamFront", (18, 1, 1), (0, 9.5, -40), WOOD, "Wood"))
    pieces.append(part("BeamBack", (18, 1, 1), (0, 9.5, -54), WOOD, "Wood"))
    # Pitched roof: two slabs tilted toward a central ridge.
    for i, (z, tilt) in enumerate(((-43.6, 30), (-50.4, -30))):
        pieces.append(part(f"Roof{i + 1}", (20, 0.5, 8.2), (0, 11.9, z), (140, 60, 50), "Brick", rot=orientation(rx=tilt)))
    pieces.append(part("Ridge", (20.4, 0.7, 0.9), (0, 13.9, -47), (110, 45, 40), "Brick"))
    # Pedestal, straw nest and a shop counter with the Eggs sign.
    pieces.append(cylinder("Pedestal", 5, 1.6, (0, 1.3, -45), (190, 185, 175), "Marble"))
    pieces.append(cylinder("Nest", 6, 0.6, (0, 2.4, -45), (200, 170, 90), "Fabric", can_collide=False))
    counter = part("Counter", (8, 2.6, 1.6), (0, 1.8, -39.5), (120, 85, 60), "Brick")
    counter.props["Transparency"] = 0.0
    pieces.append(counter)
    counter_top = part("CounterTop", (8.4, 0.3, 2), (0, 3.25, -39.5), PLANK, "WoodPlanks")
    pieces.append(counter_top)
    sign = part("HatcherySign", (8, 1.8, 0.4), (0, 7.8, -39.7), PLANK, "WoodPlanks", can_collide=False)
    sign.add(surface_label("Eggs", "Front", EGG_COLOR))
    sign.add(surface_label("Eggs", "Back", EGG_COLOR))
    pieces.append(sign)
    # Decorative eggs on the back shelf.
    shelf = part("Shelf", (12, 0.4, 2.5), (0, 3.5, -52.5), PLANK, "WoodPlanks")
    pieces.append(shelf)
    for i, (x, c) in enumerate(((-4, (240, 200, 210)), (-1.3, (200, 220, 250)), (1.3, (250, 235, 170)), (4, (190, 240, 200)))):
        pieces.append(ball(f"ShelfEgg{i + 1}", 1.8, (x, 4.6, -52.5), c, "SmoothPlastic", can_collide=False))
    return model("Hatchery", *pieces, primary=floor)


def build_portals() -> Inst:
    folder = Inst("Folder", "Portals")
    portal = part(f"Portal_{PORTAL_TARGET}", (8, 14, 1), (0, 8, 60), SHARDS, "Neon", transparency=0.3, can_collide=False)
    portal.attributes["TargetWorld"] = PORTAL_TARGET
    folder.add(portal)
    return folder


def build_portal_frame() -> Inst:
    base = part("Base", (16, 1, 8), (0, 0.5, 60), (150, 150, 145), "Cobblestone")
    step = part("Step", (12, 0.5, 3), (0, 0.25, 54.5), (160, 160, 155), "Cobblestone")
    left = part("PillarLeft", (2.5, 14, 2.5), (-5.5, 8, 60), DARK_STONE, "Granite")
    right = part("PillarRight", (2.5, 14, 2.5), (5.5, 8, 60), DARK_STONE, "Granite")
    lintel = part("Lintel", (14, 2.5, 2.8), (0, 16.25, 60), DARK_STONE, "Granite")
    pieces = [base, step, left, right, lintel]
    crystals = [((-5.5, 18.5, 60), 3.2, 15), ((5.5, 18.5, 60), 3.2, -15), ((0, 18.6, 60), 4.2, 0), ((-2.8, 17.9, 60), 2.2, 25), ((2.8, 17.9, 60), 2.2, -25)]
    for i, (pos, h, tilt) in enumerate(crystals):
        pieces.append(part(f"Crystal{i + 1}", (1.4, h, 1.4), pos, (170, 80, 230), "Glass", rot=orientation(rz=tilt, ry=45), transparency=0.15, can_collide=False))
    for i, x in enumerate((-5.5, 5.5)):
        brazier = part(f"Brazier{i + 1}", (1.6, 1.6, 1.6), (x, 1.3, 54.5), SHARDS, "Neon", can_collide=False)
        brazier.add(point_light(SHARDS, 2, 18))
        pieces.append(brazier)
    return model("PortalFrame", *pieces, primary=base)


def build_rebirth_shrine() -> Inst:
    base = cylinder("Base", 10, 0.8, (-30, 0.4, 22), (150, 150, 145), "Cobblestone")
    plinth = cylinder("Plinth", 4, 2.2, (-30, 1.9, 22), (190, 185, 175), "Marble")
    orb = ball("Orb", 3, (-30, 4.6, 22), COINS, "Neon", can_collide=False)
    orb.add(point_light(COINS, 2, 20))
    pieces = [base, plinth, orb]
    for i in range(4):
        a = math.radians(45 + i * 90)
        x, z = -30 + 4.2 * math.cos(a), 22 + 4.2 * math.sin(a)
        pieces.append(part(f"Pillar{i + 1}", (1.2, 5, 1.2), (x, 3.3, z), (190, 185, 175), "Marble"))
    plaque_pos = (-26.2, 1.6, 17.6)
    plaque = part("Plaque", (6, 1.6, 0.3), plaque_pos, DARK_STONE, "Granite", rot=orientation(ry=yaw_facing(plaque_pos, (0, 0, 0))))
    plaque.add(surface_label("Rebirth", "Front", COINS))
    plaque.add(surface_label("Rebirth", "Back", COINS))
    pieces.append(plaque)
    return model("RebirthShrine", *pieces, primary=base)


def tree(index: int, x: float, z: float, scale: float = 1.0) -> Inst:
    trunk_h = 7 * scale
    trunk = cylinder("Trunk", 1.6 * scale, trunk_h, (x, trunk_h / 2, z), WOOD, "Wood")
    canopy = ball("Canopy", 9 * scale, (x, trunk_h + 2.5 * scale, z), LEAF_A if index % 2 else LEAF_B, "LeafyGrass", can_collide=False)
    dx, dz = jitter(2.2) * scale, jitter(2.2) * scale
    tuft = ball("CanopyTop", 6 * scale, (x + dx, trunk_h + 5 * scale, z + dz), LEAF_B if index % 2 else LEAF_A, "LeafyGrass", can_collide=False)
    return model(f"Tree{index}", trunk, canopy, tuft, primary=trunk)


def build_trees() -> Inst:
    spots = [
        (-30, 40, 1.1), (-55, 55, 1.0), (-70, 20, 1.2), (-72, 0, 0.9), (-20, 65, 1.0), (25, 65, 1.1),
        (50, 50, 1.0), (72, 30, 1.2), (74, -5, 1.0), (76, -55, 1.1), (30, -60, 0.9), (60, -62, 1.0),
        (-15, -70, 1.1), (20, -72, 1.0), (-62, 75, 0.9), (70, 70, 0.95), (-78, -72, 1.0), (12, 30, 0.8),
    ]
    trees = [tree(i + 1, x, z, s) for i, (x, z, s) in enumerate(spots)]
    return model("Trees", *trees, primary=trees[0].primary)


def lamp(index: int, x: float, z: float) -> Inst:
    post = cylinder("Post", 0.6, 7.5, (x, 3.75, z), (60, 60, 65), "Metal")
    head = part("Lantern", (1.3, 1.3, 1.3), (x, 7.9, z), LAMP_WARM, "Neon", can_collide=False)
    head.add(point_light())
    cap = part("Cap", (1.8, 0.3, 1.8), (x, 8.7, z), (60, 60, 65), "Metal", can_collide=False)
    return model(f"Lamp{index}", post, head, cap, primary=post)


def build_lamps() -> Inst:
    spots = [(14, 14), (-14, 14), (14, -14), (-14, -14), (21, -26.5), (-10, -38), (-27, -13), (-8, 52), (8, 52), (-24, 27)]
    lamps = [lamp(i + 1, x, z) for i, (x, z) in enumerate(spots)]
    return model("Lamps", *lamps, primary=lamps[0].primary)


def signpost(name: str, text: str, pos, color) -> Inst:
    # Boards face the plaza centre so they read correctly from spawn.
    rot = orientation(ry=yaw_facing(pos, (0, 0, 0)))
    post = part("Post", (0.4, 4.2, 0.4), (pos[0], 2.1, pos[2]), WOOD, "Wood", rot=rot)
    board = part("Board", (4.2, 1.5, 0.3), (pos[0], 4.6, pos[2]), PLANK, "WoodPlanks", rot=rot, can_collide=False)
    board.add(surface_label(text, "Front", color))
    board.add(surface_label(text, "Back", color))
    return model(name, post, board, primary=post)


def build_signs() -> Inst:
    signs = [
        signpost("SignMine", "Mine", (-21, 0, -9), COINS),
        signpost("SignFishing", "Fishing", (21, 0, -9), (150, 200, 255)),
        signpost("SignEggs", "Eggs", (4.5, 0, -22), EGG_COLOR),
        signpost("SignRebirth", "Rebirth", (-20, 0, 8), COINS),
        signpost("SignPortal", "Portal", (4.5, 0, 22), SHARDS),
    ]
    return model("Signs", *signs, primary=signs[0].primary)


def build_border() -> Inst:
    hedges = [
        ("HedgeN", (176, 2.5, 2), (0, 1.25, -88)),
        ("HedgeS", (176, 2.5, 2), (0, 1.25, 88)),
        ("HedgeW", (2, 2.5, 176), (-88, 1.25, 0)),
        ("HedgeE", (2, 2.5, 176), (88, 1.25, 0)),
    ]
    parts = [part(n, s, p, DARK_GRASS, "LeafyGrass") for n, s, p in hedges]
    return model("Border", *parts, primary=parts[0])


def build_world() -> Inst:
    world = Inst("Folder", WORLD_ID)
    world.add(build_ground())
    world.add(build_spawn())
    world.add(build_ore_nodes())
    world.add(build_fishing_spots())
    world.add(build_egg_stands())
    world.add(build_portals())
    for builder in (
        build_plaza,
        build_paths,
        build_mine,
        build_pond,
        build_hatchery,
        build_portal_frame,
        build_rebirth_shrine,
        build_trees,
        build_lamps,
        build_signs,
        build_border,
    ):
        world.add(builder())
    return world


# Serialisation --------------------------------------------------------------------------------


def encode_attributes(attributes: dict) -> str:
    out = struct.pack("<I", len(attributes))
    for key, value in attributes.items():
        if not isinstance(value, str):
            raise TypeError(f"only string attributes are supported, got {key}={value!r}")
        out += struct.pack("<I", len(key)) + key.encode() + b"\x02" + struct.pack("<I", len(value)) + value.encode()
    return base64.b64encode(out).decode()


def fmt(v: float) -> str:
    s = f"{v:.6f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def color_uint8(rgb) -> int:
    r, g, b = (max(0, min(255, int(round(c)))) for c in rgb)
    return (r << 16) | (g << 8) | b


def color3_xml(name: str, rgb, indent: str) -> str:
    r, g, b = (c / 255 for c in rgb)
    return f'{indent}<Color3 name="{name}"><R>{fmt(r)}</R><G>{fmt(g)}</G><B>{fmt(b)}</B></Color3>\n'


def is_udim2(value) -> bool:
    return isinstance(value, tuple) and len(value) == 2 and all(isinstance(v, tuple) and len(v) == 2 for v in value)


def prop_xml(name: str, value, indent: str) -> str:
    if name == "CFrame":
        (x, y, z), m = value
        cells = "".join(f"<R{i}{j}>{fmt(m[i][j])}</R{i}{j}>" for i in range(3) for j in range(3))
        return f'{indent}<CoordinateFrame name="CFrame"><X>{fmt(x)}</X><Y>{fmt(y)}</Y><Z>{fmt(z)}</Z>{cells}</CoordinateFrame>\n'
    if is_udim2(value):
        (xs, xo), (ys, yo) = value
        return f'{indent}<UDim2 name="{name}"><XS>{fmt(xs)}</XS><XO>{int(xo)}</XO><YS>{fmt(ys)}</YS><YO>{int(yo)}</YO></UDim2>\n'
    if name == "Size":
        x, y, z = value
        return f'{indent}<Vector3 name="size"><X>{fmt(x)}</X><Y>{fmt(y)}</Y><Z>{fmt(z)}</Z></Vector3>\n'
    if name == "Color" and isinstance(value, tuple):
        # BasePart.Color serialises as Color3uint8; every other Color3 (lights, text) is float RGB.
        return f'{indent}<Color3uint8 name="Color3uint8">{color_uint8(value)}</Color3uint8>\n'
    if name == "Material":
        return f'{indent}<token name="Material">{MATERIAL[value]}</token>\n'
    if name == "Shape":
        return f'{indent}<token name="shape">{SHAPE[value]}</token>\n'
    if name == "Face":
        return f'{indent}<token name="Face">{FACE[value]}</token>\n'
    if name == "SizingMode":
        return f'{indent}<token name="SizingMode">{1 if value == "PixelsPerStud" else 0}</token>\n'
    if name == "Font":
        if value != "GothamBold":
            raise ValueError(f"unsupported font {value}")
        return (
            f'{indent}<Font name="FontFace"><Family><url>rbxasset://fonts/families/GothamSSm.json</url></Family>'
            f"<Weight>700</Weight><Style>Normal</Style></Font>\n"
        )
    if isinstance(value, bool):
        return f'{indent}<bool name="{name}">{"true" if value else "false"}</bool>\n'
    if name in INT_PROPS:
        return f'{indent}<int name="{name}">{int(value)}</int>\n'
    if isinstance(value, (int, float)):
        return f'{indent}<float name="{name}">{fmt(float(value))}</float>\n'
    if isinstance(value, str):
        return f'{indent}<string name="{name}">{escape(value)}</string>\n'
    if isinstance(value, tuple) and len(value) == 3:
        return color3_xml(name, value, indent)
    raise TypeError(f"cannot serialise {name}={value!r}")


def assign_refs(inst: Inst, counter: list[int]) -> None:
    inst.ref = f"RBX{counter[0]}"
    counter[0] += 1
    for child in inst.children:
        assign_refs(child, counter)


def inst_xml(inst: Inst, depth: int) -> str:
    indent = "  " * depth
    inner = "  " * (depth + 1)
    pind = "  " * (depth + 2)
    out = f'{indent}<Item class="{inst.class_name}" referent="{inst.ref}">\n{inner}<Properties>\n'
    out += f'{pind}<string name="Name">{escape(inst.name)}</string>\n'
    props = dict(inst.props)
    if inst.class_name in ("Part", "WedgePart", "SpawnLocation"):
        props.setdefault("TopSurface", SURFACE_SMOOTH)
        props.setdefault("BottomSurface", SURFACE_SMOOTH)
    for key in sorted(props):
        value = props[key]
        if key in ("TopSurface", "BottomSurface"):
            out += f'{pind}<token name="{key}">{value}</token>\n'
        else:
            out += prop_xml(key, value, pind)
    if inst.attributes:
        out += f'{pind}<BinaryString name="AttributesSerialize">{encode_attributes(inst.attributes)}</BinaryString>\n'
    if inst.primary is not None:
        out += f'{pind}<Ref name="PrimaryPart">{inst.primary.ref}</Ref>\n'
    out += f"{inner}</Properties>\n"
    for child in inst.children:
        out += inst_xml(child, depth + 1)
    out += f"{indent}</Item>\n"
    return out


def count_parts(inst: Inst) -> int:
    own = 1 if inst.class_name in ("Part", "WedgePart", "SpawnLocation") else 0
    return own + sum(count_parts(c) for c in inst.children)


def main() -> None:
    world = build_world()
    assign_refs(world, [0])
    xml = '<roblox version="4">\n' + inst_xml(world, 1) + "</roblox>\n"
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(xml)
    print(f"wrote {OUTPUT.relative_to(OUTPUT.parents[3])}: {count_parts(world)} parts")


if __name__ == "__main__":
    main()
