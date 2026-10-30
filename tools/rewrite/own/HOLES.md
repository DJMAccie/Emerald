# Holes in the lifted field modules

Each `--@HOLE <id>` line in the lifted file is one upstream-derived region; write the
behaviour the spec gives for that id, in place, and leave the rest verbatim.

## lib/Gen3Elevation.lua -> Gen3Elevation.lua

1342 our lines, 76 upstream lines replaced by 17 holes.

| lifted line | hole id | upstream lines | what belongs there |
|---|---|---|---|
| 1 | `file-header` | 1 | MIT header + module job in one line |
| 16 | `requires` | 5 | V, TerrainLevels, Gen3Tilesets, the weak field cache, M |
| 137 | `field-prologue` | 16 | layout/cache signature, behaviours, tileset spec, shapes, drop table, outdoor/cave/deck flags |
| 548 | `build-open` | 2 | Levels.build(w, h, read, compatible, 6, tick) - the read callback head |
| 558 | `read-shape` | 1 | the cell's shape kind (water test) inside the read callback |
| 574 | `compat-open` | 1 | the compatible callback head |
| 579 | `compat-close` | 2 | the compatible callback body + the build call tail |
| 1176 | `field-epilogue` | 7 | cache store, M.cell, M.at |
| 1233 | `bind-open` | 1 | M.bind(cells, regions) signature |
| 1246 | `bind-floor` | 16 | per region, the cell's floor/base/floorHigh lookup |
| 1293 | `bind-donor` | 6 | the nearest-region donor fallback for c.base |
| 1305 | `bind-props-open` | 7 | the props' groundHeight settle, head |
| 1317 | `bind-props-close` | 4 | the props' groundHeight settle, tail |
| 1403 | `bind-close` | 1 | end of the props loop / M.bind |
| 1405 | `lift-guard` | 1 | M.lift: return when height is 0 |
| 1407 | `lift-loop` | 1 | M.lift: the vertex loop head |
| 1415 | `lift-return` | 4 | M.lift tail, M.invalidate, return M |

## lib/TerrainLevels.lua -> TerrainLevels.lua

350 our lines, 134 upstream lines replaced by 12 holes.

| lifted line | hole id | upstream lines | what belongs there |
|---|---|---|---|
| 1 | `file-header` | 3 | the module's header comment |
| 16 | `directions` | 1 | the four neighbour offsets (E, W, S, N) and M.directions |
| 18 | `build-skeleton` | 67 | key(); M.build head; read; group flood; flights; jump-strip edges; height solve |
| 300 | `flight-bounds` | 5 | per flight: low/high from the group heights |
| 330 | `flight-close` | 4 | the step-cell loop tail of the flight interpolation |
| 338 | `support-seed` | 1 | the nearest-support queue seed |
| 340 | `support-loop` | 8 | the nearest-support BFS |
| 417 | `build-return` | 4 | return f; end |
| 424 | `align-core` | 22 | M.align head + the seam difference() sampler |
| 448 | `align-loop` | 15 | the region-offset propagation loop, M.align tail and M.at head |
| 474 | `at-flight` | 1 | M.at: the plain flight formula when no treads are set |
| 482 | `at-return` | 3 | M.at tail |

