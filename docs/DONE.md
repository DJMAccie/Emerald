# What counts as shippable

Written 2026-10-19 to give the project a finish line. Progress is counted in [LEDGER.md](LEDGER.md); this file says which faults stop a release and which do not.

## Tier 1: gates a release (the beta bar)
A map-area may be called shippable when, at the default camera (level 4, `QA_ZOOM=-2`) and the free camera (level 7), at two yaws:
- 0 fallbacks to the flat 2D map and 0 Lua errors (`grep -c fallback run.log`), over a sweep of every outdoor map and cave.
- 0 magenta holes (probe tree) in the lower 45% of the frame.
- Stairs audit 0 flat / 0 reversed / 0 cliff jumps; ledge check 0 ledges that do not drop, with straight lips and closed ends.
- No floating or buried props (prop base height equals the ground under it).
- The map shows in 3D within 1 s (serial, warm machine; noise from other apps does not count).
- Frame time within the current numbers.
- Defect scan on the baked buildings: counts listed in the ledger, none unexplained.
- The user has seen a final sheet of shots and said yes. Only the user sets ✅ in the ledger.
Packaging for a beta: version tag, install and Desktop launcher check, changelog with the known issues from the ledger, backup and rollback path.

## Tier 2: polish, never blocks a release
- First-person (level 6) 4-yaw survey, orbit, low camera.
- One-pixel seams and slivers, sub-tile roundness, plain wall areas seen from close.
- Rooms reviewed by eye, furniture detail, determinism of rock meshes between runs.
A Tier 2 fault is logged in `docs/ledger/faults.json` (tier 2) and stays there. The ledger shows it as 🟧.

## Rules that keep the work finite
1. A fault class gets one session. If it is not closed by the end of that session, list it in `faults.json` and move on.
2. A fault seen only at Tier 2 is logged, not chased in the same session, unless the fix is one line.
3. The audits and scanners stay strict. "Known faults listed" is a ledger state, not an exemption in a scanner: do not change a scanner's calibration to hide a fault.
4. New fault classes come from the user's tour (screenshots, see `tools/tour_note.sh`); the automated audits guard against regressions after a fix.
5. A ledger row moves to ✅ only when the user has reviewed it in game and `faults.json` has no open fault for it.

## Running the Tier 1 gates
`tools/release_check.sh [--out DIR] [--maps FILE] [--gates ...]` runs them all (about 1.5-2 h for every outdoor map and cave; 10-15 min for 5 maps) and writes `results.json`; `tools/ledger.py --audit-from results.json --write` puts the numbers in the ledger (a subset run is refused unless `--audits-file` is given). Not scripted: your yes on the sheet, frame time (no baseline), buried props. Level-4 magenta near a map edge is the world's edge, so the magenta gate counts level 7.
