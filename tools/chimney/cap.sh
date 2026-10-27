#!/bin/bash
# cap.sh <label> <yaw> "MAP,x,y" ...   Frames of the INSTALLED game lib (what the user sees), levels 4,6,7.
# For the Mt Chimney / Lavaridge rock task: no probe, just the current state from several angles.
set -u
R=$HOME/Documents/Emerald
L=$1; YAW=$2; shift 2
O=$R/.autoloop/runs/$L
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
mkdir -p "$O"
export QA_ZOOM=-2 QA_LIMIT=400
one(){ spec=$1; yaw=$2
  local m x y; IFS=, read m x y <<< "$spec"
  QA_SRC=$GAME EM_DRIVER=$R/tools/em_ghost_driver.lua \
    "$R/tools/qa_tryp.sh" "Gen3Scene.lua" "$O/${m}_${x}_${y}_y${yaw}" "{'$m',$x,$y}" "4,6,7" "$yaw" 300 > "$O/${m}_${x}_${y}_y${yaw}.summary" 2>&1
  echo "$spec yaw$yaw fallback $(grep -c fallback "$O/${m}_${x}_${y}_y${yaw}/run.log" 2>/dev/null)" >> "$O/zooms.txt"
}
export -f one; export O GAME R
for s in "$@"; do echo "$s $YAW"; done | xargs -P 3 -L1 bash -c 'one $0 $1'
echo done > "$O/ALLDONE"
