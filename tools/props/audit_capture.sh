#!/bin/bash
# Capture every case in OUTDIR/cases.lua on the QA identity, indexed bNNN.png (several cases may share a map).
#   EM_LEVEL=4|6|7  EM_YAW=<radians>  EM_WAIT=<frames per case>  tools/props/audit_capture.sh OUTDIR
# level 4 = the player's camera, 7 = orbit (yaw only works here), 6 = low near-ground camera.
# EM_PITCH=<rad> (with EM_LEVEL=7 and EM_DRIVER=tools/props/views_driver.lua): 0.16 low, ~1.4 top-down
#
# A thin wrapper over tools/qa_run.sh (parallel slots, offscreen background window, update-payload
# restore, watchdog). Differences: cases come from OUTDIR/cases.lua, indexed file names, and a
# watchdog that scales with the number of cases (QA_LIMIT overrides).
set -u
OUT=$1
WAIT=${EM_WAIT:-40}
N=$(grep -o "{'" "$OUT/cases.lua" | wc -l | tr -d ' ')
export QA_LIMIT=${QA_LIMIT:-$(( 60 + N * (WAIT / 8 + 12) ))}
export EM_INDEXED=1
exec "$(dirname "$0")/../qa_run.sh" "$OUT" - "${EM_LEVEL:-4}" "${EM_YAW:-0}" "$WAIT"
