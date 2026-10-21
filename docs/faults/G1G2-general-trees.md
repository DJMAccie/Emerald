# G1 + G2 — Route 112's general trees (measured, 2026-10-21)

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

## The fix (probe tree `tools/f035/probe/lib`, 3 files)
1. `Gen3TreeStamps.lua` — new `M.GENERAL.lavaridge` family: every blocked cell of those tiles becomes one
   upright tree (`kind='tree', root=true, general=true`, art = the crown tile's rows above its own), and
   `M.claim` gives a walkable crown cell whose south neighbour is such a tree `c.treeOwned` (no flat crown art,
   no canopy slab) and takes the crown art from the crown tile above the base. The tree cell leaves the rock
   mass by itself (mass membership is `shape.kind=='cliff'`).
2. `Gen3Rock.lua` — `M.tileArt=tile` exported (the foliage classifier) for the other builders.
3. `Gen3Relief.lua` — a relief wall takes **no art from a foliage-drawn neighbour** (G2's green stripes); the
   rock cell's own art instead.

## Measured result (probe build)
- `canopy` upload triangles on Route 112: **4,912 -> 0** (`tools/f035/geo_f035.sh`, dump `.autoloop/runs/f035/geo1`).
- cells dump: 4,256 cells, **219 changed** = exactly the cutover (`218` 71, `203` 48, `211` 47, `3B8` 25,
  `210` 15, `21A` 13), all `cliff,mass=t -> tree`, plus:
  - boundary fill (x<0) roof/wall base 32 -> 0 (9 cells) and two ledges outside the map (44,6)/(45,6) 0 -> -32;
  - `(28,22)(29,22)` tile `21A`: flat base 48 -> tree base **0** — **must be checked before install** (a tree
    48 px below its terrace would be buried; the old flat cells there were themselves odd, y23+ is 0/48 mixed).
- frames: `.autoloop/runs/f035/SHEET_G1G2_before_after.png` (2D | install | probe at 27,32 L6 and 11,26 L7);
  old/new pairs in `t3/`, `t4/`, `t5/` (Route 112 19,35 · 21,20 · 26,44 · Lavaridge town 10,10).
- NOT run yet: determinism (same frames twice), float gate, Mt Chimney / Jagged Pass control, full-map sweep.

## Gotchas found
- A QA identity left with another `zoom` in `options.lua` makes the two halves of an A/B incomparable (the
  driver prints `zoom` = fit + offset). `tools/f035/ab_f035.sh` now seeds all four identities before a batch.
- `qa_tryp.sh` needs **full disk access** (it rsyncs into `/tmp/emerald-qa.pcopy.*` and writes the identity
  folders under Application Support); under the default sandbox the runs silently keep the old .lua.
- The geo driver needs an **absolute** `EM_MAPS` path.
- `emdata.Layout('EM_ROUTE112').pair == 'general__lavaridge'`; `crop2d.py 0_27 general__lavaridge …`.

## Next (in order)
1. Check `(28,22)(29,22)` (frame at 28,25 L4/L7 old vs new) and the boundary/ledge cells; if the base drop is
   real, pin those two cells out of the family (`M.GENERAL.lavaridge.skip = {(28,22),(29,22)}`).
2. Determinism (two identical probe builds) + float gate (`ab/float_gate.sh` shape) + Mt Chimney/Jagged
   Pass/Lavaridge controls and 2-3 Route 111/113 controls (other tilesets, must be unchanged).
3. Sheet to the user (already built, may need one more spot), then install per the standing rule (backup,
   source+game+QA, patch with `OWN_LIB_EXTRA="lib/Gen3TreeStamps.lua lib/Gen3Rock.lua lib/Gen3Relief.lua"`,
   commit, push), then update PLAN.md.
4. Then decide about the remaining "pink sand columns" on the same terraces (a wall showing a *floor* tile's
   art, pre-existing, not F040: same family, separate task).
