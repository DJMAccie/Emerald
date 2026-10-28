#!/bin/bash
# The ONE way to start a QA game run (shared by every agent).
#   tools/qa_run.sh <outdir> "{'MAP',x,y},..." [level=4] [yaw=0] [wait=60]
# level 4 = the player's camera, 7 = turned orbit, 6 = low near-ground camera.
#
# Runs go offscreen in the background and up to 3 run in parallel (slots,
# below); a watchdog stops a run that hangs. Batch many cases/levels into ONE
# call: each launch costs ~8 s of boot, each extra shot ~1 s. Stand on a walkable cell 1-2 rows below the
# thing you check, never on a door.
set -u
OUT=$1; CASES=$2; LEVEL=${3:-4}; YAW=${4:-0}; WAIT=${5:-60}
LOCK=/tmp/emerald-qa.lock
LIMIT=${QA_LIMIT:-360}          # seconds before the watchdog stops a run
mkdir -p "$OUT"; rm -f "$OUT"/*.png
# CASES "-" keeps an existing $OUT/cases.lua (tools/props/audit_capture.sh)
[ "$CASES" = "-" ] || echo "return {$CASES}" > "$OUT/cases.lua"
echo "return {$LEVEL}" > "$OUT/levels.lua"
# Concurrency: up to QA_SLOTS (default 3) runs at once, each holding one
# atomic mkdir slot /tmp/emerald-qa.slot.N. Background mode (offscreen, no
# Dock icon, no focus steal, windowed) made parallel instances safe; the old
# deadlock came from fullscreen instances fighting over the display.
# /tmp/emerald-qa.lock is now the EXCLUSIVE lock: tools/qa_try.sh takes it to
# swap test files into QA, and new runs wait while it is held. QA_HELD=1 means
# the caller holds it. Stale slots/locks (>10 min) are crashed holders.
SLOTS=${QA_SLOTS:-3}
stale(){ [ -n "$(find "$1" -maxdepth 0 -mmin +10 2>/dev/null)" ] && rm -rf "$1"; }
SLOT=
while [ -z "$SLOT" ]; do
  if [ -z "${QA_HELD:-}" ] && [ -d "$LOCK" ]; then stale "$LOCK"; sleep 2; continue; fi
  for i in $(seq 1 "$SLOTS"); do
    stale /tmp/emerald-qa.slot.$i
    if mkdir /tmp/emerald-qa.slot.$i 2>/dev/null; then SLOT=$i; break; fi
  done
  # an exclusive lock taken while we grabbed the slot wins: give it back
  if [ -n "$SLOT" ] && [ -z "${QA_HELD:-}" ] && [ -d "$LOCK" ]; then rmdir /tmp/emerald-qa.slot.$SLOT; SLOT=; fi
  [ -z "$SLOT" ] && sleep 2
done
echo "$$ $OUT" > /tmp/emerald-qa.slot.$SLOT/owner
trap 'rm -rf /tmp/emerald-qa.slot.$SLOT; [ -n "${SETUP:-}" ] && rmdir /tmp/emerald-qa.setup 2>/dev/null' EXIT
# A QA-identity game older than the watchdog limit + 60 s is hung (its own
# watchdog died with its wrapper): stop it. The user's own game (another
# identity) is never touched, and other agents' live runs are not waited on.
for p in $(pgrep -x love); do
  if ps eww -p $p 2>/dev/null | grep -q "POKEPORT_IDENTITY=pokemon-love2d-rseqa"; then
    age=$(ps -o etime= -p $p | awk -F'[-:]' '{s=0; for(i=1;i<=NF;i++) s=s*60+$i; print s}')
    if [ "${age:-0}" -gt $((LIMIT+60)) ]; then kill $p; sleep 2; kill -9 $p 2>/dev/null; echo "stopped hung QA game $p (${age}s)" >> "$OUT/run.log"; fi
  fi
done
# options.lua is shared: edit it under a short setup lock
until mkdir /tmp/emerald-qa.setup 2>/dev/null; do stale /tmp/emerald-qa.setup; sleep 1; done; SETUP=1
QI="$HOME/Library/Application Support/pokemon-love2d-rseqa"
# the QA identity's zoom drifts to -3 (shots from far away): reset it every run
# (QA_ZOOM=-2 matches the user's own game)
python3 - <<PY
import re
p="$QI/options.lua";s=open(p,'rb').read()
s=re.sub(rb"\n  zoom = -?\d+,",b"\n  zoom = ${QA_ZOOM:-0},",s,count=1)
s=re.sub(rb"fireredCamera = \d+,",b"fireredCamera = 4,",s,count=1)
# borderless = desktop fullscreen at boot, then the driver shrinks it: a
# full-screen flash per run. QA always boots windowed.
s=re.sub(rb'videoMode = "\w+",',b'videoMode = "windowed",',s,count=1)
open(p,'wb').write(s)
PY
# The old app shell boots the checkout only through the newest update payload
# in the identity's updates/ folder. Parallel boots raced its updater, which
# deleted it (runs then quit silently and the bare 0.1.50 app popped up), so:
# restore the newest payload every run, and boot one game at a time (the setup
# lock is held until this game has loaded its mods; shots still overlap).
U="$HOME/Library/Application Support/pokemon-love2d/updates"
NEW=$(ls -t "$U"/gen1recomp-*.love 2>/dev/null | head -1)
[ -n "$NEW" ] && { cmp -s "$NEW" "$QI/updates/$(basename "$NEW")" || cp "$NEW" "$QI/updates/"; }
# a sleeping display stalls every frame (no LÖVE window can present):
# declare user activity, which wakes it, for the length of the run
caffeinate -u -t $((LIMIT+30)) >/dev/null 2>&1 &
cd ~/Documents/gen1recomp || exit 1
EM_YAW=$YAW EM_LEVELS="$OUT/levels.lua" \
  POKEPORT_DRIVER=${EM_DRIVER:-$HOME/Documents/gen1recomp-modwork/tools/em_views_driver.lua} \
  SDL_MAC_BACKGROUND_APP=${QA_SDL_BG:-1} POKEPORT_BACKGROUND=${QA_BACKGROUND:-1} POKEPORT_IDENTITY=pokemon-love2d-rseqa POKEPORT_GAME=emerald SHOT_DIR="$OUT" \
  EM_CASES="$OUT/cases.lua" EM_WAIT=$WAIT /Applications/gen1recomp.app/Contents/MacOS/love . > "$OUT/run.log" 2>&1 &
G=$!
for _ in $(seq 1 60); do grep -q "loaded mod BATTLE_ART\|EM QA\]" "$OUT/run.log" 2>/dev/null && break; kill -0 $G 2>/dev/null || break; sleep 1; done
rmdir /tmp/emerald-qa.setup; SETUP=
for _ in $(seq 1 $LIMIT); do kill -0 $G 2>/dev/null || break; sleep 1; done
if kill -0 $G 2>/dev/null; then kill $G; sleep 2; kill -9 $G 2>/dev/null; echo "WATCHDOG: stopped after ${LIMIT}s" >> "$OUT/run.log"; fi
wait $G 2>/dev/null
echo "shots $(ls "$OUT"/*.png 2>/dev/null | wc -l | tr -d ' ')  fallback $(grep -c fallback "$OUT/run.log")  $(grep -c WATCHDOG "$OUT/run.log" | sed 's/^0$//;s/^1$/WATCHDOG/')"
