#!/bin/bash
# World geometry sweep of one tree (default: rc main):  sweep.sh [maps.txt] [parallel=2]
# Dumps every map of maps.txt (default: outdoor_spots + cave_spots = the whole Tier 1 scope) into
# .autoloop/geo-cache/<rc commit>/ in batches of 3, <parallel> games at a time, 20 s apart. Resumable: maps already
# dumped are skipped, so rerun after a stop. Then runs the detectors over everything into <cache>/world_air.json and
# world_steps.json. Uses AUTOLOOP_RC (default .autoloop/rc) as the tree.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
TREE=${AUTOLOOP_RC:-$ROOT/.autoloop/rc}
H=$(git -C "$TREE" rev-parse --short HEAD)
[ -n "$(git -C "$TREE" status --porcelain)" ] && { echo "tree has uncommitted changes"; exit 3; }
GEO=$ROOT/.autoloop/geo-cache/$H; RUNS=$ROOT/.autoloop/runs/sweep-$H; mkdir -p "$GEO" "$RUNS"
ML=${1:-}; P=${2:-2}
if [ -z "$ML" ]; then ML=$RUNS/maps.txt; cat "$ROOT/docs/ledger/outdoor_spots.txt" "$ROOT/docs/ledger/cave_spots.txt" > "$ML"; fi
TODO=$RUNS/todo.txt; : > "$TODO"
while read -r m x y; do [ -n "$m" ] && [ ! -f "$GEO/$m.geo.gz" ] && echo "$m $x $y" >> "$TODO"; done < "$ML"
echo "[sweep] tree $TREE ($H): $(wc -l < "$TODO" | tr -d ' ') of $(wc -l < "$ML" | tr -d ' ') maps to dump, $P at a time"
rm -rf "$RUNS"/b_*; split -l 3 "$TODO" "$RUNS/b_"
n=0
for b in "$RUNS"/b_*; do
  [ -f "$b" ] || continue
  AUTOLOOP_RC=$TREE "$ROOT/tools/autoloop/geo_batch.sh" "$b" "$b.out" "$GEO" &
  n=$((n+1)); sleep 20
  while [ "$(jobs -r | wc -l)" -ge "$P" ]; do sleep 5; done
done
wait
echo "[sweep] dumped $(ls "$GEO"/*.geo.gz | wc -l | tr -d ' ') maps; fallbacks $(cat "$RUNS"/b_*.out/run.log 2>/dev/null | grep -c fallback); unsettled $(cat "$RUNS"/b_*.out/run.log 2>/dev/null | grep -c unsettled)"
python3 -I "$ROOT/tools/autoloop/detect.py" air "$GEO"/*.geo.gz --lib "$TREE/lib" --top 0 --json "$GEO/world_air.json" > "$GEO/world_air.txt" 2>&1
python3 -I "$ROOT/tools/autoloop/detect.py" steps "$GEO"/*.geo.gz --lib "$TREE/lib" --top 0 --json "$GEO/world_steps.json" > "$GEO/world_steps.txt" 2>&1
echo "[sweep] detectors: $GEO/world_air.txt $GEO/world_steps.txt"
