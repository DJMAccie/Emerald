# F035 — floating ash-bush crowns on Route 112 (measured, 2026-10-21)

Source: ghost v0's triage (`.autoloop/runs/ghost/TRIAGE.md`, candidate A: "floating green canopy plates in the sky", 5 spots)
against the **real install** (`~/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK`), whose geometry dump
is `.autoloop/runs/ghost/geo/EM_ROUTE112.geo.gz`. Resolved with that install's own `lib/` (the rc snapshot has different line
numbers, which is why the first attempt resolved almost no tags).

## Measured
| spot (ghost case) | crown cell | canopy bottom y | ground drawn y | lift |
|---|---|---:|---:|---:|
| 27,32 L6 | (28,34) | 74.0 | 48.0 | **+26 px** |
| 27,32 L6 | (29,33) | 74.0 | 48.0 | **+26 px** |
| 27,32 L6 | (29,34) | 74.0 | 48.0 | **+26 px** |
| 27,32 L6 | (25,30) | 26.0 | 58.0 | -32 px (crown on a lower terrace: correct) |
| 19,35 L6 | (17,33) | 26.0 | 47.7 | -21.7 px (same: a crown at a lower level, correct) |
| 20,51, 19,39, 23,35 | — | — | — | no canopy triangles within 2 cells of the spot: the plates seen there are the crown row of other cells, so those frames need the cells read off the picture, not the spot |

The class is now exact: **a crown drawn 26 px above the ground with no trunk and no body under it.** 26 px is the canopy
height from `Gen3Canopy` (the crown is lifted to `y = 26 + base` and pushed 32 px / 2 cells south so it lands on the drawn
row from the player camera). Where the crown's own cell is walkable and has nothing under it, it reads as a plate in the sky.

## What has already been tried (so a new attempt does not repeat it)
- `fix/F032b` (c0a4b23): the crown built as a solid standing bush. The plates went away, but the bush's top and side faces
  stretched a 0.5-px art strip over 4 px = 8x — rejected on the "never stretch" rule.
- `fix/F032c` (6fb06e5): an elliptical lathe with integer art rectangles. The in-box `0x21A`-footed crowns read as bright leafy
  bushes, but (a) a crown whose foot cell is on a *relief* slope is built at the cell's flat base and sinks ~11 px (the exposed
  relief face reads as stripes), (b) at the low camera one bush fills 40% of the frame, and (c) only crowns whose south
  neighbour is `0x218`/`0x21A` were converted — 11 of 40 on Route 112 still keep the lifted slab.

## The next attempt's rule (from both failures)
1. Measure the crown's **drawn** support first: the cell under the crown, the terrain surface there, and whether the crown's
   foot cell matches `0x218`/`0x21A`. Crops from `tools/buildings/art_sheet.py`-style pixel sheets, not thumbnails.
2. Build at the **drawn** height (the relief surface, not the cell's flat base).
3. Every quad an integer art rectangle; a taller face repeats the drawing's rows, never stretches one.
4. Cover the remaining crowns by the same measured rule, not by a tile whitelist (the `0x203`/`0x3B8`-footed ones).
5. Prove it twice: the same frames captured twice must agree (the loop's determinism rule), and the plate's sky pixels must
   drop to the base level at every ghost spot.
