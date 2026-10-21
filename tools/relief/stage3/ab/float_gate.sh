#!/bin/bash
# float_gate.sh <label>   Gen3Rock.audit (floating rock) on the 39 census maps: CONTROL (game lib) and PROBE, 3 games at a time.
S=$(cd "$(dirname "$0")/.." && pwd); R=$HOME/Documents/Emerald; L=$1
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
O=$S/floatgate/$L; mkdir -p $O
export QA_ZOOM=-2 QA_LIMIT=400
FILES="Gen3Cave.lua Gen3Hills.lua Gen3Mass.lua Gen3Relief.lua Gen3ReliefData.lua"
one(){ v=$1; b=$2
  if [ "$v" = control ]; then src="$GAME"; else src="${PROBE:-$S/probe}"; fi
  QA_SRC="$src" EM_DRIVER="$R/tools/em_float_driver.lua" EM_MAPS="$S/cen_$b" EM_FLOAT_WAIT=240 \
    "$R/tools/qa_tryp.sh" "$FILES" "$O/out_${v}_$b" - 4 0 60 > "$O/${v}_$b.summary" 2>&1
  grep -h "^\[RK1 float\]\|^\[EM float\]" "$O/out_${v}_$b/run.log" "$O/${v}_$b.summary" 2>/dev/null | sort -u > "$O/${v}_$b.txt"
}
export -f one; export S R GAME FILES O PROBE
for b in a b c d e f g; do for v in control probe; do echo "$v $b"; done; done | xargs -P 3 -L1 bash -c 'one $0 $1'
for v in control probe; do cat $O/${v}_?.txt | sort > $O/${v}_all.txt; echo "$v: floats $(grep -c '^\[RK1 float\]' $O/${v}_all.txt)"; done
echo done > $O/ALLDONE
