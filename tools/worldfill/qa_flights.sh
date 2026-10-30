#!/bin/bash
# QA for task 34 (gap-free ground under Fly): flights in private QA copies, at most 4 at once.
#   tools/worldfill/qa_flights.sh <outroot> "<flight[:flight2]> ..."   (e.g. "long:frontier sea mountain iso")
# Each flight: chase camera, the straight-down overview shot mid-flight, captures + log under <outroot>/<flight>.
set -u
R=$HOME/Documents/Emerald
OUTROOT=$1; FLIGHTS=$2
FILES="Gen3FlyPath.lua Gen3FlyOver.lua Gen3FlyGround.lua assets/worldfill/fill.bin assets/worldfill/placements.lua"
pids=()
for f in $FLIGHTS; do
  name=${f%%:*}; second=; [ "$f" != "$name" ] && second=${f#*:}
  out="$OUTROOT/$name"; mkdir -p "$out"
  ( cd "$R" && env EM_FLIGHT=$name ${second:+EM_FLIGHT2=$second} EM_FLY_TOPDOWN=${TOPDOWN:-9000} EM_FLY_SPECIES=${SPECIES:-18} \
      EM_DRIVER=$R/tools/fly/em_fly_driver.lua QA_LIMIT=300 tools/qa_tryp.sh "$FILES" "$out" "-" 4 0 200 > "$out/tryp.log" 2>&1 ) &
  pids+=($!)
  sleep 3
done
for p in "${pids[@]}"; do wait "$p"; done
for f in $FLIGHTS; do
  name=${f%%:*}; out="$OUTROOT/$name"
  echo "== $name: $(ls "$out"/*.png 2>/dev/null | wc -l | tr -d ' ') shots"
  grep -h "\[FlyGround\]\|ground\b.*chunks\|ground at\|landed\|abort\|frames fly\|frames mount\|frames dismount\|slow ground\|Error\|error" "$out"/run.log 2>/dev/null | cut -c1-220 | head -40
done
