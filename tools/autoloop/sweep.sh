#!/bin/bash
# World geometry sweep of one tree, headless (engine E1):  sweep.sh [maps.txt] [jobs=6]
# Builds every map of maps.txt (default: outdoor_spots + cave_spots = the whole Tier 1 scope) with the headless builder
# into .autoloop/geo-cache/h-<commit>/full/, then runs the detectors into world_air/steps/void .json/.txt there.
# Tree = AUTOLOOP_RC (default .autoloop/rc). ~6 min for 158 maps at 8 jobs on a loaded machine.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
TREE=${AUTOLOOP_RC:-$ROOT/.autoloop/rc}
H=$(git -C "$TREE" rev-parse --short HEAD)
[ -n "$(git -C "$TREE" status --porcelain)" ] && { echo "tree has uncommitted changes"; exit 3; }
OUT=$ROOT/.autoloop/geo-cache/h-$H/full; mkdir -p "$OUT"
ML=${1:-}; J=${2:-6}
if [ -z "$ML" ]; then ML=$OUT/maps.txt; cat "$ROOT/docs/ledger/outdoor_spots.txt" "$ROOT/docs/ledger/cave_spots.txt" > "$ML"; fi
"$ROOT/engine/geo.sh" --tree "$TREE" --maps "$ML" --out "$OUT" -j "$J" > "$OUT/geo.out" 2>&1
echo "[sweep] $(grep -c '^\[EM geo\]' "$OUT/headless.log") maps built; $(grep -ci 'unsettled\|skip' "$OUT/headless.log") unsettled/skip; $(tail -1 "$OUT/geo.out")"
for d in air steps void; do
  python3 -I "$ROOT/tools/autoloop/detect.py" $d "$OUT"/*.geo.gz --lib "$TREE/lib" --top 0 --json "$OUT/world_$d.json" > "$OUT/world_$d.txt" 2>&1
done
echo "[sweep] detectors: $OUT/world_{air,steps,void}.txt"
