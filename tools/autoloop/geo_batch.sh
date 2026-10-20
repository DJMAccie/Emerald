#!/bin/bash
# One geometry-dump batch on the rc tree:  geo_batch.sh <maps.txt> <outdir> [geo_dir]
# maps.txt holds "MAP x y" lines. Writes <geo_dir>/<MAP>.geo.gz and .cells (default .autoloop/geo) and
# <outdir>/run.log. Uses a private QA copy through qa_tryp.sh (slot cap 4, 400 s cap: keep batches small).
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
MAPS=$(cd "$(dirname "$1")" && pwd)/$(basename "$1"); OUT=$2; GEO=${3:-$ROOT/.autoloop/geo}
mkdir -p "$OUT" "$GEO"; OUT=$(cd "$OUT" && pwd); GEO=$(cd "$GEO" && pwd)
export QA_SRC=$("$ROOT/tools/autoloop/rc.sh" dir)
FILES="$("$ROOT/tools/autoloop/rc.sh" files)"
cd "$HOME/Documents/gen1recomp"
QA_LIMIT=400 EM_DRIVER="$ROOT/tools/autoloop/em_geo_driver.lua" EM_MAPS="$MAPS" EM_GEO_DIR="$GEO" \
  "$ROOT/tools/qa_tryp.sh" "$FILES Gen3Waterfall.lua" "$OUT" - 4 0 60 > "$OUT/summary.txt" 2>&1
grep -h "EM geo" "$OUT/run.log"
