#!/bin/bash
# Capture every case in OUTDIR/cases.lua at the player's camera (QA identity), indexed bNNN.png.
# Waits for any running game first (one instance only).
set -u
OUT=$1
QI="$HOME/Library/Application Support/pokemon-love2d-rseqa"
rm -f "$OUT"/b*.png
printf "return {4}\n" > "$OUT/levels.lua"
# [M] keeps this pgrep from matching shells whose command line quotes the pattern
while pgrep -f "[M]acOS/love \\." >/dev/null; do sleep 5; done; sleep 3
python3 - <<PY
import re
p="$QI/options.lua";s=open(p,'rb').read()
s=re.sub(rb"\n  zoom = -?\d+,",b"\n  zoom = 0,",s,count=1)
s=re.sub(rb"fireredCamera = \d+,",b"fireredCamera = 4,",s,count=1)
open(p,'wb').write(s)
PY
cd ~/Documents/gen1recomp && EM_INDEXED=1 EM_LEVELS="$OUT/levels.lua" \
  POKEPORT_DRIVER=$HOME/Documents/gen1recomp-modwork/tools/em_views_driver.lua \
  POKEPORT_IDENTITY=pokemon-love2d-rseqa POKEPORT_GAME=emerald SHOT_DIR="$OUT" \
  EM_CASES="$OUT/cases.lua" EM_WAIT=${EM_WAIT:-40} /Applications/gen1recomp.app/Contents/MacOS/love . > "$OUT/run.log" 2>&1
echo "shots $(ls "$OUT"/b*.png 2>/dev/null | wc -l) fallback $(grep -c fallback "$OUT/run.log")"
