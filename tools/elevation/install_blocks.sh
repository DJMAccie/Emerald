#!/bin/bash
# install_blocks.sh   task 34 (0b): Gen3Blocks (new) + Gen3Elevation (classifier, BORDER) + Gen3Scene (hooks) + Gen3PinData
# -> game + QA, backup, patch. Commit is a separate step. Game must be closed.
set -eu
R=$HOME/Documents/Emerald
SRC=$HOME/Documents/battle-art-notquiteog
AS="$HOME/Library/Application Support"
GAME="$AS/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
QA="$AS/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK"
B=${B_OVERRIDE:-$HOME/Documents/gen1recomp-modwork/backups/blocks-r1-20261027}
[ -z "$(pgrep -f 'MacOS/love' || true)" ] || { echo "REFUSING: a game is running"; exit 2; }
mkdir -p "$B"
# EXTRA="TerrainLevels.lua Gen3CamClear.lua": more lib files to carry in the same install (backed up, copied, in the patch)
EXTRA=${EXTRA:-}
for f in Gen3Elevation.lua Gen3Scene.lua Gen3PinData.lua $EXTRA; do
  cmp -s "$GAME/lib/$f" "$QA/lib/$f" || { echo "game/QA differ before install: $f"; exit 3; }
  cp "$GAME/lib/$f" "$B/$f"
done
[ -f "$GAME/lib/Gen3Blocks.lua" ] && cp "$GAME/lib/Gen3Blocks.lua" "$B/Gen3Blocks.lua"
for f in Gen3Elevation.lua Gen3Scene.lua Gen3PinData.lua Gen3Blocks.lua $EXTRA; do
  luajit -bl "$SRC/lib/$f" /dev/null
  cp "$SRC/lib/$f" "$GAME/lib/$f"; cp "$SRC/lib/$f" "$QA/lib/$f"
  cmp -s "$SRC/lib/$f" "$GAME/lib/$f" && cmp -s "$SRC/lib/$f" "$QA/lib/$f" || { echo "MISMATCH $f"; exit 1; }
done
echo "installed, source = game = QA (Gen3Elevation Gen3Scene Gen3PinData Gen3Blocks $EXTRA); backup $B (revert = copy the three back, delete Gen3Blocks)"
OWN_LIB_EXTRA="lib/Gen3PinData.lua lib/Gen3Elevation.lua lib/Gen3Relief.lua lib/Gen3Blocks.lua $(for f in $EXTRA; do printf "lib/%s " "$f"; done)" bash "$R/tools/props/make_patch.sh"
