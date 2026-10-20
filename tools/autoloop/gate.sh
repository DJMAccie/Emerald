#!/bin/bash
# Gate one autoloop fix (docs/AUTOLOOP.md step 6):
#   gate.sh <name> <MAP> <x0,y0,x1,y1> <kind air|steps|none> "<spot x,y>" [base-commit=main]
# The fix is FIX_TREE's HEAD (default the rc working tree; fixers use their own worktree, see FIXER-BRIEF.md); the
# base is <base-commit> (of the rc repo) checked out into
# .autoloop/trees/<commit> (cached). Dumps the fault map + REGRESSION maps from both trees (base dumps cached per
# commit), runs gate_eval.py, then captures the spot at levels 4,6,7 from yaw 0.8 and 3.9 in both trees and builds a
# before/after sheet for the verifier. Output: .autoloop/gates/<name>/{verdict.json,sheet.png,...}. Exit 0 = pass.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
NAME=$1; MAP=$2; BOX=$3; KIND=$4; SPOT=$5; BASEC=${6:-main}
RC=${FIX_TREE:-$ROOT/.autoloop/rc}
G=$ROOT/.autoloop/gates/$NAME; mkdir -p "$G"
REGRESSION=${GATE_MAPS:-"EM_ROUTE103 EM_ROUTE112 EM_ROUTE115 EM_MOSSDEEP_CITY EM_RUSTBORO_CITY EM_OLDALE_TOWN EM_ROUTE111 EM_FORTREE_CITY"}
[ -n "$(git -C "$RC" status --porcelain)" ] && { echo "rc has uncommitted changes: commit the fix on its branch first"; exit 3; }
BASEH=$(git -C "$RC" rev-parse --short "$BASEC"); FIXH=$(git -C "$RC" rev-parse --short HEAD)
[ "$BASEH" = "$FIXH" ] && { echo "fix tree HEAD equals base ($BASEH): nothing to gate"; exit 3; }
BT=$ROOT/.autoloop/trees/$BASEH
[ -d "$BT" ] || git -C "$RC" worktree add -q --detach "$BT" "$BASEH"
echo "[gate] $NAME  map $MAP box $BOX kind $KIND  base $BASEH  fix $FIXH ($(git -C "$RC" diff --stat "$BASEH" HEAD | tail -1))"
# map list: fault map first, then the regression set; spots from the ledger's outdoor/cave lists
ML=$G/maps.txt; : > "$ML"
for m in $MAP $REGRESSION; do grep -h "^$m " "$ROOT/docs/ledger/outdoor_spots.txt" "$ROOT/docs/ledger/cave_spots.txt" | head -1 >> "$ML"; done
awk '!seen[$1]++' "$ML" > "$ML.u" && mv "$ML.u" "$ML"
dump(){ # dump TREE GEO_DIR LOGDIR : missing maps only, in batches of 3, two at a time
  local tree=$1 geo=$2 log=$3; mkdir -p "$geo" "$log"
  local todo=$log/todo.txt; : > "$todo"
  while read -r m x y; do [ -f "$geo/$m.geo.gz" ] || echo "$m $x $y" >> "$todo"; done < "$ML"
  [ -s "$todo" ] || return 0
  split -l 3 "$todo" "$log/b_"
  local n=0
  for b in "$log"/b_*; do
    AUTOLOOP_RC=$tree "$ROOT/tools/autoloop/geo_batch.sh" "$b" "$b.out" "$geo" &
    n=$((n+1)); sleep 20; [ $((n % 2)) -eq 0 ] && wait
  done; wait
}
dump "$BT" "$ROOT/.autoloop/geo-cache/$BASEH" "$G/base_runs" &
sleep 10
dump "$RC" "$G/fix_geo" "$G/fix_runs" &
wait
FB=$(cat "$G"/base_runs/b_*.out/run.log "$G"/fix_runs/b_*.out/run.log 2>/dev/null | grep -c fallback)
echo "[gate] fallbacks in dump runs: $FB"
python3 -I "$ROOT/tools/autoloop/gate_eval.py" "$ROOT/.autoloop/geo-cache/$BASEH" "$G/fix_geo" --map "$MAP" --box "$BOX" --kind "$KIND" \
  --lib-base "$BT/lib" --lib-fix "$RC/lib" --out "$G/verdict.json"; EV=$?
# captures for the verifier: the spot at levels 4,6,7, two yaws, both trees
X=${SPOT%,*}; Y=${SPOT#*,}; CASE="{'$MAP',$X,$Y}"
for Y8 in 0.8 3.9; do
  AUTOLOOP_RC=$BT "$ROOT/tools/autoloop/shots.sh" "$G/shots_base_y$Y8" "$CASE" 4,6,7 "$Y8" 150 &
  sleep 20
  AUTOLOOP_RC=$RC "$ROOT/tools/autoloop/shots.sh" "$G/shots_fix_y$Y8" "$CASE" 4,6,7 "$Y8" 150 &
  sleep 20
done; wait
python3 - "$G" <<'PY'
import sys, glob, os
from PIL import Image, ImageDraw
g = sys.argv[1]
rows = []
for y in ('0.8', '3.9'):
    b = sorted(glob.glob('%s/shots_base_y%s/b*.png' % (g, y)))
    f = sorted(glob.glob('%s/shots_fix_y%s/b*.png' % (g, y)))
    for i, (pb, pf) in enumerate(zip(b, f)):
        rows.append(('yaw %s level %s' % (y, (4, 6, 7)[i] if i < 3 else i), pb, pf))
if rows:
    W, H = 960, 540
    s = Image.new('RGB', (W * 2, H * len(rows)), 'black'); d = ImageDraw.Draw(s)
    for r, (t, pb, pf) in enumerate(rows):
        s.paste(Image.open(pb).convert('RGB').resize((W, H), Image.NEAREST), (0, r * H))
        s.paste(Image.open(pf).convert('RGB').resize((W, H), Image.NEAREST), (W, r * H))
        d.text((8, r * H + 8), 'BEFORE ' + t, fill='yellow'); d.text((W + 8, r * H + 8), 'AFTER ' + t, fill='yellow')
    s.save(g + '/sheet.png')
    print('[gate] sheet', g + '/sheet.png', len(rows), 'rows')
PY
SF=$(cat "$G"/shots_*/run.log 2>/dev/null | grep -c fallback)
echo "[gate] fallbacks in capture runs: $SF"
[ "$FB" -eq 0 ] && [ "$SF" -eq 0 ] && [ $EV -eq 0 ] && { echo "[gate] PASS (pending verifier)"; exit 0; }
echo "[gate] FAIL"; exit 1
