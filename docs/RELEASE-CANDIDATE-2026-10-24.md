# Release candidate 2026-10-24 (live document, updated by each autoloop round)

## In plain words: what this candidate changes in the game
- **Route 112's stair:** the rock plates that jutted beside the stair flight (with sky showing through under them) now stand on
  their own ground, and the stair's sides are closed.
- **Route 103's rock terraces:** the faces no longer smear along their length and the crests no longer grow pale "teeth"; the rock
  shows its drawing 1:1.
- **Rock beside Route 112's ash plain:** walls had green bush art printed on them (long green stripes and green lids). They now
  show rock, and the ash bushes on the plain are untouched.
- **Route 123's north edge:** a 40-60 px band of sky under the raised sea is closed; the sea keeps its own level and the drop
  reads as a water/rock face.
- **Buildings standing in a neighbouring map's fill (Route 112 west, Route 113):** the herb shops, the gym, the Poke Center, the
  battle tent and the Cozmo house no longer sit 32-56 px too low with their facades buried.
- **A few small rock holes** where a plate stood over the mountain's own top (Route 112's terrace rim) are closed.
Everything else in the world is unchanged: the height map, the walkable floors, the doors and warps, and 156,063 cell lines were
compared before and after.


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

## Fixes merged after the first two (all verified)
| F002 | Route 115 | The meadow beside the row-70 jump ledges climbed in 2-3 px steps with a face on every tread ("mini stairs") | `Gen3Scene.lua`: a relief corner averages only the open floor cells that share it, a corner under a ledge's lip by <=3 px is raised onto the lip, two sloped tops at the same base are closed, and the walls a smoothed top runs into get a 1-px foot skirt. Heights untouched | Third attempt. Gate: fault 8 regions / 9,728 px2 -> 0, 0 new regions on 10 maps, 0 cells changed, 0 fallbacks; step regions still cured on seven maps (Route 115 15->1, Route 113 12->0, Route 111 10->0, Route 103/Rustboro 5->0 each, Route 112/Oldale 2->0 each). The two seams that got attempt 2 reverted are cured (Route 113's 26+15 px slits gone, Route 115 29,73 identical to base). Passed the new determinism check: 1.20 % worst between two runs vs base's own 8.38 % |

| Ledger | Map | What you saw | What changed | How it was verified |
|---|---|---|---|---|
| F038 | Route 112 west fill, Route 113 | The herb shops west of Route 112 had their facades buried (only roof bands showed) and the roof of the house beside one stood open; Route 113's battle tent, Poke Center and Cozmo house were bare dirt with signs | `BuildingModels.lua`: the lift offset comes from the ground drawn in front of the door, so a model claimed inside a connected map's fill keeps that map's floor offset | Rendered ortho A/B by an independent reviewer (each object a rigid 32 px / 56 px lift, dx=0, patch error 0.0, wall bottoms on their ground) and, after the geometry dump learned to carry building models, by the new D5 check: the base tree flags the shops as buried (-32 px, -56 px), the candidate flags nothing |
| F039 | Route 123 north edge | A 40-60 px band of sky under the raised sea margin, with boulders silhouetted in it | `Gen3Scene.lua`: the two blocked shore-water passes tested `collision~=0`, which matches every surfable sea tile, so the sea was dragged down to the lake's level; now `collision==7`. Then the sea surface is drawn at the bank's own height, and margin rock cells over lower water get a face down to it in 16 px courses | Attempt 1 fixed the cause but left two sky holes; attempt 2 (reviewer) measured the band 11,551 px2 -> 23 px2 at level 4 both yaws, no regression over levels 4/6/7 plus six extra yaws and shore/lake spots, 0 fallbacks; it also closes a pre-existing 1,147 px2 hole on Route 103 |
| F032 | Route 112 | Thin green plates hanging beside the red rock walls | **Parked after two attempts** (see the parked table) | Both attempts removed the plates but the replacements failed the taste bar |

## The install delta (what actually changes in your game)
Six files, +276 / -39 lines:
```
lib/BuildingModels.lua |  12 +++++-      F038 sunk building models
lib/Gen3Hills.lua      |  71 +++++++-    F040 rock art (hill masses), F039 margin faces
lib/Gen3Relief.lua     |  30 +++++---    F040 rock art (relief masses)
lib/Gen3Rock.lua       |  77 ++++++----   F031 rock art 1:1, F040 rock/foliage art choice
lib/Gen3Scene.lua      | 100 +++++++---   F006 stair flanks, F006b plate closure, F039 margin faces
lib/TerrainLevels.lua  |  25 +++++--     F006 stair flights hand no height to rock
```
`tools/autoloop/install_rc.sh` prints exactly this, refuses if the game changed since the loop last synced, and writes a
backup of game, QA and mod source before copying.

## Parked, with what a future attempt needs
| Ledger | Map | Why parked | What is known |
|---|---|---|---|
| F001 + F004 (ledges, mini-ramps) | Route 115, Route 102 | Attempt 1 (`fix/F001` 6f31bd2) cures both and makes the lip one straight 1:1 face with fewer triangles than base, and its gate passes - but the render is not reproducible: 1 capture in 4 opened new sky (61 px + 162 px on Route 115 level 7, six 1-2 px lines along the ledge feet at level 4, a 212 px hole on Route 102 level 7) because the new closure reads the streaming cell table, so a partial build decides differently. Prescription: decide from data that is always present, default to closed when a neighbour is not built, keep a 1-px foot skirt, and prove determinism with two captures of the same frames. **F002's third attempt is the working example of this pattern: same class, cured by adding foot skirts at the wall feet and passing the determinism check** |
| F032 (+F042) | Route 112 | Two attempts removed the floating plates but the replacements broke the taste rules: attempt 1's standing bush had 8x-stretched top/side faces (chunky tables), attempt 2's lathe still reads as a dark striped block where the crown's foot cell is on a relief slope (the bush is built at the cell base while the relief ramps 48->59.3, so it sinks ~11 px), and at the low camera one bush fills 40% of the frame | What works: the crowns whose south cell is 0x218/0x21A convert cleanly (bright leafy bushes). What is left: the 11 crowns with a 0x203/0x3B8 south neighbour (logged as F042) and the relief-slope foot case. A third attempt should build at the drawn relief height and settle those 11 cells |
| F030 | Route 112 west fill | Two attempts each passed their 8-map gate but opened ~30 small air regions elsewhere | The cause chain (building-claimed cliff cells at absolute 0; a hill ending at the build window standing open) is understood and the patches are kept on their branches |

## Does anything break for the player? (audit, 2026-10-21)
Both trees (the installed game's own state, and the candidate) were built headless for all 158 maps and their cell tables compared:
- **1,553 cell lines differ, and every one of them is the solved floor (`base`) of a BLOCKED cell.** Not one walkable cell's floor
  changed on any map, so no path, step, ledge drop or door can differ.
- The biggest movers are Ever Grande City (467 blocked cells), Shoal Cave's high-tide inner room (261), Magma Hideout 2F/3R (129),
  Meteor Falls 1F/1R (122) and Route 121 (106) - all stairs-heavy maps, which is exactly where F006's rule acts: the rock beside a
  stair flight takes the nearest real floor instead of the flight's tread height.
- Visual spot check on the largest mover (Ever Grande, levels 4 and 7, two spots): the terraces, stairs, buildings and rock faces are
  structurally identical between the two trees; the frame differences are flowers, water animation and NPCs.

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

## Tier 1 gates on this candidate (158 maps, full scope, 2026-10-21 01:15)
| Gate | Result | Numbers | Against the installed game |
|---|---|---|---|
| 2D fallbacks / Lua errors | **pass** | 632 of 632 captures, 0 fallbacks, 0 errors, 0 watchdogs | same |
| Stairs and ledges | **pass** | 113 stairs ok, 0 flat, 0 reversed, 0 cliff jumps; 0 of 401 ledges bad | same |
| Floating rock audit | **pass** | 4,609 masses, 0 floats | same |
| Building defect scan | **pass** | 122 bakes, 0 flagged | same |
| Magenta holes | *fails its target, not ours* | 13 of 632 level-7 frames have magenta in the lower 45% | **the installed game has 16 of 632** - pre-existing, and this candidate removes three |
| Height repeatability | *fails as expected* | 2 of 156,063 cells differ between two runs of the same code (the builder's `pairs()` noise, F037); 101 cells differ from the October baseline | the 101 are the fixes plus other sessions' installs |
| Load time | *half measured* | median **308 ms** per map (target under 1,000 ms), but 11 maps over 1 s and 9 timeouts, measured at load average 16.6 while macOS Spotlight was indexing the loop's own 5 GB of dumps | needs one rerun on an idle machine |

This run covers the candidate up to F006's second pass; F002 landed while it was running and passed its own gate (Route 115's
step regions 16 -> 1). A final run over the complete candidate is the last step before you install.

## Blast radius of the fixes (checked, not assumed)## Blast radius of the two fixes (checked, not assumed)
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
