# Lessons (L-nn)

Each mistake that cost a round, a gate run or a user correction, as a record: `### L-nn Title`, `Symptom:` (what the user or a
gate saw, quoted where possible), `Wrong model:` (what the session believed), `Cause:`, `Fix:` (commit / knob), `Proof:` (the tool
or sheet that showed it), `Rules:` (R-ids in [rules.md](rules.md)). Add with `tools/knowledge/learn.py lesson`; never renumber.

### L-01 Face bands stood at the upper plateau: every cliff edge moved 2-3 cells
Symptom: user 2026-10-27 after the Gen3Blocks round-1 install: "the stones are in completely different places. completely mangled. I guess you just cant see it."
Wrong model: a band's dark rows are the top of the upper plateau, so the whole band stands at the upper number.
Cause: the 2D draws 2-3 face rows for one 16 px step; standing them high turned face art into flat top art and put the drop 2-3 cells south of where the art draws the edge. Play-camera sheets did not show it.
Fix: Gen3Elevation.BAND_LEVEL='lower' + Gen3Blocks.UP_FACES (round 1b, d1c67c9): band flat at the lower plateau with its own art, the wall at its upper edge.
Proof: the ortho-45 overlay (docs/faults/pins/blocks/ORTHO_AB.png) showed it at once; it did not exist before this round.
Rules: R-03, R-04, R-09, R-22, R-28

### L-02 The height proposer imagined a flat world with spikes
Symptom: user 2026-10-27: "cant you see that the worlds are built out of a bunch of plateaus? you keep imagining huge and drastic changes everywhere." Route 113 proposed 6 where the user's max is 3; Route 122 all 0; Route 127 sea rocks 3-4 where the user marks 1-2.
Wrong model: heights are rare dramatic events on a 0 floor; score = per-mark error.
Cause: no plateau prior; the nibble carries no height on mountains; tile signatures repeat only within a tileset. Held-out score 25% within half a course.
Fix: proposer cancelled by the user ("everything by hand"); the plateau rule became the build rule; judge any height proposal by its histogram against the user's pins.
Proof: tools/elevation/learn/score_proposed.py; docs/elevation/proposed/ (kept, never regenerated).
Rules: R-01, R-10

### L-03 A vertex cap cannot make flat tops
Symptom: Mt Pyre exterior (20,20) showed a notch (teal plateau seen through a gap between rock columns) even with MAXFALL=0; Route 129 a water hole.
Wrong model: lowering the existing rock builders' vertices to the plateau beside them is enough.
Cause: a cap only lowers tops; it cannot make a flat top, a lean or a fillet, and the old builders still ignore the pins.
Fix: a dedicated pinned-map builder (Gen3Blocks) that replaces Gen3Relief/Hills/Rock/Mass on pinned maps, driven by the classifier.
Proof: docs/faults/pins/faces/SHEET_*.png; prototype kept in tools/elevation/plateau_proto for the hook point only.
Rules: R-02, R-05

### L-04 A leaning face's end must be a function of height
Symptom: sky slits of LEAN x height at corners where a tall column met a lower band (Route 112 (16,30)/(20,30), low camera only).
Wrong model: one constant inset per face end is enough.
Cause: a tall column's end is "convex" (full inset) while the lower band beside it sees the same corner as "concave" below its own top.
Fix: endAt(i,j)(y) in Gen3Blocks.append classifies per height (concave / collinear / plain wall / diagonal / own convex corner); courses break at the neighbours' tops; the fillet dies toward a taller neighbour (round 2, 45e990b).
Proof: knob test: slit with FILLET=0, none with LEAN=0; docs/faults/pins/blocks/SHEET_r2_slit_fix_L6.png.
Rules: R-06

### L-05 Scene cells keep the kind under c.shape.kind
Symptom: a test on c.kind=='tree' never matched; the old|new sheets were identical and the first crown fix changed nothing.
Wrong model: cache.cells carry c.kind.
Cause: c.kind is nil; the kind is c.shape.kind.
Fix: read c.shape.kind (1477b5b).
Proof: identical old|new sheets = the test is wrong, not the fix.
Rules: R-22, R-29

### L-06 A whole capture run can fall back to 2D transiently
Symptom: cap_pins.sh old AND new, every spot, even Littleroot, fell back at Gen3Scene.lua:2655 (attempt to call a nil value); the same spots reran clean minutes later.
Wrong model: a fallback in the new run means the change broke something.
Cause: transient QA copy state.
Fix: treat a run whose summary says fallback > 0 unexpectedly as void and rerun before judging.
Proof: blk17 (fallen back) vs blk20 (clean), same code.
Rules: R-23, R-27

### L-07 A dark slab beside tall rock on water is its shadow
Symptom: a uniform dark-blue shape west of the Sootopolis rim on the new sea looked like a flat riser at (2,30).
Wrong model: a wall face with the wrong art.
Cause: the shadow map drifts shadows west 0.85 px and north 0.55 px per px of height (ShadowMap.KX/KZ); the rim's shadow lies on the water.
Fix: none needed; check a suspected wall from the far side with the low camera before "fixing" a face.
Proof: plateau builder session 4 (closed without change).
Rules: R-22, R-29

### L-08 The low camera has no arm
Symptom: Route 119 (5,15) L6 stood inside a tree crown; marking trees into the camera height field did nothing.
Wrong model: Gen3CamClear's arm (built for the L7 orbit camera) also moves the L6 eye.
Cause: at L6 the eye is AT the player (dist = 0); crowns open round the eye only when eyeUnderCrown finds the player's OWN tile inked, and a path tile under overhanging crowns is not.
Fix: eyeUnderCrown also counts a solid tree cell on any of the 8 cells round the eye (1477b5b).
Proof: docs/faults/pins/blocks/SHEET_lowcam_crown_L6.png.
Rules: R-22

### L-09 Sootopolis's border became green stair-steps
Symptom: Sootopolis (12,20) top-left: grass stair-steps in the void beyond the rim.
Wrong model: the border family rule works for every map.
Cause: Sootopolis's border block is its flat white rim tile and its edge cells are blocked flat rim at 32..208 px, so the fill stepped down in rim colours.
Fix: Gen3Boundary M.SEA={EM_SOOTOPOLIS_CITY=0x279}: sea at 0 beyond the rim (install B, 4833467).
Proof: tools/elevation/qa/em_border_info.lua; SHEET_b_soot_L4/L6.png.
Rules: R-21

### L-10 The nibble flood is no flat-area detector
Symptom: Mt Chimney: one 364-cell walkable component held 12 pins of different heights; ~50% of pins sit on blocked rock-top cells.
Wrong model: cells with the same elevation nibble form one flat area.
Cause: the cartridge's nibble is layering, not height.
Fix: each pin is its own zone grown by a multi-source ring flood over same-rating same-kind cells (stops at stairs, flights, ledges, waterfalls); a pin on a blocked cell stands alone and supports its neighbours.
Proof: tools/elevation/qa/em_pins_driver.lua (field vs marks).
Rules: R-10

### L-11 Tree cells are blocked, so the pin flood left them behind
Symptom: tree gate 158 sunk / 221 floating tree cells on 9 wooded maps after phase 1; a tree took the nearest walkable ground, not its hill.
Wrong model: lifting the ground lifts what stands on it.
Cause: the flood grew over walkable cells only; Gen3Scene lifts a tree by the nearest walkable ground.
Fix: the flood claims tree cells beside a zone, tree to tree (507dd18); the loose-tree pass moved after the pocket pass (223ef91). Sunk 158 -> 14 -> 3.
Proof: tools/elevation/learn/tree_gate.py.
Rules: R-15

### L-12 The builders disagreed on the course height
Symptom: counted-relief maps stood 1.5x taller than the rest.
Wrong model: every builder uses 16 px per course.
Cause: Gen3Relief.LEVEL was 24 (its own comment said the 3DS port uses 16) while Gen3Rock.COURSE and Gen3Elevation.COURSE were 16.
Fix: LEVEL 24 -> 16 (d1c00c3), one constant.
Proof: the user's decision in docs/elevation/README.md ("Course height: DECIDED 16 px").
Rules: R-07

### L-13 Sinking c.base left the actors in the air
Symptom: Mossdeep "1 block too high"; the first fix looked right in shots but the player and NPCs floated 16 px.
Wrong model: the drawn ground is the ground.
Cause: Scene.groundAt reads the floor field, not c.base.
Fix: Gen3Elevation SINK_MAPS (field height/high/low/ledgeLow, clamped at 0), 6966aff.
Proof: a driver printing c.base and groundAt side by side.
Rules: R-16

### L-14 pairs() order is random per run
Symptom: rock groups and tree heights changed from load to load (Route 118 rock vs dome; F025).
Wrong model: iteration over cells["x:y"] is stable.
Cause: LuaJIT randomises pairs() over string-keyed tables per process.
Fix: make every flood/grouping order-independent (pair by tile; fixed map order); a dump of the same code twice must give unstable 0.
Proof: tools/heights_compare.py flips; baseline heights-2026-10-20-fix-F025.txt.
Rules: R-27, R-29

### L-15 The mod repo must never be committed
Symptom: make_patch.sh breaks when the mod repo's HEAD is not upstream.
Wrong model: commit everywhere.
Cause: tools/props/make_patch.sh diffs the working tree against HEAD = upstream; the work lives in patches/battle-art-voxel-fork.patch.
Fix: commit Emerald (tools, docs, patch) only; the mod source stays uncommitted on purpose.
Proof: PLAN.md Log 2026-10-27 (phase 1 install).
Rules: R-26

### L-16 Shell and tool gotchas that each cost a gate round
Symptom: xargs workers failed, `echo ===` printed nothing, a label dir was reused with stale dumps, Pillow missing, install refused.
Wrong model: bash habits work in zsh; python -I is always right.
Cause: zsh has no export -f (workers go in a script file); zsh expands a word starting with `=`; zsh does not split unquoted $VAR (use ${=VAR}); Pillow is in user site-packages (python3 without -I for the tools); sed -i '' on macOS; a label dir under /tmp may pre-exist; install scripts refuse while any love process runs.
Fix: as listed; check the label dir before reuse.
Proof: PLAN.md Handoff: pin heights gotchas.
Rules: R-27

### L-17 Dumps and sheets have limits
Symptom: a GRID char stuck at 35 (280 px) on tall maps; a sheet path from the Log was missing after a checkout.
Wrong model: the dump shows every height; docs images are in git.
Cause: the dump GRID saturates at 35 half-courses; *.png under docs/ is gitignored (sheets live on disk only).
Fix: read heights over 280 px from the PIN lines; keep sheet paths as disk pointers, never as proof in git.
Proof: .gitignore; em_pins_driver.lua.
Rules: R-26

### L-18 Session plumbing
Symptom: a SendMessage to a short name did not resolve; a message to an idle reader did not wake it; start_session was refused.
Wrong model: short names work; any session can start another any time.
Cause: SendMessage resolves TITLES; an idle session needs ccd send_message; the app refuses start_session on a turn triggered by another session's message.
Fix: address by title; wake with send_message; ask the user with wrap_up and start on their "go".
Proof: Handoff: coordinator in PLAN.md.
Rules: R-30

### L-19 A tall object appears north of where it stands
Symptom: Petalburg Woods "floating object" cost an hour of guesses (ledge, cloud, blimp, truck).
Wrong model: the thing is where the picture shows it.
Cause: the exit-path tile 0x205 stood up as a tall object SOUTH of the player and projected over the entrance.
Fix: tools/em_probe_driver.lua (every cell with quads above a height): trust the probe's cells, not the picture.
Proof: memory emerald-find-what-draws-it.
Rules: R-29

### L-20 Dewford's border tile is a tree
Symptom: Dewford Town ringed by forest to the horizon after the tree stamps.
Wrong model: "trees everywhere" = a stamping bug.
Cause: Dewford's border block is four copies of 0x243, the grove crown tile; Gen3Boundary repeats it beyond the edge with no collision.
Fix: none by default (that is the cartridge's own look); check which cells are border cells before judging; limit stamped trees in the void only if the user asks.
Proof: tools/trees/em_border_driver.lua.
Rules: R-21

### L-21 Capture quirks
Symptom: Route 118 (4,14)/(5,13) always differ between dumps; several far-apart spots on one map in one run showed void beyond the first spot; a trainer spotting the player dropped the run to 2D for every later case; cap_pins yaw 90 at Route 112 (37,30) put the L6 eye against a building wall.
Wrong model: every dump difference is a regression; any spot list works.
Cause: those two cells flip (time/random state); the scene streams round the first spot; "!" events; walls at the eye.
Fix: ignore the two Route 118 cells; give far spots their own run; check `active true` in run.log; pick open cells for L6.
Proof: PLAN.md Handoff gotchas; memory emerald-perfect-everything.
Rules: R-23, R-27

### L-22 Only what is written persists
Symptom: user 2026-10-27: "are you learning?" after the second builder round ignored rules given that morning.
Wrong model: a correction said in chat to one session is known to the next.
Cause: each session starts from PLAN.md and memory; the rules were in prose spread over handoffs, README and memory, and nothing measured them.
Fix: this folder: rules with ids and gates, lessons, a scorecard, a journal line per session, a fixed reading order at the top of PLAN.md.
Proof: docs/knowledge/scorecard.md over time.
Rules: R-31

### L-23 A wrong pin doubled Route 115's ledges
Symptom: user 2026-10-14: "route 115 doesnt even have a double ledge?! you need to recheck the height map"
Wrong model: the ledge drawing code is wrong.
Cause: a wrong pin in Gen3StairTerraces put the lawn a level too high, so every ledge drew twice.
Fix: fix the pin; dump the floors before touching builders.
Proof: furniture driver dump={x0,y0,x1,y1} ([CELL] lines).
Rules: R-17

### L-24 The chunky pier was the generic step-wall pass
Symptom: Route 104 jetty read as chunky blocks.
Wrong model: the pier builder is wrong.
Cause: Gen3Scene's step-wall pass closed every raised cell down to the floor below with its own art.
Fix: found by blanking the pier branch and then the furniture driver's box={x0,x1,z0,z1} attribution (which cell emits geometry in a world box); fixed in round 2 (5f2d573).
Proof: tools/furniture/driver.lua box case field.
Rules: R-29

### L-25 Mini stairs beside a flight were count-derived relief
Symptom: user 2026-10-23: "this staircase has like two mini stairs next to it that shouldnt be there" (Route 112 (20,43)).
Wrong model: the flight builder draws the shelves.
Cause: Gen3Relief's counted relief within 2 cells of the flight stood 3-19 px above the tread row.
Fix: Gen3Relief M.STAIR_TILES + M.STAIR_FLUSH=2 lay those cells at the flight's own base (372612f).
Proof: five probe trees ruled out the flight, relief heights, the flush rule and a clean twin before the box attribution found it.
Rules: R-17, R-29

### L-26 "The weather institute isn't built" = it was sunk 48 px
Symptom: user 2026-10-14: the building on Route 119 is missing.
Wrong model: the building model failed.
Cause: its doormat was a one-cell pit after the stairs pass lifted the yard; buildings stand on the floor in front of their door.
Fix: TerrainLevels POCKET rule + an all-outdoor pocket scan (M.logPockets) before installing (59a63f1).
Proof: scratch pocket_driver (em_cells_driver with short waits).
Rules: R-17

### L-27 Handoff chains stalled on "waits for the user's look"
Symptom: trees (task 11), ghost cards and rock leftovers sat parked between the user's visits.
Wrong model: a visual change needs the user's yes before install.
Cause: sessions asked for confirmation the user did not want to give piecemeal.
Fix: the STANDING RULE (R-24): judge against the 2D art yourself, install when the gates pass, the user audits once at the end.
Proof: PLAN.md Log 2026-10-27 ("go all the way").
Rules: R-24

### L-28 A hole in front of a bridge whose banks are both 2
Symptom: user 2026-10-27, Route 120 sheet: a dip at the top bridge's end although bridge and both banks are marked 2.
Wrong model: a connector between zones is a flight.
Cause: an unmarked run of walkable cells between two zones at one height took a flight (1 / 1.5) instead of the shared height.
Fix: task 34 (0c): a small unmarked run touching two zones at one height takes that height; e0 flight cells between equal floors are flat (396ec00).
Proof: docs/faults/pins/bridge/ sheets; field gate.
Rules: R-13

### L-29 The old rock builders ignored the pins
Symptom: Route 119 weather station: tall slabs beside the station where the 2D draws a one-course band (b5 shots).
Wrong model: raising the base under counted rock is enough.
Cause: Gen3Relief/Gen3Rock/Gen3Hills stacked their counted courses on the raised base.
Fix: task 34 (0b): faces between plateaus, then Gen3Blocks replacing the rock builders on pinned maps.
Proof: docs/faults/pins/faces/, then blocks/.
Rules: R-03, R-11

### L-30 OTHER_FIX flattened the sea rocks
Symptom: Route 126's white boulders flattened under round 1b (docs/faults/pins/blocks sheets).
Wrong model: every unclassified rock cell near a plateau belongs to it.
Cause: lone sea rocks have no plateau above them; the fix-up moved them to the nearest plateau.
Fix: Gen3Elevation kindAt='seaRock' excluded from OTHER_FIX (round 2).
Proof: class gate otherFix counts per map; Route 126 L4 sheet.
Rules: R-02

### L-31 A probe copy must stay a copy
Symptom: The mod source's Gen3Blocks.lua and Gen3Scene.lua differed from the installed game (a 140-line LEDGES block and a scene hook) while the builder reported its prototype lived only in /tmp/ledge_src; a later install_blocks.sh would have carried the abandoned prototype into the game
Wrong model: A builder's report of what is in the source was trusted; source = game was assumed between installs
Cause: The builder edited the source directly, then tested from a /tmp copy, and reported the copy
Fix: cmp every lib file the install script copies against the game copy BEFORE any install or gate on the source (one loop, see the coordinator 3 handoff); design work happens in a private copy (QA_SRC / SRC_OVERRIDE) and is copied into the source only right before its own install; the stray files were restored from the game and saved in backups/b9-ledge-proto-20261028
Proof: cmp loop 2026-10-28 13:00: all five terrain files src=game yes after the restore
Rules: R-26

### L-32 The flight stretch rewrote the grass below a stair
Symptom: 205 of 315 stair runs started 8-10.7 px above their lower floor; Mossdeep (25,26) had pin 0 but height 10.67 and grew a bogus hidden ledge at (25,27)
Wrong model: the stair profile was only stale after the pin passes moved the floors
Cause: TerrainLevels stretched every flight steeper than 0.9 into the floor at its foot and set c.height of that grass cell; later passes never recomputed it; rock FACE heights then followed the falsely lifted cells
Fix: Gen3Elevation stairProfile pass from the final end-floor heights (early before the classifier, late with the foot extension); Levels.stretch=false on pinned maps; TerrainLevels.at reads c.stairUp
Proof: census: foot riser 0 on 255 climbing runs, mismatches 0 (was 248), steep 19 to 9; gates stairs_rb pins 1611/1610 faceHigh 54 trees 3/44 0 fallbacks
Rules: R-34

### L-33 steep stair is not always a stair
Symptom: the stairs census lists 1-tile runs climbing 2..9 courses (Route 119 (9,16), (23,33), (5..8,52))
Wrong model: treating them as pin questions for the user or as flights to extend
Cause: the cells are plain grass with layout elevation 0 (the any-level transition tile between elev 4 and 3 areas) or sit beside the 0x206 lake tile classed OTHER at grass height; none is stair art
Fix: check the metatile and the layout elevation (tools/relief emdata Layout.metatile/elevation) and the field dump GRID rows before asking anyone; read the draw sheet at 4x for a misread digit (Mt Chimney (24,23) 10 read as 9)
Proof: coordinator 4, 2026-10-28, notes coordinator4_stairs_findings.md
Rules: R-34

### L-34 The 3D pass drew a vertically mirrored world
Symptom: In the new mod's first textured 3D captures north was at the bottom and buildings extruded downward (the user: "uhm why is the world upside down?"); the lab stood north of the houses it is south of in the 2D art and every metatile's roof sat under its wall
Wrong model: The P1 gate judged the 3D image alone (a diorama on sky) and its author read the picture as correct; nothing was compared against the engine's own flat field, and Camera3D:proj() was taken as standard GL clip space
Cause: Mat4.perspective emits textbook GL clip space (+Y up), but our shader bypasses LOVE's transform_projection and LOVE's canvas coordinates run Y down, so the whole scene composites vertically mirrored; the old mod had already learned this and multiplies proj by scale(1,-1,1) (battle-art-notquiteog lib/Voxel3D.lua:1120), the new module did not
Fix: Camera3D:proj() multiplies the perspective by Mat4.scale(1,-1,1) and Camera3D:project() reads NDC Y as down-positive; a capture gate now also takes the ENGINE's own flat field at the same spot (mod hook disabled for 20 frames, tools/rewrite/probe/p1_driver.lua) so the 3D image is judged against the 2D art and not against itself
Proof: P1.2 recapture after the fix: the lab is south of the houses as in the 2D reference, roofs above walls; docs/shots/P1.2_littleroot_L4.png beside the same-spot 2D capture
Rules: R-09,R-22

### L-35 A layer can count its geometry and draw nothing: the upload API was invented by a stub
Symptom: The tree layer logged 'trees: 421 instances, 4 models, 781081 quads per window' and the capture with those instances was byte-identical to the capture without them, at every spot (Littleroot, Route 111).
Wrong model: Assumed the draw path or the instance list was wrong (uShift, beginPass, the window, the border gate); slice 11 shipped 'the forest reads as models' off a sheet that actually showed the flat border carpet.
Cause: Trees.card wrote the drawing into the pair's ImageData with setPixel and uploaded it with Image:refresh - an API LOVE 11 removed. The guarded call (if c.image.refresh then) did nothing, the GPU texture kept its transparent pixels, and the shader's alpha discard (texel.a < 0.5) dropped every tree fragment. tests/trees_test.lua stubbed an Image with refresh, so the invented API could never fail a test.
Fix: Upload with Image:replacePixels(c.data) (keep refresh as the 0.10 fallback) and log a warn when neither exists; the test stub now offers replacePixels only and a check fails if writing a card uploads nothing.
Proof: Route 111 (6,30), same driver/cases/options: the engine's own 2D frame byte-identical (md5 0cbe8d4b, the control), the 3D frame changes on 232864 of 921600 px, 33 instances visible; Route 112 240 instances/16 models, Littleroot 15/4. docs/shots/P3s14_tree_upload_sheet.png; emerald3d c16384a.
Rules: R-29

### L-36 The play camera is a formula in the installed look, not a rig to design
Symptom: Every old|new sheet showed a scale difference at towns (Littleroot's houses ~15-30% larger in the installed look) and a blend of the two frames at Route 112 read as a rotated, shifted picture; the session that closed the camera item had checked one feature (a staircase width) and called it matched.
Wrong model: Took Camera3D's fixed 420/300/fov35 diorama for the installed look's play camera because an earlier session had measured one staircase against it, then judged tree/plants/building parity against frames taken with a different rig.
Cause: The installed look does not own a play camera when Gen3Scene leaves Voxel3D.camera nil: Voxel3D computes it from VoxelState.FOCAL and the camera ladder - pitch ANGLES_DEG[level+1] (50 deg at the play rung), distance FOCAL*the view height, fov 2*atan(1/(2*FOCAL)) = 53.13 deg, focus on the player's cell centre, up (0, sin a, -cos a). It frames the same slice of world the FLAT view shows, tilted; our rig framed ~30x20 cells.
Fix: tools/rewrite/probe/cam_driver.lua reads the camera the loaded mod actually draws with (old side: exports.BATTLE_ART_VOXEL_FORK.lib.require('Voxel3D').camera and gen3Camera; new side: the probe window), and Camera3D.lookAtGround now implements the installed formula.
Proof: Voxel3D.camera is nil at level 4 on both a town and a route (measured); docs/shots/P3s15_camera_sheet.png pairs installed|ours at Route 112 (20,45), Littleroot (10,10), Route 119 (8,10) and the staircase, houses and river bend land at the same screen position and scale; emerald3d e018902, GeometryCore.md section 3.3.
Rules: R-29, R-36

### L-37 Fit the camera to the capture; a labelled sheet can lie
Symptom: After slice 16 the two play-camera captures 'disagreed' (Route 112 matched the installed golden, Route 111 did not), so the rig was declared spot-dependent and left open; slice 15's own change (the camera lifting with the player's floor) had been shipped as a fix on that same kind of evidence.
Wrong model: Trusted the composite sheet's row labels and the source's first viewProjection call; compared the two frames by eye at 433 px wide, where an 18 percent scale difference and a 48 px vertical shift both read as 'a bigger area'.
Cause: The sheet's rows were labelled the wrong way round (its 'installed L4' was our capture: the rewrite draws no actors, the installed look does), and the installed look answers a camera question in TWO places: Gen3Scene sets Voxel3D.orbitGround and calls viewProjection, then clears orbitGround before Voxel3D.beginScene, which recomputes the view - so the drawn frame uses focus y=0 and the first call's ground is dead code. The distance also carries Voxel3D's 1.18 depth-style factor (Generation.isGen3(), always) that dist=FOCAL*vh missed.
Fix: Measure the camera the mod draws with (cam_driver prints Voxel3D.eye/focus/fovY, the engine's fieldDraw view size, worldViewSize, zoom and Tilt) and FIT the result: best (scale, dy) of our capture against the installed capture of the same spot about the frame centre. 1.00 / 0 or the camera is wrong; the two numbers also say WHICH term is off. Never close or re-open a camera from a sheet.
Proof: Before: Route 112 fit 0.84/0, Route 111 (6,30) fit 0.85/-48. After: 1.00/0 at Route 112 (20,45), Littleroot (10,10), Route 111 (6,30), Route 110 (10,25), Route 119 (8,10); camera numbers byte-identical to the installed look's (eye 328,273.056,1053.416 dist 424.800). docs/shots/P3s17_camera_fit_sheet.png, GeometryCore.md section 3.5.
Rules: R-36,R-29

### L-38 A capture reads one instant; an overlay in one frame is not a content fault
Symptom: Two sessions in a row filed the big wooden ROUTE 112 / LITTLEROOT TOWN board as a content gap ('ours draws a giant camera-facing signboard, the installed look draws nothing there') and one sheet was read as 'the two spots disagree about the camera'.
Wrong model: Compared captures taken at different instants and treated any difference between them as geometry/props/props parity.
Cause: The board is the engine's AREA-NAME POPUP (src/ui/game3/map_name_popup.lua), drawn in screen space by the UI pass over either mod: 12 frames slide-in, 120 hold, 12 slide-out = 144 frames. A 150-frame capture sits on its tail, a 20-frame capture has it fully up, a 300-frame capture has it gone - so 'the installed look draws nothing there' was a 150-frame coincidence, not a missing landmark.
Fix: Same-instant rule: two captures are compared only at the same EM_WAIT, and parity sheets use EM_WAIT >= 200 (past every engine popup/animation); a screenshot object that sits at the SAME screen rect in five different maps is an overlay, not world geometry - check that first (it is the cheap test that would have caught this twice).
Proof: Installed look at Route 112 (20,45), EM_WAIT=20: the board is up at the same rect as ours; ours at EM_WAIT=300: gone; ours at 150: up. /tmp/camf/banner20 vs /tmp/camf/banner300; M1-PLAN slice 17 note and the task-36 handoff corrected the same evening.
Rules: R-36,R-29

### L-39 The parity capture zoom decides the camera
Symptom: Our rewrite capture at Route 111 (6,30) looked 3x closer than the installed golden at the same spot and the far band was a flat wrong blue: tiles ~64 px against ~32 px, and no horizon haze.
Wrong model: A camera fault or a missing fog - slice 17 had just 'proved' the camera fit at 1.00 and looked right.
Cause: clean_try.sh defaults QA_ZOOM=0 while every parity golden is shot by cap_pins.sh, which exports QA_ZOOM=-2. The engine hands FieldView.draw its worldViewSize, and at zoom 0 that is 320x180 against 640x360 at -2; the installed camera's distance is FOCAL*vh*1.18, so half the vh is half the distance: a 15-cell frame against a 47-cell one. The camera code was right the whole time; the capture was at another zoom than the reference.
Fix: Parity captures always run QA_ZOOM=-2 (R-23's 'QA must match the user's game'). cam_driver.lua prints worldViewSize/zoom/fieldDraw, so check that line before judging any old|new sheet; a claim that a spot 'frames more area' must name the fieldDraw size on both sides.
Proof: 2026-10-31: same spot, same build, QA_ZOOM=0 -> fieldDraw 320x180, distance 212.4, ~15 cells across; QA_ZOOM=-2 -> fieldDraw 640x360, distance 424.8, ~47 cells across, and the (scale,dy) fit to the golden becomes 1.00. The far-field slice's before|after numbers only exist at -2.
Rules: R-23

### L-40 A cache asked after the work still costs the work
Symptom: Each window rebuild spent 28-55 ms in the tree layer on every six walked cells - a stutter at every bucket change - while the tree cards were supposedly cached per pair.
Wrong model: Assuming the per-tree card composition (ground palette, background flood, pixel copy, texture upload) was inherent work that only chunking could amortise.
Cause: Trees.card computed its cache key only AFTER the expensive part: the 256-pixel ground palette, the full w*h background flood against the ink outline, the trunk-foot scan, the setPixel copy of the card into the pair's canvas and the replacePixels upload. The lookup at the end always missed on the first call and hit on the next - but by then the work was already paid again for every tree in the window.
Fix: Ask the cache FIRST, keyed on what the result actually depends on (a card depends on the shape table and the atlas, nothing else), and store nil hits (false) so a shape that cannot compose is not re-flooded. This is the same fault class as slice 14's 'counted 421 trees and drew no pixel': the layer reports the intended work while the real cost or the real output happens somewhere else.
Proof: 2026-10-31: trees 28-55 ms -> 1-4 ms per window; the whole rebuild 79-101 -> 52-69 ms; Route 111's L4 capture byte-identical to the previous build (0 px differ) and the geometry dump identical on Littleroot and Route 111, so it is a pure cost fix; tests/trees_test.lua 279 checks pass.
Rules: R-29

### L-41 A tree card cache keyed on the drawing's first row
Symptom: Chunking the window (slice 20) changed Route 112's north-hill forest: 19584 px differ at L4 and 17416 at L7, all on tree crowns, on a change that was meant to be pure cost. Before the chunking the same hill was patchy green-and-pink: trees drawn with a neighbour tile's mask.
Wrong model: Assuming a tree card is identified by its family and its top row of metatiles, so c.cards[key] could not collide, and that the only thing chunking could change was the build cost.
Cause: Trees.card's key held table.concat(rows[1]) -- ONLY the drawing's first row of metatile ids -- plus tipRows/ground/footY. Trees whose top row matched but whose lower rows differed (528/536, 528/515, 528/529, 528/538) therefore shared one card, and whichever shape the window composed first decided the art of all of them. Measured with a logged full key: 48 + 44 + 15 + 13 colliding requests in one Route 112 window. The chunked build composes in chunk order instead of window row order, so a different card won and the forest changed with it. The old look was ALSO player-position dependent for the same reason.
Fix: Put every row of the drawing into the key (emerald3d slice 20). Two shapes now never share a card unless their whole drawing is the same; the art stops depending on composition order. Also: a full card texture (Trees.CANVAS) now warns instead of silently dropping trees.
Proof: Route 112 (20,45) before|after at 3x, docs/shots/P3s20_sheet.png: the hill's crowns go from patchy (pink ground showing through every tree) to one continuous canopy; the L7 diff mask shows every differing pixel on a crown. Littleroot (L4/L6/L7) and Route 111 (L4) are 0 px differ, so the chunking itself moved nothing; the clipped geometry dump is ALL SAME (ground 14984, model 11208, over 870, plants 1352).
Rules: R-29,R-36

### L-42 A local defined below its caller is a nil global, and no test sees the draw path
Symptom: The first slice-21 build logged '[EMERALD_3D] field draw failed, flat field restored: Scene.lua:535: attempt to call global assembleLayers (a nil value)': every capture and every probe was the engine's FLAT field (windowMs -1), so a whole measurement run measured nothing.
Wrong model: Inserted streamTrees above assembleLayers and assumed Lua's local declaration order did not matter; assumed the 11 test files would catch a broken Scene.
Cause: assembleLayers is a 'local function' declared after streamTrees, so inside streamTrees the name is a GLOBAL lookup; it is nil at run time. The tests only load lib modules that do not need love/Scene, so the draw path has no test at all.
Fix: Forward-declare 'local assembleLayers' above streamTrees and assign the function later ('assembleLayers = function() ... end').
Proof: After the fix the entry window built again (147.2 / 436.7 / 93.5 ms at Littleroot/Route 112/Route 111) and the 9 3D captures were pixel-identical; the smoke test is one QA run's log line, not the unit tests.
Rules: R-29

### L-43 Measure the layer before fixing the guess, and warm the QA identity before comparing
Symptom: The handoff said the map-entry hitch was the card uploads (Trees.card calling replacePixels per card, guessed 5-15 ms each). The instrumented in-game run showed 0.2-1 ms an upload and 200 ms of hull composition at Route 112. A first baseline run of the SAME slice-20 code read 239.8 ms where the next read 144.6 ms.
Wrong model: Trusted a guess in the handoff as the design input, and compared a cold QA identity's numbers (first run after a reboot: layout 88 ms against 32 ms warm) with a warm run's.
Cause: A cost guess is not a measurement: the five allocations per quad inside VoxelHull.build (and the GC of them) were the cost, not the GPU upload. And the first run of a QA copy pays cold caches/shader warm-up, so it reads ~1.6x slower across every layer.
Fix: Instrument the layer in parts (cards, upload, models, list, meshes) and read the split before choosing a fix; for a before/after, run BOTH trees the same day, same probe, same options, and treat the first run as warm-up.
Proof: Route 112 trees 489.9 ms = cards 6.7 + upload 0.2 + models 200.3 (of which hull build 200.3) + list 200.3 + meshes 18.3; slice-20 clone 144.6 ms against an instrumented run of the same code at 239.8 ms (cold).
Rules: R-29, R-36

### L-44 Bench two Lua modules in separate processes
Symptom: A hull rewrite that was 1.4x faster measured 15.8 ms a build against the reference's 3.1, and a minute later 2.0 against 3.1 - the same code, both directions.
Wrong model: The interleaved A/B in one luajit process is a fair comparison, and a slower reading means the rewrite regressed the JIT.
Cause: Two implementations of the same hot code in one process share the trace cache and each other's exits and deopts; and this machine carries other sessions (load average 40-80), so any single reading swings 2-3x. A jit.on/jit.off test then read as 'the JIT hurts the rewrite', also an artefact of the load window.
Fix: tools/bench_hull.sh runs ONE MODULE PER PROCESS, three times each, and keeps the best reading a case gets; the parity check stays in one process because it times nothing.
Proof: Same module alone 2.0-2.3 ms a build, interleaved with the reference 15.8 ms. After the harness change 1.40x total, reproducible in four consecutive runs (1.23-1.56x a case).
Rules: R-29

### L-45 The look gate needs a deterministic capture
Symptom: The nine-capture R-36 gate reported 200-2100 differing pixels on 8 of 9 frames for a change that leaves every quad identical - and the same build captured twice differed just as much.
Wrong model: Two captures of the same spots are comparable; a pixel difference is the mod.
Cause: Three things in the frame are not the mod: the engine's wandering NPC/actor sprites (drawn over the field, positions differ per run), the animated tileset (water, flowers), and the player sprite's facing, which a map script or a late reset can leave turned. They sit in compact 24-32 px blocks with max delta 214-255, which reads exactly like a geometry fault.
Fix: tools/rewrite/probe/cap_driver.lua: p0's driver with objects.forDraw = {} and tileset_anim._enabled = false, and the player's facing re-pinned before each shot. Always run the same-build control: a pixel that differs between two runs of ONE build is not evidence about the other build.
Proof: With the driver: same build twice = 8 of 9 identical (the 9th is the player sprite at Route 111, the same 724 px rect both times); before vs after = 8 of 9 identical, and the 9th differs on exactly the control's rect.
Rules: R-36

### L-46 The rewrite capture driver never set the camera level
Symptom: Audit sheets showed the rewrite's L7 as a high orbit near L4 while the installed L7 was the low camera behind the player; L6 first-person shots of the rewrite were the same overview as L4.
Wrong model: Read the old|new L6/L7 pair as a camera parity gap in the rewrite.
Cause: tools/rewrite/probe/cap_driver.lua loops over EM_LEVELS but never calls probe.setLevel, so every rewrite shot is the default camera; it also names shots MAP_Ln, so several spots of one map overwrite each other.
Fix: tools/hedge/cap_level_driver.lua: probe.setLevel(level) before each shot, files MAP_x_y_Ln. Use it (or patch cap_driver) for any L6/L7 or multi-spot capture of the rewrite.
Proof: Petalburg (21,28)/(25,28)/(27,23): with setLevel the rewrite's L6 is the first-person eye and L7 the low orbit, matching the installed framing (.rewrite/hedge/HEDGE_before_after.png).
Rules: R-36

### L-47 Builders must not end their turn on a running capture batch
Symptom: The P1 trees builder ended its turn with 'the capture batch is still running'; the chain stalled until the coordinator nudged it
Wrong model: Starting caps.sh in the background and ending the turn
Cause: The brief did not say to wait for the batch and finish the gate in the same turn
Fix: Every builder brief: wait for the capture batch (foreground or DONE markers), then sheet, controls, commit and report in ONE turn
Proof: nudge message 2026-11-01, builder then finished and committed 1b49aaa
Rules: none
