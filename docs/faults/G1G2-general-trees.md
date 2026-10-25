# G1 + G2 — Route 112's general trees (measured 2026-10-21, installed 2026-10-21/22)

Ghost cards G1 ("flat green crowns hang in the sky with no trunk") and G2 ("the bushes drawn on the red rock
stand as full-height columns of the same green tile") are one class on one tileset: the **Lavaridge / General
mountain** trees (`pair=general__lavaridge`: Route 112, Lavaridge, Mt Chimney, Jagged Pass). The cartridge
draws each tree as **two cells**: the crown in the OVER layer of a walkable cell (`0x210`/`0x211`, the player
walks behind it) and the trunk/shadow in the blocked cell one row SOUTH (`0x218`, `0x203`, `0x3B8`, `0x21A`;
same bush art plus the grey stump). Measured on the install's own dump (`.autoloop/runs/ghost/geo/`):

| what | before | cause |
|---|---:|---|
| canopy slabs on Route 112 (walk-under `Gen3Canopy`) | 4,912 triangles, 79 cells | every walkable crown cell got a 26 px slab pushed 32 px south with no body under it (F035) |
| foliage cells claimed by the rock relief mass | 219 cells, `mass=t` | they were never rock: their green printed on terrace walls/lids (F040's cause, card G2) |
| G2 wall runs (3+ cliff cells of one foliage tile) | 72 runs | same cells used as wall art |

## The fix (4 files, installed 2026-10-21)
1. `Gen3TreeStamps.lua` — new `M.GENERAL.lavaridge` family: every blocked cell of those tiles becomes one
   upright tree (`kind='tree', root=true, general=true`, art = the crown tile's rows above its own), and
   `M.claim` gives a walkable crown cell whose south neighbour is such a tree `c.treeOwned` (no flat crown art,
   no canopy slab) and takes the crown art from the crown tile above the base. The tree cell leaves the rock
   mass by itself (mass membership is `shape.kind=='cliff'`). When the cell north of the tree is the walkable
   crown tile, claim also marks the shape `crownFloor`.
2. `Gen3Rock.lua` — `M.tileArt=tile` exported (the foliage classifier) for the other builders.
3. `Gen3Relief.lua` — a relief wall takes **no art from a foliage-drawn neighbour** (G2's green stripes); the
   rock cell's own art instead.
4. `Gen3Elevation.lua` — end of `M.bind`: a tree whose shape has `crownFloor` takes the floor of the walkable
   crown cell above it (`c.base=n.base`). Without it, Route 112 (32,23) — a blocked bush cell ringed by the
   cable-car station's platform at 48 — had no mass to take its height from and sank to 0: the cell became a
   1x1 hole 48 px deep, walled on all four sides, with the tree in the bottom. It is the only cell of the
   family whose walkable crown cell stands at another height.

## Measured result (final probe build, `.autoloop/runs/f035/g14c`, `g14d`)
- Route 112 cells: 4,256; **220 differ from the install**: 181 `cliff -> tree`, 38 `flat -> tree`, 1
  `cliff -> flat` (3,34, `CROWN.edges`: a blocked crown tile next to a 3D tree becomes grass).
- 4 cells change height: (27,22) 48->0, (28,22) 48->0, (29,22) 48->0 and (32,23) 48->48 via `crownFloor`
  (0 before that rule). The first three are open cells at the foot of the 48 terrace — their walls are only
  the terrace face to the south (checked in the geo dump: no closed ring). (32,23) had walls on all four
  sides before the rule; after it there is only a subsurface face at its own east edge and a ground plane
  at 48.
- 7 cells outside the map (west x<0, east x=35) carry tree tiles in the boundary fill and become trees too,
  at their fill height (unchanged).
- Controls, cell dumps of 5 maps, control (game lib) vs probe: **Mt Chimney 2,592 / Jagged Pass 1,976 /
  Route 111 7,008 / Route 113 2,808 cells identical**; Lavaridge town 28 cells `cliff/flat -> tree` (the same
  family) with **no height change**.
- Float gate (`em_float_driver`, family maps): the same 2 pre-existing floats on Route 112 (bottom 38.4,
  ground 28.8, lowest (22,42) and (19,42)) in both builds; masses audited 26 -> 30 (the tree cells cut one
  mass into several).
- Determinism: two probe builds identical except Route 112 (44,6)/(45,6) — an out-of-map ledge whose base
  flaps 0/-32 **in the control too** (two control runs: 0 then -32) — and one Route 113 ledge (15,1) 56/64 in
  one of three probe runs; the control is deterministic there (2/2 = 56) and the repeat probe run gave 56, so
  it is a build-order artifact in a ledge height, not a shape change.
- Install equivalence: frames from the installed game lib vs the probe at (26,25), (32,22), (30,28) L4/L6/L7
  differ only on the tree sprites (sway phase; L6/L7 at 32,22 = 0.001%/0.117%), 0 fallbacks.
- Sheet: `.autoloop/runs/f035/SHEET_G1G2_fixed.png` (2D | installed | fixed at 26,25 and 30,22, plus a
  close-up east of the station).

## Gotchas found
- A QA identity left with another `zoom` in `options.lua` makes the two halves of an A/B incomparable (the
  driver prints `zoom` = fit + offset). `tools/f035/ab_f035.sh` and `gate14.sh` seed all four identities first.
- `qa_tryp.sh` needs **full disk access** in this harness (it rsyncs into `/tmp/emerald-qa.pcopy.*` and writes
  the identity folders under Application Support); under the default sandbox the runs silently keep the old
  `.lua`.
- The geo driver needs an **absolute** `EM_MAPS` path.
- `emdata.Layout('EM_ROUTE112').pair == 'general__lavaridge'`; `crop2d.py 0_27 general__lavaridge …`.
- `Map.load` with a non-numeric x silently falls back to the map's default spot: check the first `[EM view]`
  line, not just "shots 3".

## Scripts (repo)
- `tools/f035/gate14.sh <label>` — captures + full-map Route 112 geo dump (control/probe) + control cell dumps
  + float gate on the family maps.
- `tools/f035/gate14b.sh`, `cells14.sh` — re-gates with the 4th file / repeat cell dumps.
- `tools/f035/install14.sh` — backup, source/game/QA, `make_patch.sh` with `OWN_LIB_EXTRA` (4 files).
- `tools/f035/smoke14.sh` — frames from the installed game lib.

## Still open (not this task)
- The pink sand columns on the same terraces (a wall showing a *floor* tile's art, pre-existing, not F040):
  same family, separate task.
- The cable-car station's own floor / camera (ghost card G4): (27,23) sits at 0 while the rest of the station
  footprint is at 48 — a pre-existing height split the trees now sit next to.
