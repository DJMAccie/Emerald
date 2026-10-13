#!/bin/bash
# Tile the glass dump panels of a run into contact sheets, at most 12 per sheet.
#   tools/glass_sheet.sh <dir>
# Input: <dir>/<map>__<id>.png (the three-panel dumps of em_glass_driver.lua).
# The <map>__screen.png shots are not building pictures and are left out.
# Output: <dir>/sheet_01.png, sheet_02.png, ... (3 columns, each panel cell 960x480,
# scaled to fit) and <dir>/sheets.txt listing the files of each sheet in order.
set -eu
DIR=${1:?usage: glass_sheet.sh <dir>}
cd "$DIR"
rm -f sheet_*.png sheets.txt
CW=960; CH=480; COLS=3; PER=12
LIST=$(ls -1 | LC_ALL=C sort | grep '__.*\.png$' | grep -v '__screen\.png$' | grep -v '^sheet_' || true)
[ -n "$LIST" ] || { echo "no dumps in $DIR"; exit 1; }
n=0; sheet=0
set -- $LIST
total=$#
while [ "$n" -lt "$total" ]; do
  sheet=$((sheet+1))
  files=()
  i=0
  for f in "$@"; do
    if [ "$i" -ge $((n)) ] && [ "${#files[@]}" -lt "$PER" ]; then files+=("$f"); fi
    i=$((i+1))
  done
  k=${#files[@]}
  out=$(printf 'sheet_%02d.png' "$sheet")
  args=(); fc=""; labels=""; layout=""
  for ((j=0; j<k; j++)); do
    args+=(-i "${files[$j]}")
    fc+="[$j:v]scale=$CW:$CH:force_original_aspect_ratio=decrease,pad=$CW:$CH:(ow-iw)/2:(oh-ih)/2:color=0x202020[s$j];"
    x=$(( (j % COLS) * CW )); y=$(( (j / COLS) * CH ))
    layout+="${x}_${y}|"
    labels+="$(printf '%02d %s\n' "$((j+1))" "${files[$j]}")"$'\n'
  done
  if [ "$k" -eq 1 ]; then
    fc+="[s0]null[out]"
  else
    for ((j=0; j<k; j++)); do fc+="[s$j]"; done
    fc+="xstack=inputs=$k:layout=${layout%|}[out]"
  fi
  ffmpeg -y -loglevel error "${args[@]}" -filter_complex "$fc" -map "[out]" -frames:v 1 "$out"
  { echo "$out"; printf '%s' "$labels"; echo; } >> sheets.txt
  n=$((n+k))
  set -- "$@"
done
echo "$sheet sheet(s), $total dump(s): $DIR/sheets.txt"
