#!/bin/bash
# cap_game.sh <outdir> <specfile>   levels 4,6,7 yaw ${YAW:-0} from the INSTALLED game lib; one dir per spot: game_<MAP>_<x>_<y>
# specfile lines: MAP,x,y   (3 games at a time; waits for ALLDONE)
R=$HOME/Documents/Emerald
OUT=$1; SPECS=$2; mkdir -p "$OUT"
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
export QA_ZOOM=-2 QA_LIMIT=400 QA_SRC="${PROBE:-$GAME}"
FILES="${FILES:-Gen3Cave.lua Gen3Hills.lua Gen3Mass.lua Gen3Relief.lua Gen3ReliefData.lua Gen3Rock.lua Gen3RockTables.lua Gen3Elevation.lua}"
one(){ spec=$1; IFS=, read m x y <<< "$spec"
  [ -d "$OUT/game_${m}_${x}_${y}" ] && ls "$OUT/game_${m}_${x}_${y}"/*.png >/dev/null 2>&1 && return
  "$R/tools/qa_tryp.sh" "$FILES" "$OUT/game_${m}_${x}_${y}" "{'$m',$x,$y}" "4,6,7" ${YAW:-0} 300 > "$OUT/game_${m}_${x}_${y}.summary" 2>&1; }
export -f one; export OUT R FILES
xargs -P 3 -I{} bash -c 'one {}' < "$SPECS"
echo done > "$OUT/ALLDONE"
