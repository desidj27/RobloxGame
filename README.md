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
2. Press **Play**. The server generates both worlds (ground, ore nodes, pond, egg stand, portals)
   at runtime, so the empty Workspace in the file is expected.

### Option B — sync with Rojo (recommended for development)

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then in this folder run `rokit install`
   to get the pinned Rojo / selene / StyLua from `rokit.toml`.
   (Or grab the [Rojo release](https://github.com/rojo-rbx/rojo/releases) binary directly.)
2. Install the Rojo plugin into Studio: `rojo plugin install`.
3. Serve the project: `rojo serve default.project.json`.
4. In Studio open any place (or the prebuilt one), click **Rojo → Connect** (default
   `localhost:34872`). Scripts under `src/` now live-sync into the place.
5. Press **Play**.

### Build the place file yourself

```sh
rojo build default.project.json -o build/MiningFishingSim.rbxl
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

---

## Project layout

```
default.project.json         Rojo tree: src/shared → ReplicatedStorage.Shared,
                             src/server → ServerScriptService.Server,
                             src/client → StarterPlayer.StarterPlayerScripts.Client
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
```

---

## Workspace objects the scripts expect

Everything is **optional** — on startup `WorldService` creates any missing folder and, when a
folder has no parts in it, generates the defaults from `Config/Worlds.luau`. That is how the
prebuilt place plays with an empty Workspace. To use your own map, build this tree in Studio and
the server will adopt your parts (adding tags, prompts and attributes itself).

Parts the server adopts are **renamed** (ore nodes), **anchored**, and ore nodes are **resized and
recoloured** per ore type.

| Path (under `Workspace`) | Class | Required | Attributes read | Notes |
| --- | --- | --- | --- | --- |
| `Worlds` | Folder | no (created) | — | Container for all worlds. |
| `Worlds/<WorldId>` | Folder | no (created) | — | One per key in `Config/Worlds.luau` (`GrassyHills`, `CrystalCaverns`). |
| `Worlds/<WorldId>/Ground` | BasePart | no (generated) | — | If present, its top centre becomes the world origin for any generated defaults. |
| `Worlds/<WorldId>/Spawn` | SpawnLocation or BasePart | no (generated for home world) | — | Where players arrive when they travel to / rebirth into this world. Only the home world gets a real `SpawnLocation` by default. |
| `Worlds/<WorldId>/OreNodes` | Folder | no (created) | — | Holds ore node parts. Empty ⇒ defaults from `oreSpawns` are generated. |
| `Worlds/<WorldId>/OreNodes/*` | BasePart | — | `Ores : string` e.g. `"Stone=10,Coal=4"` (optional; falls back to the world's `defaultOres`) | Server sets `OreId`, `Health`, `MaxHealth`, `Depleted`, `WorldId`, adds a ProximityPrompt and the `OreNode` tag. |
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

- No runtime test in Roblox Studio (see note at top).
- Pets have no 3D models or follow behaviour — they are inventory entries with stat bonuses.
- No tool / pickaxe / rod animations; interactions are ProximityPrompt-driven.
- DataStore path is plain `SetAsync` without session locking (fine for a prototype, not for scale).
- UI is generated in code and tuned for desktop; it works on mobile but has no layout scaling.
