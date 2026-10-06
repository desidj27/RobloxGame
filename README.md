# Mine & Reel — Roblox mining / fishing / pet simulator

First playable slice of an incremental Roblox game in the spirit of Pet Simulator 99 and
Mining Simulator: mine ore nodes and fish in ponds to earn **per-world coins**, spend them on
**eggs** that hatch **mining- or fishing-focused pets**, equip pets to boost your stats, and
**rebirth** once you finish a task list and hit a coin goal for a permanent coin multiplier.

The project is a [Rojo](https://rojo.space) codebase (`default.project.json` + Luau under `src/`)
and also ships a prebuilt place file at `build/MiningFishingSim.rbxl`.

> **Not runtime-tested yet.** This was authored in a cloud environment with no Roblox Studio.
> Every script passes `luau-analyze`, `selene` and `stylua`, the shared game logic was exercised
> with an offline Luau harness, and the `.rbxl` was built with Rojo 7.4.4 — but nothing has been
> played in Studio. Expect to fix small runtime issues on first play.

---

## Running it

### Option A — open the prebuilt place (no tooling)

1. Download `build/MiningFishingSim.rbxl` and open it in Roblox Studio.
2. Press **Play**. `Workspace/Worlds/GrassyHills` is the hand-built starter world (see
   [Starter world](#starter-world)); the server adopts it and generates Crystal Caverns from config
   at runtime, so only one world is visible in the file before you press Play.

`build/StarterWorld.rbxmx` is the Grassy Hills world on its own — in Studio use
**File → Insert from file…** (or drag it into the viewport) to drop it into any place.

### Option B — sync with Rojo (recommended for development)

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then in this folder run `rokit install`
   to get the pinned Rojo / selene / StyLua from `rokit.toml`.
   (Or grab the [Rojo release](https://github.com/rojo-rbx/rojo/releases) binary directly.)
2. Install the Rojo plugin into Studio: `rojo plugin install`.
3. Serve the project: `rojo serve default.project.json`.
4. In Studio open any place (or the prebuilt one), click **Rojo → Connect** (default
   `localhost:34872`). Scripts under `src/` and the starter world under `src/workspace/` now
   live-sync into the place. Rojo owns `Workspace/Worlds`, so hand-placed worlds belong in
   `src/workspace/Worlds/` rather than loose in the Studio Explorer (Rojo will offer to remove them
   on connect otherwise).
5. Press **Play**.

### Build the place file yourself

```sh
rojo build default.project.json -o build/MiningFishingSim.rbxl        # full place
rojo build starter-world.project.json -o build/StarterWorld.rbxmx      # Grassy Hills model only
```

### DataStores in Studio

In Studio the game automatically uses an **in-memory mock** datastore (progress is not saved,
and a warning says so in Output). To use real DataStores from Studio, enable
**Game Settings → Security → Enable Studio Access to API Services** in a published place.
Live servers always use the real `DataStoreService`.

### Lint / format

```sh
selene src
stylua --check src
```

### Regenerate the starter world

The Grassy Hills model is produced by a deterministic, standard-library-only Python script so the
layout can be tweaked in code and rebuilt without Studio:

```sh
python3 tools/build_starter_world.py     # rewrites src/workspace/Worlds/GrassyHills.rbxmx
rojo build default.project.json -o build/MiningFishingSim.rbxl
rojo build starter-world.project.json -o build/StarterWorld.rbxmx
```

Editing the world directly in Studio also works — save it back with **right-click → Save to File…**
over `src/workspace/Worlds/GrassyHills.rbxmx` (Studio writes `.rbxmx` when you pick the XML format).

---

## Project layout

```
default.project.json         Rojo tree: src/shared → ReplicatedStorage.Shared,
                             src/server → ServerScriptService.Server,
                             src/client → StarterPlayer.StarterPlayerScripts.Client,
                             src/workspace/Worlds → Workspace.Worlds
starter-world.project.json   Rojo model project that builds the starter world alone
src/workspace/Worlds/
  GrassyHills.rbxmx          Hand-authored starter world (253 primitive parts, see below)
tools/
  build_starter_world.py     Generates GrassyHills.rbxmx deterministically (python3, no deps)
src/shared/
  Config/                    All tunable data (pure tables)
    GameConfig.luau          Balance constants, base stats, cooldowns, ranges
    Worlds.luau              Worlds, their currency, default layouts
    Ores.luau  Fish.luau     Ore nodes / fish (health, payout, rarity, gates)
    Eggs.luau  Pets.luau     Egg contents & weights / pet roster & stat bonuses
    Rarities.luau            Rarity ladder + colours
    Rebirth.luau             Rebirth tasks, coin threshold, evaluate()
  Network.luau               Single registry of RemoteEvents / RemoteFunctions
  Types.luau                 Profile & payload types
  Util/
    Formulas.luau            Every stat / payout formula in one place
    Weighted.luau  Format.luau  Signal.luau  TableUtil.luau
src/server/
  init.server.luau           Boots services (Init → Start)
  Services/
    DataService.luau         DataStore load/save, Studio mock, autosave, replication
    CurrencyService.luau     Per-world coin add / spend / reset
    PetService.luau          Hatch, equip, unequip, delete; computes live stats
    MiningService.luau       Ore node state machine, hit validation, payouts, respawn
    FishingService.luau      Cast → bite → reel sessions, luck-weighted catch rolls
    RebirthService.luau      Rebirth authorisation and reset
    WorldService.luau        Adopts or generates the map; world travel
src/client/
  init.client.luau           Boots controllers (Init → Start)
  Controllers/
    DataController.luau      Replicated profile + derived stats
    MiningController.luau    Auto-swing loop, node health bars, damage numbers
    FishingController.luau   Cast/reel input and state
    PetController.luau       Pet remotes
    UIController.luau        Owns the ScreenGui and wires signals into UI modules
  UI/                        Generated UI: HUD, PetInventory, EggShop, RebirthPanel,
                             FishingOverlay, HatchPopup, Notifications, Create, Theme
build/MiningFishingSim.rbxl  Prebuilt place (Rojo build of this tree)
build/StarterWorld.rbxmx     Grassy Hills world alone, insertable into any place
```

---

## Starter world

`Workspace/Worlds/GrassyHills` is a hand-authored map built from anchored primitive parts
(Part / SpawnLocation with Roblox materials and colours, grouped into Models with PrimaryParts).
Crystal Caverns has no hand-placed model yet and is still generated from `Config/Worlds.luau`.
The ground is 180×180 studs with its top at `y = 0`; everything below is relative to that.

| Area | Where | What is there |
| --- | --- | --- |
| Spawn plaza | centre `(0, 0)` | 40-stud cobblestone disc, marble inner ring, `SpawnLocation`, 8 brick planters with bushes, 4 lamps |
| Signposts | plaza rim | Wooden boards with `SurfaceGui` labels **Mine**, **Fishing**, **Eggs**, **Rebirth**, **Portal**, each facing the plaza |
| Paths | from the plaza | Cobblestone slabs to the mine, dock, hatchery, portal and rebirth shrine |
| Mine | north-west `(-72…-30, -54…-14)` | Dirt floor, stepped Slate/Rock cliff along the north and west edges, 5 boulders, granite entrance arch with a **Mine** sign, minecart rails and cart, 6 ore-node rocks at the config spawn points, each with 3 protruding ore-tinted veins |
| Pond | north-east, centre `(45, -30)` | 46×34 water slab with sandy shore, reeds and lily pads; 16-stud plank dock with posts and rails; the `FishingSpots/GrassyPond` part is an 18×16 zone off the end of the dock marked by 4 buoys |
| Hatchery | north `(0, -47)` | Plank floor, 4 posts, pitched brick roof, marble pedestal + straw nest holding the `EggStands/MeadowEgg` ball, shop counter with an **Eggs** sign, shelf of decorative eggs |
| Portal | south `(0, 60)` | Granite pillars and lintel topped with amethyst crystals, two shard-blue braziers (PointLights), the Neon `Portals/Portal_CrystalCaverns` part in the frame |
| Rebirth shrine | south-west `(-30, 22)` | Cobblestone disc, marble plinth with a glowing gold orb, 4 pillars and a **Rebirth** plaque (rebirth itself is done from the HUD) |
| Dressing | everywhere | 18 trees (Wood cylinder trunks + LeafyGrass sphere canopies), 10 lamps (Metal post, Neon lantern, PointLight), 2.5-stud hedge around the ground edge |

Ore-node veins are child parts of the node; `MiningService` re-tints them to the rolled ore's colour
(lerped 35 % toward white) and fades them with the rock when it is depleted.

---

## Workspace objects the scripts expect

Everything is **optional** — on startup `WorldService` creates any missing folder and, when a
folder has no parts in it, generates the defaults from `Config/Worlds.luau`. That is how Crystal
Caverns plays without a hand-placed model. To use your own map, build this tree (in Studio or as
a model file under `src/workspace/Worlds/`) and the server will adopt your parts (adding tags,
prompts and attributes itself).

Parts the server adopts are **renamed** (ore nodes), **anchored**, and ore nodes are **resized and
recoloured** per ore type. Decorative models can live anywhere else in the world folder; the
server only looks at the names below.

| Path (under `Workspace`) | Class | Required | Attributes read | Notes |
| --- | --- | --- | --- | --- |
| `Worlds` | Folder | no (created) | — | Container for all worlds. |
| `Worlds/<WorldId>` | Folder | no (created) | — | One per key in `Config/Worlds.luau` (`GrassyHills`, `CrystalCaverns`). Must be a `Folder` (not a `Model`) or the server creates a second one. Extra children (decor Models) are ignored. |
| `Worlds/<WorldId>/Ground` | BasePart | no (generated) | — | If present, its top centre becomes the world origin for any generated defaults. |
| `Worlds/<WorldId>/Spawn` | SpawnLocation or BasePart | no (generated for home world) | — | Where players arrive when they travel to / rebirth into this world. Only the home world gets a real `SpawnLocation` by default. |
| `Worlds/<WorldId>/OreNodes` | Folder | no (created) | — | Holds ore node parts. Empty ⇒ defaults from `oreSpawns` are generated. |
| `Worlds/<WorldId>/OreNodes/*` | BasePart | — | `Ores : string` e.g. `"Stone=10,Coal=4"` (optional; falls back to the world's `defaultOres`) | Server sets `OreId`, `Health`, `MaxHealth`, `Depleted`, `WorldId`, adds a ProximityPrompt and the `OreNode` tag. Child BaseParts (veins) are recoloured with the ore and faded when depleted. |
| `Worlds/<WorldId>/FishingSpots` | Folder | no (created) | — | Holds water parts. Empty ⇒ defaults from `fishingSpots` are generated. |
| `Worlds/<WorldId>/FishingSpots/*` | BasePart | — | `SpotId : string` (optional, must be globally unique; defaults to `<WorldId>_<PartName>`), `Fish : string` e.g. `"Minnow=10,Bass=5"` (optional; falls back to `defaultFish`) | Server sets `WorldId`, adds a ProximityPrompt and the `FishingSpot` tag. Players must stand within `FISH_INTERACT_RANGE` of the part's edge. |
| `Worlds/<WorldId>/EggStands` | Folder | no (created) | — | Empty ⇒ defaults from `eggStands` are generated. |
| `Worlds/<WorldId>/EggStands/*` | BasePart | — | `EggId : string` (an id from `Config/Eggs.luau`; falls back to the world's first egg) | Server adds a ProximityPrompt, label and the `EggStand` tag. |
| `Worlds/<WorldId>/Portals` | Folder | no (created) | — | Empty ⇒ defaults from `portals` are generated. |
| `Worlds/<WorldId>/Portals/*` | BasePart | — | `TargetWorld : string` (**required**, a world id) | Server adds a hold-to-travel ProximityPrompt and the `Portal` tag; checks `requiredRebirths`. |
| `ReplicatedStorage/Remotes` | Folder | no (created) | — | All RemoteEvents / RemoteFunctions from `Network.luau` are created here by the server. |

Ore ids: `Stone Coal Copper Gold Amethyst Diamond`. Fish ids: `Minnow Bass Trout Koi CaveEel GlowCarp CrystalPike AbyssAngler`.
Egg ids: `MeadowEgg CrystalEgg`. World ids: `GrassyHills CrystalCaverns`.

---

## Game design in brief

**Loop:** mine / fish → earn the current world's coins → hatch eggs → equip pets → stronger
mining / fishing → unlock rarer ores and fish → finish rebirth tasks + coin goal → rebirth for a
permanent coin multiplier and more pet slots → repeat, and unlock the next world.

**Per-world currency.** Each world has its own coin pool (`profile.coins[worldId]`): Grassy Hills
pays **Coins**, Crystal Caverns pays **Shards**. Eggs cost their own world's currency. Crystal
Caverns requires Rebirth 1.

**Mining minigame.** Press E on an ore node to start auto-swinging (one server-validated hit every
0.45 s). Each hit deals **Mining Power** damage; **Mining Luck** adds crit chance (×2 damage) and
a "Rich Vein" chance (×3 payout) when the node breaks. Nodes respawn with a re-rolled ore type.

**Fishing minigame.** Press E at the pond to cast. Bite wait = `base / (1 + Fishing Speed)`. When
the bite comes you have 1.6 s to reel (E / click / tap / button). The catch is rolled from the
spot's fish that your **Fishing Power** can hook (`requiredPower`), with **Fishing Luck**
multiplying rarer fish's weights.

**Pets.** Hatched from eggs with weighted rarities (Common → Legendary). Every pet is Mining- or
Fishing-focused and adds flat stat bonuses. Equipped pets' bonuses are summed:

```
MiningPower  = (1 + Σ pet MiningPower)  × (1 + 0.25 × rebirths)
MiningLuck   =      Σ pet MiningLuck
FishingPower = (1 + Σ pet FishingPower) × (1 + 0.25 × rebirths)
FishingSpeed =      Σ pet FishingSpeed
FishingLuck  =      Σ pet FishingLuck
Equip slots  = min(6, 3 + floor(rebirths / 2))
```

**Rebirth.** Allowed when *all* tasks are complete **and** home-world coins ≥ threshold:

| Task | Target at rebirth *n* |
| --- | --- |
| Break ore nodes | 40 + 20n |
| Catch fish | 20 + 10n |
| Hatch eggs | 5 + 3n |
| Find Rare+ ores or fish | 3 + 2n |

Coin threshold = `5000 × 1.6^n`. Rebirthing resets all coins and task progress, keeps pets
(`REBIRTH_KEEP_PETS`), increments the multiplier and returns you to Grassy Hills.

All numbers live in `src/shared/Config/` and `Formulas.luau`; nothing is hard-coded elsewhere.

---

## What is not done / untested

- No runtime test in Roblox Studio (see note at top). The starter world was verified structurally
  (Rojo build, instance names/attributes/PrimaryParts in the output, a top-down plot of part
  footprints) but has not been walked in-game; expect to nudge a few positions and sizes.
- Crystal Caverns still uses the generated default layout.
- Pets have no 3D models or follow behaviour — they are inventory entries with stat bonuses.
- No tool / pickaxe / rod animations; interactions are ProximityPrompt-driven.
- DataStore path is plain `SetAsync` without session locking (fine for a prototype, not for scale).
- UI is generated in code and tuned for desktop; it works on mobile but has no layout scaling.
