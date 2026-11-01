#!/bin/bash
# Battle capture: boots the QA identity, starts a wild battle through
# tools/drivers/em_battle_driver.lua and drops frames into $1.
#
#   tools/qa_battle.sh <outdir> [player_national] [foe_national] [frames]
#
# The driver itself is the capture (it owns the boot, the party and the
# battle), so this wrapper only does what every run needs: the QA identity
# guard, the windowed/zoom reset, the payload sync and the watchdog.
set -u
OUT=$1; PLAYER=${2:-252}; FOE=${3:-270}; FRAMES=${4:-760}
LOCK=/tmp/emerald-qa.lock
LIMIT=${QA_LIMIT:-420}
mkdir -p "$OUT"; rm -f "$OUT"/*.png
echo "$$ $OUT" > /tmp/emerald-qa.owner.$$
for p in $(pgrep -x love); do
  if ps eww -p $p 2>/dev/null | grep -q "POKEPORT_IDENTITY=pokemon-love2d-rseqa"; then
    age=$(ps -o etime= -p $p | awk -F'[-:]' '{s=0; for(i=1;i<=NF;i++) s=s*60+$i; print s}')
    if [ "${age:-0}" -gt $((LIMIT+60)) ]; then kill $p; sleep 2; kill -9 $p 2>/dev/null; echo "stopped hung QA game $p (${age}s)" >> "$OUT/run.log"; fi
  fi
done
until mkdir /tmp/emerald-qa.setup 2>/dev/null; do sleep 1; done
QI="$HOME/Library/Application Support/pokemon-love2d-rseqa"
python3 - <<PY
import re
p="$QI/options.lua";s=open(p,'rb').read()
s=re.sub(rb"\n  zoom = -?\d+,",b"\n  zoom = 0,",s,count=1)
s=re.sub(rb"fireredCamera = \d+,",b"fireredCamera = 4,",s,count=1)
s=re.sub(rb'videoMode = "\w+",',b'videoMode = "windowed",',s,count=1)
open(p,'wb').write(s)
PY
U="$HOME/Library/Application Support/pokemon-love2d/updates"
NEW=$(ls -t "$U"/gen1recomp-*.love 2>/dev/null | head -1)
[ -n "$NEW" ] && { cmp -s "$NEW" "$QI/updates/$(basename "$NEW")" || cp "$NEW" "$QI/updates/"; }
caffeinate -u -t $((LIMIT+30)) >/dev/null 2>&1 &
# Silence the run. SDL's dummy audio driver is the documented way to take the
# device away from a title that would otherwise open one; ALSOFT_DRIVERS=null
# is the same trick for OpenAL, which the log shows this build using.
export SDL_AUDIODRIVER=${SDL_AUDIODRIVER:-dummy}
export ALSOFT_DRIVERS=${ALSOFT_DRIVERS:-null}
cd ~/Documents/Emerald/gen1recomp || exit 1
EM_BATTLE_FRAMES=$FRAMES EM_PLAYER_SPECIES=$PLAYER EM_FOE_SPECIES=$FOE \
  POKEPORT_DRIVER=${EM_DRIVER:-$HOME/Documents/Emerald/tools/drivers/em_battle_driver.lua} \
  POKEPORT_IDENTITY=pokemon-love2d-rseqa POKEPORT_GAME=emerald SHOT_DIR="$OUT" \
  /Applications/gen1recomp.app/Contents/MacOS/love . > "$OUT/run.log" 2>&1 &
G=$!
for _ in $(seq 1 90); do grep -q "loaded mod BATTLE_ART\|\[BT\] startWild\|\[CAM\] startWild" "$OUT/run.log" 2>/dev/null && break; kill -0 $G 2>/dev/null || break; sleep 1; done
rmdir /tmp/emerald-qa.setup
for _ in $(seq 1 $LIMIT); do kill -0 $G 2>/dev/null || break; sleep 1; done
if kill -0 $G 2>/dev/null; then kill $G; sleep 2; kill -9 $G 2>/dev/null; echo "WATCHDOG: stopped after ${LIMIT}s" >> "$OUT/run.log"; fi
wait $G 2>/dev/null
rm -f /tmp/emerald-qa.owner.$$
echo "shots $(ls "$OUT"/*.png 2>/dev/null | wc -l | tr -d ' ')  fallback $(grep -c fallback "$OUT/run.log")  errors $(grep -ci 'error\|attempt to' "$OUT/run.log")"
