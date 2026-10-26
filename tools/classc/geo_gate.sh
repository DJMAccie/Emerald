#!/bin/bash
# geo_gate.sh <label> <probe-dir>   geometry dumps (3-decimal) of Routes 111/112/124 + Sootopolis for control (game lib), probe, probe2 (noise repeat).
# Probe holds only the changed files (FILES). Compare with tools/relief/stage3/ab/geo_diff.py A B.
R=$HOME/Documents/Emerald; S=$R/tools/relief/stage3; L=$1; P=$2
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
O=$R/tools/classc/geo/$L; mkdir -p $O
printf 'EM_ROUTE111 21 62\nEM_ROUTE112 26 44\nEM_ROUTE124 20 20\nEM_SOOTOPOLIS_CITY 30 40\n' > $O/maps.txt
FILES=${FILES:-"Gen3Hills.lua Gen3Rock.lua"}
cd "$HOME/Documents/gen1recomp"
one(){ v=$1
  if [ "$v" = control ]; then src="$GAME"; else src="$P"; fi
  mkdir -p $O/$v
  QA_SRC="$src" QA_LIMIT=400 EM_DRIVER="$S/ab/h3_geo_driver.lua" EM_MAPS="$O/maps.txt" EM_GEO_DIR="$O/$v" \
    "$R/tools/qa_tryp.sh" "$FILES" "$O/out_$v" - 4 0 60 > "$O/$v.summary" 2>&1
  grep -h "EM geo" "$O/out_$v/run.log" > "$O/$v.geolog" 2>/dev/null
}
for v in control probe probe2; do one $v & done; wait
for v in control probe probe2; do echo $v; cat $O/$v.geolog; done
echo done > $O/ALLDONE
