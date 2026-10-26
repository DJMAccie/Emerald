#!/bin/bash
# run_census.sh <label>   per-cell builder census (em_relief_driver) of the cave maps (m_a..) on the game lib or PROBE tree
# env: PROBE (QA_SRC), FILES, BATCHES, PAR (default 2), DUMP_WAIT; result tools/caves/<label>/dump_<b>.txt, ALLDONE
S=$(cd "$(dirname "$0")" && pwd); R=$HOME/Documents/Emerald; L=$1
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
mkdir -p $S/$L
export QA_ZOOM=-2 QA_LIMIT=400 QA_SRC="${PROBE:-$GAME}"
FILES="${FILES:-Gen3Rock.lua Gen3Mass.lua Gen3Relief.lua}"
one(){ b=$1
  cd $HOME/Documents/gen1recomp
  EM_DRIVER="$R/tools/${DRIVER:-caves/audit_driver.lua}" EM_MAPS="$S/m_$b" EM_DUMP="$S/$L/dump_$b.txt" EM_DUMP_WAIT=${DUMP_WAIT:-200} \
    "$R/tools/qa_tryp.sh" "$FILES" "$S/$L/out_$b" - 4 0 60 > "$S/$L/summary_$b.txt" 2>&1
}
export -f one; export S L R FILES DUMP_WAIT
printf '%s\n' ${BATCHES:-a b c d e f g h i j} | xargs -P ${PAR:-2} -I{} bash -c 'one {}; sleep 10'
echo done > $S/$L/ALLDONE
