#!/bin/bash
# run_dump.sh <label> [probe]   dumps the 53 outdoor maps in 8 batches, 3 at a time, into ./<label>/
S=$(cd "$(dirname "$0")" && pwd); L=$1; R=$HOME/Documents/Emerald
mkdir -p "$S/$L"
export QA_ZOOM=-2 QA_LIMIT=400
[ "${2:-}" = probe ] && export QA_SRC="$S/${PROBE:-probe}"
one(){ b=$1
  EM_DRIVER="$R/tools/em_cells_driver.lua" EM_MAPS="$S/maps_$b" EM_DUMP="$S/$L/dump_$b.txt" EM_DUMP_WAIT=300 \
    "$R/tools/qa_tryp.sh" "Gen3Elevation.lua" "$S/$L/out_$b" - 4 0 60 > "$S/$L/summary_$b.txt" 2>&1
  grep -q WATCHDOG "$S/$L/out_$b/run.log" 2>/dev/null && echo "WATCHDOG $b" >> "$S/$L/watchdog.txt"
}
export -f one; export S L R
printf '%s\n' a b c d e f g h | xargs -P 3 -I{} bash -c 'one {}; sleep 0'
echo done > "$S/$L/ALLDONE"
