# Lessons (L-nn)

Mistakes that cost a round, and still apply. Per lesson `Cause:`, `Fix:` and optionally `Rules:`. Ids never change (gaps are
retired lessons). Add with `tools/knowledge/learn.py lesson`.

### L-05 Scene cells keep the kind under c.shape.kind
Cause: cache cells have no c.kind; a test on it never matches, so before and after look identical because the test reads the wrong field.
Fix: read c.shape.kind; identical before/after shots mean the test is wrong, not the fix.

### L-06 A capture run can fall back to 2D without the change being wrong
Cause: transient QA-copy state (every spot fell back, then reran clean); dark Flash caves always fall back in QA; a trainer spotting the player or an entry dialog drops all later cases of the run to 2D; a new local named `Objects` in Gen3Scene shadows the NPC module.
Fix: treat a run with unexpected fallbacks as void and rerun; check `active true` counts in run.log; use quiet spots, one map per run when in doubt.
Rules: R-23

### L-07 A dark slab beside tall rock on water is its shadow
Cause: the shadow map moves shadows west and north with height (ShadowMap.KX/KZ), so a rim's shadow on water looks like a flat riser.
Fix: look from the far side with the low camera before "fixing" a face.

### L-14 pairs() order is random per run
Cause: LuaJIT randomises pairs() over string-keyed tables per process, so floods and groupings over cells["x:y"] changed from load to load.
Fix: make every flood or grouping order-independent; two dumps of the same code must be identical.

### L-16 zsh and macOS gotchas
Cause: the tool shell is zsh: no export -f, a word starting with `=` expands, unquoted $VAR does not split (use ${=VAR}), an unquoted `--include=*.md` is a glob error; macOS has sed -i '' and no `timeout`; Pillow is in user site-packages.
Fix: quote globs, put parallel workers in a script file, run the image tools with python3 without -I.

### L-19 A tall object appears north of where it stands
Cause: a tall object projects north over the cells behind it on screen (Petalburg Woods: the exit tile stood up south of the player).
Fix: find the drawing cell with a probe (quads above a height in a box) and trust its cells, not the picture.
Rules: R-29

### L-42 A local defined below its caller is a nil global
Cause: a `local function` declared after the function that calls it is a global lookup there (nil at run time); the unit tests never load the draw path, so they still pass.
Fix: forward-declare the local above its caller; the smoke test for the draw path is a QA run's log (fallback 0), not the unit tests.

### L-43 Measure the layer before fixing the guess; warm QA before comparing
Cause: a cost guess in a handoff was wrong (the cost was allocations in VoxelHull.build, not texture uploads), and the first run of a QA copy is ~1.6x slower (cold caches).
Fix: time the layer in parts before choosing a fix; for before/after run both the same day with the same probe and discard the first run as warm-up.
Rules: R-29

### L-44 Bench two Lua modules in separate processes
Cause: two versions of hot code in one LuaJIT process share the trace cache, and other load on the machine swings a reading 2-3x.
Fix: one module per process, three runs each, keep the best reading.

### L-49 The mod sandbox hides debug, os.getenv and plain require
Cause: lib/ modules run in a sandbox: `debug` is nil (debug.traceback -> scene fallback), os.getenv sees nothing the QA command sets, a plain `require` of a mod module never resolves. Drivers (EM_DRIVER) do have `debug`.
Fix: load mod modules with V.require, use a module flag (M.log=true) for diagnostics, and put hooks in a driver or tools/probe_main.lua.

### L-50 dead.py counts by name, so common names look used
Cause: tools/deadcode/dead.py counts any `.update` or `.apply` anywhere as a use of every module's `update`/`apply`.
Fix: tools/deadcode/deadq.py counts `M.f` only through aliases of M (`local A=V.require('M')`); grep qualified (`Name\.update`).
Rules: R-45

### L-51 Too many QA runs or background shells vanish silently
Cause: more than ~4 waiting tools/qa_tryp.sh runs drop out without a run.log; a Bash run_in_background task dies after ~2 min.
Fix: at most 3 runs at once (xargs -P3); start long sweeps with nohup and wait with Monitor.
Rules: R-27

### L-52 Compare tests with the base, not with zero
Cause: the mod's test suite has red tests in the base (17 on 2026-11-02), so "N red" after a change says nothing on its own.
Fix: run the suite with the change stashed (git stash) and without; only new reds count.

### L-53 Rocks are a per-cell priority chain, not stacked systems
Cause: Gen3Scene (~line 1330) picks ONE rock system per cell: cave wall -> Gen3Cave, masonry, c.blocks -> Gen3Blocks, else Gen3Mass or Gen3Terrain -> Gen3Rock -> Relief/Hills; on pinned maps Blocks takes almost every rock cell.
Fix: count cells per system before merging or removing one (docs/dubbel-werk.md).
Rules: R-46

### L-54 A QA shot can catch the whole-area build half done
Cause: qa_tryp shoots about 80 frames after the 3D turns on; the near area builds first, the whole area finishes around frame 50-100 (Route 104 75-96, noise +-30%), so a shot can show only the near part and look like a regression.
Fix: Before calling a missing area a regression, rerun with wait 300 or compare two base runs with each other; measure build frames with S.streaming (completed/buildMs) per case.
Rules: R-23,R-29

### L-55 Same source can give different LuaJIT bytecode
Cause: luajit -bs output depends on hash order for some files (stadium2 pack.lua, battle_fx_runtime.lua): compiling the same file twice differs, so 'bytecode equal' cannot prove a comment-only edit.
Fix: Prove comment-only edits with git diff -U0 (no changed line outside '--' comments) plus the test suite; compare bytecode only after checking the file compiles the same twice.
Rules: R-29

### L-56 A pcall-wrapped data load fails silently
Cause: Gen3Relief and Gen3Elevation loaded their tables in pcall(V.require,...): a wrong name or path just turns the feature off, with 0 fallback and no error in run.log.
Fix: After moving or renaming a data file, compare QA pixels on maps that use it (two base runs + new); drop the pcall when the file always ships.
Rules: R-29

### L-57 Recipe tables can name tilesets Emerald does not have
Cause: data/gen3_stairs.lua had 57 flight recipes, 55 for pairs like player_house, house and *rom_082d* (not Emerald); Gen3HouseStairs only drew those, so it never loaded. Static greps on module names missed it.
Fix: Check every pair name in a table against the 80 pairs in the native manifest (~/Library/Application Support/pokemon-love2d-rseqa/emerald/data/generated/gba/native/manifest.lua); entries for other pairs are dead. Mind labels the mod sets itself (InteriorDiorama gives the Abandoned Ship secondary 'rom_082d4d94').
Rules: R-44
