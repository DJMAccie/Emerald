#!/bin/bash
# m0_step4.sh <label> [after-label]   M0 step 4: golden captures + gate outputs of TODAY's installed game (QA copies only).
#   Waits for .rewrite/baseline/<after-label>/SUMMARY.txt to say ALLDONE first (so it never competes with a world run).
#   Captures: tools/rewrite/spots_m0.txt ("MAP,x,y"), levels 4,6,7, yaws 0 and 180, QA_ZOOM=-2, wait 300 frames,
#             8 spots per qa_tryp call, 3 at once -> .rewrite/baseline/<label>/caps/y<yaw>_<n>/
#   Gates:    G-01 pins_gate, G-02 blocks_gate, G-03 tree dumps (em_cells_driver on tools/knowledge/tree_maps.txt) +
#             tree_gate.py, G-11 ledge census (em_ledge_driver on the pinned maps) -> .rewrite/baseline/<label>/gates/
#   Writes ALLDONE into .rewrite/baseline/<label>/STATUS when finished.
set -u
R=$HOME/Documents/Emerald; L=$1; AFTER=${2:-}
O=$R/.rewrite/baseline/$L; mkdir -p "$O/caps" "$O/gates"
export QA_SRC="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
if [ -n "$AFTER" ]; then until grep -q ALLDONE "$R/.rewrite/baseline/$AFTER/SUMMARY.txt" 2>/dev/null; do sleep 30; done; fi
echo "start $(date)" > "$O/STATUS"
# --- captures
split -l 8 "$R/tools/rewrite/spots_m0.txt" "$O/caps/spots_"
cap(){ f=$1; yaw=$2; n=$(basename "$f")
  cases=$(awk -F, '{printf "%s{'"'"'%s'"'"',%s,%s}", (NR>1?",":""), $1,$2,$3}' "$f")
  QA_ZOOM=-2 QA_LIMIT=400 bash "$R/tools/qa_tryp.sh" "Gen3Scene.lua" "$O/caps/y${yaw}_${n#spots_}" "$cases" "4,6,7" "$yaw" 300 \
    > "$O/caps/y${yaw}_${n#spots_}.summary" 2>&1
}
export -f cap; export R O
for yaw in 0 180; do for f in "$O"/caps/spots_*; do echo "$f $yaw"; done; done | xargs -P 3 -L1 bash -c 'cap $0 $1'
cat "$O"/caps/*.summary > "$O/caps/SUMMARY.txt"
echo "caps $(date)" >> "$O/STATUS"
# --- G-01 / G-02 (the gate scripts write to /tmp/<label>)
bash "$R/tools/elevation/qa/pins_gate.sh" "${L}_g01" > "$O/gates/g01.log" 2>&1; cp /tmp/${L}_g01/pins_*.txt "$O/gates/" 2>/dev/null
bash "$R/tools/elevation/qa/blocks_gate.sh" "${L}_g02" > "$O/gates/g02.log" 2>&1; cp /tmp/${L}_g02/cls_*.txt "$O/gates/" 2>/dev/null
# --- G-03 tree dumps + gate, G-11 ledge census (the pinned-map list pins_gate made)
EM_DRIVER=$R/tools/em_cells_driver.lua EM_MAPS=$R/tools/knowledge/tree_maps.txt EM_DUMP=$O/gates/trees_cells.txt EM_DUMP_WAIT=300 QA_LIMIT=400 \
  bash "$R/tools/qa_tryp.sh" "Gen3Scene.lua" "$O/gates/out_g03" - 4 0 60 > "$O/gates/g03_run.log" 2>&1 &
split -l 22 /tmp/${L}_g01/maps_all.txt "$O/gates/lmaps_"
for b in "$O"/gates/lmaps_*; do n=$(basename "$b")
  EM_DRIVER=$R/tools/elevation/qa/em_ledge_driver.lua EM_MAPS=$b EM_DUMP=$O/gates/ledge_${n#lmaps_}.txt QA_LIMIT=360 \
    bash "$R/tools/qa_tryp.sh" "Gen3Elevation.lua Gen3PinData.lua Gen3Blocks.lua Gen3Scene.lua TerrainLevels.lua" "$O/gates/out_l_${n#lmaps_}" - 4 0 60 > "$O/gates/g11_${n#lmaps_}.log" 2>&1 &
  while [ "$(jobs -r | wc -l)" -ge 3 ]; do sleep 5; done
done
wait
python3 "$R/tools/elevation/learn/tree_gate.py" "$O/gates/trees_cells.txt" > "$O/gates/G03.txt" 2>&1
grep -h "^COUNT" "$O"/gates/pins_*.txt | sort > "$O/gates/G01.txt"
grep -h "^CLS " "$O"/gates/cls_*.txt | sort > "$O/gates/G02.txt"
grep -h "^LEDGE \|^TOTAL" "$O"/gates/ledge_*.txt | sort > "$O/gates/G11.txt"
echo "ALLDONE $(date)" >> "$O/STATUS"
