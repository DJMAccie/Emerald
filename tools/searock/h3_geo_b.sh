#!/bin/bash
# h3_geo.sh <label>   geometry dumps (em_geo_driver) of Routes 111/112/113/114 for CONTROL (game lib) and PROBE (${PROBE:-stage3/probe}).
# (h3_geo_driver = em_geo_driver with 3-decimal heights: a lift of .02 is invisible at %.1f.) VARIANTS="control probe probe2" picks the runs (probe2 = a repeat of probe, for noise).
# Result: stage3/h3geo/<label>/{control,probe}/<MAP>.geo.gz, marker ALLDONE. Compare with ab/zfight.py.
S=$HOME/Documents/Emerald/tools/relief/stage3; R=$HOME/Documents/Emerald; L=$1
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
O=$S/h3geo/$L; mkdir -p $O
printf 'EM_ROUTE111 21 62\nEM_ROUTE112 26 44\nEM_ROUTE113 44 7\nEM_ROUTE114 22 34\n' > $O/maps.txt
FILES="Gen3Rock.lua Gen3Cave.lua Gen3Hills.lua Gen3Mass.lua Gen3Relief.lua Gen3ReliefData.lua"
cd "$HOME/Documents/gen1recomp"
one(){ v=$1
  if [ "$v" = control ]; then src="$GAME"; else src="${PROBE:-$S/probe}"; fi
  mkdir -p $O/$v
  QA_SRC="$src" QA_LIMIT=400 EM_DRIVER="$S/ab/h3_geo_driver.lua" EM_MAPS="$O/maps.txt" EM_GEO_DIR="$O/$v" \
    "$R/tools/qa_tryp.sh" "$FILES" "$O/out_$v" - 4 0 60 > "$O/$v.summary" 2>&1
  grep -h "EM geo" "$O/out_$v/run.log" > "$O/$v.geolog" 2>/dev/null
}
for v in ${VARIANTS:-control probe}; do one $v & done; wait
for v in ${VARIANTS:-control probe}; do echo $v; cat $O/$v.geolog; done
echo done > $O/ALLDONE
