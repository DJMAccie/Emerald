# Emerald 3D — brief for the next agent (written 2026-10-05)

Read `HANDOFF.md` first (paths, rules, test commands). This file is the work queue: what is done, what is
half-done, and exactly what to do next, in order. The user's bar is "perfect": every visual change is checked
in a capture before it is installed, and nothing is installed that looks worse than before.

---------------------------------------------------------------------------------------------------------

## 0. Ground rules (each one has already cost hours)

1. **One game instance.** Before every QA run or install: `pgrep -fl "MacOS/love"`. If anything prints,
   wait. The user may be playing.
2. **Two identities.** Real game: `~/Library/Application Support/pokemon-love2d`. QA:
   `~/Library/Application Support/pokemon-love2d-rseqa`. Every capture runs on QA. The real game is
   touched only to install verified files.
3. **Source of truth** is `~/Documents/battle-art-notquiteog/lib`. Workflow:
   1. Edit there.
   2. Syntax-check: `luajit -e "assert(loadfile('X.lua'))"`.
   3. `rsync -a ~/Documents/battle-art-notquiteog/lib/ "<QA>/mods/BATTLE_ART_VOXEL_FORK/lib/"`.
   4. Capture.
   5. Compare before/after.
   6. Only then copy the changed files to the real game.
   7. Back up any replaced real file *outside* `mods/` first (e.g. `~/Documents/gen1recomp-modwork/backups/<date>/`).
   8. Never leave a backup folder inside `mods/` (it gets loaded as a second mod).
4. **Never commit ROM-derived data**: `world.json`, atlases, captures, `.rgba`, ROMs, `.dsm` packs.
   The Emerald repo holds only patches, tools and docs.
5. **Debug prints inside the mod**: `os.getenv` does not see variables set on the command line (the mod
   is sandboxed). Use a module flag such as `Gen3Objects.log=true` for a run, then set it back to false.
6. **Name clash**: `Gen3Scene.lua` already has `local Objects=require('src.core.game3.objects')` (NPCs).
   The generic-object module is bound as `local Standing=V.require('Gen3Objects')`. Don't shadow it.
   If the scene silently falls back to 2D, the log says `scene fallback: ...` and the driver prints
   `active false rendered 0`.
7. **Temporary debug edits** (dumps, prints) must be reverted with a guaranteed restore step. Don't chain
   the restore behind `&&` after a command that can fail.
8. **Never copy code from absol89/DramaticShapeVoxelMod.** That repo has no licence; re-implement ideas only.
   The MIT lineage is the DramaticShape / Gen2Recomped reference under
   `~/Documents/gen1recomp-modwork/refs/`.

## 1. How to test (copy-paste)

Captures (run from `~/Documents/gen1recomp`, in the background, then wait for the process to exit):
```
POKEPORT_DRIVER=$HOME/Documents/gen1recomp-modwork/tools/em_views_driver.lua \
POKEPORT_IDENTITY=pokemon-love2d-rseqa POKEPORT_GAME=emerald \
SHOT_DIR=<dir> EM_CASES=<cases.lua> EM_WAIT=70 \
/Applications/gen1recomp.app/Contents/MacOS/love . > <log> 2>&1
```
- `<cases.lua>` is `return {{'EM_RUSTBORO_CITY',14,22},...}` (map id, a WALKABLE x, y).
- Output: one PNG per case, `<MAP>_4.png` (camera level 4).
- Afterwards, check the log has zero `fallback` lines and grep it for `error`/`traceback`.
- Before/after comparison: run once with the old QA lib, rsync, run again, then
  `ffmpeg -i before.png -i after.png -filter_complex hstack pair.png`. Zoom with PIL crops.
  Tiny thumbnails hide defects.
- Useful views used this session:
  - Rustboro 14,22 (lamp posts)
  - Route 120 12,56 (boulders)
  - Mossdeep 4,7 (sea boulders) and 24,19 (tree cluster)
  - Route 104 8,42 (fences, sea rock)
  - Route 104 6,19 (flower shop: must stay a building)
  - Battle Frontier east 40,22 (Battle Palace) and 4,8
  - Sootopolis 31,26 and 10,50 (crater rock, rim)
  - Route 126 40,52 (rock island)
  - Mt. Chimney 20,23
  - Route 114 30,53
  - Route 112 19,29
  - Route 111 32,84
  - Lavaridge 10,10
  - Dewford 12,8 (grove)
  - Lilycove 22,8 (railing)
  - Slateport 4,20 (fence)
  - Mauville 30,6
  - Route 119 20,70 (grey trees, see 3.1)
  - All towns: `~/Documents/gen1recomp-modwork/cases_alltowns.lua`
- A full regression set (23 views) takes about 15 minutes. Use it before every install.

Offline (no game, seconds; run from `~/Documents/gen1recomp`):
- `luajit ~/Documents/gen1recomp-modwork/tools/shape_audit.lua` (a copy is in `tools/`).
  - It counts blocked cells left flat.
  - The `OUTDOOR` section is after `Gen3Objects`.
  - It cannot run the pixel tests (rock banks, groves, cut-out ink), so the in-game result is better than its number.
- `tools/analysis/` holds the scripts built this session. They need the QA cache, not committed data:
  - `layers.py`: read the u/m/o atlases of a tileset pair. `u` = bottom+middle composite;
    `o` = above-player layer, same slot order.
  - `render.py`: render any map with cells outlined. It needs `unknown.json` from
    `luajit dump.lua > unknown.json` in the same folder.
  - `comps.lua` → `comps.json`: every unknown blocked component outdoors. Used by `rockcls.py` / `rep.py`
    (the rock-vs-building classifier prototype).
  - `groups.lua` + `sheet_obj.py`: contact sheet of small object groups and their cut-outs.
  - `faces.lua`: floor groups either side of cliff bands (for the terrace work, 2.1).

## 2. State right now

**Installed in the REAL game and committed** (Emerald repo `da2ab87`, patch
`patches/battle-art-voxel-fork.patch`, verified to apply on base `03882a9`):
- **`lib/Gen3Objects.lua`** (new), run from `Gen3Scene` as `Standing.bank` → `Standing.joinRock` → `Standing.prepare`:
  - **Generic objects:** small groups of blocked, unrecognised cells on outdoor maps (12 cells or fewer, 4×4 or smaller).
    - Each is cut from its neighbours' ground pixel by pixel. Ground candidates are all walkable neighbours; tiles with above-player art count only as a last resort. There is a 2-pixel edge peel.
    - Each becomes a rounded voxel slab of its own pixels (`VoxelHull`).
    - The walk-behind row joins (lamp heads, sign tops).
    - Low objects (no walk-behind row) stand at half height.
  - **Fence lines:** long 1-wide lines of repeated tiles are split into 4-cell pieces. East–west pieces are thin slabs; north–south pieces are extruded upward.
  - **Rock banks:** a rock mass drawn as repeated texture (tile repeats 6+ times in view, not green/blue, thick) becomes `shape.bank`. Door-bearing groups (behaviour 0x60 or 0x69) where rock is under 60% are buildings and are left alone.
  - **Rock rims:** blocked unknown cells touching a cliff join it when 60% or more of their palette matches.
  - **Groves:** large foliage groups (mean green share ≥ .45).
    - Packed canopy (≥ 50% of tiles solid after the cut, e.g. Dewford) becomes a canopy bank.
    - Trees on open ground (Mossdeep) become per-cell slabs with crowns.
- **`Gen3EmeraldShapes.lua`:**
  - Blocked + behaviour `MOUNTAIN_TOP` (0x0C) becomes a cliff of its own art; walkable ones stay flat.
  - Sea boulders `0x150/151/158/159/15C/175–17F` become `cliff` with `bank=true` (height 14, slope 16).
- **`Gen3Terrain.lua`:**
  - Bank profile: per-shape `slope`, smoothstep foot, art draped top-down, shade by slope.
- **`Gen3Scene.lua`:** hooks; no ground plane under banks.
- **Result:** flat blocked cells game-wide went 37,892 → 19,641 (offline count; lower in game).

**In QA only, NOT installed, NOT committed** (working tree of `battle-art-notquiteog`):
- `Gen3Terrain.lua`:
  - `thickness()`: a band of rock 1–2 cells thick is capped at 13 per cell of thickness. This targets the spikes at band corners and junctions.
  - Thin-band cap measured from the lower floor and never below the upper one (`cap()` in `M.height`).
  - **Only partly verified:** Mt. Chimney still showed one wedge at a band end with the first half. The second half (`cap`) has not been captured yet.
- `Gen3Objects.lua`: `shade()`. Pixels that are the ground pixel darkened by one factor (45–90%) count as
  painted drop shadow, so they're dropped from cut-outs. Targets the grey wedge under Rustboro lamp posts.
  **Not yet captured.**
- **First task:** capture Mt. Chimney, Route 114, Route 111, Rustboro and the full regression set.
  - If they're better: install, regenerate the patch, commit.
  - Regenerating the patch: `cd battle-art-notquiteog && git diff HEAD > new.patch`, check it with
    `git apply --check` in a `git archive 03882a9` extraction, then copy it to `patches/`.

## 2b. User's verdict, end of 2026-10-05 session — READ THIS FIRST

The user looked closely and says **most tiles look completely mangled**. They are right. My captures
were judged from thumbnails, which hide this. Be far more critical: review every change at full
resolution (crop + 2× nearest-neighbour zoom), from level 4 AND the free camera (level 7, several
`EM_YAW` values).

Confirmed defects, with the root cause:
- **Pokémon Center / Mart roofs (every town):**
  - The 2D roof drawing already contains its own 3/4 perspective (curved ridge, gable, logo). It is
    texture-mapped onto a sloped 3D roof, so the result has double perspective.
  - There is a grey plane visible behind the gable, a floating overhang corner at top right, and plain
    stretched grey side walls.
  - Files: `Gen3Scene.lua` (roof/wall column branch), `Gen3RoofDetails.lua`, `RoofEaves`, `Gen3Civic.lua`.
  - Direction: model the Center/Mart as a known landmark (template geometry: box + roof volume) and map
    only the parts of the art that face that way:
    - Front wall: facade rows.
    - Roof front slope: roof rows.
    - Sides, back and unseen roof: colours sampled from the art (no stretched pixels).
- **Shorelines / cliffs (Route 104 between the grass and the water, every coast):**
  - The brown cliff-face art is stretched down vertical faces as smeared stripes.
  - The sand rim becomes stair-steps per tile, and seams show on the caps.
  - Files: `Gen3Terrain.lua` (`append`: side texture mapping), `Gen3EmeraldShapes` cliff ids, `CliffMasonry.lua`.
  - Direction: a face should repeat the face drawing at native pixel scale (one 16-unit tile per 16
    units of height, never stretched). Coast edges should follow the drawn outline smoothly, not per tile.
- **Littleroot moving truck:** it is a flat leaning CARD (billboard), not a 3D box. The user says a
  texture exists. Find it (grep `truck` in `battle-art-notquiteog/{lib,data,assets}` and
  `gen1recomp-modwork/cases_truck.lua`, `shots_truck/`) and build a real box truck: cab, cargo box,
  wheels.
- **Interiors: "completely broken"** per the user. Not examined this session. Capture every interior
  type first (see 3.4) and make the worst-first list before touching code.
- **ELEVATION: the biggest structural fix.** The user sees Mossdeep, Lilycove and Sootopolis as "flat
  ground with weird 3D formations that don't make sense". Staircases show where the levels change.
  - **Root cause, verified offline 2026-10-05:**
    - The height solver (`TerrainLevels.build`, called from `Gen3Elevation.field`) raises floors only
      across stair cells with behaviour `0x2A` or `0x1D0` and across ledge drops.
    - Emerald's staircases carry NEITHER. The count of `steps` cells / beh `0x2A` is **0** in Mossdeep,
      Lilycove and Sootopolis.
    - So every map solves to one flat level, and every cliff stands on that floor as a free-standing wall.
  - **The cartridge already states the levels:** the per-cell **elevation** nibble (grid bits 12–15,
    `raw.elev` in `Gen3Elevation`, `layout:elevAt`):
    - Mossdeep has 0:917, 1:968, 3:430, 4:33, 5:510, 7:230, 9:112 cells.
    - Lilycove has e0/e1/e3/e5.
    - Sootopolis has e0/e1/e3.
  - An overlay of Mossdeep's elevations on its map (`tools/analysis/render.py` plus grid bits 12–15)
    matches the drawn terraces exactly:
    - The town sits low.
    - The hill rises in steps of e5 and e7.
    - The Space Center plateau is e9.
    - The white staircases sit exactly on the level boundaries.
  - **Gen 3 convention:**
    - 3 = normal ground; each step up (4, 5, …) is a level higher.
    - 1 = surf water.
    - 0 = transition cells: stairs, cliff faces and edges, connectors that join any level.
    - 15 = multi-level (bridges).
  - Today `Gen3Elevation` uses `layer` only to SEPARATE floor groups. Its `seed` lifts e4 by 6 units.
  - **Do this:**
    1. In `Gen3Elevation.field`, give each walkable cell with elev ≥ 3 a pinned height of
       `(elev-3)*COURSE`. COURSE ≈ 16 world units, one tile; tune by eye: the staircase must look like
       a believable flight. Use the existing `pin` mechanism (`cell.pin`, already supported by
       `TerrainLevels.build`: a group takes the median pin of its cells).
    2. Water (elev 1) stays at the sea level of its map (0). Sea and town levels must still meet at the
       shoreline: water is at 0 and the town at e3 = 0.
    3. Elevation-0 walkable cells (stairs, ramps): treat as flights between the levels they connect.
       Recognise a staircase as an e0 strip with different levels on its two ends, and give it a stepped
       or ramped surface (`Gen3Stairs`, `Stairs.append`, the `steps` kind; mark these cells `step=true`
       so `TerrainLevels` builds a flight).
    4. Cliffs and banks between two levels then automatically become retaining walls: `Gen3Terrain.height`
       uses the neighbouring floor heights (`high>low → top=high`). Check that faces are not stretched
       (see the shoreline item above).
    5. Buildings, props, NPCs and the player must stand on their cell's level:
       - `Elevation.bind` sets `c.base`; `groundHeight` for assemblies.
       - Actors use `Gen3Scene.groundAt`.
       - Check that the player sprite and NPCs are not floating or buried.
    6. Apply it everywhere: Lilycove, Sootopolis, Mossdeep, Fortree, Route 112/114/111, Mt. Chimney
       and Lavaridge.
       - This supersedes the authored pins in `Gen3EmeraldTerraces.lua`, which can stay disabled.
       - It also supersedes the "thin band" spike hacks: once floors are at the right levels, a 1-tile
         face band between e3 and e5 is just a wall between two terraces.
    7. Verify with free-camera captures (`EM_LEVELS` {4,7}, several `EM_YAW`) that stairs connect the
       levels and nothing floats.
- **General rule from now on:**
  - Never map a 3/4-view drawing onto a surface it was not drawn for.
  - Front faces get the art drawn for them; tops and sides get either top/side art where it exists
    or flat colour sampled from it.
  - Prefer templates for well-known repeated landmarks (Center, Mart, Gym, houses, truck, boats)
    over generic extrusion.

Settings changed for the user this session:
- **Real game `options.lua`** (backup: `~/Documents/gen1recomp-modwork/backups/2026-10-05-real-lib/options.lua.before-encounters`):
  - `BATTLE_ART_VOXEL_FORK.tiltshift = 2`: top/bottom miniature blur ON, which the user wants.
  - `overworld_wild_spawns.random_encounters = false`: no grass step encounters. The user wants to battle
    only visible overworld Pokémon they walk into or talk to.
  - `overworld_wild_spawns.enable_hidden = false`: no invisible grass markers.
  - Edit `options.lua` only in byte mode. It contains non-UTF-8 bytes, so a UTF-8 rewrite fails.
    The game rewrites it, so never edit it while the game runs.
- **Real game, installed:** `Gen3SceneOptions.lua` (T-SHIFT default 2) and `RenderDistance.lua` (distance haze
  starts at 90% of the view edge instead of 80%; full-map mode 0.8 instead of 0.55). The user disliked
  the "blue fog around". Backups of the previous versions are in the same backup folder.
  Verify the result with the user; tune `TiltShift.PRESETS[2]` if the blur should be stronger or wider.
- **Verify in the real game that visible Pokémon still trigger battles** when walked into or talked to,
  and that no grass encounters happen.
- **Birds (Wild Skies) "gone" in the real game:**
  - Mod files are identical to QA, and it is enabled in the profile.
  - In QA with the user's exact Wild Skies + spawn settings, Wingull sit on the water, but no flock in
    the air was seen at level 4.
  - `lua-error.log` in the real identity is old (1 October, from a `.bak` mod copy) and not relevant.
  - Next: run QA for longer (`EM_WAIT=300`) on a route with Taillow/Wingull, look at the sky with a free
    camera, read `wild_skies/lib` for what gates spawning (time of day? density "low"? needs encounter
    tables, which may have been affected by `random_encounters=false`?), then ask the user where they
    expected birds.

## 3. Work queue, in order

Priority now (the user's list): **ELEVATION from the cartridge's elevation nibble (see 2b — do this
first; it reshapes every terrace map), mangled tiles (Center/Mart roofs, shorelines), the truck,
interiors, battle 3D animations, birds** — then the rest below.

### 3.1 Pale grey "ghost" trees (high visibility, pre-existing)
- **Where:** Route 119 near the player, and on the horizons of Routes 110 and 120. They're conifer-shaped and pale grey-green.
- **Ruled out:**
  - Tree-atlas exhaustion: a fresh session with Route 119 first is still grey.
  - Fog on instanced meshes: `placedVertex` runs before fog in `Voxel3D`.
- **Found:**
  - On Route 119 the in-game `NativeTreeArt` atlas holds only ONE card, so these trees do not come from the native-art card path.
  - The Route 119 tree roots in the shape tables are canopy trees `0C6/0C7/0CE` (`G.canopyTree`, scale .6) and narrow trees `016/017` (`G.narrowTreeRoot`).
  - Their canopy art is ONLY on the above-player layer (`o`); the bottom layer is plain grass.
- **Next steps:**
  1. Log in `Gen3Scene` (tree branch) which path these cells take: `TreeStyle.original()`, `voxel()`, `native.gen3(c)` returning nil, or `addInstance` failing.
  2. Note: `NativeTreeArt.gen3` caches cards by an id that includes only `art[1][1]` and `#art`.
  3. Also check whether `Gen3Boundary` / world fill draws these (cells outside the map use `Boundary.resolve` and can be "forest" biome trees).
  4. Expected fix: they should look like Route 104's green round trees, made from their own art. If the native card comes back empty, composite the `o` layer (it already tries via `pixel()`), or build the card from `ts.overImageData` alone.

### 3.2 Truck in Littleroot (user request)
- The moving truck in Littleroot Town is still flat, but a texture for it exists.
- Previous work lives in `~/Documents/gen1recomp-modwork/cases_truck.lua` and `shots_truck/`, so look there first.
- Also look for the truck art in `battle-art-notquiteog/assets` / `data` (grep `truck`), and at how other landmarks are built (`Gen3Civic.lua`, `data/gen3_exteriors`, the `civic` path in `Gen3Scene`).
- **Goal:** a closed 3D box using the existing texture: cab + cargo box, wheels, correct footprint on its tiles. Verify from levels 4 and 7 (free camera, `EM_LEVELS` file returning `{4,7}`, `EM_YAW`).
- Likely more of these exist: other unique landmarks drawn as tiles (boats at Slateport/Lilycove docks, Cycling Road pillars, Space Center rocket, Mt. Pyre). Once the truck works, list them with `tools/analysis/sheet_obj.py` and fix them the same way.

### 3.3 Battle 3D animations (user request — details not yet specified)
- The user said "fix the battle 3 animations".
- What exists:
  - All 386 Pokémon use 3D battle models: Stadium 2 for #1–251, Colosseum packs for #252–386.
  - 30 fps; rest pose = idle; send-out timing tuned.
  - Files: `lib/Gen3Battle.lua`, `Gen3StadiumModels.lua`, `StadiumModels.lua`, plus the importer fork `~/Documents/stadium2-importer` (Colosseum loader).
  - Test driver: `tools/em_battle_driver.lua` with `EM_PLAYER_SPECIES` / `EM_FOE_SPECIES` (national numbers).
- **Start by asking the user which animations are wrong** (attack? faint? idle? Hoenn vs Kanto models?).
- Then capture a battle for a Kanto (#25) and a Hoenn (#258) species, before you change anything.
- Known open items:
  - Shiny colour swap for Hoenn models.
  - Colosseum models for #1–251 as a toggle.

### 3.4 Indoor maps (never reviewed)
- Interiors have not had the building-style review: house interiors, Marts, Centers, gyms, labs.
- Relevant files: `Gen3EmeraldInteriors.lua`, `Gen3InteriorProfiles.lua`, `Gen3Furniture.lua`, `InteriorDiorama.lua`.
- Existing cases: `~/Documents/gen1recomp-modwork/cases_interiors.lua`.
- Method:
  1. Capture every interior type once (Littleroot houses, Birch's lab, an Oldale Mart, a Center, Petalburg Gym, a route house, Devon Corp).
  2. Make a contact sheet.
  3. Fix the worst first: furniture lying flat, walls open to the camera, floating props.
- Note: `Gen3Objects` / banks only run when `Pairs.outdoor(def)` is true, so interiors are untouched by this session's work.

### 3.5 Rock and terrace polish
- **Mt. Chimney / Route 114 / Route 112 terraces.** Cliff-face bands between floors render as ridges, because both floors sit at the same height.
  - Real terraces need the floor north of a face band raised.
  - `Gen3EmeraldTerraces.lua` holds authored levels for Fortree, Route 112 and Sootopolis (MIT, from the reference mod). It is `enabled=false`.
  - Faces are now drawn by `Gen3Terrain` (a cliff between two floor heights becomes a retaining wall), so try enabling it and capture those three maps.
  - Generic inference: `tools/analysis/faces.lua` shows that many face bands have the SAME floor group on both sides (floors connect around band ends), so inference is not trivial. Prefer authored pins per map, checked visually.
- **Sootopolis outer rim** is a high flat plateau. Consider a lower `BANK_HEIGHT` for very large masses, or a height that grows with distance from the edge.
- **Dewford canopy bank** reads terraced. Try a smaller `GROVE_HEIGHT`/`GROVE_SLOPE`, or a smooth mound across the whole grove.
- **Mossdeep cluster:** the two rear trees look dark (cells `355` etc. are blocked crown+trunk mixes).
- **Route 113 ash field:** the olive bush slabs look odd up close.

### 3.6 Buildings still listed as wrong (from HANDOFF)
- Plain block behind the contest-hall domes (Lilycove).
- Mart/Center roof cap shows a solid box behind the arch.
- One Sootopolis house.
- Fallarbor house roof patch (tiles `0x328/0x329`).
- Route 110 pink building roof (Trick House).
- Battle Frontier ground sometimes renders sky-coloured.
- Fortree tree houses look like dark boxes (seen in the 2026-10-05 survey).
- Method: `EM_INDEXED=1 EM_CASES=cases_buildings.lua EM_WAIT=110` → `shots_bld/bNNN.png` + `[BLD n]` grids.
  `tools/bld2d.py <n>` crops the original art.

### 3.7 Remaining flat blocked cells
- About 9,000 outdoor cells are flat by the offline count.
- Run `shape_audit.lua`, take the top kinds, and render each with `render.py` before deciding.
- Never blanket-convert by size or colour alone. This session's false positives:
  - The Battle Pyramid, Battle Palace and the Route 104 flower shop looked like rock.
  - The Battle Palace outline looked like a fence.
- Leave blocked water (Route 119 bridge `206/20F`) flat.

### 3.8 Queued features (after the above)
- Glowing windows at night.
- 3D followers / wild Pokémon.
- Colosseum trainer models.
- Round "lathe" trees (`treeArtwork='round'`, never judged).
- **Tilt-shift already exists:** mod option T-SHIFT (`tiltshift` 0–3). It's OFF in the real game and 1 in QA. Don't edit the user's `options.lua`; they switch it in game.

## 4. Known facts worth not re-deriving
- Doors: behaviour `0x60` = non-animated door (also cave entrances), `0x69` = animated door.
- `MOUNTAIN_TOP` (0x0C) marks whole mountains; blocked ones are rock.
- The `u` atlas already contains bottom+middle. Above-player art (`o`) carries crowns, lamp heads and roof edges.
  A walk-behind tile is a walkable cell with `o` art.
- Thresholds in `Gen3Objects.lua` (all `M.*` at the top):
  - `MAX_CELLS=12`, `MAX_SPAN=4`, `MIN_INK=.06`, `RUN=4`
  - `GROVE=.45`, `GROVE_HEIGHT=22`, `GROVE_SLOPE=10`
  - `REPEAT=6`, `BANK_HEIGHT=24`, `BANK_SLOPE=14`, `MATERIAL=.6`
- absol89 1.11.1: no Gen 3 code, no licence. Ideas worth re-implementing: a smooth "bank" distance field, a
  faceted boulder, primitives clipped to each tile, connected fence posts, prop templates.

## 5. Definition of done for each item
1. Before/after captures at level 4 (and level 7 for anything 3D-shape related), zoomed crops reviewed.
2. Full regression set: zero `fallback`, zero errors, nothing worse.
3. Installed to the real game (with a backup), patch regenerated and checked, committed in
   `~/Documents/Emerald` with a clear message, `HANDOFF.md` updated. Do not push unless the user asks.
