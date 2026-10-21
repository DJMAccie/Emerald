#!/bin/bash
# census_run.sh <label>   tree census (tools/em_trees_driver.lua) of the 53 outdoor maps in the installed game tree, 3 games at a time.
# Needs tools/relief/stage3/dumpgate/maps_a..h (= split -l 7 -a 1 docs/ledger/outdoor_spots.txt). Then: python3 tools/trees/analyze_census.py <label dir>/census_?.txt
R=$HOME/Documents/Emerald; L=$1
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
O=$R/tools/trees/$L; mkdir -p $O
export QA_ZOOM=-2 QA_LIMIT=400
one(){ b=$1
  QA_SRC="${SRC:-$GAME}" EM_DRIVER="$R/tools/em_trees_driver.lua" EM_MAPS="$R/tools/relief/stage3/dumpgate/maps_$b" EM_DUMP="$O/census_$b.txt" \
    EM_DUMP_WAIT=300 EM_EARLY=40 EM_FULL=1 "$R/tools/qa_tryp.sh" "Gen3Relief.lua" "$O/out_$b" - 4 0 60 > "$O/census_$b.summary" 2>&1
}
export -f one; export R GAME O SRC
for b in a b c d e f g h; do echo $b; done | xargs -P 3 -L1 bash -c 'one $0'
cat $O/census_?.txt | wc -l
echo done > $O/ALLDONE
