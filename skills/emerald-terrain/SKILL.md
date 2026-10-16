---
name: emerald-terrain
description: How to continue building the Pokémon Emerald 3D voxel mod (terrain, rock, hills, caves, ledges, forests, piers, railings) -- where the code is, how to test, how to find what draws a wrong object, the fix-by-class workflow, the user's taste, and what is still open. Read before touching anything in ~/Documents/battle-art-notquiteog or ~/Documents/Emerald.
---

# Emerald 3D -- terrain and rock skill

The project turns Pokémon Emerald (running in the LÖVE2D engine "gen1recomp") into a 3D voxel world
built from the original pixel art. The mod is Lua. The user walks the world, sends screenshots of
what looks wrong, and wants each problem fixed **by class** (one fix that cures every place with the
same cause), checked from several cameras, installed into their game, committed and pushed.

## 1. The user's taste (most important)

- Goal: "aesthetically in the same world as the original, but in 3D". Not a pixel-exact match.
  **More depth than the flat original is wanted** (the original's heights are a floor, not a ceiling).
- Original pixels 1:1. Never stretch a texture; repeat rows instead.
- Soft rock is liked, but "dont make it too round, its not a bouncy castle". Rounded edges at most ~3 px.
- "Wonky", "melted", "striped", "chunky", "floating", "double ledge" are the words to listen for.
- **Check the height map before changing a builder** (user caught a wrong height pin that I was trying
  to fix in the ledge drawing). Most "double ledge / pit / sunk building / floating" bugs are heights.
- Check every change from the **player camera (level 4)**, the **orbit camera (level 7, several yaws)**
  and the **low camera (level 6)**, including from behind.
- Write commit messages in plain language: what the user saw, why it happened, what it is now.

## 2. Where things are

| What | Path |
|---|---|
| Mod source (edit here) | `~/Documents/battle-art-notquiteog/lib/*.lua` |
| Repo with the patch, tools, docs (commit here) | `~/Documents/Emerald` (push `main` to origin) |
| User's real game | `~/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK/lib` |
| QA copy of the game | `~/Library/Application Support/pokemon-love2d-rseqa/...` (same layout) |
| Original art cache (read-only) | `~/Library/Application Support/pokemon-love2d-rseqa/emerald/data/generated/gba/` (`map_tree/census.json` lists maps -> slot, e.g. Route115 = `0_30`; `native/<pair>/` holds tile atlases) |
| Engine checkout (reference only) | `~/Documents/gen1recomp` (tag v0.3.52) |
| Helper scripts from this skill | `~/Documents/Emerald/skills/emerald-terrain/scripts/` |

Key Lua modules for terrain:

- `Gen3Scene.lua` -- builds every cell's geometry. Tree/forest canopy, piers (`shape.kind=='pier'`),
  the generic **step-wall pass** (closes any raised cell down to its lower neighbour -- it caused the
  "chunky pier"), cliff ground planes, SHAPE_BY_MAP per-map tile overrides.
- `Gen3Mass.lua` -- groups rock cells into masses (`M.prepare`, fixed map order, biggest first;
  `SPLIT_GENERAL` keeps the General pink mountain apart from a map's own rock); lone stones/boulders.
- `Gen3Rock.lua` -- rock built per cell in 16 px courses. `SMOOTH`+`SOFT` (soft rock, on outdoors),
  `SOFT_ROUND=3`, `SMOOTH_SKIP` (Mt. Pyre keeps blocks), `RUNFACE`, `FACE_TILE`, `NORTHCAP` (rock south
  of a path stays low so the player camera sees over it), caves: `CAVE_MAXH`, `CAVE_RISE=8`, `CAVE_EXTRA=24`.
  `M.handles` decides which builder a mass gets.
- `Gen3Hills.lua` (new) -- drawn hills as one rolling height field of 4x4 px facets. Maps in `M.MAPS`;
  `GENERAL_MAPS` = General mountain tiles count as hill; `PARAMS` per map: `TIERS` (Route 115: plateaus
  climbed column by column through the drawing), `ALL` (every rock mass is hill: Route 112, Mt. Chimney),
  `HMAX/RISE/LIP/FOLD`. Doors in a hill become an arch face; lava lies flat.
- `TerrainLevels.lua` -- the floor height solver. `CROWN_POCKET` (walk-under tree crowns in a forest
  take the forest's floor), `POCKET` (1-2 cell pits/bumps take the floor round them; fixed the sunken
  Weather Institute). `LEDGE_DROP`.
- `Gen3Elevation.lua` -- feeds the solver; `Gen3StairTerraces.lua` -- generated height pins per map
  (generator: `~/Documents/Emerald/tools/elevation/gen_stair_terraces.py`).
- `Gen3Outdoor.lua` -- ledges (`M.ledge`, `sideLedge` for east/west jumps). `Gen3Fence.lua` -- fences
  and Rustboro's railings (`alongPanel`). `Gen3EmeraldShapes.lua` -- what each tile is.

## 3. Testing (never start the game binary directly)

- `pgrep -fl "MacOS/love"` first; the user's own game may be running -- that's fine, QA uses other identities.
- Try changes in a private QA copy (runs in parallel, never touches the real game):
  `scripts/try.sh "Gen3Rock.lua Gen3Hills.lua" <outdir> "{'EM_ROUTE115',27,46},{'EM_ROUTE112',27,29}" "4,7" 0.8`
  - Cases are `{'MAP_ID',x,y}` on a walkable cell. Levels: 4 player, 6 low, 7 orbit; last arg = yaw (radians).
  - Batch many cases into one call (each launch boots ~8 s). Up to ~4 runs in parallel.
  - Extra case fields (furniture driver): `dump={x0,y0,x1,y1}` prints `[CELL]` lines (tile, shape,
    collision, base height, mass, `f.*` solver fields) to `<outdir>/run.log`; `box={x0,x1,z0,z1}` (world px,
    cell*16) prints which cell's code emits geometry there; `probe={...}` lists meshes in a box.
  - `EM_FLASH=1` before the command lights dark caves.
- Baseline of the current installed state: `cd ~/Documents/Emerald && QA_ZOOM=-2 tools/furniture/shot.sh <outdir> "<cases>" "4,7" 0.8 60`.
- Contact sheet: `scripts/sheet.sh <outdir> out.png 2`. Look at every image yourself.
- QA's options are set to match the user (zoom -2, scenery props modeled) plus daytime for judging shapes.
- Original art: `python3 scripts/crop2d.py <slot> <pair> x0 y0 x1 y1 out.png [scale] [ids]`
  (labels tile id, collision, elevation), `python3 scripts/grid.py <slot> x0 y0 x1 y1 e|m` (text grid of
  elevation/blocked or tile ids), `python3 scripts/tiles.py <pair> 0x230 0x26F out.png 6 8` (tile sheet).
- Height probe for "something floats": copy `~/Documents/Emerald/tools/em_probe_driver.lua`, set map,
  spot and `Scene.probeY`, run with `EM_DRIVER=<copy> tools/qa_tryp.sh "Gen3Scene.lua" <out> "-" 4`.
- Build time: `tools/em_times_driver.lua` (copy, edit map list).

## 4. Workflow for each screenshot / problem

1. Locate it (map + cell), reproduce in QA at the same camera.
2. Look at the original art (`crop2d.py`) and the heights (`dump=`). Decide the **class** of fault.
3. Fix the class in the right module, with a comment saying what it looked like and why.
4. `luajit -bl <file>` to syntax-check. Try at 4/6/7 cameras on the reported spot.
5. **Regression sweep**: same spots before/after on many maps (one rock-heavy spot per map; 75 outdoor,
   51 caves). Compare side by side by eye -- PSNR is useless (time of day drifts between runs).
   If a fix regresses elsewhere, remove it rather than tune it.
6. Install: back up the real files to `~/Documents/gen1recomp-modwork/backups/<date-name>/`, copy the
   changed `lib/*.lua` into BOTH the real game and QA, then `diff -rq` source vs real vs QA must be empty.
7. Patch + commit + push:
   `cd ~/Documents/Emerald && OWN_LIB_EXTRA="lib/Gen3Rock.lua lib/Gen3Hills.lua lib/Gen3StairTerraces.lua lib/TerrainLevels.lua lib/Gen3Fence.lua" bash tools/props/make_patch.sh`
   then `git add patches/battle-art-voxel-fork.patch` (+ any tools), commit, `git push origin main`.
   Grep the patch for a string of your change to confirm it is in. Never commit ROM-derived files.
8. Tell the user to restart the game; send a before/after sheet.

## 5. Lessons that cost hours

- Iterating `pairs()` gives a different order each load: any flood/grouping must run in sorted map order.
- The first scene build is a small area (`Gen3Scene.NEAR`); captures taken too early show cut-off rock
  (the furniture driver now waits).
- Something wrong may be drawn by a different code path than you think: blank the suspected branch
  (`if false and ...`) once and look; use `box=`.
- A building stands on the floor in front of its door; a wrong floor there sinks the whole building.
- zsh does not split `$VAR` lists in `for f in $LIST` -- write the names out.
- Leave other sessions' files alone; check `git status` in the mod tree before editing (it has a large
  staged set from other work -- don't commit the mod tree, only the Emerald repo patch).
- **`os.getenv` is stubbed out inside the mod sandbox** (`[warn] os.getenv was removed from the mod
  sandbox`). Any mod code gated on `os.getenv(...)` silently never runs, so a debug flag written that
  way looks like "the bug is not here". Gate debug code on a value the *driver* sets, or print
  unconditionally and filter the run log.
- **The module table the driver gets is not the one the build uses.** `export.lib.require('Gen3Scene')`
  in a driver returns a different instance than the one building cells (`Scene.streaming`,
  `M.builds`, `M.quadLog` are nil on the instance the build sees), and the mod sandbox has its own
  `_G`. So state cannot be injected into the builder from a driver. To attribute geometry, print from
  inside the mod to stdout and grep `<outdir>/run.log`.
- A "floating plate" seen from the orbit camera may be an **in-map** mountain top, not the boundary
  fill: Route 112's west margin shows the Heights-style rock cells (x 0..17, y 31..40, base 48) whose
  tops are drawn and whose sides/back are not closed, and the fill beside them floats as well. Check
  `dump=` for whether the cells in the shot are inside the map before blaming `Gen3Boundary`.
- The game process **cannot write outside its own save directory**: `io.open('/tmp/...','w')` succeeds
  and writes nothing. Hand the file handle from the driver (`Scene.geoFile=f`) instead.

## 6. Open items (as of 2026-10-16)

- **Route 112's west margin still shows flat plates hanging over the drop** from the orbit camera at
  `{'EM_ROUTE112',6,45}` / `{'EM_ROUTE112',12,45}` (yaw 1.6). Two separate faults are involved:
  1. *fixed:* the boundary fill beside the west edge rode up to the map edge's own level (nearest-floor
     donor) and stood 16 px over the ground it touches. `Gen3Elevation.supportFill` now seeds each fill
     cell from the ground it actually touches (one COURSE at a time, closed onto the map's floor when
     it touches none). Verified in the data: the fill band went 48 -> 32.
  2. *open, and why the obvious fix fails:* the **in-map** rock cells (x 0..17, y 31..40, `base=48`,
     `mid` 0x203/0x211/0x218/0x271) show their tops without a closed side. In `Gen3Scene`'s cliff
     branch the two closure loops only close onto *floors* (the first) and onto *mass* geometry whose
     neighbour has a different mass (the second), so two rock cells of the same mass at different
     terraces leave the upper one's edge open.
     Closing it in `Gen3Scene` (either course-by-course or one quad per side) **tipped the scene build
     over its budget**: every QA capture of Route 112 then fell back to the flat map view
     (`fallback` in `run.log`), for both the per-course and the single-quad variant. Reverted. The
     closure has to come from the mass builder (`Gen3Mass`/`Gen3Hills`) without adding per-cell quads,
     or as an instanced batch. Measure the budget with `grep -c fallback <outdir>/run.log` after any
     change here.
     Attribute with `tools/em_attrib_driver.lua`; the stdout geometry logger pattern is in Lessons.

     **The plates are real floating surfaces, and these are ruled out** (each tried, rendered and
     reverted; the pixel scan below proves the gap, so do not re-litigate them):
     - *Pixels first.* Sampling a vertical line through a plate in the orbit shot gives
       `S...S ggggg SSSSSSSSSSSSSSSS ....` - sky ABOVE the green band and sky BELOW it, terrain
       only much lower. So it is a surface with air under it, not a thin band against a backdrop.
       Script pattern: decode the PNG, classify a colour as sky, print one letter per row.
     - boundary fill height: fixed (`supportFill`), and it does not move the plates.
     - `Gen3Mass` column floors clamped to the lowest floor of their own mass: correct-looking,
       cheap (49 frames vs 48), rendered - plates unmoved.
     - fill-tree `treeY` forced to the tree's own `c.base` (Gen3Scene, canopy block): plates unmoved.
     - per-cell rock side closure in `Gen3Scene` (two variants): both stalled the build.
     Next place to look: the fill cell's OWN ground plane. `Gen3Scene`'s canopy branch computes
     `treeY = c.canopyBottom` (the lowest/nearby walkable floor of the whole canopy GROUP) and draws
     the ground plane at `treeY` while lifting the cell's other geometry by `c.base`; for a fill tree
     whose group ends at a lower walkable cell, ground and canopy can part company by a course or
     more. Print `c.cx, c.cy, c.base, c.canopyBottom, treeY` for the boundary tree cells in the shot
     before changing anything.
- Fill outside Route 112's west map edge floats as stepped plates (visible only from the orbit camera).
- Mt. Pyre: **done 2026-10-16, user's choice.** `Gen3Rock.SMOOTH_SKIP` now lists only
  `EM_MT_PYRE_EXTERIOR`, so the exterior's drawn graveyard terraces stay crisp blocks (soft rock made
  a mess of those walls) while the summit's outer mountain gets the soft rolling treatment. The
  exterior render is pixel-identical to before; sweep over Mt. Chimney, Routes 114/112/104 and
  Rustboro clean. A/B: `docs/shots/mtpyre-rock-block-vs-soft-2026-10-16.png`.
- Rustboro's lamp posts: diagnosed 2026-10-16, **user approved a restyle to match the art**.
  What the art draws (`0_3 general__rustboro`): the lamp block is 2 cells wide and 2 tall - head in
  the row above the foot row, `next_mid` 0x300/0x302 over 0x05E (four cells: 0x05E, 0x05E / 0x300,
  0x302). In the drawing the lamp is a *slender* navy post (about 2 px wide) with a flared foot, a
  collared waist and a pale BLUE glass lantern under a peaked cap - 16 px wide, 32 tall in total.
  In 3D the post comes out roughly twice as thick as drawn and the lantern does not read at all:
  the cap overhangs it, so the head is a dark layered slab with the pale glass hidden inside.
  Ruled out: the `RUSTBORO_RAIL` pins (blanking 0x300/0x301/0x302 for that map changed nothing), so
  the rail mapping does not build the lamp; the shape comes from the tile art itself, and no module
  in the mod names these tiles.
  Two independent fixes, both still to do:
  1. the shape - a lamp builder (see `Gen3AshPine` for the pattern: a PINS entry in
     `Gen3EmeraldShapes.lua` returning a shape flag, plus an append call in `Gen3Scene.lua`) that
     lays each drawn crown row as a ring as wide as the drawing's outline in that row, which is how
     the pines get their exact silhouette; 1 px per row is the taste (never stretch).
  2. the lantern glass - `GlassMask` finds windows by SHAPE (a border row of six black texels, four
     or five rows of glass) and the Emerald facade detector then looks only at wall and door cells,
     judging a pane by colour (`b - r >= 48`, or `>= 36` when dark). The lamp's lantern is a washed
     pale blue that fails that test, so the lamp never lights after dark while the Pokemart's
     windows beside it do.
     *Tried and reverted (2026-10-16):* registering the lamp tile (`0x302`) as a facade tile and
     adding the lantern's rect to the mask through `GlassMask`'s existing pixel-exact `ov.add`
     path - twice, once with a hand-pinned rect and once with the rect **measured from the tile**
     (pale, blue-leaning pixels inside a mostly-dark 16x16). Neither made the lantern glow in a
     night render. The mask is only one of the gates: `Voxel3D` samples it with `glassOn`, and a
     SPOT/card geometry (see the `part.panes` / card paths in `Gen3Scene`) may not carry the mask
     at all, so check which draw path the lamp's head actually uses before trying again.
     A night render is easy to make: a driver that sets `DayNight.setting:setIndex(3,game)` (index
     3 = "night", `DayNight.rigTime()` then reads 900) and shots at level 7.
  Comparison image: `docs/shots/rustboro-lamp-art-vs-3d-2026-10-16.png`.
  Lamp art lives in the MIDDLE atlas layer: the native pair has `atlas_u_*`, `atlas_m_*` and
  `atlas_o_*`, and the lamp's drawing is not in the under layer (reading only `atlas_u_*` shows
  the plaza speckle and makes it look as if the tile were empty).
- Route 104 pier planks still read as separate slats up close (low priority, user's own ranking).
  Reviewed again 2026-10-16 and left alone: the brief records that an earlier attempt to fill the gaps
  between the boards looked *worse*, so the next move must not be "fill them". Current state at
  `{'EM_ROUTE104',8,42}` and `{'EM_ROUTE104',10,55}`:
  `docs/shots/route104-pier-slats-2026-10-16.png` - the deck is yellow-brown boards with dark posts
  under them and a visible gap between adjacent boards; the fix has to come from the pier's own
  drawing (`Gen3Scene`, `shape.kind=='pier'`), making the boards read as one deck without repeating
  a row or stretching a texel. Ask the user what they want before spending time here.
- Wait for the user's next walk-through screenshots; they are the work queue.
