#!/bin/bash
# ctl14.sh [label]  CONTROL (game lib) cell dump of the 5 control maps a second time: is the Route 113
# (15,1) ledge's base (56 or 64) the same between two runs of the UNCHANGED code?
set -u
R=$HOME/Documents/Emerald; L=${1:-ctl14}; O=$R/.autoloop/runs/f035/$L
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
FILES="Gen3TreeStamps.lua Gen3Rock.lua Gen3Relief.lua Gen3Elevation.lua"
mkdir -p "$O"; export QA_ZOOM=-2 QA_LIMIT=400
cp "$R/.autoloop/runs/f035/g14a/ctl_maps.txt" "$O/ctl_maps.txt"
QA_SRC=$GAME EM_DRIVER="$R/tools/em_cells_driver.lua" EM_MAPS="$O/ctl_maps.txt" EM_DUMP="$O/cells_control2.txt" EM_DUMP_WAIT=300 \
  "$R/tools/qa_tryp.sh" "$FILES" "$O/out" - 4 0 60 > "$O/summary.txt" 2>&1
echo done > "$O/ALLDONE"
