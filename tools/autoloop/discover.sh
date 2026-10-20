#!/bin/bash
# Discovery by capture (docs/AUTOLOOP.md): the air rule only ranks candidates, so capture the top ones and let a
# verifier-looking agent judge them from full-size frames.
#   discover.sh WORLD_DIR [TOP=24] [CASE_BATCH=6] [yaw=0.8]   (output dir: $DISCOVER_OUT, default .autoloop/runs/discover)
# Writes .autoloop/runs/discover/index.json (one row per case: map, cell, cluster box/score) plus
# .autoloop/runs/discover/<map>/shots/... (levels 4 and 7) and <map>/sheet.png. Uses 2 games at a time.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
W=$1; TOP=${2:-24}; B=${3:-6}; YAW=${4:-0.8}
OUT=${DISCOVER_OUT:-$ROOT/.autoloop/runs/discover}; mkdir -p "$OUT"
export CASE_BATCH=${3:-6}
python3 -I "$ROOT/tools/autoloop/triage.py" "$W" --top "$TOP" --json "$OUT/clusters.json" --cases "$OUT/cases.txt" > "$OUT/queue.txt" 2>&1
python3 -I - "$OUT" <<'PY'
# frames are numbered INSIDE each batch dir (shots.sh writes b001.. per run), so the index has to record the batch and
# the case's position in it - an earlier version assumed one global numbering and the judges could not find the frames
import json, sys, re, os
out = sys.argv[1]
cl = json.load(open(out + '/clusters.json'))
cases = re.findall(r"\{'([^']+)',(\d+),(\d+)\}", open(out + '/cases.txt').read())
idx = {}
per = int(os.environ.get('CASE_BATCH', '6'))
for b, first in enumerate(range(0, len(cases), per), 1):
    for j, (m, x, y) in enumerate(cases[first:first + per]):
        c = next((c for c in cl if c['map'] == m), None)
        idx['batch%02d/b%03d' % (b, 2 * j + 1)] = {'map': m, 'cell': [int(x), int(y)], 'cluster_box': c['box'] if c else None,
                                                   'score': c['score'] if c else None, 'kind': c['kind'] if c else None,
                                                   'cell_kind': c['cell_kind'] if c else None,
                                                   'frames': ['batch%02d/b%03d.png' % (b, 2 * j + 1), 'batch%02d/b%03d.png' % (b, 2 * j + 2)]}
json.dump(idx, open(out + '/index.json', 'w'), indent=1)
print(len(idx), 'cases indexed (per batch)')
PY
CASES=$(cat "$OUT/cases.txt")
python3 - "$CASES" "$B" "$OUT" <<'PY' > "$OUT/batches.txt"
import sys, re
cases = re.findall(r"\{[^}]+\}", sys.argv[1]); b = int(sys.argv[2]); out = sys.argv[3]
for i in range(0, len(cases), b):
    print(out + '/batch%02d|' % (i // b + 1) + ','.join(cases[i:i + b]))
PY
n=0
while IFS='|' read -r dir cases; do
  [ -z "$cases" ] && continue
  "$ROOT/tools/autoloop/shots.sh" "$dir" "$cases" 4,7 "$YAW" 150 > "$dir.log" 2>&1 &
  n=$((n + 1)); sleep 20; [ $((n % 2)) -eq 0 ] && wait
done < "$OUT/batches.txt"
wait
for d in "$OUT"/batch*; do
  [ -d "$d" ] || continue
  "$ROOT/tools/autoloop/contact.py" "$d"/b*.png "$d/sheet.png" 4 2>/dev/null || true
done
FB=$(cat "$OUT"/batch*/run.log 2>/dev/null | grep -c "fallback [1-9]")
echo "[discover] $(ls "$OUT"/batch*/b*.png 2>/dev/null | wc -l | tr -d ' ') frames, $FB fallbacks; index $OUT/index.json"
