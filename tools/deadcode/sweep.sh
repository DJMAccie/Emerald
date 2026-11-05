#!/bin/bash
# coverage sweep: all runs in parallel; qa_tryp.sh limits itself to 4 games
cd "$(cd "$(dirname "$0")/../.." && pwd)"
P=${PROBE:-/tmp/deadscan/probe}; O=${OUTROOT:-/tmp/deadscan/cov}
FILES=$(cat /tmp/deadscan/files.txt)
mkdir -p $O; rm -f $O/DONE
run(){ name=$1; shift; grep -q "^shots" $O/$name.out 2>/dev/null && return; ( "$@" > $O/$name.out 2>&1; echo "$name $(tail -1 $O/$name.out)" >> $O/DONE ) & sleep 2; }
export QA_SRC=$P QA_LIMIT=400
for c in A B C D E; do run views$c tools/qa_tryp.sh "$FILES" $O/views$c "$(cat tools/qa_cases/cases$c.txt)" 4; done
run lv_out tools/qa_tryp.sh "$FILES" $O/lv_out "{'EM_RUSTBORO_CITY',20,30},{'EM_ROUTE116',30,10},{'EM_LILYCOVE_CITY',20,20}" "0,1,6,7"
run lv_in tools/qa_tryp.sh "$FILES" $O/lv_in "{'EM_GRANITE_CAVE_1F',21,7},{'EM_OLDALE_TOWN_POKEMON_CENTER_1F',3,6},{'EM_ABANDONED_SHIP_DECK',11,9}" "0,1,6,7"
run lv_mid tools/qa_tryp.sh "$FILES" $O/lv_mid "{'EM_ROUTE111',22,20},{'EM_PETALBURG_WOODS',26,22},{'EM_FORTREE_CITY',20,10}" "2,3,5"
run bat1 env EM_DRIVER=$PWD/tools/drivers/em_battle_driver.lua EM_BATTLE_FRAMES=760 EM_PLAYER_SPECIES=252 EM_FOE_SPECIES=270 tools/qa_tryp.sh "$FILES" $O/bat1 "-" 4
run bat2 env EM_DRIVER=$PWD/tools/drivers/em_battle_driver.lua EM_BATTLE_FRAMES=760 EM_PLAYER_SPECIES=25 EM_FOE_SPECIES=6 tools/qa_tryp.sh "$FILES" $O/bat2 "-" 4
run fly_long env EM_DRIVER=$PWD/tools/drivers/em_fly_driver.lua EM_FLIGHT=long tools/qa_tryp.sh "$FILES" $O/fly_long "-" 4 0 200
run fly_land env EM_DRIVER=$PWD/tools/drivers/em_fly_driver.lua EM_FLIGHT=land tools/qa_tryp.sh "$FILES" $O/fly_land "-" 7 0 200
wait
echo ALLDONE >> $O/DONE
