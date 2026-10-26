#!/bin/bash
# run_probe.sh <label> <probe root>   the 18 class A spots at yaw 0 and 90 from a probe tree -> .autoloop/runs/<label>y0, <label>y90
R=$HOME/Documents/Emerald
SP=("EM_ROUTE126,43,58" "EM_ROUTE126,5,54" "EM_ROUTE126,12,14" "EM_MOSSDEEP_CITY,18,26" "EM_MOSSDEEP_CITY,15,37" "EM_LILYCOVE_CITY,66,3" "EM_LILYCOVE_CITY,42,37" "EM_SKY_PILLAR_OUTSIDE,15,21" "EM_ROUTE121,18,14" "EM_ROUTE121,51,14" "EM_ROUTE129,57,11" "EM_ROUTE129,33,29" "EM_ROUTE130,68,13" "EM_ROUTE105,32,44" "EM_ROUTE105,33,24" "EM_ROUTE108,26,5" "EM_ROUTE104,5,55" "EM_ROUTE110,3,67")
export FILES="${FILES:-Gen3Hills.lua}"
rm -rf $R/.autoloop/runs/${1}y0 $R/.autoloop/runs/${1}y90
YAW=0 bash $R/tools/searock/cap_trace.sh ${1}y0 "$2" "${SP[@]}" > /dev/null 2>&1
YAW=90 bash $R/tools/searock/cap_trace.sh ${1}y90 "$2" "${SP[@]}" > /dev/null 2>&1
echo done > $R/.autoloop/runs/${1}_RUNDONE
