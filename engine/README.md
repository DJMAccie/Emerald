# Headless builder (engine track E1)

The voxel mod's real 3D scene builder (`Gen3Scene` and everything it calls, from the autoloop's
release-candidate tree, read only) running outside the game, driven by the in-game dump driver
`tools/autoloop/em_geo_driver.lua` itself, so it writes the same geometry dump. No game boot, one process per
map, many at once.

```bash
engine/geo.sh --tree ~/Documents/Emerald/.autoloop/rc --maps maps.txt --out /tmp/geo -j 8   # "MAP x y" lines
engine/geo.sh EM_ROUTE103 EM_OLDALE_TOWN EM_RUSTBORO_CITY --out /tmp/geo           # ledger spots, live rc tree
engine/geo.sh EM_ROUTE103 --out /tmp/geo --rc e6a02ab --driver c4cae35               # a given rc and driver commit
python3 engine/compare_geo.py ~/Documents/Emerald/.autoloop/geo/EM_ROUTE103.geo.gz /tmp/geo/EM_ROUTE103.geo.gz
python3 engine/compare_all.py IN_GAME_DIR HEADLESS_DIR                                # every map in both, one table
```

## What runs

| Layer | Headless | Source |
|---|---|---|
| Lua VM | **the game's own LuaJIT** (2.1.1700008891, `gen1recomp.app/.../Lua.framework`) through `bin/emhost`, a 40-line C host (`host/emhost.c`) built into the engine cache | the app bundle, read only |
| Driver | `tools/autoloop/em_geo_driver.lua` **unmodified** (main checkout, or `--driver COMMIT`): spot walk, capture, settle, ownership, output | `~/Documents/Emerald`, read only |
| Engine | the **real** engine modules of the payload the game runs (`updates/gen1recomp-<ver>.love`, unzipped into the engine cache): `game3/dataset` (map defs, connections, warps), `layout_native`, `tileset_native` + `asset_decode` (atlases), `map` (`refreshWorld`, `computeWorld`, `worldMidAt`, `loadNeighborsDepth1`), `collision`, `field` (`setMetatile`, `clearMetatiles`), the script VM (`scripting/space`, map enter scripts), `interaction_scripts` (tile behaviours), `tileset_anim`, `rng` | payload, read only |
| ROM data | the QA identity's cache `pokemon-love2d-rseqa/emerald/data/generated/gba` (zlib blobs inflated through FFI `libz`) | read only |
| Mod | `lib/*.lua`, `data/*.lua` of the rc tree, loaded exactly as the mod's `main.lua` does (`V.require` / `V.data`, chunk names `@<root>/lib/<name>.lua`) | `~/Documents/Emerald/.autoloop/rc` or a `git archive` snapshot |

A game frame is the builder's own entry: `Gen3Scene.draw`'s first step, the local `prepare()` (request ->
`SceneStream` -> `build`), taken from `Gen3Scene.draw`'s upvalues; the rest of `draw` only renders. Entering a
map therefore builds what the game builds (near area, its upgrade, then the AUTO = 32-cell view window round the
player) through the same coroutine, so even the dump's `?:0` caller tags come out the same.

## Stand-ins (what the game provides that is not run)

| Game part | Stand-in | Why it cannot change geometry |
|---|---|---|
| LOVE `ImageData` | FFI byte buffer; `getPixel` returns LOVE's float32 `byte/255f`, `setPixel` rounds as LOVE 11.5 (`c*255f+0.5f`) | pixels are real: every pixel test of the builder (crowns, glass, rock faces, tree carving) reads the true atlas |
| LOVE `Mesh` / `newMesh` | keeps the vertex list and vertex map; GPU edits (`setVertex`) kept apart | the dump reads the Lua vertex tables, as in game |
| LOVE `Image`, `Canvas`, `Shader`, drawing state | inert objects (dimensions only); every other `love.graphics` name answers a no-op and is counted (`[EM headless] love stand-ins reached`, `none` so far) | drawing only |
| `love.timer.getTime` | stands still while a frame builds, CPU time between frames | `BuildBudget` never yields: a build is one resume (in game it is sliced over frames; same result) |
| `love.data` | `compress`/`decompress` via FFI zlib, `pack` (f, d, I4...), `newByteData`, `newDataView` | `FlatMesh` uploads, which the dump never sees (not `Voxel3D.newMesh`) |
| `love.thread` | absent | the engine's asset stream decodes tilesets synchronously (`Stream:get`), same data |
| driver's `U.wait(n)` | n frames of `prepare()`; the camera's `.active` set when the scene is ready; `EM_SETTLE` 3 (no build spans frames) | |
| `game:_handleBootAction(new_game)` | loads the boot map (Littleroot); its 90 boot frames do not build it unless `--boot` | no difference found with or without |
| `Map.load` | `lib/headless.lua H.loadMap`: current map, def, layout, depth-1 neighbours, player at the spot, collision grid, `Field.clearMetatiles`, then the map's **enter scripts on the engine's script VM** (ON_TRANSITION, ON_LOAD, ON_RESUME, ON_WARP_INTO_MAP) with a fresh new-game flag store, so their `setmetatile` edits (doors, tombs, Lilycove's rock, Sootopolis) are in the layout | ON_FRAME (cutscenes), NPCs, audio, weather, popups are not run |
| `src.core.game3.player` | a table with `px, py, cellX, cellY, facing, elevation` | the build reads only the position |
| mod object (`V.mod`) | `options:get` from the QA identity's `options.lua` (`modOptions.BATTLE_ART_VOXEL_FORK`), else the schema default; `read` = rc tree then the QA install (assets) | |
| camera | `Gen3Integration`'s camera table, `setLevel(4)` by the driver (`install()` is not run: it only wraps engine draw hooks) | |
| mod tree | **not modified, not wrapped** | |

## Contract and known differences with in-game dumps

* **Draw-time and prototype meshes.** In-game dumps also hold meshes made while frames are drawn (NPC/player
  cards `fn=actor`, field effect cards `fn=effect`, landmark models `SpriteVoxel<LandmarkModels`, rock/ball/boat
  models `Gen3RockSprites`) and tree prototypes (`NativeTreeArt.addInstance`, instanced at draw time). Most are
  in model space at the origin, so they land in cells round 0,0, and which build's group holds them varies.
  `compare_geo.py` lists them as `draw:*` / `proto:*` and leaves them out of the scene checksum.
* **Route 111's Mirage Tower** stands headless and is hidden in game (18 `.cells` lines, about 69k triangles):
  the enter scripts run headless leave `FLAG_MIRAGE_TOWER_VISIBLE` unset, as in game, but the hiding tile edits
  do not happen; not traced further.
* **In-game noise.** The same driver twice in game: Battle Frontier West differs in 22 cells of row 39
  (6720/3800 triangles; headless equals one of the two runs exactly); actor meshes differ (Rustboro 432 vs 744).
  The builder's own `pairs()` order (string hashes are seeded per process in this LuaJIT) gives the same kind
  of noise headless: two headless sweeps of 158 maps differ on 12 maps.
* **Dark caves.** In game, a cave that needs Flash is drawn by the flat renderer (`Scene.nativeRequired`), so the
  driver dumps nothing for it (Granite Cave B1F/B2F: 0 triangles, `.cells` left over from the previous map).
  Headless builds them in 3D.
* **Tileset animation at boot.** The driver before 20 Oct 18:30 pinned the animation after its 90 boot frames;
  dumps made with it need `--anim-steps 64` for Littleroot's tileset (Route 103).
* **LuaJIT version.** Only the game's LuaJIT gives identical text: the system luajit (2.1.1788856981) formats
  `%.1f` ties to even (35.25 -> "35.2"), the game's away from zero ("35.3"). `--luajit` runs on it anyway.

## Files

* `geo.sh` - wrapper: payload, host, rc snapshot, driver version, parallel runs.
* `headless_geo.lua` - runs the in-game driver with the game parts above stood in.
* `lib/headless.lua` - boot: engine modules, data, tilesets, scripts, mod loader, `loadMap`.
* `lib/love_stub.lua`, `lib/zlib.lua`, `lib/paths.lua` - LOVE stand-in, FFI zlib, input paths (env overrides
  `EM_RC`, `EM_PAYLOAD`, `EM_GBA_CACHE`, `EM_OPTIONS`, `EM_ENGINE_CACHE`).
* `host/emhost.c` - the host for the game's LuaJIT.
* `compare_geo.py`, `compare_all.py` - kinds, checksums, differing cells, `.cells` diff; per map and per folder.
* `probes/align_views.lua` - E2 groundwork: how the per-viewer alignment of connected maps disagrees.
* `DESIGN.md` - E2: our own engine pieces, starting with a whole-world height solve.
