Sea-at-0 gate kit (2026-10-20). run_dump.sh <label> [probe]: dumps 53 outdoor maps in 8 batches (needs maps_a..maps_h = `split -l 7 -a 1 docs/ledger/outdoor_spots.txt maps_`
next to it, and for `probe` a tree $S/${PROBE:-probe}/lib/Gen3Elevation.lua = the patched file); compare with tools/heights_compare.py diff CONTROL PROBE EMPTY_FLIPS.
The two .patch files are the probes that FAILED the gate (see docs/reference/POKEEMERALD-HEIGHT-MINING-2026-10-20.md); not for install.
sheet.py <dir>: before/after contact sheets from <dir>/shots_control and <dir>/shots_sea (run without python -I: needs Pillow).
