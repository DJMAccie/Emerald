#!/bin/bash
# dump_gate.sh <label>   whole-map cell dumps of the 53 outdoor maps, CONTROL (game lib) and PROBE (stage3/probe), 3 games at a time.
# Compare: python3 -I tools/heights_compare.py diff CONTROL PROBE EMPTY  (needs dumpgate/maps_a..h = split -l 7 -a 1 docs/ledger/outdoor_spots.txt)
S=$(cd "$(dirname "$0")/.." && pwd); R=$HOME/Documents/Emerald; L=$1
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
O=$S/dumpgate/$L; mkdir -p $O
export QA_ZOOM=-2 QA_LIMIT=400
FILES="Gen3Cave.lua Gen3Hills.lua Gen3Mass.lua Gen3Relief.lua Gen3ReliefData.lua"
one(){ v=$1; b=$2
  if [ "$v" = control ]; then src="$GAME"; else src="${PROBE:-$S/probe}"; fi
  QA_SRC="$src" EM_DRIVER="$R/tools/em_cells_driver.lua" EM_MAPS="$S/dumpgate/maps_$b" EM_DUMP="$O/${v}_$b.txt" EM_DUMP_WAIT=300 \
    "$R/tools/qa_tryp.sh" "$FILES" "$O/out_${v}_$b" - 4 0 60 > "$O/${v}_$b.summary" 2>&1
  grep -q WATCHDOG "$O/out_${v}_$b/run.log" 2>/dev/null && echo "WATCHDOG $v $b" >> "$O/watchdog.txt"
}
export -f one; export S R GAME FILES O PROBE
for b in a b c d e f g h; do for v in control probe; do echo "$v $b"; done; done | xargs -P 3 -L1 bash -c 'one $0 $1'
cat $O/control_?.txt | sort > $O/control_all.txt; cat $O/probe_?.txt | sort > $O/probe_all.txt
wc -l $O/control_all.txt $O/probe_all.txt
echo done > $O/ALLDONE
