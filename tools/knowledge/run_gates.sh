#!/bin/bash
# run_gates.sh <label> [files]
# Runs the numeric gates on the mod SOURCE lib (= the installed game after an install) in the private QA copies and writes
# one scorecard row: G-01 field gate (pins_gate.sh), G-02 class table (blocks_gate.sh), G-03 tree gate (em_cells_driver on the
# wooded maps + tree_gate.py), G-05 fallbacks (summed from the tryp logs). About 20-30 min with 3 QA copies.
# Refuses while a QA game is running (another session's gate or capture), so results never mix. Then: git add the two
# scorecard files and commit them with the install. The user's own game may stay open (the QA copies are separate).
set -u
R=$HOME/Documents/Emerald; L=${1:?label}; FILES=${2:-"Gen3Elevation.lua Gen3PinData.lua Gen3Blocks.lua Gen3Scene.lua TerrainLevels.lua"}
O=/tmp/$L
if pgrep -x love >/dev/null && ps eww $(pgrep -x love) 2>/dev/null | grep -q 'POKEPORT_IDENTITY=pokemon-love2d-rseqa'; then
  echo "run_gates.sh: a QA game is running (another session's gate or capture); try again when it is done" >&2; exit 2; fi
[ -e $O ] && { echo "run_gates.sh: $O exists; pick a fresh label" >&2; exit 2; }
mkdir -p $O/cls
echo "== G-01 field gate -> $O"; bash $R/tools/elevation/qa/pins_gate.sh $L "$FILES"
echo "== G-02 class table -> $O/cls"; bash $R/tools/elevation/qa/blocks_gate.sh $L/cls "$FILES"
echo "== G-03 tree dump -> $O/tree.txt"
EM_DRIVER=$R/tools/em_cells_driver.lua EM_MAPS=$R/tools/knowledge/tree_maps.txt EM_DUMP=$O/tree.txt EM_DUMP_WAIT=300 QA_LIMIT=400 \
  bash $R/tools/qa_tryp.sh "$FILES" $O/out_tree - 4 0 60 > $O/tryp_tree.log 2>&1
python3 $R/tools/elevation/learn/tree_gate.py $O/tree.txt > $O/tree_gate.txt; tail -1 $O/tree_gate.txt
echo "== scorecard row"
python3 $R/tools/knowledge/scorecard.py --label $L --pins $O --cls $O/cls --tree $O/tree_gate.txt --source "run_gates.sh $L on the mod source lib"
python3 $R/tools/knowledge/check.py
