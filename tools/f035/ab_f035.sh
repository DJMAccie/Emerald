#!/bin/bash
# ab_f035.sh <batch> <yaw> "MAP,x,y" ...   OLD (game lib) and NEW (f035 probe) captures, levels 4,6,7
# The G1/G2 A/B for task 14 (floating crowns and bush columns on rock, Route 112).
R=$HOME/Documents/Emerald
B=$1; YAW=$2; shift 2
OUT=$R/.autoloop/runs/f035/$B
mkdir -p "$OUT"
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
export QA_ZOOM=-2 QA_LIMIT=400 EM_DRIVER=$R/tools/em_ghost_driver.lua
# (gotcha: a QA identity whose options.lua was left at another zoom makes the two halves of an A/B
# incomparable - the driver prints `zoom` as fit scale + offset. Seed all four identities first.)
AS="$HOME/Library/Application Support"
for i in 1 2 3 4; do
  d="$AS/pokemon-love2d-rseqa-p$i"
  if [ -f "$d/options.lua" ]; then
    cp "$AS/pokemon-love2d-rseqa/options.lua" "$d/options.lua"
    sed -i '' 's/^  zoom = -\?[0-9]*,$/  zoom = -2,/' "$d/options.lua"
  fi
done
FILES="Gen3TreeStamps.lua Gen3Rock.lua Gen3Relief.lua"
PROBE=$R/tools/f035/probe
one(){ v=$1; spec=$2; yaw=$3
  IFS=, read m x y <<< "$spec"
  if [ "$v" = old ]; then src="$GAME"; else src="$PROBE"; fi
  QA_SRC="$src" "$R/tools/qa_tryp.sh" "$FILES" "$OUT/${v}_${m}_${x}_${y}_y${yaw}" "{'$m',$x,$y}" "4,6,7" "$yaw" 300 > "$OUT/${v}_${m}_${x}_${y}_y${yaw}.summary" 2>&1
  echo "$v $m $x $y yaw$yaw zoom $(grep -m1 'EM cam' "$OUT/${v}_${m}_${x}_${y}_y${yaw}/run.log" | awk '{print $8}')" >> "$OUT/zooms.txt"
}
export -f one; export OUT R GAME FILES PROBE YAW
for s in "$@"; do for v in ${VARIANTS:-old new}; do echo "$v $s $YAW"; done; done | xargs -P 3 -L1 bash -c 'one $0 $1 $2'
echo done > $OUT/ALLDONE
