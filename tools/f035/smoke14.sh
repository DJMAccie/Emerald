#!/bin/bash
# smoke14.sh  Task 14 post-install smoke: frames from the INSTALLED game lib at the two spots the gate used.
set -u
R=$HOME/Documents/Emerald; O=$R/.autoloop/runs/f035/INSTALL
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
FILES="Gen3TreeStamps.lua Gen3Rock.lua Gen3Relief.lua Gen3Elevation.lua"
mkdir -p "$O"; export QA_ZOOM=-2 QA_LIMIT=400
one(){ local m=$1 x=$2 y=$3
  QA_SRC=$GAME EM_DRIVER=$R/tools/em_ghost_driver.lua \
    "$R/tools/qa_tryp.sh" "$FILES" "$O/game_${m}_${x}_${y}" "{'$m',$x,$y}" "4,6,7" 0.8 300 > "$O/game_${m}_${x}_${y}.summary" 2>&1
}
export -f one; export R O GAME FILES
printf 'EM_ROUTE112 26 25\nEM_ROUTE112 32 22\nEM_ROUTE112 30 28\n' | xargs -P 3 -L1 bash -c 'one $0 $1 $2'
grep -h "fallback" $O/game_*.summary 2>/dev/null | head -3
echo done > "$O/ALLDONE"
