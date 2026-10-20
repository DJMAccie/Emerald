# Release candidate 2026-10-24 (live document, updated by each autoloop round)

Everything here is in the **release-candidate tree** `~/Documents/Emerald/.autoloop/rc` (git, branch `main`), never in
your game or in `~/Documents/battle-art-notquiteog`. `upstream` in that repo is a copy of your installed game at the
moment the loop synced; the diff `upstream..main` is exactly what this candidate changes.

## Install / rollback (when you say so)
```
cd ~/Documents/Emerald
tools/autoloop/install_rc.sh            # dry run: lists the commits and files, checks nothing moved under us
tools/autoloop/install_rc.sh --yes      # backs up game, QA and mod source, then copies the loop's files into all three
tools/autoloop/install_rc.sh --rollback <backup dir printed at the end>
```
It refuses while the game is running, when the game has been updated since the loop last synced (run
`tools/autoloop/rc.sh sync`), or when a target file was changed by someone else. After installing, the patch is
regenerated with `OWN_LIB_EXTRA="<files>" bash tools/props/make_patch.sh` and committed.

## Fixes in the candidate

| Ledger | Map | What you saw | What changed | Evidence | Revert |
|---|---|---|---|---|---|
| F006 | Route 112 20,41-44 | Grey plates jutting beside the stair's treads, with sky showing through under them | `TerrainLevels.lua`, `Gen3Scene.lua`: a stair flight's cells no longer hand their tread heights to the rock/cliff beside them (that rock takes the nearest real floor); the flight closes its sides to lower rock; the cliff ground plane is cut back half a pixel toward such a flight | Gate: air at the box 2716 px² → 28 px² (3 sub-visible slivers), 0 fallbacks. Verifier: the two enclosed-sky holes (120 px² at (378,406), 270 px² at (415,465) in the orbit frame) gone, no regression in 10 review frames. `docs/shots/` sheet: `.autoloop/gates/F006/sheet.png`, crops in `verify/` | `git -C .autoloop/rc revert e3011de` |
| F031 | Route 103 46..61 × 0..6 | Rock faces "melted": long smeared bands along the terraces and a row of pale teeth on the crests | `Gen3Rock.lua`: east/west-facing slopes lay their art 1:1 (along z, like the vertical side walls) and the course cuts run straight | Gate PASS: no new detector regions on 8 regression maps, zero cell changes, 0 fallbacks. Verifier KEEP on six full-resolution pairs: teeth gone, art 1:1, no new sky/void pixel, silhouette unchanged; 16.9% of the near orbit frame changed because the smear became crisp art. `.autoloop/gates/F031/sheet.png`, crops in `verify/` | `git -C .autoloop/rc revert 1d04b0e` |
| F030b | Route 112, west of the map edge (−6..−1 × 40..42) | A plate floating in the sky west of the route, and the ground under the neighbouring town's rock drawn at height 0 | `Gen3Hills.lua` (and, in the first attempt, `Gen3Elevation.lua`/`Gen3Scene.lua`): a hill patch that ends at the build window's edge closes down to the hill's own foot instead of standing open; a building-claimed cliff cell takes its ground at the cell's base | Gate PASS: the 3,096 px² region at gap 34 is gone; Route 112 gains 269 quads at the window edge, no cell change, 0 fallbacks. Verifier: pending | `git -C .autoloop/rc revert 2957245 0fd360b` |

## Fixes in the candidate, round two (awaiting their verifier's verdict at the time of writing)
| Ledger | Map | What you saw | What changed | Evidence |
|---|---|---|---|---|
| F032 (+F035) | Route 112 11..26 x 21..26 | Thin green plates hanging in the air beside the red rock walls | `Gen3Canopy.lua`: a canopy whose drawing is a whole bush standing on its own ground (the ash bush, tile 0x210 of `general__lavaridge`) is built as a solid bush on its own cell instead of a crown lifted 26 px and pushed 2 cells south with no trunk | Gate PASS (kind=none: the air detector never covered this fault); the earlier attempt 9ce350a was refuted by a byte-identical dump comparison. Headless canopy geometry at F035's plate cells (9..10 x 40..41, y 74-76) is gone and the crowns now stand at ground height on cells 9..10 x 38 (y 48-63) - F035 is cured by the same change |
| F039 | Route 123, north edge | A 40-60 px band of pure sky between the sea's lip and the lake below | `Gen3Scene.lua` lines 1055/1117: the two "blocked shore-water" passes tested `collision~=0`, which matches every surfable sea tile (collision 41), so the whole sea beyond the edge was dragged down to the lake's level and left pits under the sea rocks; they now test `collision==7` | Fault regions 388/384/384 px2 (gap 37) -> 0, 0 fallbacks, triangles 98704 -> 98764 (no per-cell quads) |

## Closed without a code change
- **F005** (Mossdeep 45,7 floating rock): not reproducible on the installed build; the bluff stands on its floor (fixed
  by 1b0efaa). Evidence: level-4 shot from 47,7.
- **F007** (Route 103 24,14 floating rock): not reproducible; geometry starts at y=0 on ground 0, and both a level-4 and
  an orbit shot show the stone standing on the grass. The "4 px" came from the rock audit the beta notes already
  distrusted.

## Known, not fixed in this candidate (honest list)
- The **inside of terraced mountains** (Ever Grande, Route 111, Sootopolis, Route 115, Route 114, Southern Island,
  Battle Frontier, Mt Pyre summit, Route 119/120): the air detector flags them, but captures at the spots look correct —
  the visible geometry closes the terraces. Kept as detector false positives, not faults.
- **Caves**: the air rule cannot judge them (Gen3 draws no cave ceiling, so "sky" reaches every cave interior). They are
  covered by the fallback/magenta gates and by spot captures only.
- **Ledge and mini-stair faults** F001, F002, F004: other sessions were working on `Gen3Outdoor.lua` and Route 115's
  terraces during this loop; the loop has not touched that code.
- **F003** (Route 104 stepped slope by a ledge): could not be located — the mini-stair detector finds nothing on Route 104
  at any step size. Needs the user's screenshot or cell.
- **Builder determinism** F034/F036/F037: the geometry of ~12 maps varies slightly between identical builds (`pairs()`
  order), and Route 112's rock/shore triangles follow the water animation frame. The gate builds twice and filters this;
  fixing it is a separate job.

## Tier 1 gates on this candidate (158 maps, all gates, 2026-10-21)
| Gate | Result | Numbers | Against the installed game |
|---|---|---|---|
| 2D fallbacks / Lua errors | **pass** | 632 of 632 captures, 0 fallbacks, 0 errors, 0 watchdogs | same |
| Stairs and ledges | **pass** | 113 stairs ok, 0 flat, 0 reversed, 0 cliff jumps; 0 of 401 ledges bad | same |
| Floating rock audit | **pass** | 4,471 masses, 0 floats | same |
| Building defect scan | **pass** | 122 bakes, 0 flagged | same |
| Magenta holes | *fails its target, but not ours* | 15 of 632 level-7 frames have magenta in the lower 45% | **the installed game has 16 of 632** - it is pre-existing, and this candidate removes one |
| Height repeatability | *fails as expected* | 1 of 156,063 cells differs between two runs of the same code (the builder's `pairs()` noise, F037); 100 cells differ from the October baseline | those 100 are the fixes (F006) plus other sessions' installs |
| Load time | *unmeasured* | median 434 ms, but the machine was at load 23.6 and 9 runs timed out | needs a quiet rerun |

## Blast radius of the two fixes (checked, not assumed)
Built both trees headless with the same driver and engine payload and compared all 158 maps: cells changed on 29 maps,
triangle counts on 56, and **every** difference is in the terrain meshes (`under`/`over`) - never in plants, roofs,
canopies, water or civic geometry. The biggest movers are Mt Pyre summit (-9.7% terrain triangles), Ever Grande (-5.8%),
Jagged Pass (-5.9%) and Magma Hideout 2F_3R (+3.1%, F006 closing stair flights). Visual A/B at the three biggest movers
(levels 4 and 7): identical silhouettes and heights, the only visible difference is the rock faces losing their smeared
bands and showing the drawing 1:1. Sheets: `.autoloop/runs/ab_base` vs `ab_cand`.

## How this was checked
Every fix goes through `tools/autoloop/gate.sh`: the headless builder (identical to the game's own build; verified by the
engine track on Route 103, Oldale and Rustboro, triangle for triangle) builds base and fix twice each; the fault's own
detector region must be gone, no *new* region may appear on 8 regression maps, cells may only change inside the fault's
box (changes elsewhere are captured for the reviewer), and the captures at levels 4, 6 and 7 (two yaws) must come out
with 0 fallbacks. An independent verifier agent then tries to refute the fix on full-resolution before/after crops; a fix
is only kept if it cannot be refuted.
