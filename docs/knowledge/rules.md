# Rules (R-nn)

Every rule the user gave, as records. Format per rule: `### R-nn Title`, then `Rule:`, `Source:` (quote, date, where),
`Gate:` (G-ids from [gates.md](gates.md), or `none yet`), `Applied:` (commits, modules, knobs), `Lessons:` (L-ids from
[lessons.md](lessons.md)), `Status:` (`active` or `superseded by R-mm`). Add with `tools/knowledge/learn.py rule`; never renumber.
Groups: World shape, Heights from the user's sheets, Water and bridges, Trees and props, Borders and cameras, Workflow.

## World shape

### R-01 Hoenn is a staircase of plateaus
Rule: every outdoor map is flat plateaus one course (sometimes two) apart, accumulating from 0 at the water or map edge; never a 0 floor with isolated spikes, never a jump of 3+ courses between neighbours unless the user drew one. Sea rocks stand 1/2/3 by footprint.
Source: user 2026-10-27, while drawing the height sheets: "cant you see that the worlds are built out of a bunch of plateaus? you keep imagining huge and drastic changes everywhere."
Gate: G-01, G-02
Applied: PLAN.md PLATEAU RULE; Gen3Elevation pin flood (phase 1, 803a37d); proposer cancelled (R-10).
Lessons: L-02
Status: active

### R-02 Per platform: classify every cell first, build second
Rule: on a pinned map every cell is exactly one of PLATEAU (at its number, trees and props included), FACE (between two plateaus), MASS (numbered rock, top = its number), WATER (surrounding water level, also under bridges), DECK (bridge / stair run) or BORDER. Nothing else gets rock; the gate counts unclassified rock cells and they must be 0.
Source: user 2026-10-27: "we NEED to make sure we do everything per platform and not just gung-ho build rocks everywhere."
Gate: G-02
Applied: classifier at the end of Gen3Elevation.field (c.cls), Gen3Blocks round 1 (3c234a4); Gen3Relief/Hills/Rock/Mass never run on a pinned map.
Lessons: L-01, L-03, L-30
Status: active

### R-03 An unnumbered rock band is a face, never a mass
Rule: a cliff band with no number on it is where the ground moves up or down between the two numbered plateaus beside it: top = the upper plateau, foot = the lower. Only a numbered rock is a mass. A face is never taller than its plateaus.
Source: user 2026-10-27, Route 119 weather station sheet (written into docs/elevation/README.md the same hour).
Gate: G-02, G-06
Applied: task 34 (0b); Gen3Elevation FACE class; blocks gate faceHigh (269 -> 50 at round 1b).
Lessons: L-01, L-29
Status: active

### R-04 A face band stands flat at the LOWER plateau, with the wall at its upper edge
Rule: the 2D draws two or three dark rows for one 16 px step. Those rows lie flat at the lower plateau, carrying their own dark art, and the one-course wall stands at the band's upper edge, where the art draws the edge. Never stand the band at the upper plateau: that moves every drop 2-3 cells south.
Source: user 2026-10-27 on the Gen3Blocks round-1 install: "the stones are in completely different places. completely mangled. I guess you just cant see it." (the rule is the fix that satisfied the user; the quote is the symptom)
Gate: G-06
Applied: Gen3Elevation.BAND_LEVEL='lower' + Gen3Blocks.UP_FACES (round 1b, d1c67c9).
Lessons: L-01
Status: active

### R-05 Rock tops are flat
Rule: a numbered mass is a flat-topped block at its number with faces for sides. No rounded, ridged, lathed, profile or parabola tops on a pinned map (no Gen3Relief hybrids, Gen3Hills PROFILE, Gen3Rock lids there).
Source: user 2026-10-27: "the tops of all those rocks are flat! so its really built like plateaus stacked on top of each other."
Gate: G-02
Applied: Gen3Blocks round 1; blocks gate massNotFlat = 0.
Lessons: L-03
Status: active

### R-06 Not a cube: faces lean about 5 percent, the top edge is slightly rounded, the top stays flat
Rule: every face (between plateaus and on a block) leans ~5 percent off vertical, top narrower than foot, with a small rounding (fillet, about a quarter course) where the face meets the flat top.
Source: user 2026-10-27: "the edges are slightly slanted, about 5 percent. so not 90 degree to the top. its not a literal cube. and the top edge also is slightly round."
Gate: G-07
Applied: Gen3Blocks LEAN=.05, FILLET=4 (round 2, 45e990b), per-height face ends.
Lessons: L-04
Status: active

### R-07 One course = 16 px everywhere
Rule: one drawn course is 16 px of height in every builder (Gen3Elevation.PIN_PX, Gen3Relief.LEVEL, Gen3Rock.COURSE agree). No per-builder course heights.
Source: user 2026-10-27: "if a tile is 16x16px lets do 16px height as well"
Gate: G-01
Applied: Gen3Relief LEVEL 24 -> 16 (d1c00c3).
Lessons: L-12
Status: active

### R-08 More depth than the flat original, from the object's own pixels
Rule: heights read off the oblique art are a floor, not a ceiling: props, furniture and structures get believable 3D proportions, filled by repeating their own pixels (never stretched, never invented colours). Terrain heights come from the user's pins (R-10), not from this rule.
Source: user 2026-10-05: "we must introduce more depth since we are making it 3d, the OG was super flat"; 2026-10-14 (Route 115 terrace): the user wants MORE than the cartridge's 10 px levels.
Gate: G-07
Applied: Gen3PixelFurnitureB recipes, building bakes, Gen3Hills rise 16.
Lessons: none
Status: active

### R-09 Same world as the original, in 3D; the pixel score is a fault finder, not the goal
Rule: the 3D does not have to match the 2D pixel for pixel; it must read as the same world. Use the ortho-45 overlay to find scrambled rows, missing parts, doubled or squashed models and wrong placement; accept deliberate differences (extra depth, roofs carried round the back, real trees).
Source: user 2026-10-13: "it doesnt need to be exactly like the og but it does [need] to be aesthetically in the same world as the og but in 3d"
Gate: G-06
Applied: tools/ortho45 (diff.py), docs/ortho45.
Lessons: L-01
Status: active

### R-10 Terrain heights are hand-drawn by the user, per map, relative to that map, water 0
Rule: the cartridge has no heights, so the user draws one number per flat area on docs/elevation/draw sheets; Claude transcribes to docs/elevation/pins/<MAP>.txt (x y height [top]). Courses are relative to each map's own 0, water is 0, connected maps get one offset at the seam. No proposer: "just skip the proposal sheets. im just gonna do everything by hand." Never regenerate docs/elevation/draw/*.png (draw_pack.py overwrites the user's marks).
Source: user 2026-10-27 (drawing sheets; proposer cancelled the same day).
Gate: G-01
Applied: tools/elevation/bake_pins.py -> lib/Gen3PinData.lua; Gen3Elevation pin zones; 64 maps / 1597 pins installed.
Lessons: L-02, L-10
Status: active

### R-11 Fit the user's drawing exactly where it marks; trust the pins over the 2D course count
Rule: the drawn cliff art between two numbers is the slope however many bands it shows (the 2D is inconsistent about course counts; the pins win). One wall of (hi - lo) courses, interpolated across the band.
Source: docs/elevation/README.md convention, user 2026-10-27.
Gate: G-01
Applied: Gen3Elevation pin flood + FACE class.
Lessons: L-29
Status: active

## Heights from the user's sheets (reading rules)

### R-12 How to read the user's marks
Rule: a loop or scribbled circle is 0; a 2 struck by a diagonal is 7; a comma between digits is a decimal (0,5 = 0.5, one mark); `^ up` is a stairs/ramp arrow; a number under a tree is the GROUND there; a number on a rock mass is that mass's top; `top` marks a ledge top, not a walkable plateau; a 0.5 platform sits a hair above the water it stands in. Read the marks from the PNG on disk at full resolution, never from the chat paste (a third of the size); use tools/elevation/find_marks.py and send the `_read.png` for the user's check.
Source: user 2026-10-27 (several sheets: Pacifidlog 0,5; Mt Pyre top; Route 121 (31,16)).
Gate: G-01
Applied: docs/elevation/README.md; task 35 reader session.
Lessons: none
Status: active

## Water and bridges

### R-13 Water is 0; under a bridge is water at the surrounding level; the deck is flat bank to bank
Rule: water stands at 0 in its map (a pool above a waterfall may carry its own number). A number on a bridge is the DECK's height; the cells under it are water at the water around them; the deck runs flat from bank to bank with no dip at either end. Connectors and stair runs between two EQUAL numbers are flat too.
Source: user 2026-10-27 (Route 120 top bridge, both banks 2, a hole in front of it): "the area UNDER a bridge is obviously WATER and should be the same height as the water around it"
Gate: G-01, G-07
Applied: task 34 (0c) connectors (396ec00): small unmarked runs between equal zones take that height; e0 flight cells between equal floors are flat.
Lessons: L-28
Status: active

### R-14 Waterfalls go straight up
Rule: a waterfall is a vertical sheet from the upper pool's level to the foot's level, never a ramp; the fall tiles take the highest water beside them.
Source: user 2026-10-27: "always go straight up, 90 degrees, never on a slant"
Gate: none yet
Applied: Gen3Elevation phase 1 (waterfall runs).
Lessons: none
Status: active

## Trees and props

### R-15 Trees on hills stand on their plateau
Rule: a tree cell belongs to the flat area round it and takes that area's pin, even though the cell is blocked; the tree gate counts tree cells sunk below or floating above every rim cell, target 0 sunk.
Source: user 2026-10-27: "a lot of mountains/hills had trees on top of them, we probably need to re-plant them after we have done the height of the terrain."
Gate: G-03
Applied: pin flood claims tree cells (507dd18); loose-tree pass after the pocket pass (223ef91): sunk 158 -> 3.
Lessons: L-11
Status: active

### R-16 Height fixes go in the field, never in c.base
Rule: Scene.groundAt (player, NPCs, camera) reads the floor field, so a per-cell c.base shift lowers the drawn ground and leaves the actors in the air. Per-map shifts go in Gen3Elevation (SINK_MAPS / the field); check with a driver that prints c.base and groundAt for a few cells.
Source: user 2026-10-26, Mossdeep "1 block too high" (first fix looked right in shots, actors floated).
Gate: G-10
Applied: Gen3Elevation SINK_MAPS (6966aff).
Lessons: L-13
Status: active

### R-17 Check the height map before patching the drawing
Rule: when ledges double, stairs flatten or a building "is not built", dump the floor field for those cells first (em_cells_driver / em_cell_info.lua); a wrong pin or pocket is the usual cause, not the drawing code.
Source: user 2026-10-14: "route 115 doesnt even have a double ledge?! you need to recheck the height map"
Gate: G-10
Applied: tools/elevation/qa/em_cell_info.lua, em_cells_driver dumps.
Lessons: L-23, L-26
Status: active

### R-18 Walk-under structures stay walk-under
Rule: before flattening or raising an over-layer piece drawn across a path, check whether the path continues under it (Ever Grande gates are arches).
Source: user 2026-10-07: Ever Grande's orange things are "arches where you walk through underneath".
Gate: G-07
Applied: Gen3LeagueGate.
Lessons: none
Status: active

### R-19 CRT sets are deep
Rule: PCs and TVs are old tube sets: near-cubes, depth about 4/5 of the width, never thin panels.
Source: user 2026-10-06: "those old school tube ones so they need to be a bit more like a cube"
Gate: G-07
Applied: Gen3PixelFurnitureB backZ.
Lessons: none
Status: active

### R-20 Not a bouncy castle (unpinned rock only)
Rule: rounded rock shoulders stay small (Gen3Rock SOFT_ROUND 3). On pinned maps this is superseded: tops are flat (R-05) with a small fillet (R-06).
Source: user 2026-10-14: "dont make it too round haha. its not a bouncy castle"
Gate: G-07
Applied: Gen3Rock SOFT_ROUND 3 (6d13a03); caves and unpinned maps.
Lessons: none
Status: active on unpinned maps and caves; superseded by R-05 and R-06 on pinned maps

## Borders and cameras

### R-21 Beyond the map edge: the border tile's family, never green steps
Rule: off-map fill follows the nearest edge cell's family (forest / mountain / water) or the map's border block, continuing the edge heights; a map whose rim is flat rock over sea gets sea at 0 (Gen3Boundary M.SEA, Sootopolis). Check which cells are border cells before judging a shot "trees everywhere" or "stairs in the void".
Source: user 2026-10-27 (Sootopolis (12,20)): crater rock or nothing, never green steps.
Gate: G-04, G-07
Applied: Gen3Boundary.resolve, M.SEA={EM_SOOTOPOLIS_CITY=0x279} (install B, 4833467).
Lessons: L-09, L-20
Status: active

### R-22 Judge from three cameras and from behind, against the 2D art, yourself
Rule: before installing, look at the play camera (L4, zoom -2), the low camera (L6) and the orbit camera (L7) at several yaws, including the back of objects, beside the original 2D crop. A capture that only shows the play camera is not a placement check (use G-06 for that).
Source: user 2026-10-05 and 2026-10-13: "Make sure to really look at the original pixel art carefully, and check in 3D from all angles, also the back."
Gate: G-06, G-07
Applied: cap_pins.sh + ab_sheet2.py (L4 + L6), em_shape_driver clay views, tools/em_ortho_driver.lua.
Lessons: L-01, L-05, L-07, L-08
Status: active

### R-23 QA must match the user's game
Rule: capture with QA_ZOOM=-2, sceneryProps "modeled", daytime day, tilt 2, and wait for the full build; otherwise the shots mislead. Rerun a capture run whose summary shows unexpected fallbacks before judging anything.
Source: user 2026-10-14 (Routes 104-115 walk, shots did not match the game).
Gate: G-05, G-07
Applied: tools/qa_run.sh, qa_tryp.sh (copies main QA options.lua).
Lessons: L-06, L-21
Status: active

## Workflow

### R-24 Go as far as possible without waiting for the user's look
Rule: never park a task on "waits for the user's look" or "needs a user screenshot": judge against the 2D art yourself, install when the gates pass, log it, move to the next task. Only a real design choice with two defensible answers gets a card; work continues on everything else meanwhile. The user does one eyeball audit at the end.
Source: user 2026-10-27: "go as far as agentically possible in voxelizing the entire world; indoors, outdoors, furniture, rocks, caves, routes, trees and misc. items. When you are completely done and you are happy with it, then I will look around, take screenshots and do a eyeball world audit."
Gate: G-09
Applied: PLAN.md STANDING RULE; tasks 11, 16-21 unblocked.
Lessons: L-27
Status: active

### R-25 Review the delegated work yourself, then fix the easy things directly
Rule: when a builder or side session reports done, read its sheets and diffs against the 2D art, run the gates, fix small things (pin files, knobs) directly and install; hand back only the hard ones.
Source: user 2026-10-25: "once they're done, I want you to step in, review their work and fix this issue once and for all! You are allowed to execute in case you see anything that you can easily fix."
Gate: G-07
Applied: coordinator role (Handoff: coordinator in PLAN.md).
Lessons: none
Status: active

### R-26 Install rule
Rule: install only with the game closed (pgrep -fl MacOS/love), backup under ~/Documents/gen1recomp-modwork/backups/<name>-<date>, source = game = QA, patch regenerated (tools/props/make_patch.sh), Emerald commit + push, one Log line in PLAN.md. The mod repo (~/Documents/battle-art-notquiteog) stays uncommitted: make_patch.sh needs its HEAD = upstream. Install QA-checked work without asking; push main every few commits; never push ROM-derived files.
Source: user 2026-10-05: "we also need to push once in a while"; "you can install your work, we can always refine".
Gate: G-05
Applied: tools/elevation/install_pins.sh, install_blocks.sh, install_trees.sh.
Lessons: L-15, L-17, L-31
Status: active

### R-27 QA runs are batched and never started by hand
Rule: every check goes in one tools/qa_run.sh or qa_tryp.sh call (boot costs ~8 s, each shot ~1 s; at most 3-4 QA games at once); never start the game binary directly (the old 0.1.50 shell takes over); never pkill -x love (kills the user's game and other sessions' runs).
Source: user 2026-10-06 (asked all agents to batch).
Gate: G-05
Applied: tools/qa_run.sh, qa_tryp.sh, the elevation gate scripts (3 QA copies in parallel).
Lessons: L-06, L-14, L-16, L-21
Status: active

### R-28 Before judging any rock change, check placement with the ortho-45 overlay
Rule: render the 3D from the 2D's own angle beside the art (tools/em_ortho_driver.lua + tools/ortho45/diff.py) for a few maps of each tileset and look at WHERE the dark bands and tops sit; only then look at the play camera.
Source: the fix that ended "completely mangled" (user 2026-10-27, round 1b); user 2026-10-13 asked for this rigor ("take his rigor", ZallaxDev's 3DS port).
Gate: G-06
Applied: docs/faults/pins/ORTHO_*.png per round since 1b.
Lessons: L-01
Status: active

### R-29 Measure what draws it; never guess from the picture
Rule: when something is wrong and the cause is not obvious, attribute it with a probe (em_probe_driver, Voxel3D.probe box, logActors, em_cell_info) before changing a builder. A tall object appears north of where it stands; a dark slab beside tall rock may be its shadow; a test that changes nothing in old|new is probably testing the wrong field.
Source: derived from the user's time lost on 2026-10-13 ("floating object" in Petalburg Woods) and the builder sessions of 2026-10-27.
Gate: G-07
Applied: tools/em_probe_driver.lua, tools/elevation/qa/em_cell_info.lua, em_cells_shape.lua, em_border_info.lua.
Lessons: L-05, L-07, L-14, L-19, L-24, L-25
Status: active

### R-30 One coordinator, builders report to it, sessions only on the user's go
Rule: one coordinator session talks to the user; builder and reader sessions report to it by SendMessage (addressed by TITLE); start_session only on the user's word (the app refuses it on a turn started by another session); no subagents and no side sessions on Claude's own initiative; every session carries a short title naming its task.
Source: user 2026-10-18 (subagents paused for usage), 2026-10-21 (automatic handoffs), 2026-10-27 (coordinator rhythm accepted).
Gate: G-09
Applied: ~/.claude/CLAUDE.md, PLAN.md Handoff: coordinator.
Lessons: L-18
Status: active

### R-31 One linear plan file; the handoff is written, not remembered
Rule: .claude/handoffs/PLAN.md is the only plan (Goal, rules, Tasks with one [NOW], Handoff under 300 words, dated Log). At the 250k context note the session writes lasting facts to this folder and to memory, one journal line, rewrites the Handoff, adds a Log line and starts the next session. Only what is written persists.
Source: user 2026-10-21 (automatic handoffs); user 2026-10-27: "are you learning?"
Gate: G-09
Applied: ~/.claude/CLAUDE.md handoff rules; docs/knowledge (this folder).
Lessons: L-22
Status: active

### R-32 The finish line is the ledger, and the scanners stay strict
Rule: "perfect" is measured by docs/DONE.md (Tier 1 blocks a release, Tier 2 never does) and docs/LEDGER.md; a fault class gets one session, unclosed faults are listed in docs/ledger/faults.json, never hidden by recalibrating a scanner; only the user sets a ledger row to done.
Source: user 2026-10-06: "every interior and exterior in the game is perfect"; user agreed to the finish-line plan 2026-10-19.
Gate: G-08
Applied: tools/release_check.sh, tools/ledger.py, tools/tour_note.sh.
Lessons: none
Status: active

## World shape, continued (rules given 2026-10-28)

### R-33 NEVER ON GRASS OR SAND
Rule: Grass and sand are always flat: never a 45 degree ridge and never a plateau step on them. A level change between plateaus happens only through a rock ledge (band tile = ridge wedge, or a rock face with the 5 percent lean) or a stair run. No ramp pass on plain ground; a bare drop between grass cells in the pins is a rock ledge face, or the pins are wrong.
Source: user 2026-10-28: "there are never 45 degree ridges or plateau differences on grass or sand! never. only rock ledges or stairs do that"
Gate: none yet
Applied: census tools/elevation/qa/em_stairs45_driver.lua + stairs45_analyze.py (foot riser 0, mismatches 0, steep = listed runs only); Gen3Elevation stairProfile pass (M.STAIR_PROFILE, M.STAIR_EXT, early + late call), TerrainLevels.at stairUp + Levels.stretch=false on pinned maps, Gen3Scene.flightTreads stepMid; installed 2026-10-28 (backup stairs-20261028)
Lessons: L-32
Status: active


### R-34 STAIRS FOLLOW THE 45 DEGREE PRINCIPLE
Rule: A stair run between two levels is the same wedge as a ridge band tile: about 45 degrees, one course of rise per tile, consecutive stair tiles stacking into one continuous slant. Never a vertical step and never a flat deck with a riser at one end. Equal pins at both ends still mean flat (DECK).
Source: user 2026-10-28: "stairs also adhere to the 45 degree principle"
Gate: none yet
Applied: see R-35 (hidden ledges) and the stairs builder (R-34), 2026-10-28
Lessons: L-32, L-33
Status: active


### R-35 Rock ledges ring the whole platform, hidden faces included
Rule: Every edge of a plateau is a 45 degree rock ledge, also the edges the top-down art hides (north-facing rims drawn as a line only, the edge behind a boulder, the edge under a tree row). Where the 2D has no band tile, the lower plain cell beside the edge becomes the ledge: a wedge in the face art of the nearest band from the rim down to the lower level, one course per row, convex corners rounded. The grass itself never slopes (R-33): the cell is rock there. Where the lower cell cannot take a wedge (a tree, tall grass, a stair, a mark) the riser is rock face art, never the rim's grass stretched down.
Source: user 2026-10-28: "elevating rocks are on a 45 degree angle, they are all around the platform"; on the Safari NW crops: "the ledge behind that rock is the same type ledge of 45 degrees", "there is also a ledge in the top left against the trees. this is also a 45 degree rock ledge"
Gate: G-11
Applied: Gen3Elevation HIDDEN LEDGES pass (M.LEDGES, LEDGE_MIN 8, LEDGE_MAX 3), Gen3Scene ledge slope + ledgeUV, Gen3Blocks.ledgeFaceUV (coordinator 3, 2026-10-28)
Lessons: none
Status: active


## R-ridge-slope: RIDGES ARE SLOPES
- Source: user 2026-10-27, Safari Zone SE sheet with yellow arrows: "the dark brown tiles are ridges that span from the one side of the tile to the other side of the tile but in 3 dimensions ... almost 45 degrees until the top (maybe 40?) ... They dont go up 90 degrees at all."
- Rule: an unnumbered band tile is a ~40-45 degree ramp across the whole tile from the lower plateau to the upper plateau; never a vertical wall. Supersedes the flat-band-plus-wall build of Gen3Blocks round 1b.
- Gate: ortho-45 overlay placement unchanged; a slope gate = band cells rise monotonically from their lower to their upper plateau across the band width.
- Clarified (user 2026-10-27, Route 114 panel): the band rows are the slope's footprint; the slope climbs across them toward the upper plateau, up AND over ("an angle and not a straight upward thing"); a multi-row band is one ramp over all its rows.
- WEDGES STACK (user 2026-10-27, cube-with-diagonal sketch + Safari N arrows): each band tile is a wedge, the cube cut by its diagonal (foot at the lower side, top at the upper side: one course per tile at 45 degrees); consecutive band tiles in the climb direction stack into one continuous slant, N rows = N courses.
- Applied by: Gen3Blocks.RAMPS (r1 aa14ea6, r2 022561d), Gen3Elevation RAMP_EXT ramp extension (2026-10-28); open: stair-side slit, tall bands left steep
