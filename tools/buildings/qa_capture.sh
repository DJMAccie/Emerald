#!/bin/bash
# QA capture at the player's camera (level 4, zoom 0). Kept for old callers:
#   tools/buildings/qa_capture.sh <outdir> "{'EM_SLATEPORT_CITY',28,40},..."
# It goes through tools/qa_run.sh (shared lock + watchdog). For turned or low
# views call qa_run.sh directly with level 7 or 6 and a yaw.
exec "$(dirname "$0")/../qa_run.sh" "$1" "$2" 4 0 "${3:-60}"
