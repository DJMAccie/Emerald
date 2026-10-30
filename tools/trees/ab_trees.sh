#!/bin/bash
# ab_trees.sh <batch> "<lib files>" "MAP,x,y" ...   OLD (installed game lib) and NEW (tools/trees/probe) captures, levels 4,6,7, yaw 0
# (the tree twin of tools/relief/stage3/ab/ab_run.sh; sheets: python3 tools/relief/stage3/ab/ab_sheet.py <batch dir> <out> MAP,x,y ... with VARS=old,new)
# NEWTAG=<name> uses tools/trees/probe_<name> instead of tools/trees/probe, and VARIANTS="old new" can be narrowed (e.g. VARIANTS=new)
R=$HOME/Documents/Emerald
B=$1; FILES=$2; shift 2
OUT=$R/docs/rock-gates/general-rollout/$B
mkdir -p $OUT
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
PROBE=$R/tools/trees/probe${NEWTAG:+_$NEWTAG}
export QA_ZOOM=-2 QA_LIMIT=400
one(){ v=$1; spec=$2
  IFS=, read m x y <<< "$spec"
  if [ "$v" = old ]; then src="$GAME"; else src="$PROBE"; fi
  QA_SRC="$src" "$R/tools/qa_tryp.sh" "$FILES" "$OUT/${v}_${m}_${x}_${y}" "{'$m',$x,$y}" "4,6,7" 0 300 > "$OUT/${v}_${m}_${x}_${y}.summary" 2>&1
}
export -f one; export OUT R GAME FILES PROBE
for s in "$@"; do for v in ${VARIANTS:-old new}; do echo "$v $s"; done; done | xargs -P 3 -L1 bash -c 'one $0 $1'
echo done > $OUT/ALLDONE
