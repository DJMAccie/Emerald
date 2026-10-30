# Spec — P2 HeightField: the floor field (TerrainLevels + Gen3Elevation)

Spec writer: rewrite coordinator (Emerald repo), 2026-10-29. Implementer: a fresh session in this repo.
Read only: this spec, `docs/specs/ProbeContract.md`, `docs/specs/GeometryCore.md`, the engine reference in
`.ref/`, and our own lifted code in `docs/own/`. Never the old mod (the deny rules enforce it).

## 0. The parity rule (read first)

The 3D game Petya plays today is the target look (Emerald `docs/knowledge/rules.md` R-36, 2026-10-29:
"one thing i want to make sure is that we dont change anything about the look we have now! we are really
close to the desired look of the game"). This milestone invents nothing: it reproduces the field the old mod
has, cell for cell and class for class. A height or class that differs from the baseline is a fault, not an
improvement. The gate (§9) is exact.

## 1. Purpose

Every drawn height in the mod comes from one table, the **floor field**: for every map cell it says whether
the cell is walkable floor, what height that floor stands at, which group of connected floor it belongs to,
and (on the hand-drawn maps) which PLATEAU RULE class it is. `TerrainLevels` solves the topology; `Gen3Elevation`
turns a map definition into the field: it reads the layout, lets Petya's pins override the cartridge's
elevation nibble, applies the special floors (stairs, decks, daises, terraces), and classifies every cell.

P2 brings both modules into the clean mod. The scene keeps drawing its flat P1.2 ground: **P2 changes no
pixel.** The field is exposed through the probe (§8) and consumed by P3.

## 2. Interface

### 2.1 `lib/TerrainLevels.lua`

| Call | Meaning |
|---|---|
| `M.build(w, h, read, compatible, rise, tick)` | build the field for a `w x h` map; returns the field table (below). `read(x,y)` returns one cell table; `compatible(a,b,d)` says whether floor cells `a` and `b` may join one group across direction `d` (optional); `rise` is the height of one step cell (pass 6); `tick` is called once per read cell (optional, cooperative build budget). |
| `M.align(regions)` | set `region.floorOffset` for a list of `{x,y,w,h,floorField}` regions so connected maps' floors meet at their seam (§5.5). |
| `M.at(f, x, z)` | the height (px) of the ground under a world point, including stair treads and sloped cells (§5.6). |
| `M.key(x, y)` | the cell key, `"<x>:<y>"`. |
| `M.directions` | the four neighbour offsets, in the order E, W, S, N (§5.2). |
| `M.mapId`, `M.stretch` | set by Gen3Elevation before `build`: the map id (some passes only run on `EM_` maps) and whether flights may be stretched. |

### 2.2 `lib/Gen3Elevation.lua`

| Call | Meaning |
|---|---|
| `M.field(def)` | the field for a map definition (cached, §6.3); nil when the def has no layout. |
| `M.cell(def, x, y)` | one field cell. |
| `M.at(def, x, z)` | `TerrainLevels.at(M.field(def), x, z)`. |
| `M.bind(cells, regions)` | bind scene cells to the field: `c.floor`, `c.base`, `c.floorHigh`, then the prop/assembly settles (§6.7). P3 uses it; P2 must provide it. |
| `M.supportFill(cells, regions)` | the border-fill settle, called by `bind` (our lifted code). |
| `M.lift(vertices, start, height, back)` | lift a vertex list by a height (§6.8). |
| `M.daisPrepare(cells, def)`, `M.daisSettle(cells, def)` | the dais stages (our lifted code). |
| `M.invalidate()` | drop the field cache. |

### 2.3 The probe

`probe.field(mapId)` returns `rows[y][x]` (0-based) with one table per cell:

```
{ mid, collision, cls, height, kind, pin }
```

- `mid`, `collision`: the layout's metatile id and collision for the cell;
- `cls`: the PLATEAU RULE class (`PLATEAU`, `FACE`, `MASS`, `WATER`, `DECK`, `OTHER`) or nil off a pinned map;
- `height`: `cell.height` in px (nil is allowed and means "no height");
- `kind`: `cell.floor and (cell.kind or 'floor') or 'blocked'` (the same string the old gate dumps use);
- `pin`: Petya's mark for this cell (`pins[x..':'..y]`, courses x 16) or nil.

## 3. Data shapes

**cell** (one per map cell; `read` fills the first block, the passes fill the rest):

| key | meaning |
|---|---|
| `x, y` | cell coordinates (set by `build`) |
| `floor` | walkable floor |
| `step` | a stair/step cell |
| `drop` | `{dx,dy}` of the jump direction for a ledge cell (nil otherwise) |
| `layer` | the layout's raw elevation nibble (0..15) |
| `behavior` | the metatile's interaction behaviour id (nil when none) |
| `kind` | the shape family: `flat`, `grass`, `sand`, `water`, `cliff`, `tree`, `ledge`, `steps`, `rail`, `ladder`, … |
| `seed` | a bias for the height solver (the old solver adds it to group heights) |
| `pin` | the authored height in px (Petya's mark, Gen3StairTerraces / Gen3Decks / dais rows) |
| `anchor` | true when the cell is an authored anchor (its group takes the pin, never a lift) |
| `zone` | the id of the pin flood zone a cell belongs to |
| `treads` | treads per flight cell (default 4) |
| `waterfall` | the cell is a waterfall drop |
| `height, high, low` | the solved height, and the two ends of a flight cell's tread |
| `ledgeLow` | the lower floor's height under a ledge cell |
| `cls` | PLATEAU/FACE/MASS/WATER/DECK/OTHER |
| `srcMax, srcMin, srcPin` | classifier sources (the highest/lowest plateau or water a FACE saw; the pin a MASS copied) |
| `distance, support` | nearest-support fill |
| `connector`, `relief`, `treeLoose` | pass flags |
| `slope` | `{nw,ne,se,sw}` corner offsets of a bent cell (the scene reads it in P3) |

**group**: `{cells = {...}, edges = {{otherGroup, deltaPx}, ...}, height, pinned, anchored}`.

**flight**: `{x, top, bottom, high = group, low = group, rise = px}`; rows `top .. bottom-1` are the step cells.

**field**: `{width, height, cells = {key = cell}, groups = {...}, flights = {...}, conflicts = {...}, classes = {PLATEAU=n,...}, signature}`.

## 4. Engine facts (0.3.95; read `.ref/`)

- Map layout: `def.midLayout`; `l.width`, `l.height`, `l.pair`, `l.cells`, `l.overrides`,
  `l:cellAt(x,y)` -> `{mid, coll, elev}`, `l:midAt/collAt/elevAt`.
- Metatile behaviours: `require("src.core.game3.scripting.interaction_scripts").behaviors[l.pair]` maps
  `mid -> behavior id`.
- Tileset pairs: `require("src.import.gba.versions").TILESET_PAIRS` is the table `Gen3Tilesets.resolve` reads
  (public data; do not read ROM or cache files).
- A map def by id: `require("src.core.game3.dataset").map(mapId)`, then `Map.ensureMidLayout(game, mapId, def)`
  (this is what `probe.field` uses; `Map.currentDef()` when the id is the current map).
- Build budget: `V.require("BuildBudget").tick` is passed to `TerrainLevels.build` (§7.2).
- Sandbox: no io/os/ffi/debug; only `V.require`, `V.mod`, `V.data`; the probe is the only debug surface.

## 5. TerrainLevels (lifted file: `docs/own/TerrainLevels.lua`)

Copy the lifted file to `lib/TerrainLevels.lua` and fill every `--@HOLE` line in place. The lifted code
between holes is ours and must not be moved, reordered, re-indented or "cleaned up": the passes depend on the
order and on the locals the holes define.

### 5.1 `file-header` hole
One comment line naming the module, then `local M={}`. Our constants follow immediately.

### 5.2 `directions`, `build-skeleton`, `build-return` holes

`directions={{1,0},{-1,0},{0,1},{0,-1}}` (E, W, S, N: the direction index is passed to `compatible(a,b,d)` and
to `opposite` in Gen3Elevation, so the order is part of the interface). Assign `M.directions=directions`, then
`local function key(x,y) return x..":"..y end`, `M.key=key`, then `function M.build(w,h,read,compatible,rise,tick)`.

`build` creates `f={width=w,height=h,cells={},groups={},flights={},conflicts={}}` and `local cells=f.cells`, then
runs these passes, in this order:

1. **read** — row-major `y=0..h-1`, `x=0..w-1`: `c=read(x,y)`, set `c.x,c.y`, `cells[key(x,y)]=c`, `tick()`
   after each cell.
2. **groups** — row-major: for each floor cell without a group, make `g={cells={},edges={}}`, append to
   `f.groups`, BFS from the cell (queue + head index), assigning `c.group=g` to every cell reached; a
   neighbour `b` joins when `b` exists, `b.floor`, has no group, and `compatible` is absent or
   `compatible(a,b,d)` is true. Append visited cells to `g.cells` in visit order.
3. **flights** — for every cell `c` with `c.step` whose north neighbour is not a step, walk south from `y` while
   the cells are steps: `bottom` is the first row below the run; `south=cells[key(x,bottom)]`,
   `north=cells[key(x,y-1)]`. Append `{x=x, top=y, bottom=bottom, high=north and north.group,
   low=south and south.group, rise=(bottom-y)*(rise or 6)}` to `f.flights`; when both groups exist and differ,
   add an edge `{low, -s.rise}` to the high group and `{high, +s.rise}` to the low group.
4. **jump strips** — a helper `network(root)` returns the set (table) of groups reachable from `root` through
   edges, BFS, including `root`. For every cell with `c.drop={dx,dy}`: `a=cells[key(x-dx,y-dy)]` (the cell the
   jump starts from) and `b=cells[key(x+dx,y+dy)]` (the landing cell); when both have groups, the groups
   differ, both already have at least one edge, and `not network(high)[low]`, add edges `±(rise or 6)` the
   same way as in pass 3.
5. **height solve** — for each group root in `f.groups` order with `root.height==nil`: set `root.height=0`,
   BFS the edge graph; for edge `{b, delta}`, `target=a.height+delta`; when `b.height==nil` set it, lower
   `minimum` to it and queue it; when it already has a different height, append
   `{a=a,b=b,delta=delta}` to `f.conflicts` (do not change it). After the BFS, `offset` is the largest
   `(c.seed or 0) - (g.height - minimum)` over the reached groups' cells; then every reached group becomes
   `g.height = g.height - minimum + offset`, and every cell in it takes `c.height=g.height`.

Our authored-height pass (the first lifted block after this hole) then overwrites pinned groups; the rest of
the lifted body follows. `build-return` closes with `return f` and `end`.

### 5.3 `flight-bounds`, `flight-close` holes

For each flight `s`: `low = s.low and s.low.height or 0`, `high = s.high and s.high.height or low + s.rise`;
when `s.low` is nil, `low = max(0, high - s.rise)`; when `high < low`, `high = low`. Our lifted block then
stretches steep flights and interpolates each row's `high`, `low` and `height`. `flight-close` closes the
step-row loop and the flights loop.

### 5.4 `support-seed`, `support-loop` holes

After all our height passes: `local queue={}`, then row-major over every cell: (our lifted line makes a
blocked cell with a `pin` stand at that pin); every cell with `c.height~=nil` gets `c.distance=0`,
`c.support=c` and is queued. Then BFS with a head index over `directions`; a neighbour without a distance
takes `b.height=a.height`, `b.distance=a.distance+1`, `b.support=a.support` and is queued. This is a full-map,
order-stable fill: do not iterate `pairs()`.

### 5.5 `align-core`, `align-loop` holes

`M.align(regions)`: clear every `region.floorOffset`; the first region gets 0. A local `difference(a,b)`
samples the walkable seam between two adjacent regions and returns the most frequent height difference:

- `sample(ax,ay,bx,by)`: `u=a.floorField.cells[key(ax,ay)]`, `v=b.floorField.cells[key(bx,by)]`; only when
  both exist, are floors, and their `kind=='water'` agrees, count `d=(u.height or 0)-(v.height or 0)`.
- Adjacency: when `a.x+a.w==b.x` or `b.x+b.w==a.x` (east-west), for `y` over the overlapping rows sample the
  touching column of each (`a.w-1` or 0; `b.w-1` or 0). When `a.y+a.h==b.y` or `b.y+b.h==a.y` (north-south),
  for `x` over the overlapping columns sample the touching row of each (`a.h-1` or 0; `b.h-1` or 0).
- The result is the most frequent `d`; ties go to the smaller `|d|` (our lifted line adds: equal `|d|` -> the
  lower `d`), because ties used to depend on `pairs()` order.

`align-loop`: return that best `d`, close `difference`, then repeat at most `#regions` times: for every region
`a` with an offset and every region `b` without one, `d=difference(a,b)`; when `d` is not nil set
`b.floorOffset = a.floorOffset + d` and mark changed; stop early when a round changes nothing. Any region
still nil gets 0. The same hole ends with the `function M.at(f,x,z)` head: `c=f.cells[key(floor(x/16),floor(z/16))]`,
`if not c then return 0 end`.

### 5.6 `at-flight`, `at-return` holes

`at-flight`: when the cell has `c.high` (but is not a step cell), return
`c.high - (c.high-c.low) * min(3, max(0, floor(z%16/4))) / 4` (a flight cell the tread block did not take).
`at-return`: `return c.height or 0`, close `M.at`, then `return M`.

### 5.7 Our passes (lifted; no holes)

Between the holes the file carries, in order: authored heights (group median pins; unpinned groups stand down),
jump-ledge drops, the hidden-ledge relief, crown pockets, floor pockets, the stretched-ramp flight
interpolation, the nearest-support exceptions (pinned blocked cells), corridor rows, ledge corner/end cells, and
the flat water bodies. Each pass is preceded by its own comment. Do not reorder them; they read and write the
same cell fields.

## 6. Gen3Elevation (lifted file: `docs/own/Gen3Elevation.lua`)

Copy to `lib/Gen3Elevation.lua`, fill the holes in place, keep the lifted code untouched.

### 6.1 `file-header`
One-line comment naming the module, then the block comment already in the file (the elevation-nibble rules).

### 6.2 `requires`
`local V=...`, `local Levels=V.require("TerrainLevels")`, `local Pairs=V.require("Gen3Tilesets")`,
`local cache=setmetatable({},{__mode="k"})`, `local M={}`.

### 6.3 `field-prologue`

- Two constants used by the compatible test: `blocked` (per direction, the set of behaviours that forbid
  leaving a cell in that direction) and `opposite={2,1,4,3}` (the reverse of the direction order in §5.2).
  The blocking behaviours are the game's directional jump behaviours: E `{0x30,0x34,0x36}`, W `{0x31,0x35,0x37}`,
  S `{0x33,0x36,0x37}`, N `{0x32,0x34,0x35}`.
- `function M.field(def)`: `l=def and def.midLayout; if not l then return end`.
- Cache signature: the sorted `l.overrides` keys plus `tostring(l.cells)` and each override's `mid,coll,elev`
  ("k,mid,coll,elev" joined by `;`). The cache is weak-keyed by the layout; return the cached field when its
  `signature` matches.
- Then the per-call locals the read callback uses: `behaviors` (§4), `spec=Pairs.resolve(l.pair, TILESET_PAIRS)`,
  `shapes=V.require("Gen3TileShape")`, the `drop` table (`0x38`->E, `0x39`->W, `0x3A`->N, `0x3B`->S),
  `outdoor=Pairs.outdoor(def)`, `cave=def.mapType==4`, `deck` (the three FRLG deck ids; keep it, it is read
  by the read callback).

### 6.4 `build-open`, `read-shape` holes

Open `local f=Levels.build(l.width, l.height,` with a read callback `function(x,y)` whose first two statements
are `local raw=l:cellAt(x,y)` and `local beh=behaviors[raw.mid]`; the lifted block follows. `read-shape` is
`local shape=shapes.of(spec.primary, spec.secondary, raw.mid, beh, raw.coll)` (one statement).

### 6.5 `compat-open`, `compat-close` holes

`compat-open` closes the read callback and opens the compatible callback: `end, function(a,b,d)`.
The lifted block computes `local layer=...`; `compat-close` is the return statement and the call tail:

- compatible when: `layer` is true (same layer and same pin zone — the lifted line), and both cells agree on
  water-ness, and `a`'s behaviour does not block direction `d`, and `b`'s behaviour does not block the
  opposite direction (both through `blocked`);
- then `end, 6, V.require("BuildBudget").tick)` (rise 6 px per step cell).

### 6.6 `field-epilogue`
`f.signature=signature; cache[l]=f; return f; end`, then `M.cell(def,x,y)` (`f=M.field(def); return f and
f.cells[Levels.key(x,y)]`) and `M.at(def,x,z)` (`return Levels.at(M.field(def),x,z)`).

### 6.7 `bind-*` holes

`bind-open`: `function M.bind(cells, regions)`.

`bind-floor`: run `Levels.align(regions)`; then, for every scene cell `c` (`pairs(cells)`), find the region
`r` whose `x,y,w,h` box holds `c.cx,c.cy`; inside it `floor = r.floorField and r.floorField.cells[Levels.key(cx-r.x, cy-r.y)]`,
then `c.floor=floor`, `c.base=(floor and floor.height or 0) + r.floorOffset`,
`c.floorHigh = floor and floor.high and floor.high + r.floorOffset`, and stop at the first containing region.

`bind-donor`: when no region contained the cell (`c.base==nil`), pick the region with the smallest squared
distance from the cell to the region's clamped box, and set `c.base = (that region's clamped cell height or 0)
+ r.floorOffset`. Our lifted block (border families) sits between the loop head and this assignment and must
stay where it is.

`bind-props-open`/`bind-props-close`: after `M.supportFill(cells,regions)` (lifted) and the `bound` snapshot
(lifted), for every cell that belongs to an assembly (`c.column.group`, `c.civic` or `c.prop`): compute the
group's ground cell (front centre when `g.front`; else `g.cx/g.cy` plus half the group's footprint), and when
`g.groundHeight` is still nil set it to the bound base of that cell; then the lifted "stoop" lines add
`M.STOOP` for a drawn stair under the door; then `c.base=g.groundHeight`.

`bind-close`: the single `end` that closes `M.bind`, after the lifted open-ground / tree-pair / boulder /
crownFloor blocks (the props loop was already closed by `bind-props-close`).

### 6.8 `lift-*` holes

`lift-guard`: `function M.lift(vertices,start,height,back)` and `if height==0 then return end`.
`lift-loop`: the loop over the vertex list from `(start or 0)+1` to `#vertices` (one `local v=vertices[i]`).
The lifted body adds `height` to `v[2]`, adds `height` to the card anchor `v[9]` when it is non-zero, and adds
`height` to `v[3]` when `back` is true. `lift-return`: close the loop and the function, then
`M.invalidate` (reset the weak cache) and `return M`.

### 6.9 The lifted body

The lifted body carries, in order, the whole field logic: the tile-shape read; the elevation remap and the
nibble height; the stair/platform generation (Gen3StairTerraces); the pin flood from Gen3PinData (including
zones and tree settle); the pin flood's unreached-floor orphan pass; the bridge span; the e0 flights; the ramps;
Mossdeep's sink; waterfalls; the stair profile (run twice); the classifier (PLATEAU/FACE/MASS/WATER/DECK/
OTHER); the other-cell and pocket fixups; the support fill; the bind passes; and the scene helpers. Each pass is
preceded by its comment. **Keep the order; do not rewrite a pass.** The constants at the top of the file
(`M.PINS_ON`, `M.PIN_PX=16`, `M.BLOCKS_ON`, `M.BAND_LEVEL='lower'`, `M.LEDGES`, `M.STAIR_PROFILE`, …) are part
of the behaviour and are read by other modules; do not change their values.

## 7. The small modules P2 needs

### 7.1 `lib/Gen3TileShape.lua` (new, small)

`M.of(primary, secondary, mid, behavior, collision)` returns a shape table (`{kind=..., ground=..., ...}`)
for one metatile:

- non-Emerald (FRLG) carts are out of scope for M1: return `{kind="flat"}`;
- `primary ~= "general"` (interiors, buildings): `{kind="flat"}` for now (P4 owns interiors);
- otherwise delegate to `V.require("Gen3EmeraldShapes").of(primary, secondary, mid, behavior, collision)` and
  return `{kind="flat"}` when it answers nil.

The field reads only `kind` (water/cliff/tree/flat/…), `seaRock`, `river` and `canopy` from the result; all of
them come from our own `Gen3EmeraldShapes` on Emerald.

### 7.2 `lib/BuildBudget.lua` (new, small)

The cooperative build budget the field's read loop ticks: `begin(co, seconds, pollEvery)` stores the build
coroutine and a deadline; `finish()` clears them; `expired()` reads the clock past the deadline; `tick()`
counts calls and, every 32nd call (every 4th when `pollEvery==4`), yields `"budget"` when the current
coroutine is the build coroutine and the deadline has passed; `check()` does the same clock test on every call.
`tick()` must be safe outside the build coroutine (do nothing). Engine clock: `love.timer.getTime`, with
`os.clock` fallback.

### 7.3 `lib/Gen3Tilesets.lua` (new, small)

Emerald only; FRLG's ROM-pair aliases are not needed.

- `M.canonical(pair)` -> `pair` (`bind` may stay a no-op: Emerald's pair names are already canonical).
- `M.resolve(pair, known)` -> `known[pair]` when present, else split `"primary__secondary"` into
  `{primary=..., secondary=...}`, else `{}`.
- `M.outdoor(def)` -> `def.mapType` in `{1,2,3,6}`, else `def.environment` is `TOWN` or `ROUTE`.
- `M.cave(spec)` -> `spec.primary=="general"` and `spec.secondary` in
  `{cave, meteor_falls, rusturf_tunnel, mirage_tower, navel_rock, underwater}`.
- `M.supports(def, spec)` -> true for the general, building and secret_base primaries (P3 refines it).

### 7.4 Data modules to copy verbatim from `docs/own/modules/`

`Gen3PinData.lua` (Petya's pins, generated), `Gen3EmeraldShapes.lua`, `Gen3EmeraldAuto.lua`,
`Gen3TreeStamps.lua`, `Gen3StairTerraces.lua`, `Gen3EmeraldTerraces.lua`. They are our own code; copy them
into `lib/` unchanged (strip the two provenance header lines at the top).

`lib/Gen3Decks.lua`: P2 needs only `M.MAPS` (the field reads `Gen3Decks.MAPS[def.id]`). Deck maps are not in
the 64 pinned maps, so for P2 ship the table empty (`local M={MAPS={}}; return M`); the real deck recipes
cross in P3/P4.

## 8. Wiring

- `Probe.field(mapId)`: resolve the def (`Map.currentDef()` when `mapId` is nil or equal, else
  `Dataset.map(mapId)` + `Map.ensureMidLayout(game, mapId, def)`), call `Gen3Elevation.field(def)`, and build
  the rows of §2.3. It must work for many maps in one run (gate drivers walk the 64 maps) and return nil when
  the def or layout is missing.
- `Scene`/`CellSource` are **not** changed in P2: the drawn ground stays flat (P1.2). If a scene cell needs a
  field height to build, that is P3.
- `main.lua` loads `Gen3Elevation` once at boot (it is required by the probe), and the probe table already
  exists; no new exports.

## 9. Gate (verifier, Emerald repo)

The verifier runs the neutral probe drivers against this mod in a QA identity and compares with
`~/Documents/Emerald/.rewrite/baseline/s4a/gates/`:

| Check | Target |
|---|---|
| boot | no `[error] EMERALD_3D`, no sandbox warning, probe answers |
| G-01 pins | per map `COUNT ... diff=0` for every one of the 64 pinned maps |
| G-01 grid | per map `GRID` rows identical to `pins_aa/ab/ac.txt` (heights in 8 px units, `.` = no cell) |
| G-02 classes | per map `CLS ... unclassified=0` and every class count equal to `cls_aa/ab/ac.txt` |
| syntax | `luajit -e "assert(loadfile(f))"` on every new/changed file |
| cost | `field()` on the largest map (Ever Grande 40x80) completes without the build budget erroring |

The implementer cannot run the game; its self-check is the Lua syntax check plus a small headless test
(`tests/heightfield_test.lua`, pure Lua) that builds a 12x12 synthetic map through `TerrainLevels.build` with a
stub `read`/`compatible` and asserts: the group count, a flight's `top/bottom/rise`, the height solve of two
groups joined by a stair, and `at()` on a step cell. Run it with `luajit tests/heightfield_test.lua`.

## 10. Out of scope

Drawing (P3), interiors (P4), actors, caves beyond what the field needs, Gen 1/2 code paths, FRLG shape tables,
3D battles (M4). No new visual feature, no tuning of a constant: parity only.

## 11. Provenance and simcheck

The lifted files are our own code (the old repo's uncommitted diff over upstream base 03882a9). Every lifted
module gets a row in `docs/PROVENANCE.md` (kind `lifted-own`, our lines, upstream lines replaced by holes).
The verifier runs `tools/rewrite/simcheck.py` on the finished files; exact lines must be on the trivial list or
explained, and the token share must stay well under 15 %.
