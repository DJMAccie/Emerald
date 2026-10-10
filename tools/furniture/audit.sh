#!/bin/bash
# tools/furniture/audit.sh indoor|outdoor OUTDIR -- whole-game furniture audit:
# OUTDIR/run.log gets [AUD] map x y mid prop (built props; names with _prop_ are
# automatic stand-ins) and [FLAT] map x y mid (blocked cells built as nothing).
H=$(cd "$(dirname "$0")" && pwd)
EM_AUDIT=1 QA_LIMIT=3000 "$H/shot.sh" "$2" "$(python3 "$H/cases.py" $1)" 4 0 20
