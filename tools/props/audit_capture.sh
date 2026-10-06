#!/bin/bash
# Capture every case in OUTDIR/cases.lua on the QA identity, indexed bNNN.png (several cases may share a map).
#   EM_LEVEL=4|6|7  EM_YAW=<radians>  EM_WAIT=<frames per case>  tools/props/audit_capture.sh OUTDIR
# level 4 = the player's camera, 7 = orbit (yaw only works here), 6 = low near-ground camera.
#
# Takes the same atomic lock as tools/qa_run.sh (/tmp/emerald-qa.lock): two game instances started at
# the same moment deadlock. Differences from qa_run.sh: indexed file names, a watchdog that scales with
# the number of cases (QA_LIMIT overrides), and the display is woken with caffeinate -u before the run.
set -u
OUT=$1
LOCK=/tmp/emerald-qa.lock
QI="$HOME/Library/Application Support/pokemon-love2d-rseqa"
WAIT=${EM_WAIT:-40}
N=$(grep -o "{'" "$OUT/cases.lua" | wc -l | tr -d ' ')
LIMIT=${QA_LIMIT:-$(( 60 + N * (WAIT / 8 + 12) ))}
rm -f "$OUT"/b*.png
printf "return {%s}\n" "${EM_LEVEL:-4}" > "$OUT/levels.lua"
until mkdir "$LOCK" 2>/dev/null; do
  if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +10 2>/dev/null)" ]; then rm -rf "$LOCK"; continue; fi
  sleep 3
done
echo "$$ $OUT" > "$LOCK/owner"
trap 'rm -rf "$LOCK"' EXIT
while pgrep -x love >/dev/null; do sleep 3; done
caffeinate -u -t 60 >/dev/null 2>&1 &   # wake a sleeping display: a window that cannot present stalls the game
python3 - <<PY
import re
p="$QI/options.lua";s=open(p,'rb').read()
s=re.sub(rb"\n  zoom = -?\d+,",b"\n  zoom = 0,",s,count=1)
s=re.sub(rb"fireredCamera = \d+,",b"fireredCamera = 4,",s,count=1)
open(p,'wb').write(s)
PY
cd ~/Documents/gen1recomp || exit 1
EM_INDEXED=1 EM_YAW=${EM_YAW:-0} EM_LEVELS="$OUT/levels.lua" \
  POKEPORT_DRIVER=$HOME/Documents/gen1recomp-modwork/tools/em_views_driver.lua \
  POKEPORT_IDENTITY=pokemon-love2d-rseqa POKEPORT_GAME=emerald SHOT_DIR="$OUT" \
  EM_CASES="$OUT/cases.lua" EM_WAIT=$WAIT /Applications/gen1recomp.app/Contents/MacOS/love . > "$OUT/run.log" 2>&1 &
G=$!
for _ in $(seq 1 $LIMIT); do kill -0 $G 2>/dev/null || break; sleep 1; done
if kill -0 $G 2>/dev/null; then kill $G; sleep 2; kill -9 $G 2>/dev/null; echo "WATCHDOG: stopped after ${LIMIT}s" >> "$OUT/run.log"; fi
wait $G 2>/dev/null
echo "shots $(ls "$OUT"/b*.png 2>/dev/null | wc -l | tr -d ' ') fallback $(grep -c fallback "$OUT/run.log") $(grep -q WATCHDOG "$OUT/run.log" && echo WATCHDOG)"
