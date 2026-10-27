#!/bin/bash
# base_ground.sh <label> [probe root|GAME]: walkable cells whose drawn base is not what groundAt reads, on the 53 outdoor spots (3 games at a time)
R=$HOME/Documents/Emerald; L=$1; P=${2:-GAME}
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
O=$R/.autoloop/runs/$L; mkdir -p $O; [ "$P" = GAME ] && P="$GAME"
export QA_ZOOM=-2 QA_LIMIT=400
one(){ b=$1
  QA_SRC="$P" EM_DRIVER="$R/tools/classd/base_ground_driver.lua" EM_MAPS="$O/maps_$b" EM_DUMP="$O/out_$b.txt" EM_DUMP_WAIT=200 \
    "$R/tools/qa_tryp.sh" "${FILES:-Gen3Scene.lua}" "$O/run_$b" - 4 0 60 > "$O/$b.summary" 2>&1
}
export -f one; export O R P
ls $O | sed -n 's/^maps_//p' | xargs -P 3 -I{} bash -c 'one {}'
echo done > $O/ALLDONE
