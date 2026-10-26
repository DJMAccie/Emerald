#!/bin/bash
# cap.sh <batch> <variant> "MAP,x,y" ...   captures levels 4,6,7 yaw 0 of each spot -> docs/rock-gates/caves/<batch>/<variant>_<MAP>_<x>_<y>/
# variant "old" = the installed game lib; any other variant = the probe tree $PROBE (QA_SRC), with FILES copied from it
R=$HOME/Documents/Emerald
B=$1; V=$2; shift 2
OUT=$R/docs/rock-gates/caves/$B
mkdir -p $OUT
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
export QA_ZOOM=-2 QA_LIMIT=400 EM_FLASH=1 EM_DRIVER=${EM_DRIVER:-$R/tools/em_views_flash_driver.lua}
FILES="${FILES:-Gen3Cave.lua Gen3Scene.lua}"
one(){ spec=$1
  IFS=, read m x y <<< "$spec"
  if [ "$V" = old ]; then src="$GAME"; else src="$PROBE"; fi
  QA_SRC="$src" "$R/tools/qa_tryp.sh" "$FILES" "$OUT/${V}_${m}_${x}_${y}" "{'$m',$x,$y}" "4,6,7" 0 300 > "$OUT/${V}_${m}_${x}_${y}.summary" 2>&1
}
export -f one; export OUT R GAME FILES V PROBE EM_FLASH EM_DRIVER
printf '%s\n' "$@" | xargs -P ${PAR:-2} -I{} bash -c 'one {}'
echo done > $OUT/ALLDONE_$V
