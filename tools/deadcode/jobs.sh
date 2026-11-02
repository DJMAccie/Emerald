#!/bin/bash
# jobs.sh: every coverage/QA job, at most 3 at a time (more waiting qa_tryp runs drop out)
cd ~/Documents/Emerald
export FILES=$(cat ${FILESF:-/tmp/deadscan/files.txt}) QA_SRC=${PROBE:-/tmp/deadscan/probe} QA_LIMIT=400 R=${R:-/tmp/deadscan/run}
mkdir -p $R
one(){ n=$1; o=$R/$n; F=$PWD/tools/drivers/em_battle_driver.lua; Y=$PWD/tools/drivers/em_fly_driver.lua
  case $n in
   views?) tools/qa_tryp.sh "$FILES" $o "$(cat tools/qa_cases/cases${n#views}.txt)" 4 ;;
   lv_out) tools/qa_tryp.sh "$FILES" $o "{'EM_RUSTBORO_CITY',20,30},{'EM_ROUTE116',30,10},{'EM_LILYCOVE_CITY',20,20}" "0,1,6,7" ;;
   lv_in) tools/qa_tryp.sh "$FILES" $o "{'EM_GRANITE_CAVE_1F',21,7},{'EM_OLDALE_TOWN_POKEMON_CENTER_1F',3,6},{'EM_ABANDONED_SHIP_DECK',11,9}" "0,1,6,7" ;;
   lv_mid) tools/qa_tryp.sh "$FILES" $o "{'EM_ROUTE111',22,20},{'EM_PETALBURG_WOODS',26,22},{'EM_FORTREE_CITY',20,10}" "2,3,5" ;;
   bat1) EM_DRIVER=$F EM_BATTLE_FRAMES=760 EM_PLAYER_SPECIES=252 EM_FOE_SPECIES=270 tools/qa_tryp.sh "$FILES" $o "-" 4 ;;
   bat2) EM_DRIVER=$F EM_BATTLE_FRAMES=760 EM_PLAYER_SPECIES=25 EM_FOE_SPECIES=6 tools/qa_tryp.sh "$FILES" $o "-" 4 ;;
   fly_long) EM_DRIVER=$Y EM_FLIGHT=long tools/qa_tryp.sh "$FILES" $o "-" 4 0 200 ;;
   fly_land) EM_DRIVER=$Y EM_FLIGHT=land tools/qa_tryp.sh "$FILES" $o "-" 7 0 200 ;;
   b??) tools/qa_tryp.sh "$FILES" $o "$(cat /tmp/deadscan/allmaps/$n.txt)" 4 0 5; rm -f $o/*.png ;;
  esac > $o.out 2>&1
  echo "$n $(tail -1 $o.out) err=$(grep -ciE 'stack traceback|\[error\]' $o/run.log 2>/dev/null)"
}
export -f one
JOBS=${JOBS:-"viewsA viewsB viewsC viewsD viewsE lv_out lv_in lv_mid bat1 bat2 fly_long fly_land $(cd /tmp/deadscan/allmaps; ls | sed 's/.txt//' | tr '\n' ' ')"}
for j in $JOBS; do grep -q '^shots' $R/$j.out 2>/dev/null || echo $j; done | xargs -P3 -I{} bash -c 'one {}'
echo ALLDONE
