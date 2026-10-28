#!/bin/bash
# Try source files in a PRIVATE QA copy, so tries run in parallel:
#   tools/qa_tryp.sh "Gen3Elevation.lua TerrainLevels.lua" <outdir> "<cases>" [level=4] [yaw=0] [wait=60]
# A file name with a slash is taken from the mod root instead of lib/:
#   tools/qa_tryp.sh "BuildingVoxels.lua data/buildings/littleroot_house_brendan.lua" ...
# Same arguments and output as tools/qa_try.sh, but it never takes the
# exclusive lock /tmp/emerald-qa.lock and never writes into the one QA copy.
# It uses its own copy of the QA folder (identity pokemon-love2d-rseqa-p1..p4,
# next to the main one in Application Support; APFS clones, little disk):
#   1. takes a free copy (/tmp/emerald-qa.pcopy.N, held by a live pid);
#   2. makes the copy's mods/ equal to main QA's mods/ - leaving out the lib
#      files a running qa_try.sh has swapped into main QA at that moment (read
#      from the lock owner's command line), so no other agent's test file is
#      ever picked up; a file it cannot get clean yet makes it wait;
#   3. puts the named lib files from the mod source into the copy;
#   4. waits until fewer than 4 QA games run (qa_run.sh slots + private runs,
#      counted under /tmp/emerald-qa.setup), then boots with that identity,
#      boot serialised under the setup lock exactly as qa_run.sh does.
# Nothing is ever copied back into main QA or the real game.
# The cap of 4 is checked when a private run starts; qa_run.sh does not count
# private runs, so read-only runs starting later can briefly push the total over.
# QA_LIMIT is capped at 400 s: qa_run.sh's reaper stops any QA game older than
# its own limit + 60 s (420 s by default). Split longer jobs into several calls.
# The copies can be deleted whenever no qa_tryp.sh is running.
set -u
FILES=$1; OUT=$2; CASES=$3; LEVEL=${4:-4}; YAW=${5:-0}; WAIT=${6:-60}
LOCK=/tmp/emerald-qa.lock
AS="$HOME/Library/Application Support"
MAIN="$AS/pokemon-love2d-rseqa"
# QA_SRC: take the named files from this tree instead of the mod source (a QA-only probe build)
M=${QA_SRC:-$HOME/Documents/battle-art-notquiteog}
LIMIT=${QA_LIMIT:-360}; [ "$LIMIT" -gt 400 ] && LIMIT=400
COPIES=4; GAMES=4
# a bare name is a lib file; a name with a slash is a path under the mod root
# (e.g. data/buildings/littleroot_house_brendan.lua)
rel(){ case "$1" in */*) echo "$1";; *) echo "lib/$1";; esac; }
for f in $FILES; do [ -f "$M/$(rel "$f")" ] || { echo "no such source file: $(rel "$f")"; exit 2; }; done
mkdir -p "$OUT"; rm -f "$OUT"/*.png
[ "$CASES" = "-" ] || echo "return {$CASES}" > "$OUT/cases.lua"
echo "return {$LEVEL}" > "$OUT/levels.lua"
stale(){ [ -n "$(find "$1" -maxdepth 0 -mmin +10 2>/dev/null)" ] && rm -rf "$1"; }
alive(){ [ -n "$1" ] && kill -0 "$1" 2>/dev/null; }
N=; SETUP=; G=
cleanup(){
  [ -n "$G" ] && kill "$G" 2>/dev/null
  [ -n "$SETUP" ] && rmdir /tmp/emerald-qa.setup 2>/dev/null
  [ -n "$N" ] && rm -rf /tmp/emerald-qa.prun.$N /tmp/emerald-qa.pcopy.$N
}
trap cleanup EXIT
trap 'exit 143' TERM INT
# 1. a private copy; a holder whose pid is gone has crashed
while [ -z "$N" ]; do
  for i in $(seq 1 $COPIES); do
    d=/tmp/emerald-qa.pcopy.$i
    if [ -d "$d" ] && ! alive "$(cat "$d/pid" 2>/dev/null)"; then sleep 1; alive "$(cat "$d/pid" 2>/dev/null)" || rm -rf "$d" /tmp/emerald-qa.prun.$i; fi
    if mkdir "$d" 2>/dev/null; then echo $$ > "$d/pid"; N=$i; break; fi
  done
  [ -z "$N" ] && sleep 2
done
ID=pokemon-love2d-rseqa-p$N
QI="$AS/$ID"
# a game still running on this copy is an orphan of a crashed try
for p in $(pgrep -x love); do ps eww -p $p 2>/dev/null | grep -q "POKEPORT_IDENTITY=$ID\( \|$\)" && { kill $p; sleep 1; kill -9 $p 2>/dev/null; }; done
# 2. main QA's current mods, minus what a qa_try.sh holds swapped in.
# holder: "pid file file ..." of the exclusive lock's owner, "" when free,
# "?" while it cannot be read yet (lock just taken, or just released).
holder(){
  [ -d "$LOCK" ] || { echo ""; return; }
  local p; p=$(awk '{print $1; exit}' "$LOCK/owner" 2>/dev/null)
  [ -n "$p" ] || { echo "?"; return; }
  # an owner that is gone crashed without restoring: as qa_run.sh does once
  # the lock is stale, carry on as if it were free
  alive "$p" || { sleep 2; [ "$(awk '{print $1; exit}' "$LOCK/owner" 2>/dev/null)" = "$p" ] && echo "" || echo "?"; return; }
  echo "$p $(ps -o args= -p "$p" | awk '{on=0; for(i=1;i<=NF;i++){ if(on){ if($i ~ /^[\/~.]/) break; printf "%s ", $i } else if($i ~ /qa_try\.sh$/) on=1 }}')"
}
has(){ case " $2 " in *" $1 "*) return 0;; esac; return 1; }
NEW=; [ -d "$QI" ] || NEW=1
DIRTY=$(cat "$QI/.tryp_swapped" 2>/dev/null)     # this copy's test files of last time
while :; do
  H=$(holder); [ "$H" = "?" ] && { sleep 1; continue; }
  HP=${H%% *}; HF=${H#* }; [ -z "$H" ] && HF=
  wait_for=
  for f in $DIRTY; do has "$f" "$FILES" || { has "$f" "$HF" && wait_for=$f; }; done
  [ -n "$wait_for" ] && { sleep 3; continue; }
  if [ -n "$NEW" ]; then
    rm -rf "$QI" "$QI.tmp"; cp -Rc "$MAIN" "$QI.tmp" 2>/dev/null || cp -R "$MAIN" "$QI.tmp"; mv "$QI.tmp" "$QI"
    DIRTY="$DIRTY $HF"                              # cloned with them in: not clean yet
  else
    EX=(); for f in $HF; do EX+=(--exclude "/BATTLE_ART_VOXEL_FORK/lib/$f"); done
    rsync -a --delete ${EX[@]+"${EX[@]}"} "$MAIN/mods/" "$QI/mods/"
  fi
  H2=$(holder)
  if [ "$H2" = "$H" ]; then
    if [ -n "$NEW" ]; then NEW=; [ -n "$HF" ] && continue; fi   # a clone made beside a holder: sync again once its files are free
    break
  fi
  # the lock changed hands while copying: the new holder's files may be test files
  [ "$H2" != "?" ] && [ -n "$H2" ] && DIRTY="$DIRTY ${H2#* }"
  NEW=
done
# 3. the files under test
echo "$FILES" > "$QI/.tryp_swapped"
for f in $FILES; do mkdir -p "$(dirname "$QI/mods/BATTLE_ART_VOXEL_FORK/$(rel "$f")")"; cp "$M/$(rel "$f")" "$QI/mods/BATTLE_ART_VOXEL_FORK/$(rel "$f")"; done
# 4. room for one more game, then boot under the setup lock
while :; do
  until mkdir /tmp/emerald-qa.setup 2>/dev/null; do stale /tmp/emerald-qa.setup; sleep 1; done; SETUP=1
  n=$(ls -d /tmp/emerald-qa.slot.* /tmp/emerald-qa.prun.* 2>/dev/null | wc -l)
  [ "$n" -lt $GAMES ] && break
  rmdir /tmp/emerald-qa.setup; SETUP=; sleep 3
done
mkdir /tmp/emerald-qa.prun.$N
# the copy takes main QA's options (camera, props, light) as they stand; QA_ZOOM as in qa_run.sh
cp "$MAIN/options.lua" "$QI/options.lua"
QI="$QI" QZ="${QA_ZOOM:-0}" python3 - <<'PY'
import os,re
p=os.environ["QI"]+"/options.lua";s=open(p,'rb').read()
s=re.sub(rb"\n  zoom = -?\d+,",b"\n  zoom = "+os.environ["QZ"].encode()+b",",s,count=1)
s=re.sub(rb"fireredCamera = \d+,",b"fireredCamera = 4,",s,count=1)
s=re.sub(rb'videoMode = "\w+",',b'videoMode = "windowed",',s,count=1)
open(p,'wb').write(s)
PY
U="$AS/pokemon-love2d/updates"
PAY=$(ls -t "$U"/gen1recomp-*.love 2>/dev/null | head -1)
[ -n "$PAY" ] && { mkdir -p "$QI/updates"; cmp -s "$PAY" "$QI/updates/$(basename "$PAY")" || cp "$PAY" "$QI/updates/"; }
caffeinate -u -t $((LIMIT+30)) >/dev/null 2>&1 &
cd ~/Documents/gen1recomp || exit 1
echo "[qa_tryp] identity $ID files $FILES" > "$OUT/run.log"
EM_YAW=$YAW EM_LEVELS="$OUT/levels.lua" \
  POKEPORT_DRIVER=${EM_DRIVER:-$HOME/Documents/gen1recomp-modwork/tools/em_views_driver.lua} \
  SDL_MAC_BACKGROUND_APP=${QA_SDL_BG:-1} POKEPORT_BACKGROUND=${QA_BACKGROUND:-1} POKEPORT_IDENTITY=$ID POKEPORT_GAME=emerald SHOT_DIR="$OUT" \
  EM_CASES="$OUT/cases.lua" EM_WAIT=$WAIT /Applications/gen1recomp.app/Contents/MacOS/love . >> "$OUT/run.log" 2>&1 &
G=$!
for _ in $(seq 1 60); do grep -q "loaded mod BATTLE_ART\|EM QA\]" "$OUT/run.log" 2>/dev/null && break; kill -0 $G 2>/dev/null || break; sleep 1; done
rmdir /tmp/emerald-qa.setup; SETUP=
for _ in $(seq 1 $LIMIT); do kill -0 $G 2>/dev/null || break; sleep 1; done
if kill -0 $G 2>/dev/null; then kill $G; sleep 2; kill -9 $G 2>/dev/null; echo "WATCHDOG: stopped after ${LIMIT}s" >> "$OUT/run.log"; fi
wait $G 2>/dev/null; G=
echo "shots $(ls "$OUT"/*.png 2>/dev/null | wc -l | tr -d ' ')  fallback $(grep -c fallback "$OUT/run.log")  $(grep -c WATCHDOG "$OUT/run.log" | sed 's/^0$//;s/^1$/WATCHDOG/')  ($ID)"
