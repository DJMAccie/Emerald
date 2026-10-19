# Offline bake spike: step 1 findings (read-only, 2026-10-19)

Question: can scenes be built once and loaded from disk, so 3D is instant, runs are repeatable and geometry checks need no game?

## What the code shows (`lib/Gen3Scene.lua`, `lib/Gen3SceneCache.lua`)
- **Geometry is camera independent, except in battles.** `Gen3SceneCache.key` hashes the map layout, its overrides (`mid`, `coll`, `elev` per changed cell), the tileset image objects and the extent; its own comment says yaw is deliberately not in the key because "geometry is world-space". Only a battle (`cam.battle`: which buildings are cleared) and a replay (`cam.replay`: no cache at all) change it. The other `cam.` uses (lines ~2762-3237) are draw-time: eye position, card lean, canopy facing, rider dust. The one geometry-side camera input is the request extent (`NEAR_NORTH` when `cam.level < 6`), which a whole-map bake does not need.
- **The result is more than meshes.** A built scene (`cache`) holds GPU meshes (`parts`, `civics`, `buildingModels`, waters, `wood`/`leaves`) AND query state used by gameplay and actors: `cells`, `floorRegions`, `openings`, `treeInstances`, plus the counters in `SCENE_FIELDS`. A mesh-only bake cannot replace the build unless those are rebuilt or serialized too.
- **The key is not stable between runs.** It uses `tostring(table)` addresses for layouts and tilesets. A disk key must be content based: hash of the map cells and overrides, the tileset image bytes, and the lib files that feed geometry.
- **Where the time goes (Rustboro profile in `.claude/handoffs/2026-10-18-speed-and-hairlines.md`, 79k samples):** `BuildingVoxels.mesh` 14k + `VoxelHull.build` 9.5k (about 30%, building models), the build closure 7.5k, `quad` 7.2k, `Gen3Fence` ~6k, `VoxelHull.oval` 2.4k. Buildings are already baked offline as geometry-only files (`data/buildings/*.lua`); the runtime cost is composing their art and building the hull mesh from them.
- Already unproven: whether the vertex arrays are identical run to run. The handoffs report noisy mesh checksums, probably `pairs()` order over cell-keyed tables (Route 112 red cliff).

## Revised staging (lower risk than baking whole scenes first)
- **Stage A, measure (no behaviour change):** a probe tree (QA only) that wraps `R.newMesh` to log count, vertex total and an order-independent checksum per map, run twice, plus the `mark()` stage times. Answers: are builds deterministic, and what share is mesh generation vs cell solving.
- **Stage B, cache the building meshes (about 30% of Rustboro):** key = building id + recipe file hash + tile image hash; store vertices/indices in the mod's save folder; load instead of `BuildingModels.mesh`. Independent per building, so a stale entry affects one building and the key proves freshness.
- **Stage C, whole-scene bake:** only if A shows determinism and the cell/query state can be rebuilt cheaply or serialized. Output stays on the user's machine (it derives from ROM art), never in git.

## Go / no-go (unchanged from the plan)
Byte-identical double run; 8 captures baked vs live with 0 differing pixels; map-to-3D at least 5x faster for stage C, at least 25% for stage B; no new fallbacks. Any mod change goes through `tools/qa_tryp.sh` first, then the install protocol.

## Stage A results (2026-10-19, `tools/em_meshprobe_driver.lua`, 6 runs on QA, maps Oldale, Littleroot, Rustboro, Route 111, Dewford Gym)
The driver wraps `Voxel3D.newMesh` per map and prints per-mesh counts, vertices, an order-independent vertex-set checksum, an ordered checksum and the time spent inside `newMesh`. Needs `Gen3Scene.lua Gen3Waterfall.lua` in the qa_tryp file list (else a 2D fallback; one run was discarded for it).
1. **Order is never stable.** Vertex order and mesh order differ in every run, even when the geometry is identical (same set checksum, different sequence). Any byte-level comparison or bake diff must sort first.
2. **Content is nearly stable.** 89-95% of meshes are identical run to run (Oldale 39 of 46, Rustboro 158 of 169, Route 111 48 of 60, Dewford Gym 17 of 17). The big meshes that differ differ by a few quads (Rustboro 263888 vs 263880 vertices).
3. **Two sources of the differences.** (a) Actor sprite cards (local-space quads x -8..8, sprite-sheet uv rows): the frame an NPC shows when the mesh is made. Not scene geometry. (b) Real terrain: a world-space dump of Oldale twice shows 300-400 vertices (about 0.1%) at different heights, e.g. a cell north of the map at y 0 in one run and 8 in the other, spread over the border area x -384..710, z -352..176. This is the map-edge / boundary height flip, probably `pairs()` order in a tie-break; it survives the 4b06331 edge fix.
4. **The same area is built several times.** Per map entry the scene completes 4 to 6 builds: Rustboro 865k vertices four times, then 1.5M, then 9k; Oldale 156k, 157k, 258k, 6k; Littleroot 87k twice, 193k, 2k. By design there are a near build, a whole-near upgrade and the full build; the extra equal-sized ones are unexplained (hypothesis: the key changes as tilesets finish loading, since `Tiles._pairs` identity is in `SceneCache.key`). Worth a probe that prints `req.key` at each build start: if two builds share content, one is wasted work.
5. **Upload share.** Time inside `newMesh` summed per map: Rustboro about 1.4 s of 7.4 s of build time (19%), Oldale 0.24 s, Route 111 0.5 s. Mesh creation from Lua vertex tables is a real but minority cost; generation dominates.

### What this means for the plan
- A byte-identical double bake (acceptance 1) fails today, for the two reasons above. Acceptance becomes: same vertex SET per mesh after excluding sprite cards, with the known boundary flips listed. Fixing the flip (item 4's height path) is a precondition for byte-identical output, and a bake would freeze one variant rather than fix it.
- Stage B (cache building meshes) is still the lowest-risk saving (about 30% in the earlier Rustboro profile). Before that, finding why the area is built 4 times could save more with no cache at all.
- Next probes: (1) `req.key` / `tileIdentity` per build start; (2) per-stage cost of the near vs full build from the `[EM stage]` marks; (3) sort-and-compare of the Oldale border cells to name the nondeterministic tie-break.

## Stage A2: why the same area is built 4-6 times (2026-10-19)
Probe: a QA-only copy of `Gen3Scene.lua` that logs each build's start (extent, `upgrade`, radius, key pieces) and its CPU cost (`stream.stats.buildMs`). Not installed.
- **By design a map entry builds three times**: first area (radius 14), the same area whole (`upgrade`), then the full scene (radius 32).
- **Extra work comes from the cache key.** `Gen3SceneCache.key` includes the tileset objects of EVERY connected region, even regions far outside the build extent. A neighbour map's tileset is `nil` until it loads; when it loads while the full build runs, the key (and the 'context' used to decide 'same map') changes, the full build is thrown away and the near, upgrade and full builds run again. Seen directly in the key diff: `general__dewford ... nil:nil:nil` became `...table:ImageData:ImageData`.
- **Cost** (CPU ms of build work, one cold entry each; thrown-away = every build that finished or was cancelled before the last clean near-upgrade-full chain):
  | Map | Total | Thrown away | Share |
  |---|---:|---:|---:|
  | Rustboro | 6218 | 2099 | 34% |
  | Littleroot (boot) | 1995 | 1147 | 57% |
  | Route 111 | 3582 | 523 | 15% |
  | Oldale | 1106 | 0 | 0% (neighbour tilesets already loaded) |
  Cities with many connected tileset pairs lose a third or more of build CPU, and the finished scene arrives that much later; the first view is not delayed because the first near build is shown.
- **Fix tried in the probe tree** (`docs/proposals/SceneCache-narrow-key.diff`, 31-line file): the key lists only regions that touch the build extent, and the whole-map 'context' omits tileset identity. Result: every map builds exactly near, upgrade, full once. Rustboro 4316 ms (was 6218, -31%), Littleroot 1292 (was 1995), Route 111 3157 (was 3582), Oldale unchanged.
- **Same geometry?** Mesh-by-mesh against stock builds: fixed-vs-stock identical shares 93-100% (Rustboro 123 of 129 and 118 of 129), the same as stock-vs-stock noise (Rustboro 158 of 169). No systematic change; the fixed run has fewer meshes only because it has fewer builds.
- **Not done**: not installed in the mod. Still to do before installing: a pixel-diff of captures (levels 4 and 7, two yaws, edge-of-extent spots such as Rustboro west and Route 111 south) and a check that a tileset loading late still triggers a rebuild of the regions that use it (it does in the probe: only regions touching the extent are keyed, and the full extent touches them). Install via the usual protocol; another session owns `Gen3Outdoor.lua`, this change touches only `Gen3SceneCache.lua`.

## Not done yet
Stages A to C. They need game runs and edits to `Gen3Scene.lua`/`BuildingModels.lua`, which another session is also touching (ledges, `Gen3Outdoor.lua`); coordinate or use `OWN_LIB`.
