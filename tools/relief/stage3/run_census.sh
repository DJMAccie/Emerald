#!/bin/bash
# run_census.sh <label> <probe-dir> <prefix>   claim census of the maps listed in $S/<prefix>_{a..g}, 3 games at a time
S=$(cd "$(dirname "$0")" && pwd)
R=$HOME/Documents/Emerald
L=$1; P=$2; X=$3
mkdir -p $S/$L
export QA_ZOOM=-2 QA_LIMIT=400 QA_SRC=$P
FILES="Gen3Cave.lua Gen3Hills.lua Gen3Mass.lua Gen3Relief.lua Gen3ReliefData.lua"
one(){ b=$1
  EM_DRIVER="$R/tools/em_relief_driver.lua" EM_MAPS="$S/${X}_$b" EM_DUMP="$S/$L/dump_$b.txt" EM_DUMP_WAIT=300 \
    "$R/tools/qa_tryp.sh" "$FILES" "$S/$L/out_$b" - 4 0 60 > "$S/$L/summary_$b.txt" 2>&1
  grep -q WATCHDOG "$S/$L/out_$b/run.log" 2>/dev/null && echo "WATCHDOG $b" >> "$S/$L/watchdog.txt"
  sleep 0
}
export -f one; export S L R P X FILES
printf '%s\n' a b c d e f g | xargs -P 3 -I{} bash -c 'one {}; sleep 20'
echo done > $S/$L/ALLDONE
