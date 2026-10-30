#!/bin/bash
# clean_try.sh <outdir> "<cases>" <levels> [yaw] [wait] [frames]
# Boots a private QA copy with the CLEAN rewrite mod (~/Documents/emerald3d) installed as EMERALD_3D and the old
# BATTLE_ART_VOXEL_FORK removed. Same private-copy machinery as tools/qa_tryp.sh (identities pokemon-love2d-rseqa-pN,
# never touches the main QA copy or the real game). The pipeline is switched on in the copy's options.lua.
# Env: QA_DRIVER  driver (default tools/rewrite/probe/p0_driver.lua), QA_ZOOM zoom, QA_LIMIT seconds,
#      plus whatever the driver reads (EM_MAPS, EM_GEO_DIR …).
set -u
OUT=$1; CASES=$2; LEVELS=${3:-4}; YAW=${4:-0}; WAIT=${5:-120}
R=$HOME/Documents/Emerald
SRC=${QA_SRC:-$HOME/Documents/emerald3d}
AS="$HOME/Library/Application Support"; MAIN="$AS/pokemon-love2d-rseqa"
LIMIT=${QA_LIMIT:-360}; [ "$LIMIT" -gt 400 ] && LIMIT=400
COPIES=4; GAMES=4
mkdir -p "$OUT"; rm -f "$OUT"/*.png
[ "$CASES" = "-" ] || echo "return {$CASES}" > "$OUT/cases.lua"
echo "return {$LEVELS}" > "$OUT/levels.lua"
stale(){ [ -n "$(find "$1" -maxdepth 0 -mmin +10 2>/dev/null)" ] && rm -rf "$1"; }
alive(){ [ -n "$1" ] && kill -0 "$1" 2>/dev/null; }
N=; SETUP=; G=
cleanup(){ [ -n "$G" ] && kill "$G" 2>/dev/null; [ -n "$SETUP" ] && rmdir /tmp/emerald-qa.setup 2>/dev/null
  [ -n "$N" ] && rm -rf /tmp/emerald-qa.prun.$N /tmp/emerald-qa.pcopy.$N; }
trap cleanup EXIT; trap 'exit 143' TERM INT
[ -d "$SRC" ] || { echo "no clean tree at $SRC" >&2; exit 2; }
[ -f "$SRC/manifest.json" ] || { echo "no manifest.json in $SRC" >&2; exit 2; }
while [ -z "$N" ]; do
  for i in $(seq 1 $COPIES); do
    d=/tmp/emerald-qa.pcopy.$i
    if [ -d "$d" ] && ! alive "$(cat "$d/pid" 2>/dev/null)"; then sleep 1; alive "$(cat "$d/pid" 2>/dev/null)" || rm -rf "$d" /tmp/emerald-qa.prun.$i; fi
    if mkdir "$d" 2>/dev/null; then echo $$ > "$d/pid"; N=$i; break; fi
  done
  [ -z "$N" ] && sleep 2
done
ID=pokemon-love2d-rseqa-p$N; QI="$AS/$ID"
for p in $(pgrep -x love); do ps eww -p $p 2>/dev/null | grep -q "POKEPORT_IDENTITY=$ID\( \|$\)" && { kill $p; sleep 1; kill -9 $p 2>/dev/null; }; done
# first use of this identity clones main QA; later runs refresh only the mods (fast)
if [ ! -d "$QI" ]; then
  rm -rf "$QI.tmp"; cp -Rc "$MAIN" "$QI.tmp" 2>/dev/null || cp -R "$MAIN" "$QI.tmp"
  mv "$QI.tmp" "$QI"
fi
rm -rf "$QI/mods/BATTLE_ART_VOXEL_FORK"
mkdir -p "$QI/mods/EMERALD_3D"
rsync -a --delete --exclude '.git/' --exclude 'docs/' "$SRC/" "$QI/mods/EMERALD_3D/"
cp "$MAIN/options.lua" "$QI/options.lua"
QI="$QI" QZ="${QA_ZOOM:-0}" CL="${CLEAN_LEVEL:-1}" python3 - <<'PY'
import os,re
p=os.environ["QI"]+"/options.lua";s=open(p,'rb').read()
s=re.sub(rb"\n  zoom = -?\d+,",b"\n  zoom = "+os.environ["QZ"].encode()+b",",s,count=1)
s=re.sub(rb'videoMode = "\w+",',b'videoMode = "windowed",',s,count=1)
s=re.sub(rb"pipelines = \{[^}]*\},",b"pipelines = { emerald3d = "+os.environ["CL"].encode()+b" },",s,count=1)
s=re.sub(rb"\n  tilt = \d+,",b"\n  tilt = 0,",s,count=1)
s=re.sub(rb"tiltshift = \d+,",b"tiltshift = 0,",s,count=1)
open(p,'wb').write(s)
PY
U="$AS/pokemon-love2d/updates"
PAY=$(ls -t "$U"/gen1recomp-*.love 2>/dev/null | head -1)
[ -n "$PAY" ] && { mkdir -p "$QI/updates"; cmp -s "$PAY" "$QI/updates/$(basename "$PAY")" || cp "$PAY" "$QI/updates/"; }
caffeinate -u -t $((LIMIT+30)) >/dev/null 2>&1 &
while :; do
  until mkdir /tmp/emerald-qa.setup 2>/dev/null; do stale /tmp/emerald-qa.setup; sleep 1; done; SETUP=1
  n=$(ls -d /tmp/emerald-qa.slot.* /tmp/emerald-qa.prun.* 2>/dev/null | wc -l)
  [ "$n" -lt $GAMES ] && break
  rmdir /tmp/emerald-qa.setup; SETUP=; sleep 3
done
mkdir /tmp/emerald-qa.prun.$N
cd ~/Documents/gen1recomp || exit 1
echo "[clean_try] $ID driver ${QA_DRIVER:-$R/tools/rewrite/probe/p0_driver.lua}" > "$OUT/run.log"
EM_YAW=$YAW EM_LEVELS="$OUT/levels.lua" EM_CASES="$OUT/cases.lua" EM_WAIT="$WAIT" \
  POKEPORT_DRIVER=${QA_DRIVER:-$R/tools/rewrite/probe/p0_driver.lua} \
  SDL_MAC_BACKGROUND_APP=${QA_SDL_BG:-1} POKEPORT_BACKGROUND=${QA_BACKGROUND:-1} POKEPORT_IDENTITY=$ID POKEPORT_GAME=emerald SHOT_DIR="$OUT" \
  /Applications/gen1recomp.app/Contents/MacOS/love . >> "$OUT/run.log" 2>&1 &
G=$!
n=0
while kill -0 $G 2>/dev/null && [ $n -lt $((LIMIT*10)) ]; do sleep 0.1; n=$((n+1)); done
if kill -0 $G 2>/dev/null; then kill $G 2>/dev/null; sleep 1; kill -9 $G 2>/dev/null; echo "WATCHDOG: stopped after ${LIMIT}s" >> "$OUT/run.log"; fi
wait $G 2>/dev/null
echo "shots $(ls "$OUT"/*.png 2>/dev/null | wc -l | tr -d ' ')  fallback $(grep -c 'fallback' "$OUT/run.log")    ($ID)"
