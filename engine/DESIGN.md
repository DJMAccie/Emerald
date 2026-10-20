# E2 design: our own engine pieces, starting with a whole-world height solve

Status: design only (2026-10-20). Nothing here is implemented. Prerequisite E1 (headless builder,
`engine/README.md`) is accepted: Route 103, Oldale and Rustboro headless dumps equal the in-game ones.

## 1. The contract every piece is judged by

* **Output:** the geometry dump (`<MAP>.geo.gz` + `<MAP>.cells`, `tools/autoloop/em_geo_driver.lua` format),
  written by `engine/headless_geo.lua`. A piece is a replacement for part of the rc builder; the dump with the
  piece in is compared with the dump of the unchanged rc builder on **every** map of the ledger
  (53 outdoor + 105 caves: 200-500 s wall for all 158 with 8 processes on today's shared machine, load average
  80-150; about 580 s of CPU in all).
* **Judges, in order:** (1) `compare_geo.py` / `compare_all.py`: which cells moved, and that only cells the piece
  is meant to move did; (2) the autoloop detectors on the dumps (D1 float, D2 hanging plate, D3 mini-stairs,
  D4 ledge lip): no map may get worse, the piece's target faults must go; (3) `heights_compare.py` on the
  `.cells` base column; (4) in-game captures at levels 4, 6, 7 for the final look (the user's taste rules:
  `docs/AUTOLOOP.md`, skill `emerald-terrain` section 1). Accepted = matches or beats the rc builder everywhere.
* **Entry into the mod:** a piece enters the rc tree like any loop fix, through `tools/autoloop/gate.sh`, one
  piece per commit, revertible on its own.

## 2. Where heights come from today (what E1 measured)

The builder solves heights per **build window**, from the map the player stands on:

1. `Gen3Elevation.field(def)` solves one map's floor field (`TerrainLevels.build`: floor groups by flood,
   stair flights between groups, median pin per group, ledge drops, pockets, relief). It is per layout and
   cached, so it is already window independent. **All 53 outdoor maps (118,360 cells) take 1.07 s CPU
   together** (worst Route 124, 0.07 s): a whole-world solve is affordable at runtime.
2. `TerrainLevels.align(regions)` places the connected maps the window reaches: the viewer map is datum 0,
   every other region takes an offset = the most common height difference along its shared seam, spread
   breadth-first from the viewer in region-list order.
3. `Gen3Elevation.bind(cells, regions)` gives every cell `base = field height + region offset`, then
   window-local passes adjust it: `supportFill` (void fill), assembly foundations, rivers, sea rocks, water
   settling, decks, Cycling Road, ledge ends, corner slopes; Gen3Mass/Rock/Relief/Hills then raise rock.

Two consequences, both measured headless (`engine/probes/align_views.lua`, rc e6a02ab):

* **A map's height depends on where you look from.** Of 319 map pairs seen together from two or more viewer
  maps, **68 get a different relative height depending on the viewer**: Route 113 stands 56 px above Route 114
  seen from five maps and level with it seen from Route 115; Route 123 is 96 or 48 px under Route 120;
  Lavaridge is 64 px off from Route 116's view. Walking across a seam re-roots the solve, so the far scenery
  jumps, and the margins of a dump depend on which map was dumped.
* **Window edges are built with half a neighbourhood.** The in-game dump keeps each cell from the first spot
  whose window held it. A whole-map (`--full`) headless build of Route 103 differs from it in 6 cells only
  (326 / 306 triangles): x = 50, rows 0-4, which is exactly the east edge of the first spot's window (spot
  12,10: window x -20..50), where rock courses are cut by the window, and 56,2 beside it. Oldale's and the
  in-game dump agree everywhere (tree prototypes aside). (Since c4cae35 the driver owns only cells 6+ inside a
  window for this reason; the builder still builds the edge that way, and a world solve removes the cause.)

World geometry facts (headless probe over the engine's own `connections.lua`): 61 maps have connections,
in **4 components of 49, 6, 4 and 2 maps**; placing maps by their connections gives **one** loop that does not
close (Oldale / Route 103: 2 rows apart going round the loop through Route 110). Every other map is a
component of its own (caves, interiors, islands reached by warp).

## 3. Piece 1: the world height solve

### What it computes
For each connected component, once: a **world height field** = one absolute height per cell of every map in
the component, plus the same for the fill ring round the component's outer edge (8 cells, what `Gen3Boundary`
draws), plus the per-cell solver fields the builder reads today (`floor` record: group, step, connector,
relief, ledge drop, slope corners). It replaces steps 2 and 3a (`align` and the base part of `bind`,
`supportFill`) of section 2; everything after the base stays the rc builder's at first.

### How
1. **Layout.** Place every map of the component by its connections, breadth-first from a fixed root (the
   component's first map in sorted id order), integer cell offsets. An edge that disagrees with the placement
   (the Oldale/Route 103 loop closure) is kept as a seam for alignment but not used for placement; it is
   reported. Result: `world[mapId] = {ox, oy}`; deterministic, independent of the viewer.
2. **Per-map fields.** Unchanged at first: `Gen3Elevation.field(def)` for every map (1 s for the whole outdoor
   world). Later (piece 1b) the field solve itself becomes world-wide: floor groups that continue across a seam
   are one group, so a median pin and a stair flight on one side constrain the other.
3. **Global alignment** instead of the viewer's breadth-first one. Every seam between two maps gives a
   histogram of height differences of floor cells facing each other (`TerrainLevels.align`'s `difference`,
   same water/water rule). Unknowns: one offset per map, root = 0. Solve as a **maximum spanning tree by seam
   support** (number of agreeing cells), ties by map id; then report every non-tree seam whose own mode
   disagrees with the tree (the residual): these are the places where the drawn world itself is inconsistent,
   and each becomes a ramp or a cliff decided once, in data (`height_overrides.json`-style rows with a `why`),
   instead of a jump that depends on the viewer.
4. **Fill ring.** `supportFill`'s rule run once on the world grid (fill cell no higher than the ground it
   touches, one COURSE down, closed onto the map's floor), so the margin of a map is the same from every
   viewer and from every spot of the dump.
5. **Lookup.** `base(mapId, x, y)` for any cell of the component, and `baseAt(worldX, worldY)` for fill.
   The builder's window then reads instead of solves: `regions[i].floorOffset = world[region].offset - world[viewer].offset`,
   `c.base` from the field. Heights stay viewer-relative numbers (the renderer's datum is the viewer's map), but
   every viewer gets the same world.

### Determinism (the rules E1 showed are needed)
* No decision may depend on `pairs()` order: the game's LuaJIT randomises string hashes per process (two
  processes iterate `{k1..k12}` in different orders), which already made heights differ run to run (F025).
  Iterate sorted ids / row-major cells; break every tie by coordinates or ids.
* No tables as keys in an iteration that decides anything (addresses differ per run).
* No dependence on tileset animation state (F034: Route 103's shore rock changed with the water frame): read
  tiles from the decoded atlas, never from a live, animated one.
* Integer heights (px) in the field; fractional values only in mesh vertices.

### Running it inside the mod (players)
* **Pure Lua 5.1 / LuaJIT, no FFI** (the mod sandbox denies FFI), no `io`, no `os.getenv` (stubbed in the
  sandbox). Inputs only through what the mod already reads: `def.midLayout`, `game.data.maps[*].connections`,
  the tile tables, the pin tables.
* **Generated on the player's machine, never shipped**: the output derives from the ROM's maps and art. First
  entry into a component (or a loading screen at boot) runs the solve as a coroutine under `BuildBudget`
  (the same slicing the scene build uses), about 1-2 s CPU for the 49-map component.
* **Cached** in the mod's save area (`mod.storage`, the API `VoxelMeshDisk` already binds) as a Lua table:
  per map a run-length string of heights and the floor records' small fields; about 120k cells for the outdoor
  world. **Key = content hash** of: every map layout of the component (cells + overrides), the tile tables and
  pin tables (`Gen3StairTerraces`, `Gen3EmeraldTerraces`, `height_overrides`), and the engine piece's own
  version string. Not `tostring(table)` (BAKE-SPIKE: addresses change per run). A stale or missing entry is
  just recomputed.
* **Overrides at runtime** (a layout cell changed by a script: Cut tree, boulder, door) change the key of
  that map only; that component is re-solved (1 s) or, later, patched locally.

### Acceptance for piece 1 (in this order)
1. Headless, **identity check**: with alignment replaced by "the world offsets as the viewer's BFS would give
   them", every dump is identical to the rc builder (proves the plumbing changes nothing).
2. Headless, real world offsets: `compare_all.py` shows changes **only** in cells of regions whose viewer
   offset disagreed (the 68 pairs) and in fill rings; `.cells` base moves listed per map.
3. Detectors on all 158 maps: no new D1/D2/D3/D4 hit; seam faults the loop has parked as "depends where you
   stand" disappear.
4. Dumps of each map from several spots (the spot walk's spots, and one per neighbour) give the same heights
   for every cell: the window-edge difference of section 2 goes to 0 for heights.
5. In-game captures across seams (Route 113/114, Route 120/123, Lavaridge/Route 112, Oldale/Route 103) from
   both sides, levels 4/6/7: no jump, no double ledge. User's yes.

## 4. Later pieces (same harness, same contract)
* **1b. World floor groups**: the field solve across seams (see 3.2). Judge: D3 mini-stairs and seam ledges.
* **2. Fill ring geometry** from the world field instead of per window (the Route 112 west-margin plates).
* **3. Terrain surface mesher**: flat and sloped ground from the world field as merged quads (today one quad
  per cell side: Rustboro's field meshes are 505k vertices). Judge: triangle set equal after merging coplanar
  quads (a checksum on the covered area per plane, not per triangle), then frame time.
* **4. Rock**: masses solved world-wide (a mass cut by a map seam is one mass), then their meshes.
  Each step keeps the rc builder as the reference until it is replaced.

## 5. What the harness needs for E2 (small, all in `engine/`)
* `--substitute Module.fn=engine/pieces/<file>.lua`: replace a module function at load time (in the harness
  only; the rc tree is never edited) so a piece runs inside the real builder.
* `--world` dump mode: the whole component in one build, cells owned by the map they belong to (no spot walk,
  no window edges), for piece judgement next to the in-game-compatible spot walk.
* A `.heights` side file per map: `x y base floorGroup offset` for the heights gates, cheaper than `.cells`.
* Run-to-run noise list per rc commit (two headless sweeps, `compare_all.py`), so a gate can tell a piece's
  change from the builder's own `pairs()` noise.
