#!/bin/bash
# ab_cam.sh <label> <probe root> "<yaws>" [level=7]: L7 frames on the 53 outdoor spots, control (installed game) and probe, 3 games at a time.
# Frames: .autoloop/runs/<label>/<ctl|prb>_<yaw>_<batch>/b001.png.. (spot order of the batch's maps_ file)
R=$HOME/Documents/Emerald; L=$1; PROBE=$2; YAWS=$3; LV=${4:-7}
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
O=$R/.autoloop/runs/$L; mkdir -p $O
cp $R/.autoloop/runs/bg1/maps_* $O/ 2>/dev/null
export QA_ZOOM=-2 QA_LIMIT=400
one(){ v=$1; y=$2; b=$3
  if [ "$v" = ctl ]; then src="$GAME"; files=Gen3Scene.lua; else src="$PROBE"; files="${FILES:-Gen3Scene.lua}"; fi
  cases=$(awk '{printf "%s{\x27%s\x27,%s,%s}", (NR>1?",":""), $1,$2,$3}' $O/maps_$b)
  QA_SRC="$src" EM_DRIVER=$R/tools/em_ghost_driver.lua EM_INDEXED=1 \
    "$R/tools/qa_tryp.sh" "$files" "$O/${v}_${y}_$b" "$cases" "$LV" $y 250 > "$O/${v}_${y}_$b.summary" 2>&1
}
export -f one; export O R PROBE GAME LV FILES
for y in $YAWS; do for v in ${VARIANTS:-ctl prb}; do for f in $O/maps_*; do echo "$v $y ${f##*maps_}"; done; done; done | xargs -P 3 -L1 bash -c 'one $0 $1 $2'
echo done > $O/ALLDONE
