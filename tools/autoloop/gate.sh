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
REGRESSION=${GATE_MAPS:-"EM_ROUTE103 EM_ROUTE112 EM_ROUTE113 EM_LAVARIDGE_TOWN EM_ROUTE115 EM_MOSSDEEP_CITY EM_RUSTBORO_CITY EM_OLDALE_TOWN EM_ROUTE111 EM_FORTREE_CITY"}
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
# Geometry: the headless builder (engine E1: same triangles as the game, no game boot, 8 at once). Each side is built
# twice, because the builder itself varies run to run on some maps (pairs() order); gate_eval counts only changes that
# hold in both fix builds and differ from both base builds. In-game captures below stay for the look.
hdump(){ # hdump TREE OUT : the gate's maps, headless
  mkdir -p "$2"; "$ROOT/engine/geo.sh" --tree "$1" --maps "$ML" --out "$2" -j 4 > "$2/geo.out" 2>&1
}
# Base dumps are cached per commit, but a cache entry is only valid for the SAME driver and payload that made it (the
# engine app updates its payload on its own, and the driver keeps changing): a stale entry made the two "independent" base
# builds non-independent and turned builder noise into "new detector regions" (found by the F040 fixer 2026-10-22).
BC=$ROOT/.autoloop/geo-cache/h-$BASEH
STAMP="$(md5 -q "$ML") $(git -C "$ROOT" log -1 --format=%h -- tools/autoloop/em_geo_driver.lua) $(sed -n 's/.*payload \([^ ]*\).*/\1/p' "$BC/a/headless.log" 2>/dev/null | head -1)"
for side in a b; do
  want=$(printf '%s' "$STAMP" | md5 -q)
  if [ ! -f "$BC/$side/done" ] || [ "$(cat "$BC/$side/done")" != "$want" ]; then
    rm -rf "$BC/$side"; hdump "$BT" "$BC/$side"; printf '%s' "$want" > "$BC/$side/done"
  fi
done
rm -rf "$G/fix_a" "$G/fix_b"; hdump "$RC" "$G/fix_a"; hdump "$RC" "$G/fix_b"
FB=$(cat "$BC"/a/headless.log "$BC"/b/headless.log "$G"/fix_a/headless.log "$G"/fix_b/headless.log 2>/dev/null | grep -ci "fallback\|unsettled\|error")
echo "[gate] fallback/unsettled/error lines in headless builds: $FB"
python3 -I "$ROOT/tools/autoloop/gate_eval.py" "$BC/a" "$G/fix_a" --base2 "$BC/b" --fix2 "$G/fix_b" --map "$MAP" --box "$BOX" --kind "$KIND" \
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
if [ $EV -eq 2 ]; then
  # REVIEW: before/after of every area where cells changed outside the box (levels 4 and 7, yaw 0.8)
  RCASES=$(python3 -I -c "import json;print(','.join(\"{'%s',%d,%d}\"%tuple(s) for s in json.load(open('$G/verdict.json'))['review_spots']))")
  if [ -n "$RCASES" ]; then
    AUTOLOOP_RC=$BT "$ROOT/tools/autoloop/shots.sh" "$G/review_base" "$RCASES" 4,7 0.8 150 &
    sleep 20; AUTOLOOP_RC=$RC "$ROOT/tools/autoloop/shots.sh" "$G/review_fix" "$RCASES" 4,7 0.8 150 &
    wait; python3 "$ROOT/tools/autoloop/review_sheet.py" "$G"
  fi
fi
# DETERMINISM: capture the same frames a second time from the fix tree and compare. A fix whose own render is not
# reproducible is not a fix (F001 looked strictly better and still opened fresh sky in 1 of 4 captures because its closure
# read the streaming cell table - docs/AUTOLOOP.md 2026-10-22).
for Y8 in 0.8 3.9; do
  AUTOLOOP_RC=$RC "$ROOT/tools/autoloop/shots.sh" "$G/shots_fix2_y$Y8" "$CASE" 4,6,7 "$Y8" 150 > /dev/null 2>&1
done
DET=$(python3 "$ROOT/tools/autoloop/gate_determinism.py" "$G/shots_fix_y0.8" "$G/shots_fix2_y0.8" --json "$G/determinism.json" 2>&1 | tail -1); echo "[gate] $DET"
case "$DET" in *STABLE*) DETOK=0;; *) DETOK=1;; esac
SF=$(cat "$G"/shots_*/run.log "$G"/review_*/run.log 2>/dev/null | grep -c fallback)
echo "[gate] fallbacks in capture runs: $SF"
[ $DETOK -ne 0 ] && { echo "[gate] FAIL: the fix's own capture is not reproducible (see determinism.json) - that is the F001/F002 class"; exit 1; }
[ "$FB" -eq 0 ] && [ "$SF" -eq 0 ] && [ $EV -eq 0 ] && { echo "[gate] PASS (pending verifier)"; exit 0; }
[ "$FB" -eq 0 ] && [ "$SF" -eq 0 ] && [ $EV -eq 2 ] && { echo "[gate] REVIEW: fault fixed, cells changed elsewhere; the verifier judges sheet_review.png too"; exit 2; }
echo "[gate] FAIL"; exit 1
