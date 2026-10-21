# Build our own engine? — investigation, 2026-10-21

**Question:** is it beneficial to expand or migrate Emerald 3D off Lua/LÖVE2D and build our own
engine?

**Answer:** not as a rewrite. The steady-state renderer is not the problem — its world draw costs
about **4 ms of a 16.7 ms frame** at 1080p on this Mac (the whole 3D frame is ~12 ms, inside 60
fps), with 150 draw calls, and LuaJIT has the headroom. The problem the player feels is a **scene
rebuild that costs 1.1–1.4 s of CPU and restarts every six cells of walking**
(`Gen3Scene.lua:381`), with no disk cache for Gen 3. A new engine written in C++/Rust will still
stall unless that pipeline is rebuilt first, and a full rewrite would have to reproduce (or
re-host) ~777k lines of engine Lua plus ~173k lines of mod Lua.

So: **expand, don't migrate.** Spend the next block on a baked, stable-section world pipeline; then
put a native renderer behind the existing draw seam only if the frame budget is still the limit.
A from-scratch engine is only rational if the goal changes from "the best Emerald 3D mod" to
"a standalone product on our own storefront/consoles".

Everything below is measured on this machine (Apple M1, macOS 27.0, 4K display at 1920×1080
desktop, LÖVE 11.5 / OpenGL 3.3, engine v0.3.52, mod 1.28.9). The harness is a QA copy, not the
user's install; numbers are for engineering direction, not a release benchmark.

---

## 1. What "our own engine" would actually replace

```
[4] content        ROM (user-supplied) + 123 baked building models + tile/shape tables
[3] the mod        172,603 lines Lua, 295 files: world builders, materials, Gen3Scene/Voxel3D,
                   battle stage, UI overrides, 32 shaders
[2] the game engine 776,886 lines Lua (GPLv3): ROM import, maps, scripts, battles, save, audio,
                   online, UI         (~343k more lines are generated symbol tables)
[1] the host        LÖVE 11.5 / SDL2 / OpenGL 3.3 / C++: window, input, image, audio, filesystem,
                   Mesh/Shader/Canvas API
```

"Migrate off Lua" can mean replacing [1], [2], [3], or all of them:

- **Replace [3] (the renderer)** — keeps everything the project has built; this is the "expand" path.
- **Replace [1]+[2] (a new host/engine)** — must re-run or reimplement 777k lines of Lua with 4,593
  `love.graphics` call sites alone. This is where "our own engine" gets expensive.
- **Replace everything** — a different product. Not an engineering upgrade.

The value of this project is in [3] + the content pipeline, not in [1]. That is the layer to invest
in.

## 2. What we measured

Method: `tools/em_bench_driver.lua` (new) boots Emerald in a disposable QA identity, loads Route
112 at (27,29) — a rock/cliff-heavy spot — sets the 2.5D camera, warms 180–240 frames, then samples
180 frames with vsync off and the frame cap raised. It records frame interval, CPU inside the world
draw, CPU inside the engine/mod present, draw-call and shader-switch counts from
`love.graphics.getStats()`, and GPU wait inside `love.graphics.present`. Reproduce with:

```bash
cd ~/Documents/Emerald
QA_ZOOM=-2 EM_W=1920 EM_H=1080 EM_WARM=240 EM_FRAMES=180 \
EM_DRIVER=$PWD/tools/em_bench_driver.lua \
tools/qa_tryp.sh "Gen3Scene.lua" /tmp/bench "{'EM_ROUTE112',27,29}" "4,7" 0.8 220
grep '\[BENCH\]' /tmp/bench/run.log
```

| Metric (Route 112, 1080p) | 3D, level 4 | 3D, level 7 | flat 2D (level 0) |
|---|---:|---:|---:|
| Frame, median | **11.9–12.2 ms** | 10.0 ms | 4.2 ms |
| Frame, p95 | 16.1–18.2 ms | 13.2 ms | 7.0 ms |
| Frame, mean | 12.4–14.7 ms | 9.9 ms | 4.3–5.1 ms |
| World draw CPU (mod) | **3.5–4.2 ms** | 3.9 ms | 0.5–0.7 ms |
| Present CPU (engine + post) | 3.8–4.7 ms | — | — |
| GPU wait in present | 1.7 ms | — | — |
| Draw calls / shader switches | 149 / 50 | 150 / 50 | 35–55 / 4 |
| Canvas switches | 12 | 12 | 10 |

Cross-checks:

- **Not GPU-bound at this resolution.** 720p and 1080p frames are within noise of each other
  (9.9–11 ms at both), no scaling with pixels. The frame is CPU-bound at 1080p.
- **60 fps fits, barely.** At the user's 1080p/60 borderless setting the budget is 16.7 ms; median
  12 ms leaves ~4.5 ms for everything else. p95 is already at the cap.
- **Occasional 300 ms stalls.** Two of six runs recorded a single 335–340 ms frame. The
  steady-state averages do not locate it; per-frame attribution (which call owns the frame) is the
  first profiling job — it may be asset upload, shader compile, GC, or a synchronous build step.
- **Route 115 / 111** (cliff and plate spots) at 720p: 8.3–9.5 ms mean, 113–118 draw calls,
  3.4–4.4 ms world CPU. Route 112 is the expensive case, not the norm.

The steady state is fine. The 300 ms stalls and the pop-in are the defects.

## 3. The real bottleneck: the scene is rebuilt as a window, not stored as chunks

The scene builder produces a *camera-window snapshot*:

- `Gen3Scene.lua:381` — `bx,bz = floor(px/96)*6, floor(pz/96)*6`; the window origin moves in
  **6-cell (96 px) steps**.
- `Gen3Scene.lua:399` — the stream key includes `x0,z0,x1,z1`, and `Gen3SceneCache.lua:6` puts the
  same bounds in the cache key. Moving six cells changes the key.
- `SceneStream.update` treats a key change as a different scene: it starts a build of the whole
  window, keeps showing the old scene, and `keepStale=true` lets the old build finish while the
  next one is requested. Walking continuously queues rebuild after rebuild.

Measured build cost (`tools/em_times_driver.lua`, same QA harness):

| Map | First visible area | Full scene build | Most expensive tile class |
|---|---:|---:|---|
| Route 112 | 685 ms | **1,413 ms** | tree 527 ms / 241 cells; cliff+mass 448 ms / 715 cells |
| Rustboro City | 352 ms | **1,096 ms** | fence 253 ms / 64 cells; flat 40 ms / 645 cells |

And the build is sliced at **40 ms per frame** when cold (`Gen3Scene.lua:2662`; 120 ms for the
first area). That is ~25 fps during a cold build and ~8 fps during the first area, and the full
build is ~1.4 s of CPU — so entering a map is a multi-second flat/stale view, and a six-cell step
starts the next one.

Why this settles the engine question:

- A native builder that is **10× faster** would still spend ~140 ms per six cells, and a running
  player crosses six cells in about a second. It is still a stall, still a rebuild.
- A **cache/chunk** design spends ~0 ms on the step and ~50 ms on a cold map load.
- The fix is the world representation (stable sections + baked vertex streams), not the language.
  Lua already produces the geometry correctly; it is being thrown away and rebuilt.

This matches what Gen 1/2 already do: `ChunkMesher` builds stable map chunks, `VoxelMeshDisk`
persists the vertex streams to the save directory, and `VoxelPrecache` warms warp destinations.
Gen 3 has an in-memory scene cache but neither stable sections nor a disk stream cache. That is the
gap to close.

There is a second, smaller cost in the same place: cold builds deliberately buy time with a low
frame rate (`40 ms` slices) instead of a loading screen. A baked cache makes that trade-off mostly
disappear.

## 4. Is Lua itself too slow?

No, at this scale:

- **LuaJIT runs the game logic and the builders.** The per-frame path is ~150 C draw calls; the
  per-cell geometry is Lua arithmetic and table building, which LuaJIT compiles and which finishes
  a map in ~1.4 s. The mod already uses `Mesh:setVertices` uploads and has an FFI buffer path where
  `ffi` is available.
- **Draw submission is not the bottleneck.** 149 draw calls and 50 shader switches per frame is a
  hand-written renderer's normal range. A native renderer would cut the 3.5–4.2 ms world CPU maybe
  in half and the present path by some amount; it would not touch the 1.4 s rebuild.
- **The 335 ms stalls are unexplained, not proven to be Lua.** They must be attributed per frame
  before any language decision; the steady-state numbers alone do not say where they live.
- **What Lua does cost** is engineering discipline: a 173k-line dynamically typed mod that
  monkey-patches a 777k-line engine. A native rewrite does not fix that; it duplicates it.

## 5. What a custom engine would buy, and what it would cost

| | Stay on LÖVE, fix the pipeline | Native renderer inside a LÖVE fork | New host/engine from scratch |
|---|---|---|---|
| Keeps engine + mod Lua | yes | yes | no (port or embed) |
| Fixes the 1.4 s rebuilds | **yes, if chunked/baked** | only if the builder is also rebuilt | only if rebuilt |
| Cuts steady-state CPU | a few ms via batching/LOD | ~3–6 ms, more headroom | ~4–8 ms |
| Compute / indirect / bindless | no | yes (native GL) | yes |
| Vulkan/Metal, DLSS/FSR3 frame-gen | no | no (LÖVE is GL) | yes |
| Console/mobile store control | no (engine-dependent) | no | yes |
| Distribution | mod into official engine | **own engine build for every platform** | own build |
| Effort (solo estimate) | **6–10 weeks** for chunk+disk cache | 3–6 months for static-world parity, 6–12 for full | 12–24 months, high risk |
| Ongoing cost | tracks upstream engine | fork maintenance, CI, signing/notarising, upstream drift | all of the above + platform ports |
| Legal | mod licence chain unresolved | fork is GPLv3 + attribution | GPL if it reuses engine code |
| Chance of visual regression | low (same pipeline) | medium (GL state interop) | high |

Important constraints that decide the middle column:

- **A mod cannot load native code today.** The mod sandbox denies `ffi` (`Sandbox.lua`'s `DENIED`
  table: "arbitrary C calls") and `love.thread` needs a `compute` permission; graphics objects are
  main-thread only. A native renderer therefore requires an engine fork or an upstream engine
  change — not a mod drop-in.
- **The app is fused and auto-updates.** A fork means distributing your own build and carrying it
  against upstream; the current project deliberately needs "no custom engine patch".
- **The engine is GPLv3 with attribution terms.** A fork must be GPL and credit the original; the
  mod's upstream chain has no licence at all (`PROVENANCE.md`), which a custom engine does not fix.

## 6. Options, judged

| Option | Verdict |
|---|---|
| **A. Stay in Lua, bake/chunk the world + disk cache** | **Do this now.** Biggest player-visible win per week of work; survives any future engine move. |
| **B. Lua renderer batching/LOD/instancing** | Do after A. Cheap ms, no architectural change. |
| **C. Native renderer inside a LÖVE fork** | Conditional. Only after A, and only if the frame budget blocks the "life" pillar (ambient Pokémon, more foliage). Start as a 2–3 week spike on one terrain chunk with a hard A/B gate. |
| **D. New host embedding the existing Lua engine** | Not now. 12–24 months of host API work (LÖVE graphics/audio/filesystem/window/event), for maybe 4–8 ms and platform control. |
| **E. Port to Godot/Unity/Unreal** | No. Same as D plus re-authoring the renderer, UI, audio, save and mod API; loses the ROM-import and engine feature set. |

## 7. Recommended path (phases and gates)

**Phase 0 — profile the stall (2–3 days).** Instrument the 335–340 ms frame: wrap `newMesh`,
`newImage`, `newCanvas`, `newShader`, mesh uploads and GC; attribute it. Do not start an engine
project before the cause is known.

**Phase 0b — try the one-line window snap (half a day, in parallel).** `Gen3Scene.lua:381` snaps the
window to 6 cells (`px/96*6`). Coarsening that to 24 or 48 cells cuts the rebuild frequency 4–8× at
the cost of a larger edge pop; measure it with the bench before touching anything else. It is a
band-aid, not a substitute for Phase 1, but it is the cheapest way to confirm the diagnosis.

**Phase 1 — stable sections + baked vertex streams (6–10 weeks).**
- Cut the Gen3 world into stable sections (per map section / 6-cell block, aligned with the current
  window grid) and build each once per (map, section, tile identity, options) key.
- Persist the vertex/index streams with the `VoxelMeshDisk` contract (header, `CACHE_REVISION`,
  fingerprints, fail-open reads); port `VoxelPrecache` for warp destinations.
- Keep one mesh per material and update only changed ranges (`Mesh:setVertices` with a start/count)
  or one mesh per section if the draw-call count stays under ~400.
- Dynamic edits (cut trees, doors, flags) become section invalidation or a small overlay mesh.
- Acceptance: crossing six cells costs **no rebuild**; a cold map entry is **< 200 ms** (warm
  cache < 50 ms); no frame over 50 ms in the walk bench; the existing dump/geometry gates stay
  identical (they compare cell data, not mesh layout).

**Phase 2 — Lua renderer wins (1–2 weeks).** Sort draws by atlas/material to cut the 50 shader
switches, instance repeated props/canopy, add section-level frustum culling and a distance LOD;
re-measure with the same bench.

**Phase 3 — decide on native (gate).** Only if, after Phases 1–2, the 3D world draw is still the
limit for the planned content: build the seam first (below) and spike one static terrain section in
C++ inside a LÖVE fork. Gate: ≥3 ms/frame saved at 1080p, pixel-identical or better on the existing
A/B sheets, no regression in the dump/geometry gates. If it fails, stop; the seam still pays for
itself.

**Not on the roadmap:** a from-scratch host or a Godot port. Revisit only on a product decision
(standalone release, consoles, 4K/120, frame generation) — and even then the baked world format is
the first deliverable, because it is the only part that survives the move.

## 8. If we do go native: the migration shape

Do not port the 777k-line engine. Put a narrow seam under the world renderer and replace it
feature by feature:

```
Lua (unchanged):  world builders → baked sections → [seam] → LÖVE meshes / native renderer
seam (new):       world_begin(camera) ; world_add_section(material, vertexBytes, indexBytes)
                  world_draw_pass(pass) ; world_end()
```

- Lua keeps ownership of geometry generation; the native side owns GPU buffers, sorting, culling,
  shadows and post. That keeps the content pipeline and the game logic untouched.
- Inside a LÖVE fork, the module can use the current GL context; it must save/restore LÖVE's GL
  state (FBO, shader, depth mode, VAO) before the UI pass. LÖVE caches state, so this is the main
  interop hazard.
- Replace in order: static terrain → static props/buildings → trees/foliage (instanced) → actors
  and sprites → shadows/post. Each step has the repo's existing screenshot and geometry gates.
- Distribution cost is real: universal macOS build + notarisation, Windows/Linux CI, engine update
  policy, GPL source publication and attribution. Budget it before writing shader code.

## 9. Signals that would change this recommendation

- After Phase 1–2 the 3D world draw is still > 8 ms/frame at 1080p, or the target becomes 4K/120.
- The "life" pillar needs 2–4× more drawable objects than the current budget allows.
- A standalone/console/mobile-store release becomes the goal (platform control, frame generation).
- Upstream engine changes start breaking the mod faster than they can be absorbed (then a fork is
  about stability, not performance).
- The 340 ms stall turns out to be inside LÖVE itself rather than the mod (unlikely, but profile
  first).

## 10. Files and commands

Mod paths named below (`Gen3Scene.lua`, `VoxelMeshDisk.lua`, ...) are in
`~/Documents/battle-art-notquiteog/lib`; engine paths are in `~/Documents/gen1recomp`.

- New bench: `tools/em_bench_driver.lua` (frame, world CPU, present CPU, draw calls, GPU wait).
- Build-time driver: `tools/em_times_driver.lua` (copy, edit the map list; prints `[EM times]` and
  `[EM kind]`).
- Existing renderer: `Gen3Scene.lua` (build/draw), `Gen3SceneCache.lua` (key), `SceneStream.lua`
  (slicing), `VoxelMeshDisk.lua` + `VoxelPrecache.lua` (the Gen 1/2 pattern to port).
- Existing perf surface: `Perf.lua`, `LoadTimings.lua`, `BuildBudget.lua`,
  `PerformanceExport.lua` (`mod.exports.performance.snapshot()`).

## 11. Bottom line

- The engine is not what is failing. The scene pipeline rebuilds a 1.4 s window every six cells.
- A rewrite would reproduce that unless the pipeline is redesigned; a 10× faster builder still
  cannot keep up with a six-cell cadence.
- Fix the pipeline (chunk + bake + cache) in Lua. Then, if headroom is still the blocker, add a
  native renderer behind the seam inside a LÖVE fork.
- Keep the full-engine rewrite off the table until the product, not the frame time, demands it.
