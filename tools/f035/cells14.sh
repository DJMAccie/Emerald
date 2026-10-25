#!/bin/bash
# cells14.sh [label]   probe cell dump of the 5 control maps, repeatable (Route 113 (15,1) flap check)
set -u
R=$HOME/Documents/Emerald; L=${1:-g14d}; O=$R/.autoloop/runs/f035/$L
PROBE=$R/tools/f035/probe
FILES="Gen3TreeStamps.lua Gen3Rock.lua Gen3Relief.lua Gen3Elevation.lua"
mkdir -p "$O"; export QA_ZOOM=-2 QA_LIMIT=400
cp "$R/.autoloop/runs/f035/g14a/ctl_maps.txt" "$O/ctl_maps.txt"
QA_SRC=$PROBE EM_DRIVER="$R/tools/em_cells_driver.lua" EM_MAPS="$O/ctl_maps.txt" EM_DUMP="$O/cells_new.txt" EM_DUMP_WAIT=300 \
  "$R/tools/qa_tryp.sh" "$FILES" "$O/out" - 4 0 60 > "$O/summary.txt" 2>&1
echo done > "$O/ALLDONE"
