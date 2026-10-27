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
