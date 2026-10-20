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

## How this was checked
Every fix goes through `tools/autoloop/gate.sh`: the headless builder (identical to the game's own build; verified by the
engine track on Route 103, Oldale and Rustboro, triangle for triangle) builds base and fix twice each; the fault's own
detector region must be gone, no *new* region may appear on 8 regression maps, cells may only change inside the fault's
box (changes elsewhere are captured for the reviewer), and the captures at levels 4, 6 and 7 (two yaws) must come out
with 0 fallbacks. An independent verifier agent then tries to refute the fix on full-resolution before/after crops; a fix
is only kept if it cannot be refuted.
