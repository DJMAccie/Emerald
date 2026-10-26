#!/bin/bash
# moss_geo.sh   geometry dumps (h3_geo_driver) of Mossdeep: control = game now, preB = class B reverted, preC = class C reverted
S=$HOME/Documents/Emerald/tools/relief/stage3; R=$HOME/Documents/Emerald
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
O=$R/.autoloop/runs/mossgeo; mkdir -p $O; echo "EM_MOSSDEEP_CITY 18 26" > $O/maps.txt
cd "$HOME/Documents/gen1recomp"
one(){ v=$1; src=$2; files=$3; mkdir -p $O/$v
  QA_SRC="$src" QA_LIMIT=400 EM_DRIVER="$S/ab/h3_geo_driver.lua" EM_MAPS="$O/maps.txt" EM_GEO_DIR="$O/$v" \
    "$R/tools/qa_tryp.sh" "$files" "$O/out_$v" - 4 0 60 > "$O/$v.summary" 2>&1
  grep -h "EM geo" "$O/out_$v/run.log" > "$O/$v.geolog" 2>/dev/null; }
one control "$GAME" "Gen3Rock.lua" &
one preB $R/tools/classa/preB "Gen3Rock.lua Gen3Mass.lua Gen3Hills.lua" &
one preC $R/tools/classa/preC "Gen3Rock.lua Gen3Relief.lua Gen3ReliefData.lua Gen3RockTables.lua" &
wait; echo done > $O/ALLDONE
