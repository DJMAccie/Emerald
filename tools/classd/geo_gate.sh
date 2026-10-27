#!/bin/bash
# geo_gate.sh <label> <probe root>   geometry dumps (h3_geo_driver) of the ledge/relief maps for CONTROL (game lib), CONTROL2 (noise) and PROBE.
# FILES = the lib files the probe tree carries (env FILES). Result: tools/relief/stage3/h3geo/<label>/{control,control2,probe}/<MAP>.geo.gz, marker ALLDONE.
S=$HOME/Documents/Emerald/tools/relief/stage3; R=$HOME/Documents/Emerald; L=$1; P=$2
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
O=$S/h3geo/$L; mkdir -p $O
if [ -n "${MAPS_ONLY:-}" ]; then printf "$MAPS_ONLY" > $O/maps.txt; else printf 'EM_ROUTE111 21 62\nEM_ROUTE112 26 44\nEM_ROUTE113 44 7\nEM_ROUTE114 22 34\nEM_ROUTE115 20 40\nEM_ROUTE116 40 10\nEM_ROUTE119 24 40\nEM_ROUTE104 16 40\nEM_PETALBURG_WOODS 30 30\nEM_ROUTE120 30 20\nEM_ROUTE118 20 10\n' > $O/maps.txt; fi
cd "$HOME/Documents/gen1recomp"
one(){ v=$1
  if [ "$v" = probe ]; then src="$P"; else src="$GAME"; fi
  mkdir -p $O/$v
  QA_SRC="$src" QA_LIMIT=400 EM_DRIVER="$S/ab/h3_geo_driver.lua" EM_MAPS="$O/maps.txt" EM_GEO_DIR="$O/$v" \
    "$R/tools/qa_tryp.sh" "$FILES" "$O/out_$v" - 4 0 60 > "$O/$v.summary" 2>&1
  grep -h "EM geo" "$O/out_$v/run.log" > "$O/$v.geolog" 2>/dev/null
}
for v in ${VARIANTS:-control control2 probe}; do one $v & done; wait
echo done > $O/ALLDONE
