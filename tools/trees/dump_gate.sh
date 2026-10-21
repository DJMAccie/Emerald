#!/bin/bash
# dump_gate.sh <label> "<lib files>"   (VS="control" runs only the installed-game half; control takes only the files the game already has)
# whole-map cell dumps of the 53 outdoor maps: CONTROL (installed game lib) and PROBE (tools/trees/probe_final/lib), 3 games at a time.
# Compare: python3 -I tools/heights_compare.py diff CONTROL PROBE EMPTY   (needs tools/relief/stage3/dumpgate/maps_a..h)
R=$HOME/Documents/Emerald; L=$1; FILES=$2
M=$R/tools/relief/stage3/dumpgate
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
O=$R/tools/trees/gate/$L; mkdir -p $O
export QA_ZOOM=-2 QA_LIMIT=400
one(){ v=$1; b=$2
  if [ "$v" = control ]; then src="$GAME"; else src="$R/tools/trees/probe_final"; fi
  F=$FILES
  if [ "$v" = control ]; then F=; for f in $FILES; do [ -f "$GAME/lib/$f" ] && F="$F $f"; done; fi
  QA_SRC="$src" EM_DRIVER="$R/tools/em_cells_driver.lua" EM_MAPS="$M/maps_$b" EM_DUMP="$O/${v}_$b.txt" EM_DUMP_WAIT=300 \
    "$R/tools/qa_tryp.sh" "$F" "$O/out_${v}_$b" - 4 0 60 > "$O/${v}_$b.summary" 2>&1
  grep -q WATCHDOG "$O/out_${v}_$b/run.log" 2>/dev/null && echo "WATCHDOG $v $b" >> "$O/watchdog.txt"
}
export -f one; export R M GAME FILES O
for b in a b c d e f g h; do for v in ${VS:-control probe}; do echo "$v $b"; done; done | xargs -P 3 -L1 bash -c 'one $0 $1'
for v in ${VS:-control probe}; do cat $O/${v}_?.txt | sort > $O/${v}_all.txt; wc -l $O/${v}_all.txt; done
echo done > $O/ALLDONE
