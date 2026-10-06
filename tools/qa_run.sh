#!/bin/bash
# The ONE way to start a QA game run (shared by every agent).
#   tools/qa_run.sh <outdir> "{'MAP',x,y},..." [level=4] [yaw=0] [wait=60]
# level 4 = the player's camera, 7 = turned orbit, 6 = low near-ground camera.
#
# Two game instances started at the same moment deadlock each other, so a
# wait loop is not enough: an atomic mkdir lock serialises every run, and a
# watchdog stops a run that hangs. Stand on a walkable cell 1-2 rows below the
# thing you check, never on a door.
set -u
OUT=$1; CASES=$2; LEVEL=${3:-4}; YAW=${4:-0}; WAIT=${5:-60}
LOCK=/tmp/emerald-qa.lock
LIMIT=${QA_LIMIT:-360}          # seconds before the watchdog stops a run
mkdir -p "$OUT"; rm -f "$OUT"/*.png
echo "return {$CASES}" > "$OUT/cases.lua"
echo "return {$LEVEL}" > "$OUT/levels.lua"
# take the lock (a lock older than 10 minutes is a crashed holder: break it)
# QA_HELD=1: the caller already holds the lock (tools/qa_try.sh swaps test
# files into QA inside it)
if [ -z "${QA_HELD:-}" ]; then
  until mkdir "$LOCK" 2>/dev/null; do
    if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +10 2>/dev/null)" ]; then rm -rf "$LOCK"; continue; fi
    sleep 3
  done
  echo "$$ $OUT" > "$LOCK/owner"
  trap 'rm -rf "$LOCK"' EXIT
fi
# games started outside the lock still count. A QA-identity game older than
# the watchdog limit + 60 s is hung (its own watchdog died with its wrapper):
# stop it. The user's own game (another identity) is never touched.
while pgrep -x love >/dev/null; do
  for p in $(pgrep -x love); do
    if ps eww -p $p 2>/dev/null | grep -q "POKEPORT_IDENTITY=pokemon-love2d-rseqa"; then
      age=$(ps -o etime= -p $p | awk -F'[-:]' '{s=0; for(i=1;i<=NF;i++) s=s*60+$i; print s}')
      if [ "${age:-0}" -gt $((LIMIT+60)) ]; then kill $p; sleep 2; kill -9 $p 2>/dev/null; echo "stopped hung QA game $p (${age}s)" >> "$OUT/run.log"; fi
    fi
  done
  sleep 3
done
QI="$HOME/Library/Application Support/pokemon-love2d-rseqa"
# the QA identity's zoom drifts to -3 (shots from far away): reset it every run
python3 - <<PY
import re
p="$QI/options.lua";s=open(p,'rb').read()
s=re.sub(rb"\n  zoom = -?\d+,",b"\n  zoom = 0,",s,count=1)
s=re.sub(rb"fireredCamera = \d+,",b"fireredCamera = 4,",s,count=1)
open(p,'wb').write(s)
PY
# a sleeping display stalls every frame (no LÖVE window can present):
# declare user activity, which wakes it, for the length of the run
caffeinate -u -t $((LIMIT+30)) >/dev/null 2>&1 &
cd ~/Documents/gen1recomp || exit 1
EM_YAW=$YAW EM_LEVELS="$OUT/levels.lua" \
  POKEPORT_DRIVER=$HOME/Documents/gen1recomp-modwork/tools/em_views_driver.lua \
  POKEPORT_IDENTITY=pokemon-love2d-rseqa POKEPORT_GAME=emerald SHOT_DIR="$OUT" \
  EM_CASES="$OUT/cases.lua" EM_WAIT=$WAIT /Applications/gen1recomp.app/Contents/MacOS/love . > "$OUT/run.log" 2>&1 &
G=$!
for _ in $(seq 1 $LIMIT); do kill -0 $G 2>/dev/null || break; sleep 1; done
if kill -0 $G 2>/dev/null; then kill $G; sleep 2; kill -9 $G 2>/dev/null; echo "WATCHDOG: stopped after ${LIMIT}s" >> "$OUT/run.log"; fi
wait $G 2>/dev/null
echo "shots $(ls "$OUT"/*.png 2>/dev/null | wc -l | tr -d ' ')  fallback $(grep -c fallback "$OUT/run.log")  $(grep -c WATCHDOG "$OUT/run.log" | sed 's/^0$//;s/^1$/WATCHDOG/')"
