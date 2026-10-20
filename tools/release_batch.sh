#!/bin/bash
# One QA batch of tools/release_check.sh (run by xargs -P 3):  release_batch.sh <batchdir>
# The batch dir holds maps.txt ("MAP x y" lines). Environment (set by release_check.sh):
#   RC_MODE views|dump|times|floats   RC_FILES  lib files for qa_tryp.sh   RC_SRC  QA_SRC tree (optional)
#   RC_LEVEL ("4,7")  RC_YAW  RC_WAIT  RC_STAGGER (s between starts)  RC_STAMP (shared start-time file)
# Resumable: a batch with a 'done' file is skipped; a watchdog stop leaves it undone so a rerun retries it.
set -u
D=$1
[ -f "$D/done" ] && exit 0
ROOT=$(cd "$(dirname "$0")/.." && pwd)
# stagger: at least RC_STAGGER s between two batch starts
LK=$RC_STAMP.lock
until mkdir "$LK" 2>/dev/null; do sleep 1; done
last=$(cat "$RC_STAMP" 2>/dev/null || echo 0); now=$(date +%s)
[ $((last + RC_STAGGER)) -gt "$now" ] && sleep $((last + RC_STAGGER - now))
date +%s > "$RC_STAMP"; rmdir "$LK"
export QA_ZOOM=-2 QA_LIMIT=400
rm -rf "$D/out"
case $RC_MODE in
  views)
    cases=$(awk '{printf "{\x27%s\x27,%s,%s},",$1,$2,$3}' "$D/maps.txt")
    QA_SRC=${RC_SRC:-} ; [ -z "$QA_SRC" ] && unset QA_SRC || export QA_SRC
    "$ROOT/tools/qa_tryp.sh" "$RC_FILES" "$D/out" "$cases" "$RC_LEVEL" "$RC_YAW" "$RC_WAIT" > "$D/summary.txt" 2>&1 ;;
  dump)
    EM_DRIVER="$ROOT/tools/em_cells_driver.lua" EM_MAPS="$D/maps.txt" EM_DUMP="$D/dump.txt" EM_DUMP_WAIT=300 \
      "$ROOT/tools/qa_tryp.sh" "$RC_FILES" "$D/out" - 4 0 60 > "$D/summary.txt" 2>&1 ;;
  times)
    EM_DRIVER="$ROOT/tools/em_times_driver_all.lua" EM_MAPS="$D/maps.txt" EM_LEVEL=4 \
      "$ROOT/tools/qa_tryp.sh" "$RC_FILES" "$D/out" - 4 0 60 > "$D/summary.txt" 2>&1 ;;
  floats)
    EM_DRIVER="$ROOT/tools/em_float_driver.lua" EM_MAPS="$D/maps.txt" \
      "$ROOT/tools/qa_tryp.sh" "$RC_FILES" "$D/out" - 4 0 60 > "$D/summary.txt" 2>&1 ;;
esac
grep -q WATCHDOG "$D/out/run.log" 2>/dev/null || touch "$D/done"
