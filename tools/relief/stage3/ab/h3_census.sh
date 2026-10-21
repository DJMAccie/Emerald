#!/bin/bash
# h3_census.sh <label>   Gen3Relief.stats (lift / clean / wall) per relief map on PROBE (${PROBE:-stage3/probe}), 3 games at a time.
# Result: stage3/h3census/<label>/all.txt
S=$(cd "$(dirname "$0")/.." && pwd); R=$HOME/Documents/Emerald; L=$1
O=$S/h3census/$L; mkdir -p $O
export QA_ZOOM=-2 QA_LIMIT=400
FILES="Gen3Cave.lua Gen3Hills.lua Gen3Mass.lua Gen3Relief.lua Gen3ReliefData.lua"
one(){ b=$1; cd $HOME/Documents/gen1recomp
  QA_SRC="${PROBE:-$S/probe}" EM_DRIVER="$S/ab/h3_census_driver.lua" EM_MAPS="$S/dumpgate/maps_$b" \
    "$R/tools/qa_tryp.sh" "$FILES" "$O/out_$b" - 4 0 60 > "$O/$b.summary" 2>&1
  grep -h "EM h3stats" "$O/out_$b/run.log" "$O/$b.summary" 2>/dev/null | sort -u > "$O/$b.txt"; }
export -f one; export S R FILES O PROBE
for b in a b c d e f g h; do echo $b; done | xargs -P 3 -L1 bash -c 'one $0'
cat $O/?.txt | sort > $O/all.txt; wc -l $O/all.txt
echo done > $O/ALLDONE
