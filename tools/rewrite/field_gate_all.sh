#!/bin/bash
# field_gate_all.sh <first> <last> [jobs] [mapsdir]
# Runs tools/rewrite/field_gate.sh over the 8-map batches /tmp/p2d_batches/maps_<k>.txt (or <mapsdir>),
# <jobs> batches at a time (default 3: never more than 3 QA games, R-27), labels p2f<k>.
# Needs the QA identity folders writable: run it with the wider sandbox (clean_try rsyncs the clean tree in).
set -u
R=$HOME/Documents/Emerald
first=${1:-1}; last=${2:-8}; jobs=${3:-3}; MD=${4:-/tmp/p2d_batches}
run(){ L=p2f$1; rm -rf /tmp/$L
  bash $R/tools/rewrite/field_gate.sh $L $MD/maps_$1.txt > /tmp/$L.summary 2>&1
  echo "done $L $(grep -c '^COUNT' /tmp/$L/pins_aa.txt 2>/dev/null) pins $(grep -c '^CLS' /tmp/$L/cls_aa.txt 2>/dev/null) cls"
}
export -f run; export R MD
seq $first $last | xargs -P $jobs -I{} bash -c 'run {}'
echo "=== all batches"
for k in $(seq $first $last); do echo -n "p2f$k: "
  echo -n "$(grep -c '^COUNT' /tmp/p2f$k/pins_aa.txt 2>/dev/null) pins, "
  echo "$(grep -c '^CLS' /tmp/p2f$k/cls_aa.txt 2>/dev/null) cls; $(grep -h '^COUNT' /tmp/p2f$k/pins_aa.txt 2>/dev/null | grep -v 'diff=0' | wc -l | tr -d ' ') pin diffs"
done
