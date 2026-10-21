#!/bin/bash
# H3 gates in sequence (max 3 games at a time each): V1 heights, floor dump, float. Labels h3_*. Result: stage3/h3_chain.log, marker stage3/h3_chain.ALLDONE
S=$HOME/Documents/Emerald/tools/relief/stage3; export PROBE=$S/probe_h3
cd $S
{ echo "== v1"; bash ab/v1_gate.sh h3_v1 2>&1 | tail -6
  echo "== dump"; bash ab/dump_gate.sh h3_d 2>&1 | tail -4
  echo "== float"; bash ab/float_gate.sh h3_f 2>&1 | tail -4; } > $S/h3_chain.log 2>&1
echo done > $S/h3_chain.ALLDONE
