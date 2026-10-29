#!/bin/bash
# baseline_geo.sh <label> <maps.txt>  geometry + cell dumps of TODAY's game (installed mod lib, QA copies only)
# maps.txt: "MAP x y" lines. Splits into batches of 4 maps (qa_tryp caps a run at 400 s), up to 3 at once.
# EM_BASE_DRIVER: the driver (default: the old h3 geometry driver; tools/rewrite/probe/geo_driver.lua = mod-neutral probe driver).
# Out: ~/Documents/Emerald/.rewrite/baseline/<label>/<MAP>.geo.gz + <MAP>.cells, summaries in out_<n>/.
set -u
L=$1; MAPS=$2; R=$HOME/Documents/Emerald
O=$R/.rewrite/baseline/$L; mkdir -p "$O"
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
split -l 4 "$MAPS" "$O/batch_"
n=0
for b in "$O"/batch_*; do
  n=$((n+1))
  ( QA_SRC="$GAME" QA_LIMIT=400 EM_DRIVER="${EM_BASE_DRIVER:-$R/tools/relief/stage3/ab/h3_geo_driver.lua}" EM_MAPS="$b" EM_GEO_DIR="$O" \
      bash "$R/tools/qa_tryp.sh" "Generation.lua" "$O/out_$n" - 4 0 60 > "$O/out_$n.summary" 2>&1 ) &
  while [ "$(jobs -r | wc -l)" -ge 3 ]; do sleep 5; done
done
wait
grep -h "EM geo" "$O"/out_*/run.log | sort > "$O/SUMMARY.txt"; echo ALLDONE >> "$O/SUMMARY.txt"
