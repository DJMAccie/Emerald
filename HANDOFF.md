# Emerald 3D ("Utali") — handoff brief

Pokémon Emerald in gen1recomp (LÖVE2D/Lua) with a 2.5D/3D voxel overworld, original pixel art,
and 3D Pokémon models in battle. This file is everything a new session needs.

## Goal and taste
**The goal (user, 2026-10-05):** a 3D vibe for Emerald with four pillars:
1. A voxel world true to the original art.
2. Overworld Pokémon: battle only those you walk into or talk to; no grass encounters.
3. A Pokémon following you. Works (user confirmed 2026-10-05).
4. Stadium/Colosseum-style 3D battles.
- "2D/3D cartoony, slick, **no artifacts**." Original Emerald art on real 3D boxes.
- Stock Emerald battle UI, classic flat water, few flying birds, 3D ledges/grass with a breeze.
- Buildings must be well-formed, checked **one by one**. Reference look: warm evening light,
  clean simple buildings, no haze. Trees and grass must hold up from above (not flat cards).
- Wants to publish it open source as his own mod.

## Where everything is
| What | Path |
|---|---|
| Real game data (never touch while the game runs) | `~/Library/Application Support/pokemon-love2d` |
| Test copy ("QA") | `~/Library/Application Support/pokemon-love2d-rseqa` |
| Voxel mod source (fork of notquiteog/DramaticShapeVoxelMod) | `~/Documents/battle-art-notquiteog` |
| Stadium 2 importer fork (+ Colosseum packs loader) | `~/Documents/stadium2-importer` |
| Engine checkout (reference only) | `~/Documents/gen1recomp` at tag **v0.3.52** (updated 2026-10-05 at the user's request; the old v0.3.38 local edits are in `git stash` there and in `~/Documents/gen1recomp-modwork/engine-local-edits-v0.3.38.patch`, not re-applied: not needed so far) |
| Tools, capture drivers, map data, screenshots | `~/Documents/gen1recomp-modwork` |
| Colosseum model pipeline | `~/Documents/colosseum-work` |
| MIT Hoenn reference mod | `~/Documents/gen1recomp-modwork/refs/Gen2Recomped-DramaticShapes` |
| This repo (patches + tools, no game assets) | `~/Documents/Emerald` → github.com/DJMAccie/Emerald (private) |

Installed mods (real): BATTLE_ART_VOXEL_FORK, STADIUM2_IMPORTER (+ `baseroms/stadium2.z64`,
`colosseum/` packs), animated_menu_pokemon (Kanto in Motion, patched), wild_skies,
overworld_wild_spawns. Engine: official 0.3.40 payload, **no custom engine patch needed**.

## Rules that cost hours when broken
1. Check `pgrep -fl "MacOS/love"` before every QA run or install. The app allows one instance,
   and the game rewrites `options.lua`.
2. Never leave backup folders inside `mods/` (a `.bak` copy was loaded as a second mod).
3. The app is fused: `love .` ignores the checkout and runs the payload in `<identity>/updates/`.
   If QA shows no Emerald, copy the real `updates/*.love` and `emerald/` cache into QA.
4. The auto-updater replaces engine payloads; don't depend on engine patches.
5. Verify every visual change with a capture **before** installing. Install = rsync
   `battle-art-notquiteog/lib/` → `<identity>/mods/BATTLE_ART_VOXEL_FORK/lib/`.

## How to test (all from `~/Documents/gen1recomp`)
```
POKEPORT_DRIVER=~/Documents/gen1recomp-modwork/tools/em_views_driver.lua \
POKEPORT_IDENTITY=pokemon-love2d-rseqa POKEPORT_GAME=emerald \
SHOT_DIR=<dir> EM_CASES=<cases.lua> EM_WAIT=90 \
/Applications/gen1recomp.app/Contents/MacOS/love .
```
- Cases file: `return {{'EM_OLDALE_TOWN',10,10}, ...}` (map id, player x, y). `EM_LEVELS` picks camera
  levels (4 = default 50°, 7 = free camera, honours `EM_YAW`). No `timeout` on this Mac: background
  the process and poll.
- **All buildings:** `EM_INDEXED=1 EM_CASES=cases_buildings.lua EM_WAIT=110` → `shots_bld/bNNN.png` and
  `[BLD n]` classification grids in the log. Contact sheets: ffmpeg `tile=3x3`. `tools/bld2d.py <n>`
  crops the labelled original art for building n. `tools/crop.py` enlarges part of a capture.
- **Battles:** `tools/em_battle_driver.lua` with `EM_PLAYER_SPECIES` / `EM_FOE_SPECIES` (national numbers).
- **Offline classifier (no game, seconds):** `luajit ~/Documents/gen1recomp-modwork/tools/shape_audit.lua`
  (run from `~/Documents/gen1recomp`) runs the mod's own shape tables over every map and reports
  props on water ground, blocked cells left flat, and an OUTDOOR section after `Gen3Objects`.
  Pixel-based tests (object cut, rock banks) only run in game.
- Debug prints inside the mod: `os.getenv` sees nothing the capture command sets; use a module
  flag (`Gen3Objects.log`). `Gen3Scene` already has a local `Objects` (NPCs) — don't shadow it.
- Regenerate tile tables: `python3 tools/gen_emerald_tables.py . out.lua` (in modwork) → copy to
  `battle-art-notquiteog/lib/Gen3EmeraldAuto.lua`.

## How the world is built (key files in `battle-art-notquiteog/lib`)
- `Gen3EmeraldShapes.lua` — what each metatile is (hand tables + behaviour bytes + generated tables).
  Unknown = flat. `ROCKY` whitelists tilesets whose guessed cliffs may stand up.
- `Gen3EmeraldAuto.lua` — generated (door-anchored building boxes, floors, cliffs).
- `Gen3TileShape.lua` — `emeraldBuildings`: touching columns form one box with one facade line.
- `Gen3Scene.lua` — geometry: walls, roofs (`roofType` front/twoTier/lowRidge/flat), props, actors
  (lean + slab depth), `debugCell` for audits.
- `Gen3RoofDetails.lua` — roof profiles and the roof texture bake (closes transparent gaps).
- `Gen3Outdoor.lua` — ledges, grass tufts, awnings, plant cut-outs. `Gen3Terrain.lua` — cliffs (dome).
- `Gen3Boundary.lua` — fills outside the map from the map's border block.
- `NativeTreeArt.lua` — trees from their sprite; `lathe` = new round style (`treeArtwork='round'`).
- `Gen3Battle.lua`, `Gen3StadiumModels.lua`, `StadiumModels.lua` — battle stage, models, camera orbit.
- `Voxel3D.lua` — shader (breeze, card lean). `RenderDistance.lua` — haze.

## Where we are (read these, in this order)
1. [docs/LEDGER.md](docs/LEDGER.md): generated coverage per map and area, open faults, audit numbers. Regenerate with `python3 tools/ledger.py --write`.
2. [docs/DONE.md](docs/DONE.md): what blocks a release (Tier 1) and what never does (Tier 2); one session per fault class.
3. The newest file in `.claude/handoffs/` for the task in flight (older ones are history).
4. New faults go in `docs/ledger/faults.json` (`tools/tour_note.sh`); the user's tour screenshots find them.
Dated status, the 2026-10-05 problem list and the old next steps: [docs/history/HANDOFF-2026-10-05.md](docs/history/HANDOFF-2026-10-05.md) (not read by default).
