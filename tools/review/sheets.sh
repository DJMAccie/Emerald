#!/bin/bash
# sheets.sh <batchdir> <specfile>  one old-vs-game sheet per spot -> <batchdir>/sheets/AB_<MAP>_<x>_<y>.png (cols 2D | OLD census | NOW game)
B=$1; S=$2; R=$HOME/Documents/Emerald
mkdir -p $B/sheets
while IFS=, read m x y; do
  [ -f $B/sheets/AB_${m}_${x}_${y}.png ] && [ -z "$FORCE" ] && continue
  ls $B/game_${m}_${x}_${y}/*_7.png >/dev/null 2>&1 || continue
  [ -e $B/old_${m}_${x}_${y} ] || ln -s $R/docs/rock-gates/general-rollout/allrocks1/old_${m}_${x}_${y} $B/old_${m}_${x}_${y}
  VARS=old,game python3 $R/tools/relief/stage3/ab/ab_sheet.py $B $B/sheets ${m},${x},${y} >/dev/null
  python3 -c "from PIL import Image;f='$B/sheets/AB_${m}_${x}_${y}.png';Image.open(f).crop((0,0,1920,1080)).save(f)"
done < $S
ls $B/sheets/AB_*.png | wc -l
