#!/bin/bash
# QA capture at the player's camera (level 4, zoom 0) on the QA identity.
#   tools/buildings/qa_capture.sh <outdir> "{'EM_SLATEPORT_CITY',28,40},{'EM_ROUTE104',17,52}"
# Each case is {MAP, x, y}: the player stands there, facing down. Pick a WALKABLE
# cell 1-2 rows below the building's door (standing on a door cell warps/fails).
# Waits for any running game to exit first (only one instance may run).
set -u
OUT=$1; CASES=$2
mkdir -p "$OUT"; rm -f "$OUT"/*.png
QI="$HOME/Library/Application Support/pokemon-love2d-rseqa"
echo "return {$CASES}" > "$OUT/cases.lua"
printf "return {4}\n" > "$OUT/levels.lua"
for try in 1 2 3 4 5 6; do
  while pgrep -f "MacOS/love" >/dev/null; do sleep 5; done; sleep 3
  pgrep -f "MacOS/love" >/dev/null && continue
  # the QA identity's zoom drifts to -3 (shots from far away): reset it every run
  python3 - <<PY
import re
p="$QI/options.lua";s=open(p,'rb').read()
s=re.sub(rb"\n  zoom = -?\d+,",b"\n  zoom = 0,",s,count=1)
s=re.sub(rb"fireredCamera = \d+,",b"fireredCamera = 4,",s,count=1)
open(p,'wb').write(s)
PY
  cd ~/Documents/gen1recomp && EM_LEVELS="$OUT/levels.lua" \
    POKEPORT_DRIVER=$HOME/Documents/gen1recomp-modwork/tools/em_views_driver.lua \
    POKEPORT_IDENTITY=pokemon-love2d-rseqa POKEPORT_GAME=emerald SHOT_DIR="$OUT" \
    EM_CASES="$OUT/cases.lua" EM_WAIT=60 /Applications/gen1recomp.app/Contents/MacOS/love . > "$OUT/run.log" 2>&1
  break
done
echo "shots $(ls "$OUT"/*.png 2>/dev/null | wc -l)  fallback $(grep -c fallback "$OUT/run.log")"
