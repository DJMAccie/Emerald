#!/bin/bash
# cap_pins.sh <label> <old|new> <yaw> "MAP,x,y" ...   Frames at levels 4,6,7 (QA_ZOOM=-2).
#   old = the INSTALLED game lib; new = the mod source's Gen3Elevation + Gen3PinData (+ EXTRA_FILES) on top of it.
# Out: .autoloop/runs/<label>/<old|new>/<map>_<x>_<y>_y<yaw>/  (max 3 games here; 4 machine-wide)
set -u
R=$HOME/Documents/Emerald
L=$1; MODE=$2; YAW=$3; shift 3
O=$R/.autoloop/runs/$L/$MODE
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
SRC=${SRC_OVERRIDE:-$HOME/Documents/battle-art-notquiteog}
mkdir -p "$O"
export QA_ZOOM=-2 QA_LIMIT=400
if [ "$MODE" = new ]; then export QA_SRC=$SRC FILES="Gen3Elevation.lua Gen3PinData.lua ${EXTRA_FILES:-}"; else export QA_SRC=$GAME FILES="Gen3Scene.lua"; fi
one(){ spec=$1; yaw=$2
  local m x y; IFS=, read m x y <<< "$spec"
  EM_DRIVER=$R/tools/em_ghost_driver.lua "$R/tools/qa_tryp.sh" "$FILES" "$O/${m}_${x}_${y}_y${yaw}" "{'$m',$x,$y}" "4,6,7" "$yaw" 300 > "$O/${m}_${x}_${y}_y${yaw}.summary" 2>&1
  echo "$spec yaw$yaw $(cat "$O/${m}_${x}_${y}_y${yaw}.summary")" >> "$O/summary.txt"
}
export -f one; export O R
for s in "$@"; do echo "$s $YAW"; done | xargs -P 3 -L1 bash -c 'one $0 $1'
echo done > "$O/ALLDONE"
