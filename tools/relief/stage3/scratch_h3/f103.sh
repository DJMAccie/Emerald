#!/bin/bash
S=$HOME/Documents/Emerald/tools/relief/stage3; R=$HOME/Documents/Emerald; O=$S/scratch_h3/f103; mkdir -p $O
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
FILES="Gen3Cave.lua Gen3Hills.lua Gen3Mass.lua Gen3Relief.lua Gen3ReliefData.lua"
export QA_ZOOM=-2 QA_LIMIT=400
one(){ v=$1; if [ "$v" = control ]; then src="$GAME"; else src="$S/probe_h3"; fi
  cd $HOME/Documents/gen1recomp
  QA_SRC="$src" EM_DRIVER="$R/tools/em_float_driver.lua" EM_MAPS="$S/scratch_h3/r103" EM_FLOAT_WAIT=240 \
    "$R/tools/qa_tryp.sh" "$FILES" "$O/out_$v" - 4 0 60 > "$O/$v.summary" 2>&1
  grep -h "^\[RK1 float\]\|^\[EM float\]" "$O/out_$v/run.log" "$O/$v.summary" 2>/dev/null | sort -u > "$O/$v.txt"; }
one control & one probe & wait
echo done > $O/ALLDONE
