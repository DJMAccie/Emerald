#!/bin/bash
# gate14.sh [label]   Task 14 (G1+G2, Route 112's general trees) gates in one batch, 3 QA games at a time.
#   capture  A/B frames (old = game lib, new = probe): Route 112 28,25 / 26,25 / 30,28, levels 4,6,7
#   geodump  full-map Route 112 geometry + cells: game lib (old) and probe (new), the new one twice for determinism
#   cells    whole-map cell dumps of the control maps (Mt Chimney, Jagged Pass, Lavaridge, Route 111/113)
#   float    Gen3Rock float audit on the family maps, game lib vs probe
# All output under .autoloop/runs/f035/<label>/.
set -u
R=$HOME/Documents/Emerald
L=${1:-g14}
O=$R/.autoloop/runs/f035/$L
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
PROBE=$R/tools/f035/probe
FILES="Gen3TreeStamps.lua Gen3Rock.lua Gen3Relief.lua"
mkdir -p "$O"
export QA_ZOOM=-2 QA_LIMIT=400 R O GAME PROBE FILES
AS="$HOME/Library/Application Support"
# (an identity left at another zoom makes the two halves of an A/B incomparable)
for i in 1 2 3 4; do
  d="$AS/pokemon-love2d-rseqa-p$i"
  if [ -f "$d/options.lua" ]; then
    cp "$AS/pokemon-love2d-rseqa/options.lua" "$d/options.lua"
    sed -i '' 's/^  zoom = -\?[0-9]*,$/  zoom = -2,/' "$d/options.lua"
  fi
done
cp "$R/.autoloop/runs/f035/maps112.txt" "$O/route112_maps.txt"
printf 'EM_MT_CHIMNEY 22 20\nEM_JAGGED_PASS 15 21\nEM_LAVARIDGE_TOWN 10 12\nEM_ROUTE111 21 62\nEM_ROUTE113 44 7\n' > "$O/ctl_maps.txt"
printf 'EM_ROUTE112 10 30\nEM_MT_CHIMNEY 22 20\nEM_JAGGED_PASS 15 21\nEM_LAVARIDGE_TOWN 10 12\nEM_ROUTE111 21 62\nEM_ROUTE113 44 7\n' > "$O/float_maps.txt"
one(){ mode=$1; v=$2; arg=$3
  local src
  if [ "$v" = old ] || [ "$v" = control ]; then src=$GAME; else src=$PROBE; fi
  case $mode in
   capture)
    local m x y; IFS=, read m x y <<< "$arg"
    QA_SRC=$src EM_DRIVER=$R/tools/em_ghost_driver.lua EM_LEVELS=4,6,7 EM_WAIT=300 \
      "$R/tools/qa_tryp.sh" "$FILES" "$O/${v}_${m}_${x}_${y}" "{'$m',$x,$y}" "4,6,7" 0.8 300 > "$O/${v}_${m}_${x}_${y}.summary" 2>&1
    echo "$v $m $x $y zoom $(grep -m1 'EM cam' "$O/${v}_${m}_${x}_${y}/run.log" | awk '{print $8}')" >> "$O/zooms.txt"
    ;;
   geodump)
    mkdir -p "$O/geo_$v"
    QA_SRC=$src EM_DRIVER="$R/tools/autoloop/em_geo_driver.lua" EM_MAPS="$O/route112_maps.txt" EM_GEO_DIR="$O/geo_$v" \
      "$R/tools/qa_tryp.sh" "$FILES" "$O/out_geo_$v" - 4 0 200 > "$O/geo_$v.summary" 2>&1
    ;;
   cells)
    QA_SRC=$src EM_DRIVER="$R/tools/em_cells_driver.lua" EM_MAPS="$O/ctl_maps.txt" EM_DUMP="$O/cells_$v.txt" EM_DUMP_WAIT=300 \
      "$R/tools/qa_tryp.sh" "$FILES" "$O/out_cells_$v" - 4 0 60 > "$O/cells_$v.summary" 2>&1
    ;;
   float)
    QA_SRC=$src EM_DRIVER="$R/tools/em_float_driver.lua" EM_MAPS="$O/float_maps.txt" EM_FLOAT_WAIT=240 \
      "$R/tools/qa_tryp.sh" "$FILES" "$O/out_float_$v" - 4 0 60 > "$O/float_$v.summary" 2>&1
    grep -h "^\[RK1 float\]\|^\[EM float\]" "$O/out_float_$v/run.log" 2>/dev/null | sort -u > "$O/float_$v.txt"
    ;;
  esac
}
export -f one
{
 echo "capture old EM_ROUTE112,28,25"
 echo "capture new EM_ROUTE112,28,25"
 echo "capture old EM_ROUTE112,26,25"
 echo "capture new EM_ROUTE112,26,25"
 echo "capture old EM_ROUTE112,30,28"
 echo "capture new EM_ROUTE112,30,28"
 echo "geodump old x"
 echo "geodump new x"
 echo "geodump new2 x"
 echo "cells old x"
 echo "cells new x"
 echo "float control x"
 echo "float probe x"
} > "$O/jobs.txt"
cat "$O/jobs.txt" | xargs -P 3 -L1 bash -c 'one $0 $1 $2' > "$O/jobs.log" 2>&1
echo done > "$O/ALLDONE"
