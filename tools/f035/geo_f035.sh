#!/bin/bash
# geo_f035.sh <batch> <maps.txt>   geometry + cells dump of the f035 probe build (Route 112)
# Same driver and output format as tools/autoloop/geo_batch.sh, but from the probe tree (game lib + F035 fix).
set -u
R=$HOME/Documents/Emerald
B=$1; MAPS=$2
OUT=$R/.autoloop/runs/f035/$B
GEO=$OUT/geo
mkdir -p "$OUT" "$GEO"
cd "$HOME/Documents/gen1recomp"
export QA_ZOOM=-2
QA_LIMIT=400 EM_DRIVER="$R/tools/autoloop/em_geo_driver.lua" EM_MAPS="$MAPS" EM_GEO_DIR="$GEO" \
  QA_SRC="$R/tools/f035/probe" \
  "$R/tools/qa_tryp.sh" "Gen3TreeStamps.lua Gen3Rock.lua Gen3Relief.lua" "$OUT" - 4 0 200 > "$OUT/summary.txt" 2>&1
grep -h "EM geo" "$OUT/run.log"
ls -la "$GEO"
