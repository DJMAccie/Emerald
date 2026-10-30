#!/bin/bash
# run_census_game.sh <label>   per-cell builder census (em_relief_driver) of maps_outdoor.txt on the INSTALLED game lib, 3 games at a time
# Result: allrocks/<label>/dump_{a..g}.txt, ALLDONE
S=$(cd "$(dirname "$0")" && pwd)
R=$HOME/Documents/Emerald
L=$1
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
mkdir -p $S/$L
export QA_ZOOM=-2 QA_LIMIT=400 QA_SRC="${PROBE:-$GAME}"
FILES="${FILES:-Gen3Rock.lua Gen3Mass.lua Gen3Relief.lua}"
one(){ b=$1
  cd $HOME/Documents/gen1recomp
  EM_DRIVER="$R/tools/${DRIVER:-em_relief_driver.lua}" EM_MAPS="$S/m_$b" EM_DUMP="$S/$L/dump_$b.txt" EM_DUMP_WAIT=300 \
    "$R/tools/qa_tryp.sh" "$FILES" "$S/$L/out_$b" - 4 0 60 > "$S/$L/summary_$b.txt" 2>&1
}
export -f one; export S L R FILES
printf '%s\n' ${BATCHES:-a b c d e f g h i j k l} | xargs -P 3 -I{} bash -c 'one {}; sleep 20'
echo done > $S/$L/ALLDONE2
