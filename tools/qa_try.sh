#!/bin/bash
# Try source files in QA without installing them, safely:
#   tools/qa_try.sh "Gen3Elevation.lua TerrainLevels.lua" <outdir> "<cases>" [level] [yaw] [wait]
# Takes the shared lock, copies the named lib files from the mod source into
# QA, runs tools/qa_run.sh, and ALWAYS restores QA's own copies afterwards.
set -u
FILES=$1; shift
LOCK=/tmp/emerald-qa.lock
QA="$HOME/Library/Application Support/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK"
M=~/Documents/battle-art-notquiteog
BAK=$(mktemp -d)
until mkdir "$LOCK" 2>/dev/null; do
  if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +10 2>/dev/null)" ]; then rm -rf "$LOCK"; continue; fi
  sleep 3
done
echo "$$ qa_try $1" > "$LOCK/owner"
restore(){ for f in $FILES; do cp "$BAK/$f" "$QA/lib/$f"; done; rm -rf "$BAK" "$LOCK"; }
trap restore EXIT
for f in $FILES; do cp "$QA/lib/$f" "$BAK/$f"; cp "$M/lib/$f" "$QA/lib/$f"; done
QA_HELD=1 "$(dirname "$0")/qa_run.sh" "$@"
