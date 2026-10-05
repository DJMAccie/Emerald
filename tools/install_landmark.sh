#!/usr/bin/env bash
# Install the landmark tool + the modelled truck into the mod source and the
# QA identity's copy of it. The staged files in .qa-stage/landmark/lib are the
# ones every capture in this round was judged from; this promotes exactly
# those, then proves the three installed files are byte-identical to the
# staged ones.
#
#   tools/install_landmark.sh            # mod source + QA
#   DRY=1 tools/install_landmark.sh      # report what would change
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="$ROOT/.qa-stage/landmark/lib"
MOD="${MOD_LIB:-$HOME/Documents/battle-art-notquiteog/lib}"
QA="${QA_LIB:-$HOME/Library/Application Support/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK/lib}"
FILES=(SpriteVoxel.lua LandmarkModels.lua Gen3Scene.lua)

if pgrep -f "MacOS/love" >/dev/null; then
  echo "the game is running (MacOS/love); refusing to install" >&2
  exit 1
fi
for f in "${FILES[@]}"; do
  [ -f "$STAGE/$f" ] || { echo "staged $f missing" >&2; exit 1; }
done
if [ -n "${DRY:-}" ]; then
  echo "would install into $MOD and $QA:"
  for f in "${FILES[@]}"; do echo "  $f"; done
  exit 0
fi

for f in SpriteVoxel.lua LandmarkModels.lua; do
  cp "$STAGE/$f" "$MOD/$f"
done
# The staged Gen3Scene is the installed file plus the landmark hook; applying
# the same anchored edit to the mod's own copy keeps the two identical.
python3 "$ROOT/tools/stage_landmark.py" --src "$MOD" --out "$MOD"
rsync -a "$MOD/" "$QA/"

for f in "${FILES[@]}"; do
  cmp "$STAGE/$f" "$QA/$f" || { echo "MISMATCH after install: $f" >&2; exit 1; }
  printf '%-20s %s bytes  ok\n' "$f" "$(wc -c <"$QA/$f" | tr -d ' ')"
done
echo "installed to $MOD and $QA"
