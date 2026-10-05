#!/bin/bash
# Morning verification of everything built overnight WITHOUT in-game checks
# (2026-10-05: the display was off from ~23:00, no LÖVE window could present).
#   tools/morning_check.sh [outdir]
# 1. Copies the mod SOURCE lib/ and data/buildings into QA (backup first).
# 2. Captures every UNVERIFIED item at the player's camera (4), the turned
#    orbit (7) and the low camera (6) through tools/qa_run.sh (shared lock).
# 3. Builds one contact sheet per item group in <outdir>/sheets.
# Then: look at every sheet zoomed in. Install to the real game only what is
# right; revert the rest in the mod source.
set -u
OUT=${1:-$HOME/Documents/Emerald/shots_morning}
QA="$HOME/Library/Application Support/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK"
M=~/Documents/battle-art-notquiteog
T=$(dirname "$0")
mkdir -p "$OUT/sheets" "$HOME/Documents/gen1recomp-modwork/backups"
BK="$HOME/Documents/gen1recomp-modwork/backups/qa-before-morning-$(date +%Y%m%d-%H%M)"
cp -R "$QA/lib" "$QA/data" "$BK" 2>/dev/null || { mkdir -p "$BK"; cp -R "$QA/lib" "$BK/"; cp -R "$QA/data" "$BK/"; }
rsync -a "$M/lib/" "$QA/lib/"; rsync -a --delete "$M/data/buildings/" "$QA/data/buildings/"
echo "QA backed up to $BK and synced from source"
# trial in QA only: the generated stair platforms (off by default in source)
sed -i '' 's/ onStairs={}/ onStairs={EM_BATTLE_FRONTIER_OUTSIDE_EAST=true,EM_SAFARI_ZONE_NORTHEAST=true,EM_SAFARI_ZONE_SOUTHEAST=true}/' "$QA/lib/Gen3EmeraldTerraces.lua"

# group|cases|yaw for the turned and low views
ITEMS=(
 "opus_sootopolis_terraces|{'EM_SOOTOPOLIS_CITY',31,20},{'EM_SOOTOPOLIS_CITY',17,31},{'EM_SOOTOPOLIS_CITY',44,33}|0.5"
 "opus_door_floor|{'EM_MOSSDEEP_CITY',30,12},{'EM_MOSSDEEP_CITY',28,22},{'EM_LILYCOVE_CITY',30,20},{'EM_LITTLEROOT_TOWN',10,10}|0.6"
 "opus_water_bodies|{'EM_ROUTE119',14,38},{'EM_ROUTE119',20,60},{'EM_ROUTE119',30,20}|0.6"
 "opus_stair_platforms|{'EM_BATTLE_FRONTIER_OUTSIDE_EAST',16,40},{'EM_BATTLE_FRONTIER_OUTSIDE_EAST',39,40},{'EM_SAFARI_ZONE_NORTHEAST',30,12},{'EM_SAFARI_ZONE_SOUTHEAST',18,20}|0.6"
 "furniture_center|{'EM_OLDALE_TOWN_POKEMON_CENTER_1F',6,8},{'EM_OLDALE_TOWN_POKEMON_CENTER_1F',3,5}|-1.2"
 "furniture_mart|{'EM_OLDALE_TOWN_MART',4,6},{'EM_OLDALE_TOWN_MART',4,5}|1.6"
 "furniture_houses|{'EM_MOSSDEEP_CITY_HOUSE1',4,6},{'EM_LILYCOVE_CITY_HOUSE1',4,6},{'EM_OLDALE_TOWN_HOUSE1',5,7}|0.6"
 "furniture_center_2f|{'EM_OLDALE_TOWN_POKEMON_CENTER_2F',6,7}|0.6"
 "furniture_mauville_gym|{'EM_MAUVILLE_CITY_GYM',5,18},{'EM_MAUVILLE_CITY_GYM',5,10}|0.6"
 "furniture_gyms|{'EM_PETALBURG_CITY_GYM',4,5},{'EM_MOSSDEEP_CITY_GYM',23,9},{'EM_SOOTOPOLIS_CITY_GYM_1F',8,4},{'EM_DEWFORD_TOWN_GYM',4,4},{'EM_LAVARIDGE_TOWN_GYM_1F',13,11}|-0.6"
 "furniture_tent_store|{'EM_SLATEPORT_CITY_BATTLE_TENT_LOBBY',6,7},{'EM_LILYCOVE_CITY_DEPARTMENT_STORE_1F',8,6},{'EM_LILYCOVE_CITY_DEPARTMENT_STORE_1F',14,5},{'EM_LILYCOVE_CITY_DEPARTMENT_STORE_2F',8,7},{'EM_LILYCOVE_CITY_DEPARTMENT_STORE_2F',4,7}|0.6"
 "furniture_contest_museum_devon|{'EM_LILYCOVE_CITY_CONTEST_LOBBY',14,6},{'EM_LILYCOVE_CITY_CONTEST_LOBBY',23,7},{'EM_SLATEPORT_CITY_OCEANIC_MUSEUM_1F',9,7},{'EM_RUSTBORO_CITY_DEVON_CORP_1F',5,6}|0.6"
 "furniture_frontier_booth_RISKY|{'EM_BATTLE_FRONTIER_BATTLE_TOWER_LOBBY',10,7},{'EM_BATTLE_FRONTIER_BATTLE_TOWER_LOBBY',6,6},{'EM_BATTLE_FRONTIER_LOUNGE1',4,8}|-0.6"
 "furniture_flowershop_daycare|{'EM_ROUTE104_PRETTY_PETAL_FLOWER_SHOP',3,8},{'EM_ROUTE117_POKEMON_DAY_CARE',4,7}|0.6"
 "furniture_museum_seashore_gamecorner|{'EM_LILYCOVE_CITY_LILYCOVE_MUSEUM_1F',17,11},{'EM_ROUTE109_SEASHORE_HOUSE',6,8},{'EM_MAUVILLE_CITY_GAME_CORNER',5,10},{'EM_MAUVILLE_CITY_GAME_CORNER',6,8}|0.6"
 "furniture_lab|{'EM_ROUTE119_WEATHER_INSTITUTE_1F',11,8},{'EM_LITTLEROOT_TOWN_PROFESSOR_BIRCHS_LAB',6,9}|0.6"
 "sonnet_slateport_bush|{'EM_SLATEPORT_CITY',15,13}|0.6"
)
# more items: read docs/FURNITURE-UNVERIFIED.md and docs/PROPS-UNVERIFIED.md and
# add a line per room before running
for it in "${ITEMS[@]}"; do
  IFS='|' read -r NAME CASES YAW <<<"$it"
  for spec in "4 0" "7 $YAW" "6 $YAW"; do
    set -- $spec
    "$T/qa_run.sh" "$OUT/$NAME/l$1" "$CASES" "$1" "$2" 150
  done
  python3 - "$OUT/$NAME" "$OUT/sheets/$NAME.png" <<'PY'
import sys, glob, os
from PIL import Image, ImageDraw
d, out = sys.argv[1], sys.argv[2]
fs = []
for lv in ('l4', 'l7', 'l6'):
    fs += sorted(glob.glob(os.path.join(d, lv, '*.png')), key=os.path.getmtime)
if not fs: sys.exit()
cols = 3; rows = (len(fs) + cols - 1) // cols
s = Image.new('RGB', (cols * 640, rows * 360))
for i, f in enumerate(fs):
    im = Image.open(f).convert('RGB').resize((640, 360))
    ImageDraw.Draw(im).text((4, 4), os.path.basename(os.path.dirname(f)) + ' ' + os.path.basename(f), fill=(255, 255, 0))
    s.paste(im, ((i % cols) * 640, (i // cols) * 360))
s.save(out)
PY
  echo "sheet: $OUT/sheets/$NAME.png"
done
