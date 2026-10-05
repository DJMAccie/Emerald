# Emerald 3D ("Utali") — handoff brief

Pokémon Emerald in gen1recomp (LÖVE2D/Lua) with a 2.5D/3D voxel overworld, original pixel art,
and 3D Pokémon models in battle. This file is everything a new session needs.

## Goal and taste
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
| Engine checkout (reference only) | `~/Documents/gen1recomp` |
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

## State right now
Working and installed: all 386 Pokémon as 3D battle models (Stadium 2 #1–251, Colosseum #252–386,
30 fps, rest pose = idle), send-out timing, stock UI, building boxes (107 reviewed), rounded rocks,
3D ledges and grass with breeze, HD-2D character stance, tree ring around towns, haze pushed to the
far edge, props no longer sit on a square of sea.

Options: T-SHIFT (tilt-shift, `tiltshift` 0–3) and DAYTIME (`daytime` sync/day/dusk/night/cycle)
already exist in the mod's options. QA is set to dusk + tilt 1; the real game is on defaults.

2026-10-05 (b) (installed in real + QA, committed `6c511c2`): two QA-only follow-ups from (a) are
now verified and shipped. `Gen3Terrain.thickness()` caps a rock band 1-2 cells thick at
`NARROW*thickness`, measured from the lower floor and never below the upper one (`cap()`), so a
band end cannot rise above the terrace it holds up. `Gen3Objects.shade()` drops pixels that are
the ground pixel darkened by one factor (45-90% per channel) — a painted drop shadow — from the
cut-out. Verification: a per-cell height-field diff (old vs new `M.height` over every cliff cell
of Mossdeep, Mt. Chimney, Route 114, Sootopolis) shows 0 samples raised and 408 lowered, all by
exactly -6 units, i.e. only over-tall thin bands move; the offline audit is bit-identical either
side (9011 flat, 469 objects); 25-view set plus a 4-yaw level 4/7 sweep show zero fallbacks and
zero errors. `shade()` has no effect at Rustboro 14,22 (those lamps carry no such shadow).
Patch `patches/battle-art-voxel-fork.patch` was regenerated, `git apply --check`ed on a fresh
`git archive 03882a9`, and the applied `Gen3Terrain`/`Gen3Objects` are byte-identical to the
installed files. Backups: `~/Documents/gen1recomp-modwork/backups/2026-10-05-thinband-cap/`.
Repo hygiene: `.qa-stage/` (511 mod-source files swept into `a09f015`/`6334370`) is now untracked
and ignored, along with `.DS_Store`; those blobs remain in history — ask before rewriting.

2026-10-05 (a) (installed in real + QA): `lib/Gen3Objects.lua` stands unrecognised blocked art up
(cut from its ground pixel-by-pixel, rounded voxel slab of its own pixels, walk-behind row joins;
low objects half height; fence lines split into thin pieces, north-south ones extruded); blocked
`MOUNTAIN_TOP` (beh 0x0C) cells are cliffs of their own art; rock drawn as repeated texture
(Sootopolis crater, Route 126) and sea boulders are **banks** (`shape.bank`: eased mound, art draped
top-down, `Gen3Terrain`). Flat blocked cells: 37,892 → 19,641. Backup of the replaced real files:
`~/Documents/gen1recomp-modwork/backups/2026-10-05-real-lib/`.

## Known problems, in priority order
1. **Tiles / objects lying flat.** ~9,000 outdoor blocked cells still flat by the offline count
   (much less in game: rock and grove tests need pixels). Groves the tables miss are handled in
   game (packed canopy → canopy bank, e.g. Dewford; trees on open ground → per-cell slabs with
   their crowns, e.g. Mossdeep). Left: building pieces, blocked water under the Route 119 bridge
   (`206/20F`, should stay flat). Props (lamps, signs, bushes, planters) use the generic slab and
   read well; templates only worth it for rare landmarks (boats, benches). Minor: spikes on
   Mt. Chimney walls, odd slope strips on Route 114, Sootopolis rim plateau flat-topped, Dewford
   canopy terraced, two Mossdeep rear trees dark.
2. **Building leftovers:** plain block behind contest-hall domes; Mart/Center roof cap shows a
   solid box behind the arch; one Sootopolis house; Fallarbor house roof patch (tiles 0x328/0x329);
   Route 110 pink building roof; Battle Frontier ground renders sky-coloured in captures.
3. **Trees:** round "lathe" style is written but never run. Current trees are blocky voxels.
4. **Not done:** glowing windows at night; shiny colour swap for Hoenn models; Colosseum models for
   #1–251 as a toggle; 3D followers/wild Pokémon; Colosseum trainer models; real terraces
   (`Gen3EmeraldTerraces.enabled=false`).
5. Interiors and routes have not had the building-style review.

**User's verdict, end of the 2026-10-05 session (see `docs/NEXT-AGENT-BRIEF.md` 2b).** Most tiles look
mangled, and the captures above were judged from thumbnails, which hid it. Judge every change at full
resolution (crop + 2x nearest-neighbour zoom) and from level 4 *and* free camera (level 7, several
`EM_YAW`). Confirmed: Center/Mart roofs map a 3/4 drawing onto a sloped roof (double perspective, grey
plane behind the gable, floating overhang); shorelines stretch the cliff-face art into smeared stripes
and stair-step the sand rim; the Littleroot truck is a leaning card; interiors are "completely broken".
Biggest structural fix: **elevation from the cartridge's per-cell elevation nibble** (grid bits 12-15).
`TerrainLevels.build` only lifts across behaviour `0x2A`/`0x1D0` stairs and ledges, and Emerald's
staircases carry neither, so Mossdeep/Lilycove/Sootopolis solved flat and every cliff stood as a
free-standing wall on one floor.

**DONE and installed (2026-10-05 (c), commit `c01dd81`).** `Gen3Elevation` now pins the floor height
from the nibble: a walkable non-water cell with `elev>=3` gets `min(elev-3, M.MAX_STEP) * M.COURSE`
(`COURSE=16`, `MAX_STEP=3`). Two things are load-bearing and easy to get wrong:
- **Grouping must be exact** (`a.layer==b.layer`). `TerrainLevels` gives a group the *median pin* of
  its cells, so the old `a.layer==0 or b.layer==0 or a.layer==15 or b.layer==15` relaxation merges a
  whole town into one group. Measured: Mossdeep flattened to 1959 cells at a single height.
- **The e4 `seed` must be 0.** It was a stand-in for the one-step floors the nibble states outright;
  on top of a pin it lifted every e4 floor twice, and a stair flight added +80 more (Fortree's
  walkway read 96 instead of 16).
Solved heights now land on the drawn terraces: Mossdeep 0/16/32/64/96, Lilycove 0/32,
Fortree 0/16/48, Route 114 0/16/32/64. Flat maps are untouched (Rustboro, Mauville, Slateport,
Petalburg, Oldale solve to one height either way). Evidence: 65 captures (terraced set at 4 yaw
angles x levels 4 and 7, plus the 25-view set), zero `fallback`, zero errors. Notes:
`docs/ELEVATION-NOTES.md`.

Stair flights are now implemented too (commit `991d89d`): a walkable elevation-0 cell whose walkable
neighbours disagree about their elevation is claimed as a step, and `TerrainLevels` builds a flight
from it. Measured offline: 19 cells claimed (Route 114 8, Mossdeep 7, Lilycove 4), each run yielding
one flight bridging the drawn levels (Route 114 16→0, 32→16, 48→32). Fortree, Sootopolis and
Route 111 claim none, which matches their maps. The in-game change is confined to the stair cells
(0.2–0.6% of the frame).

Still open: Fortree's `e15` is a "very high" sentinel that `MAX_STEP` clamps rather than describes, and
the new retaining faces still show the stretched-texture defect below. NPC/player grounding on
terraces has not been checked by a human playing.


## Recommended approach for the tile problem (new philosophy)
Stop guessing shapes per tile. Use what the cartridge states and one generic fallback:
- **Certain things get real geometry:** water, ledges, grass, rails (behaviour bytes); buildings
  (door-anchored boxes); known trees; cliffs in rocky tilesets.
- **Everything else that is blocked is an "object":** group connected blocked cells plus the
  walk-behind cells above them (art on the above-player layer), cut the original art out from the
  ground colours, and stand it up as a thin slab of its own pixels on the ground its neighbours
  use. No invented hulls, so nothing can look mangled; nothing blocked is left lying flat.
- Guard cases to test first: pond/shore edges and blocked mountain tops must stay ground; fences
  already have behaviours. Use `shape_audit.lua` to count before/after and capture the top offenders.
- The MIT reference mod calls this class `prop/billboard (per-pixel slab)`; its
  `data/gen3_shapes.lua` has hand pins worth porting per tileset.

## Next steps (suggested order)
1. Polish the minor rock/grove artifacts above; prop templates only for rare landmarks (ideas
   from absol89 1.11.1 — no Gen 3 code there and **no licence**: re-implement, never copy).
2. Fix the building leftovers above; re-run the 107-building sheets.
3. Run and judge the round trees (`treeArtwork='round'` in `modOptions.BATTLE_ART_VOXEL_FORK`).
4. Review routes and interiors with the same sheet method.
5. Glowing windows at night, then the five queued features in item 4 above.
6. Publishing: this repo holds patches against upstream commits (`patches/*.base` names them) and
   tools. Never commit ROM-derived files (`world.json`, `atlases/`, captures, `.dsm` packs, ROMs).
   Licences: DramaticShape lineage is MIT; notquiteog's fork and the Stadium importer ship no
   licence file (ask the authors before a public release); the Colosseum converter uses StarsMmd's
   GPL-3 parser. Kanto in Motion needs its 4-line fix in `lib/gen3_frlg.lua` (capture upstream once).
