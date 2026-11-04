# Lessons (L-nn)

Mistakes that cost a round, and still apply. Per lesson `Cause:`, `Fix:` and optionally `Rules:`. Ids never change (gaps are
retired lessons). Add with `tools/knowledge/learn.py lesson`. Full wording before 2026-11-04: archief/knowledge-2026-11-04/.

### L-05 Scene cells keep the kind under c.shape.kind
Cause: cache cells have no c.kind; a test on it never matches, so before and after look identical.
Fix: read c.shape.kind; identical before/after shots mean the test is wrong, not the fix.

### L-06 A capture run can fall back to 2D without the change being wrong
Cause: transient QA-copy state; dark Flash caves always fall back in QA; a trainer spotting the player or an entry dialog drops all later cases of the run to 2D; a new local named `Objects` in Gen3Scene shadows the NPC module.
Fix: treat a run with unexpected fallbacks as void and rerun; check `active true` counts in run.log; quiet spots, one map per run when in doubt.
Rules: R-23

### L-07 A dark slab beside tall rock on water is its shadow
Cause: the shadow map moves shadows west and north with height (ShadowMap.KX/KZ), so a rim's shadow on water looks like a flat riser.
Fix: look from the far side with the low camera before "fixing" a face.

### L-14 pairs() order is random per run
Cause: LuaJIT randomises pairs() over string-keyed tables per process, so floods and groupings over cells["x:y"] changed from load to load.
Fix: make every flood or grouping order-independent; two dumps of the same code must be identical.

### L-16 zsh and macOS gotchas
Cause: the tool shell is zsh: no export -f, a word starting with `=` expands, unquoted $VAR does not split (use ${=VAR} or an array), an unquoted `--include=*.md` is a glob error; macOS has sed -i '' and no `timeout`; Pillow is in user site-packages.
Fix: quote globs, put parallel workers in a script file, run the image tools with python3 without -I.

### L-19 A tall object appears north of where it stands
Cause: a tall object projects north over the cells behind it on screen (Petalburg Woods: the exit tile stood up south of the player).
Fix: find the drawing cell with a probe (quads above a height in a box) and trust its cells, not the picture.
Rules: R-29

### L-42 A local defined below its caller is a nil global
Cause: a `local function` declared after its caller is a global lookup there (nil at run time); the unit tests never load the draw path, so they pass.
Fix: forward-declare the local above its caller; the smoke test for the draw path is a QA run's log (fallback 0).

### L-43 Measure the layer before fixing the guess; warm QA before comparing
Cause: a cost guess was wrong (allocations in VoxelHull.build, not texture uploads); the first run of a QA copy is ~1.6x slower.
Fix: time the layer in parts before choosing a fix; run before and after the same day with the same probe and discard the first run.
Rules: R-29

### L-44 Bench two Lua modules in separate processes
Cause: two versions of hot code in one LuaJIT process share the trace cache, and machine load swings a reading 2-3x.
Fix: one module per process, three runs each, keep the best.

### L-49 The mod sandbox hides debug, os.getenv and plain require
Cause: lib/ modules run in a sandbox: `debug` is nil (debug.traceback -> scene fallback), os.getenv sees nothing the QA command sets, a plain `require` of a mod module never resolves. Drivers (EM_DRIVER) do have `debug`.
Fix: load mod modules with V.require, use a module flag (M.log=true) for diagnostics, put hooks in a driver or tools/probe_main.lua.

### L-50 dead.py counts by name, so common names look used
Cause: tools/deadcode/dead.py counts any `.update` or `.apply` anywhere as a use of every module's `update`/`apply`; it also counts tests as users, so test-only helpers look alive.
Fix: tools/deadcode/deadq.py counts `M.f` only through aliases of M; grep qualified (`Name\.update`); check tests/ before calling a function dead.
Rules: R-45

### L-51 Too many QA runs or background shells vanish silently
Cause: more than ~4 waiting tools/qa_tryp.sh runs drop out without a run.log; a Bash run_in_background task dies after ~2 min.
Fix: at most 3 runs at once (xargs -P3); start long sweeps with nohup and wait with Monitor.
Rules: R-27

### L-53 Rocks are a per-cell priority chain, not stacked systems
Cause: Gen3Scene picks ONE rock system per cell: cave wall -> Gen3Cave, c.blocks -> Gen3Blocks, else Gen3Mass or Gen3Terrain -> Gen3Rock -> Hills; on pinned maps Blocks takes almost every rock cell.
Fix: count cells per system before merging or removing one (docs/dubbel-werk.md).
Rules: R-46

### L-54 A QA shot can catch the whole-area build half done
Cause: qa_tryp shoots ~80 frames after the 3D turns on; the whole area finishes around frame 50-100, so a shot can show only the near part and look like a regression.
Fix: rerun with wait 300 or compare two base runs before calling a missing area a regression; measure with S.streaming (completed/buildMs).
Rules: R-23,R-29

### L-55 Same source can give different LuaJIT bytecode
Cause: luajit -bs output depends on hash order for some files (stadium2 pack.lua, battle_fx_runtime.lua), so 'bytecode equal' cannot prove a comment-only edit.
Fix: prove comment-only edits with git diff -U0 (no changed line outside '--' comments) plus the test suite.
Rules: R-29

### L-56 A pcall-wrapped data load fails silently
Cause: Gen3Relief and Gen3Elevation loaded tables in pcall(V.require,...): a wrong name or path turns the feature off with 0 fallback and no error.
Fix: after moving or renaming a data file, compare QA pixels on maps that use it (two base runs + new); drop the pcall when the file always ships.
Rules: R-29

### L-57 Recipe tables can name tilesets Emerald does not have
Cause: data/gen3_stairs.lua had 55 of 57 recipes for pairs Emerald lacks (player_house, house, *rom_082d*); static greps on module names missed it.
Fix: check every pair name in a table against the native manifest (~/Library/Application Support/pokemon-love2d-rseqa/emerald/data/generated/gba/native/manifest.lua); mind labels the mod sets itself (InteriorDiorama gives the Abandoned Ship secondary 'rom_082d4d94').
Rules: R-44

### L-58 Another session commits your staged files
Cause: two sessions in one checkout: `git add -A` or `commit -a` takes the other's staged files (also git rm/git mv stage). Happened twice (63e4710, 0cf0897). The mod/ tree may hold another party's uncommitted work.
Fix: stage nothing for later (use rm/mv); commit only your own paths: git commit -m ... -- <paths>; check git status before and never add or install what you did not change.

### L-59 Pinned caves: black holes and domes after pinning
Cause: Gen3Scene caveWall/rock draw branches skip Gen3Blocks.append, and Mass.prepare runs after Blocks.prepare so Mass still drew domes.
Fix: branch (caveWall|rock + c.blocks -> Blocks.append) and mass.blocksOwned on pinned caves.

### L-60 Mod settings live only under MODS, not in the options menu
Cause: engine 0.3.99: the Emerald options menu builds its rows locally, so a mod replacing Rows.build never shows; only the ui.options.rows hook works (the importer's STADIUM 2 ROM line).
Fix: look at what Petya sees: MODS -> BATTLE ART VOXEL FORK -> options = the mod.options:define schema; read it with a driver (ModManager.show + openOptions, print m.optionRows).

### L-61 Odd-sized maps are padded by one row or column
Cause: native_pack pads an odd side to even by repeating the last row/column, so l.width/l.height can be one more than the art (Granite Cave 1F 42x15 vs 42x16); an exact size check silently skipped 72 of 96 height maps.
Fix: compare per-cell data to the true size and clamp x,y to the last row/column (Gen3Elevation height-map branch, Gen3Blocks.arrowRamps).
Rules: R-29

### L-62 Cave bridges and stairs under a drawn height map
Cause: Victory Road bridge cells (layer 15 plus end caps, collision 43) got ramp arrows and pins and became boxes; Scene.isDeck refused collision 43; cave stair metatile 0x204 (elev 0) was no step. Dark caves also fall back to 2D in QA.
Fix: a layer-15 run plus its end caps stays a deck (no pin, no arrow); isDeck accepts layer 15 with collision 0 or >7; general__cave 0x204 is a step (PAIR_STEP_MIDS); QA drivers take EM_NODARK=1.
Rules: R-13,R-18,R-43

### L-63 QA shots are dark at night and qa_tryp wipes *.png in the outdir
Cause: the game follows the real clock (DayNight.hours); qa_tryp does rm *.png in the outdir.
Fix: daylight: a QA_SRC copy of DayNight.lua with 'do return 12 end'; low camera: a copy of em_views_driver.lua with C.pitch=EM_PITCH; keep reference shots outside the outdir.

### L-64 Counting the ink led to errors
Cause: agents took Petya's numbers as sacred even where the walls said otherwise (Route 103 1 vs 3, Mt Pyre 16 vs 19, Safari North 1 vs 5), and read side bands as straight slopes.
Fix: put doubtful spots to Petya as a crop (heights over the screenshot); follow the wall count if he does not know; slanted bands and pyramid rocks follow his arrows.
Rules: R-48

### L-65 QA without tour and camera 7 misses Petya's faults
Cause: Petya plays with tour=true and camera 7; QA ran without tour at level 4, so 2D flashes and missing neighbour maps did not show.
Fix: reproduce with EM_TOUR=1 and level 7 (em_views_driver, em_cross_driver); read modOptions in his options.lua.
Rules: R-23

### L-66 A mod folder must not use assets/generated
Cause: assets/generated is where the engine keeps the player's ROM-derived cache; modkit lint MK301 (and the community mod index CI) fail any mod shipping files there, and any lib file naming that path.
Fix: Ship art under another folder such as assets/water_runtime and run: python3 gen1recomp/tools/modkit.py lint <mod folder> and validate <mod folder> --strict for all three mods.

### L-67 A mod's version must equal the release tag's x.y.z
Cause: The launcher updater and the mod index take a mod's latest version from the release tag (v0.1.0-alpha becomes 0.1.0) and compare it with the installed manifest version. 0.1.0-alpha sorts below 0.1.0, and 0.23.0 or 2.4.3 never trail a 0.1.x tag, so updates loop or never come.
Fix: Keep the three manifests, MOD_BUILD in stadium2-importer/main.lua and exports.version in overworld-wild-spawns/main.lua at the release x.y.z; put alpha only in the tag and the GitHub prerelease flag; attach <id>-<x.y.z>.zip for every mod to each release (tools/build_release.sh).

### L-68 Fortree treehouse 'pillars' were cliff cells, not model strips
Cause: Tiles 0x22C/0x22E/0x234/0x236 beside each hut door classify as kind=cliff, so the scene drew rock-band pillars next to the model; deleting the model's own post strips did not remove them (found with scene.debugRaw via a probe driver)
Fix: Model flag flatten=true in BuildingVoxels.place turns claimed cliff cells into the model's flat shape; keepTrees=true keeps claimed tree cells (leaf-corner tiles) out of the bush-tree pass

### L-69 Fortree palm crown must sit over the trunk and use its own bark
Cause: The crown was centred on its own tile one cell north of the trunk (looked bent backwards) and the trunk sampled whole tile columns, which include the bush art beside the bark
Fix: Gen3Fortree.palmCrown centres on the trunk cell and builds a 2px voxel shell; prism() uses trunk-tile columns 3-13 only, scaled to the trunk width

### L-70 Fortree rope bridges: tile art is two layers, and three scene walls hid it
Cause: Bridge tile 0x256/0x24E is leaf art (under) plus planks/ropes (over layer, ts.overImageData); the scene drew it flat with a 3px slab, a 6px deck band wall and a 32px ground-coloured wall on the canopy cells south of it, and no floor under raised cells (pale backdrop showed under huts). os.getenv is nil inside lib code, so QA flags must be driver-side or edit a QA_SRC copy.
Fix: Gen3Fortree.bridge builds plank + rope boxes, Gen3Fortree.bridgeDrop lowers the leaf plane and the scene skips its over layer, deck band and canopy wall for bridge cells; Gen3Fortree.floor lays grass under raised cells. Scene hunks are in Gen3Scene (committed alone via update-index).

### L-71 Sootopolis ridges were drawn by a per-map masonry list, not the drawn arrows
Cause: Gen3Masonry (hand lists of top/face mids for EM_SOOTOPOLIS_CITY) took ~1000 ridge cells before Gen3Blocks.arrowRamps, so the height map's 45-degree ramps were never built and faces were vertical courses (Petya 2026-11-04: 'the ridges arent read'). Also only 12 of ~28 huts/houses got a model: BuildingVoxels family anchors demanded the door row, window variants (0x211/0x204/0x213, 0x225/0x237) never matched and drew as draped rock.
Fix: Gen3Masonry deleted with its Gen3Scene/Gen3Blocks hooks; BuildingVoxels.LOOSE matches only the roof row (209/20A/20B cone, 20E+25A box, 20D/20E/20F box2) and takes facade art from the cells. Side effect found: once huts left the one 931-cell rock mass, Gen3Blocks.faceMid's mass fallback (mass.blocksFace = face-like tile with most votes) picked ONE stray dark door tile (0x221, 1 vote of 245) for every face of the east masses, so ridges rendered navy with tan swirls (before: 0x210, 2 votes, dark grey). Fix: a fallback winner needs >=3 votes or a tenth of the mass, else the cell's own tan tile is the face (swept 38 QA maps: no other map has such a winner).
Rules: R-38,R-43,R-46,R-48

### L-72 Sootopolis railings lay flat on the rock block's lid
Cause: the railing tiles (0x240-0x243 bar, 0x246/0x247 bar+post corner, 0x262/0x263 post beside the stairs) are cliff cells that Gen3Blocks turns into rock blocks, with the tile art as the lid: a painted strip lying on the ground (Petya 2026-11-04: 'also do the railings'). The art is oblique: bar = top rows 2-5 (depth 4), face rows 6-13 (height 8); post = 6 px wide, top rows 0-4, end face rows 6-14. Posts overshot north when the bar was placed at rows 10-14: the footprint is the TOP rows.
Fix: Gen3Parapet (SPEC per tile) gives the block a plain floor lid (0x2D9, or rock 0x2E1 beside posts), rock faces (0x2E1) and stands bar/post boxes from the tile's own rows on top; hooked in Gen3Blocks.append (par). Not done: the stair-flank posts stay level while the stairs drop 16 px; the gate frame 0x251-0x253 around the pink door is still flat paint.
Rules: R-48

### L-73 Zero-context patches land insertions on the wrong line when others' hunks sit above
Cause: committing only my hunks of a shared file with `git diff -U0` + `git apply --cached --unidiff-zero` uses the WORKING-TREE line numbers; the other party's uncommitted hunks above shift them, so a pure insertion (my `if par then ... end`) landed after `return true` in HEAD's blob (8c93e280 did not compile, fixed in 0ab86896). Deleting hunks were fine because they carry the removed text.
Fix: after every partial stage, compile the STAGED blob (`git show :path > t.lua; luajit -bl t.lua`) before committing, and compile every `git ls-tree HEAD mod/lib` file after; if wrong, build the blob from HEAD in python and `git update-index --cacheinfo`.

### L-74 Sootopolis gate frame is a hanging ring, not paint on the terraces
Cause: The 15 tiles round the cave door (0x251-0x253 top beam, 0x220/0x222 sides, 0x228/0x22A front corners, 0x230/0x232 legs, 0x229 front beam over walkable floor) are one stone cube-frame the art draws in oblique view; the 3D cells are a stepped cliff (48/32/16), so every beam lay flat on a lid of another height (Petya 2026-11-04: 'like a cube around the entrance, it hangs in the air, its now flat').
Fix: Gen3Parapet.GATE: one level ring at the back row's lid height (beams 5x5 px from the art's top rows, side beams over the y16 terrace, lintel bridging the door cell by 0x252 at x30), legs from the floor under the two front corners (0x228/0x22A cells), lids plain floor/rock/pink; the walkable 0x229 cells get the pink floor via Gen3Parapet.floorUV hooked at the uv line of Gen3Scene.build. Art rows were read as a pixel char map, not by eye.
Rules: R-48
