#!/bin/bash
# cmp.sh <cmpdir> <NOWdir> <PROBEdir> <specfile>  sheets: 2D | NOW | PROBE (rows L4/L6/L7)
C=$1; N=$2; P=$3; S=$4; mkdir -p $C
while IFS=, read m x y; do
  ln -sfn $N/game_${m}_${x}_${y} $C/now_${m}_${x}_${y}; ln -sfn $P/game_${m}_${x}_${y} $C/new_${m}_${x}_${y}
  VARS=now,new python3 $HOME/Documents/Emerald/tools/relief/stage3/ab/ab_sheet.py $C $C/sheets ${m},${x},${y} >/dev/null
  python3 -c "from PIL import Image;f='$C/sheets/AB_${m}_${x}_${y}.png';Image.open(f).crop((0,0,1920,1080)).save(f)"
done < $S
