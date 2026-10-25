#!/bin/bash
# cap_trace.sh <label> <probe-lib-dir|GAME> "MAP,x,y" ...   levels 4,6,7 frames + run.log ([TR] lines) from a probe tree
set -u
R=$HOME/Documents/Emerald; L=$1; P=$2; shift 2
O=$R/.autoloop/runs/$L; mkdir -p "$O"
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
export QA_ZOOM=-2 QA_LIMIT=400
one(){ spec=$1; local m x y; IFS=, read m x y <<< "$spec"
  if [ "$P" = GAME ]; then src="$GAME"; else src="$P"; fi
  QA_SRC=$src EM_DRIVER=$R/tools/em_ghost_driver.lua \
    "$R/tools/qa_tryp.sh" "${FILES:-Gen3Rock.lua}" "$O/${m}_${x}_${y}" "{'$m',$x,$y}" "4,6,7" ${YAW:-0} 300 > "$O/${m}_${x}_${y}.summary" 2>&1
  echo "$spec fallback $(grep -c fallback "$O/${m}_${x}_${y}/run.log" 2>/dev/null)" >> "$O/zooms.txt"
}
export -f one; export O GAME R P
for s in "$@"; do echo "$s"; done | xargs -P 3 -L1 bash -c 'one $0'
echo done > "$O/ALLDONE"
