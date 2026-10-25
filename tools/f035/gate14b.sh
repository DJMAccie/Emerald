#!/bin/bash
# gate14b.sh [label]   Task 14 re-gate with the crownFloor base rule (Gen3Elevation.lua is now in the probe):
#   geodump  full-map Route 112 geometry + cells from the PROBE
#   cells    whole-map cell dumps of the control maps from the PROBE
#   capture  fresh probe frames of Route 112 32,22 and 30,22 (the hole's spot)
set -u
R=$HOME/Documents/Emerald
L=${1:-g14b}
O=$R/.autoloop/runs/f035/$L
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
PROBE=$R/tools/f035/probe
FILES="Gen3TreeStamps.lua Gen3Rock.lua Gen3Relief.lua Gen3Elevation.lua"
mkdir -p "$O"
export QA_ZOOM=-2 QA_LIMIT=400 R O GAME PROBE FILES
cp "$R/.autoloop/runs/f035/g14a/ctl_maps.txt" "$O/ctl_maps.txt"
cp "$R/.autoloop/runs/f035/g14a/route112_maps.txt" "$O/route112_maps.txt"
one(){ mode=$1; arg=$2
  case $mode in
   geodump)
    mkdir -p "$O/geo_new"
    QA_SRC=$PROBE EM_DRIVER="$R/tools/autoloop/em_geo_driver.lua" EM_MAPS="$O/route112_maps.txt" EM_GEO_DIR="$O/geo_new" \
      "$R/tools/qa_tryp.sh" "$FILES" "$O/out_geo" - 4 0 200 > "$O/geo.summary" 2>&1 ;;
   cells)
    QA_SRC=$PROBE EM_DRIVER="$R/tools/em_cells_driver.lua" EM_MAPS="$O/ctl_maps.txt" EM_DUMP="$O/cells_new.txt" EM_DUMP_WAIT=300 \
      "$R/tools/qa_tryp.sh" "$FILES" "$O/out_cells" - 4 0 60 > "$O/cells.summary" 2>&1 ;;
   capture)
    local m x y; IFS=, read m x y <<< "$arg"
    QA_SRC=$PROBE EM_DRIVER=$R/tools/em_ghost_driver.lua \
      "$R/tools/qa_tryp.sh" "$FILES" "$O/new_${m}_${x}_${y}" "{'$m',$x,$y}" "4,6,7" 0.8 300 > "$O/new_${m}_${x}_${y}.summary" 2>&1 ;;
  esac
}
export -f one
{
 echo "geodump x"
 echo "cells x"
 echo "capture EM_ROUTE112,32,22"
 echo "capture EM_ROUTE112,30,22"
} | xargs -P 3 -L1 bash -c 'one "$0" "$1"'
echo done > "$O/ALLDONE"
