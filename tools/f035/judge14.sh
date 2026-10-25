#!/bin/bash
# judge14.sh [label]   the two extra views for task 14's (27..29,22)/(32,23) base question, plus a second
# CONTROL geo dump (same lib as the first) to see whether the out-of-map ledge cells (44,6)/(45,6) flap there too.
set -u
R=$HOME/Documents/Emerald
L=${1:-j14}
O=$R/.autoloop/runs/f035/$L
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
PROBE=$R/tools/f035/probe
FILES="Gen3TreeStamps.lua Gen3Rock.lua Gen3Relief.lua"
mkdir -p "$O"
export QA_ZOOM=-2 QA_LIMIT=400 R O GAME PROBE FILES
one(){ v=$1; spec=$2
  local src; if [ "$v" = old ]; then src=$GAME; else src=$PROBE; fi
  local m x y; IFS=, read m x y <<< "$spec"
  QA_SRC=$src EM_DRIVER=$R/tools/em_ghost_driver.lua \
    "$R/tools/qa_tryp.sh" "$FILES" "$O/${v}_${m}_${x}_${y}" "{'$m',$x,$y}" "4,6,7" 0.8 300 > "$O/${v}_${m}_${x}_${y}.summary" 2>&1
  echo "$v $m $x $y zoom $(grep -m1 'EM cam' "$O/${v}_${m}_${x}_${y}/run.log" | awk '{print $8}')" >> "$O/zooms.txt"
}
old2(){ mkdir -p "$O/geo_old2"
  QA_SRC=$GAME EM_DRIVER="$R/tools/autoloop/em_geo_driver.lua" EM_MAPS="$R/.autoloop/runs/f035/g14a/route112_maps.txt" EM_GEO_DIR="$O/geo_old2" \
    "$R/tools/qa_tryp.sh" "$FILES" "$O/out_geo_old2" - 4 0 200 > "$O/geo_old2.summary" 2>&1
}
export -f one old2
{
 echo "one old EM_ROUTE112,30,22"
 echo "one new EM_ROUTE112,30,22"
 echo "one old EM_ROUTE112,32,22"
 echo "one new EM_ROUTE112,32,22"
 echo "old2 x"
} | xargs -P 3 -L1 bash -c 'if [ "$0" = old2 ]; then old2; else one "$1" "$2"; fi'
echo done > "$O/ALLDONE"
