#!/bin/bash
# Captures on the rc tree:  shots.sh <outdir> "<cases>" [levels=4,7] [yaw=0.8] [wait=90]
# Indexed shots (b000.png ... in case order, levels in order per case) plus run.log; QA_ZOOM=-2 like the user.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$1; CASES=$2; LEVELS=${3:-4,7}; YAW=${4:-0.8}; WAIT=${5:-90}
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)
export QA_SRC=$("$ROOT/tools/autoloop/rc.sh" dir) QA_ZOOM=-2 QA_LIMIT=400 EM_INDEXED=1
FILES="$("$ROOT/tools/autoloop/rc.sh" files)"
cd "$HOME/Documents/gen1recomp"
"$ROOT/tools/qa_tryp.sh" "$FILES Gen3Waterfall.lua" "$OUT" "$CASES" "$LEVELS" "$YAW" "$WAIT" > "$OUT/summary.txt" 2>&1
cat "$OUT/summary.txt" | tail -1
