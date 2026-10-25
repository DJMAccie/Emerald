#!/bin/bash
# dump.sh <label>   whole-map geometry + cell dump of the INSTALLED build for the Mt Chimney / Lavaridge rock work.
set -u
R=$HOME/Documents/Emerald; L=$1; O=$R/.autoloop/runs/$L
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
mkdir -p "$O/geo"
printf 'EM_MT_CHIMNEY 22 20\nEM_LAVARIDGE_TOWN 10 12\n' > "$O/maps.txt"
export QA_ZOOM=-2 QA_LIMIT=400
QA_SRC=$GAME EM_DRIVER="$R/tools/autoloop/em_geo_driver.lua" EM_MAPS="$O/maps.txt" EM_GEO_DIR="$O/geo" \
  "$R/tools/qa_tryp.sh" "Gen3Scene.lua" "$O/out" - 4 0 200 > "$O/geo.summary" 2>&1
grep -h "^\[EM geo\]" "$O/geo.summary"
echo done > "$O/ALLDONE"
