#!/bin/bash
# ab_run.sh <batch> "<lib files to try>" "MAP,x,y" ...   levels 4,6,7 yaw 0 of the source-tree files (private QA copies, 3 games at a time).
# Compare with the installed game (old) from tools/relief/stage3/ab/ab_run.sh (VARIANTS=old) and ab_sheet.py (VARS=old,new).
R=$HOME/Documents/Emerald
B=$1; FILES=$2; shift; shift
OUT=$R/docs/rock-gates/general-rollout/$B
mkdir -p $OUT
export QA_ZOOM=-2 QA_LIMIT=400
one(){ spec=$1
  IFS=, read m x y <<< "$spec"
  "$R/tools/qa_tryp.sh" "$FILES" "$OUT/new_${m}_${x}_${y}" "{'$m',$x,$y}" "4,6,7" 0 300 > "$OUT/new_${m}_${x}_${y}.summary" 2>&1
}
export -f one; export OUT R FILES
for s in "$@"; do echo "$s"; done | xargs -P 3 -L1 bash -c 'one $0'
echo done > $OUT/ALLDONE
