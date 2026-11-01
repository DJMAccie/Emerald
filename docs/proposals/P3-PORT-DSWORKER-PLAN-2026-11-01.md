# P3 port plan for DeepSeek workers (2026-11-01, Fable coordinator 4; Petya: "we already have all the recipes and code from the previous version that we built ourselves" and "just ask the deepseek agents to do all the work")

Runner: `tools/rewrite/dsport.sh` feeds each `## T<n>` section below (plus the PREAMBLE) to `tools/rewrite/dsworker_lift.sh`
(a DeepSeek worker on the dirty side, cwd Emerald, Bash allowed; the first run from inside the clean tree hit its clean-room
guard and headless permission prompts, so T1-T3 of 13:26 produced reports, not ports) in order; after each task it compiles every lib file, runs all suites, and commits on audit/overworld
("port T<n>: ..."); it stops on the first failure. Log `.rewrite/night/p3port/run.log`, per task `task_T<n>.json` (`.result`).
The coordinator reviews `docs/port/T<n>.report.md` and the diffs, runs simcheck + captures (caps.sh, sheet3.py) and fixes.

## PREAMBLE (sent with every task)
You are a headless worker on the Emerald 3D clean-room rewrite (emerald3d: MIT, our own code). You run on the DIRTY side:
your working directory is `/Users/user/Documents/Emerald` (the tools repo). You have the owner's permission to read the
previous version of the mod, our own code, at `/Users/user/Documents/battle-art-notquiteog/lib/` (read-only: that is the
source you port from). The CLEAN TREE you write into is `/Users/user/Documents/emerald3d-audit` (git branch
audit/overworld: never switch branches, never stash, never push, never touch any other worktree): name every file you
create or edit there by its ABSOLUTE path (`/Users/user/Documents/emerald3d-audit/lib/...`), and run every test, simcheck
or git command after `cd /Users/user/Documents/emerald3d-audit`. The clean-room deny text in that tree's CLAUDE.md is for
its implementer sessions, not for you: this port is the dirty-side lift that REWRITE-PLAN.md section 2 allows, and that
tree's guard does not run in your session. Never open the engine's source
beyond what the clean tree already requires (`src.core.game3.*` public calls that exist in `lib/*.lua` today). NEVER copy
`Gen3ReliefData.lua` (58,981 ROM-derived lines) into the clean tree: it is data, handled in T2. Every new or ported file
starts with the MIT header the other `lib/*.lua` files carry (copy the header from `lib/BlockBuilder.lua`). Keep the
algorithm of the ported module; change only what calls upstream internals or the old scene's cell record, per the mapping
in `docs/port/INVENTORY.md` (T1). The clean tree's interfaces: cell records `docs/specs/SceneDispatch.md` section 2 and
`docs/specs/HeightField.md` section 3 (fields x, y, mid, top, cls, kind, side, step/high/low/treads, ledge, bareDrop,
shape, n/s/e/w); `uv(mid) -> u0,v0,u1,v1` from `lib/TileAtlas.lua`; `lib/BlockBuilder.lua` (`analyze(cells)` gives
`rampOf`/`stepOf`, `build(cells, uv, analysis)` emits quads as `{x,y,z,u,v,r,g,b,a}` vertices + indices, see
`docs/specs/BlockBuilder.md`); `lib/MeshBatch.lua` owns meshes. The field is `lib/Gen3Elevation.lua` (`M.field(def)`
-> `f.cells["x:y"]` with height, cls, kind, floor, shape, ledge, bareDrop, tallDrop). Modules load through the sandbox
table `V` (`local V = ...` then `V.require("Name")`); a module can be loaded in a test with
`assert(loadfile("lib/Name.lua"))(V)` where V is a fake with `require`. Check your work (from the clean tree): `luajit -bl lib/<file>.lua`
compiles every file you touched, and `for t in tests/*_test.lua; do luajit $t || echo FAIL $t; done` prints no FAIL.
Run the similarity gate on every ported file (from the clean tree): `python3 /Users/user/Documents/Emerald/tools/rewrite/simcheck.py lib/<File>.lua`
(FLAG = any exact upstream line that is not an interface line, or token share >= 15 percent): rewrite flagged blocks in
your own words and rerun until clean, and paste the final numbers in your report. Touch only: `lib/`, `tests/`,
`docs/port/`, `docs/PROVENANCE.md`, `.gitignore`, `data/relief/`. Do not commit (the runner commits). Finish by writing
`docs/port/T<n>.report.md`: files changed, what was replaced and why, test output summary, simcheck numbers, open
questions for the coordinator. Do not ask questions; decide and record the decision in the report.

## T1 Inventory (docs only)
For each old module `~/Documents/battle-art-notquiteog/lib/{Gen3Rock,Gen3Relief,Gen3Hills,Gen3Blocks,Gen3Mass,Gen3Cave,Gen3RockTables}.lua`
write `docs/port/INVENTORY.md` with one section per module: (a) line count; (b) every `V.require(...)` and
`require(...)` it makes, and for each whether a file of that name exists in the clean `lib/` (run `ls lib`), and if not,
which clean module covers it (Gen3Scene -> lib/Scene.lua + lib/MeshBatch.lua; TileAtlas uv; Gen3Elevation; BuildBudget
exists; Gen3Objects/Gen3Outdoor/Gen3Terrain/TreePresentation/VoxelHull/Gen3RockSprites: say "missing: stub" with the
exact functions the module calls on them and their meaning read from the old source); (c) every field read or written on
a scene cell (`c.floor`, `c.base`, `c.boundary`, `c.stageHidden`, `c.relief`, `c.height`, `c.shape`, ...) with the clean
cell field it maps to (`c.top` = height in px, `c.cls`, `c.kind`, `c.shape`, `c.ledge`, `c.bareDrop`, `c.inside` (not
boundary), `c.side`); (d) every exported function with its signature and one line of meaning, and who calls it in the old
`Gen3Scene.lua` (grep); (e) data tables that are ROM-derived (Gen3ReliefData) vs ours. End with a proposed port order
and the stubs needed. No code changes in this task.

## T2 Data and tables
(1) Copy `Gen3RockTables.lua` from the old lib to `lib/Gen3RockTables.lua` with the MIT header; run simcheck on it and
rewrite any flagged non-table code. (2) Write `lib/Gen3ReliefData.lua` as a LOADER only: it tries `V.require` /
`loadfile` of `data/relief/Gen3ReliefData.lua` (a git-ignored local file) and returns that table, else returns an empty
table with `missing = true` and logs one warning through `V.mod.log:warn` if available. Add `data/relief/` to
`.gitignore` (keep `data/relief/.gitkeep` tracked). (3) Write `tools/port/export_relief_data.sh` in the clean tree that
copies `~/Documents/battle-art-notquiteog/lib/Gen3ReliefData.lua` to `data/relief/` locally, and RUN it once so the file
is present for the tests. (4) `tests/reliefdata_test.lua`: loads the loader with a fake V; asserts a table comes back and
that `missing` is set exactly when the data file is absent (test both by temporarily renaming nothing: use a V whose
loader points at a temp path). Report.

## T3 Gen3Hills
Port `Gen3Hills.lua` (655 lines) to `lib/Gen3Hills.lua` per INVENTORY.md: requires -> clean names (BuildBudget exists;
Gen3Rock may not exist yet: require it LAZILY inside the functions that use it, `local function Rock() return
V.require("Gen3Rock") end`); cell fields -> the clean cell record; upstream internals -> the clean interface or a small
local helper of our own. Keep the algorithm (bankOk, claims, tiers, append) and its constants. simcheck clean. Add
`tests/gen3hills_test.lua`: loads the module with a fake V (stub `Gen3Rock` with the functions Hills calls, returning
neutral values) and calls `bankOk`/`claims`/`tiers` on a 6x6 synthetic cell set with one 2-course hill, asserting it
returns without error and claims the hill cells. Report.

## T4 Gen3Mass
Port `Gen3Mass.lua` (1140 lines) to `lib/Gen3Mass.lua`. PROVENANCE.md (2026-10-29) says this module carries a copied
upstream tileset pixel-reader and a uv sub-rectangle helper: REWRITE those two blocks as our own `lib/TilePixels.lua`
(functions: `readPixel(atlas, mid, px, py)` returning r,g,b,a of a metatile texel with the over-layer on top, and
`subRect(u0,v0,u1,v1, x0,y0,x1,y1)` mapping a 16x16 sub-rectangle into a quad's uv), written from the one-line specs here,
not from the old code; Gen3Mass calls them. Gen3Objects is missing in the clean tree: stub the functions Mass calls
(from INVENTORY.md) in `lib/Gen3Objects.lua` with a header saying it is a stub and what each function must do. Keep
the mass algorithm (isFoam, newBuild, prepare, ground, usable, append, appendObject). simcheck clean on both files.
`tests/gen3mass_test.lua`: fake V, `newBuild()` then `prepare` on a 5x5 synthetic set with a 3x3 rock mass of one mid,
assert `usable` is true for the mass cells and `append` emits > 0 vertices through a collecting quad callback. Report.

## T5 Gen3Relief
Port `Gen3Relief.lua` (719 lines) to `lib/Gen3Relief.lua`: requires Gen3Hills (T3), Gen3ReliefData (T2 loader),
Gen3Rock (lazy), Gen3RockTables (T2). When `Gen3ReliefData.missing` is true every relief function must return the
"no relief" result without error (the clean tree may run without the data file). Keep claims/mounds/append. simcheck
clean. `tests/gen3relief_test.lua`: fake V with the loader pointing at a missing file -> `claims` returns empty and
`append` emits nothing; with the local data file present (skip if absent) `claims` on a 4x4 set of one pink-rock mid
returns a table. Report.

## T6 Gen3Rock
Port `Gen3Rock.lua` (1169 lines) to `lib/Gen3Rock.lua`: requires Gen3Hills, Gen3Mass, Gen3Relief (all lazy to break the
cycle). Exports cave(def), handles(...), flat(...), append(...), checkFloat(...), occupancy(...) and `M.CAVES`,
`M.mapId`. Map the cell fields per INVENTORY.md; `c.boundary` -> `not c.inside`; `c.stageHidden` -> nil (not used in
the clean tree). Where the old code reads the old scene's region/plateau tables, read the clean field instead
(`V.require("Gen3Elevation").field(def).cells`). simcheck clean. `tests/gen3rock_test.lua`: fake V; `cave(def)` on a
def with id "EM_GRANITE_CAVE_1F" sets the cave mode; `handles`/`flat`/`append` on a 6x6 synthetic set with a 2x2 rock
block of one mid emit vertices through a collecting callback without error. Report.

## T7 Gen3Blocks against BlockBuilder
The clean tree already has `lib/BlockBuilder.lua` (pinned-map rock blocks, ramps for every FACE band since P3a, hidden
ledges) implemented from `docs/specs/BlockBuilder.md`. Read the old `Gen3Blocks.lua` (570 lines: pinned, prepare,
buildRamps, owns, ledgeFaceUV, append) and `docs/specs/BlockBuilder.md`, then write `docs/port/T7.gap.md`: for each
old function, whether BlockBuilder covers it (name the BlockBuilder function/section) or not. Port ONLY what is missing
into `lib/BlockBuilder.lua` as new functions with their own section comments (expected: `ledgeFaceUV` = the band art
a hidden-ledge wedge wears, chosen from the nearest band cell's side art; anything in prepare/owns the clean analyze
lacks). Do NOT duplicate BlockBuilder's ramps or walls, and do not change its existing behaviour: all 31+ suites must
still pass unchanged. Add cases to `tests/blockbuilder_test.lua` for each ported function. simcheck clean. Report.

## T8 Gen3Cave
Port `Gen3Cave.lua` (218 lines: wall, positionMask, rock, settle) to `lib/Gen3Cave.lua`. It requires Gen3Outdoor,
Gen3Terrain, TreePresentation, VoxelHull, Gen3Rock: for each missing one, stub ONLY the functions Cave calls in
`lib/<Name>.lua` (header: stub, what the function must do, from the old source's use) or, where the clean tree has an
equivalent (check `lib/` and INVENTORY.md), call that. `settle(def, cells)` must read the clean field cells (height =
`c.top`/`c.height`). simcheck clean. `tests/gen3cave_test.lua`: fake V; `positionMask` and `wall` on a 5x5 synthetic
cave set (caveWall mids from `lib/Gen3EmeraldAuto.lua`'s `caveWall` list for the "cave" secondary) emit vertices through a
collecting callback. Report.

## T9 Wiring behind a flag
Write `lib/RockPort.lua` (our own, new): `M.ON = true`; `M.prepare(def, cells, f)` runs, in the old Gen3Scene's order
(see old `Gen3Scene.lua` lines 891, 1041, 1183-1220): `Gen3Mass.newBuild()`, `Gen3Rock.mapId = def.id`,
`Gen3Rock.cave(def)`, `Gen3Cave.settle(def, cells)` when `Gen3Rock.CAVES[def.id]`, and the mass/hill/relief `prepare`
and `claims` passes; `M.cell(c, cells, quad, uv)` emits, for one cell, what the old scene emitted at lines 1725-1745
(cave wall/rock for caveWall cells, Gen3Rock/Gen3Relief/Gen3Hills append for cliff cells on UNPINNED maps) and returns
true when it drew the cell so the caller skips BlockBuilder's flat block for it. Then in `lib/Scene.lua` and/or
`lib/MeshBatch.lua`, where BlockBuilder.build is called for the ground layer, call `RockPort.prepare` once per window
build and, per cell, `RockPort.cell` first when `RockPort.ON` and the cell is a rock cell (`c.cls == "FACE"` or `"MASS"`
or `c.shape.kind == "cliff"`/`"caveWall"`) on a map WITHOUT pins (`Gen3Elevation` exposes whether the map has pins:
`f.pinned`, add it in `M.field` as `f.pinned = userPins ~= nil`); pinned maps keep BlockBuilder (P3a rules). RULE R-38
stays on top: a cell whose `analysis.rampOf[c]` exists is drawn by BlockBuilder's ramp, never by the port (the port
must skip it). With `RockPort.ON = false` the scene must be byte-identical to today: assert that in
`tests/rockport_test.lua` by building a 4x4 synthetic window twice through the same entry (flag off vs. today's path)
and comparing vertex counts. All suites pass. Report, including the exact call sites you changed (file:line).

## T10 Gates and provenance
Run every suite; run simcheck over all ported/new files (`python3 ~/Documents/Emerald/tools/rewrite/simcheck.py
lib/Gen3RockTables.lua lib/Gen3ReliefData.lua lib/Gen3Hills.lua lib/Gen3Mass.lua lib/TilePixels.lua lib/Gen3Objects.lua
lib/Gen3Relief.lua lib/Gen3Rock.lua lib/BlockBuilder.lua lib/Gen3Cave.lua lib/RockPort.lua --report
docs/port/simcheck_p3port.md`); fix anything flagged and rerun. Add one row per ported module to `docs/PROVENANCE.md`
(Date 2026-11-01, item, kind "lifted-own (port)", session "DeepSeek worker, plan docs/proposals/P3-PORT-DSWORKER-PLAN-2026-11-01.md",
source = old path + line count, simcheck numbers). Write `docs/port/T10.report.md` with the full test and simcheck
summary and the list of stubs that still need real implementations.
