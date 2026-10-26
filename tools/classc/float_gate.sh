#!/bin/bash
# float_gate.sh <probe-dir> <maps file> <outdir>   Gen3Rock.audit float lines, control (game lib) vs probe
R=$HOME/Documents/Emerald; P=$1; M=$2; O=$3; mkdir -p $O
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
export QA_ZOOM=-2 QA_LIMIT=400
run(){ v=$1; src=$2; QA_SRC="$src" EM_DRIVER=$R/tools/em_float_driver.lua EM_MAPS=$M EM_FLOAT_WAIT=240 $R/tools/qa_tryp.sh "${FILES:-Gen3Hills.lua Gen3Rock.lua}" $O/out_$v - 4 0 60 > $O/$v.summary 2>&1; }
run control "$GAME" & run probe "$P" & wait
for v in control probe; do echo "== $v"; grep -h "RK1 float\|EM float" $O/out_$v/run.log $O/$v.summary | sort -u | cut -c1-200; done
