#!/bin/bash
# run.sh <label>   stair census of maps_all.txt on the INSTALLED game lib (3 games at a time) -> <label>/dump_<b>.txt
S=$(cd "$(dirname "$0")" && pwd); R=$HOME/Documents/Emerald; L=$1
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
mkdir -p $S/$L
export QA_ZOOM=-2 QA_LIMIT=400 QA_SRC="${PROBE:-$GAME}"
one(){ b=$1; cd $HOME/Documents/gen1recomp
  EM_DRIVER="$S/em_stairs_census_driver.lua" EM_MAPS="$S/m_$b" EM_DUMP="$S/$L/dump_$b.txt" EM_DUMP_WAIT=120 \
    "$R/tools/qa_tryp.sh" "Gen3Scene.lua" "$S/$L/out_$b" - 4 0 60 > "$S/$L/summary_$b.txt" 2>&1; }
export -f one; export S L R
printf '%s\n' ${BATCHES:-$(ls $S/m_* | sed "s#.*/m_##" | tr "\n" " ")} | xargs -P 3 -I{} bash -c 'one {}; sleep 10'
echo done > $S/$L/ALLDONE
