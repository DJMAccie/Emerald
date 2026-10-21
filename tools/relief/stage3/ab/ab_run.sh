#!/bin/bash
# ab_run.sh <batch> "MAP,x,y" ...   OLD (game lib) and NEW (stage3 probe) captures, levels 4,6,7, yaw 0
R=$HOME/Documents/Emerald
B=$1; shift
OUT=$R/docs/rock-gates/general-rollout/$B
mkdir -p $OUT
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
export QA_ZOOM=-2 QA_LIMIT=400
FILES="Gen3Cave.lua Gen3Hills.lua Gen3Mass.lua Gen3Relief.lua Gen3ReliefData.lua"
one(){ v=$1; spec=$2
  IFS=, read m x y <<< "$spec"
  if [ "$v" = old ]; then src="$GAME"; else src="${PROBE:-$R/tools/relief/stage3/probe}"; fi
  QA_SRC="$src" "$R/tools/qa_tryp.sh" "$FILES" "$OUT/${v}${ROUND:-}_${m}_${x}_${y}" "{'$m',$x,$y}" "4,6,7" 0 300 > "$OUT/${v}${ROUND:-}_${m}_${x}_${y}.summary" 2>&1
}
export -f one; export OUT R GAME FILES ROUND PROBE
for s in "$@"; do for v in ${VARIANTS:-old new}; do echo "$v $s"; done; done | xargs -P 3 -L1 bash -c 'one $0 $1'
echo done > $OUT/ALLDONE
