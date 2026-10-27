#!/bin/bash
# install_trees.sh   task 34 (0): Gen3Elevation only (pin flood claims tree cells) -> game + QA, backup, patch. Game must be closed.
# Gen3PinData is NOT touched (the game's 43-map data stays; new pin files are a separate bake round).
set -eu
R=$HOME/Documents/Emerald
SRC=$HOME/Documents/battle-art-notquiteog
AS="$HOME/Library/Application Support"
GAME="$AS/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
QA="$AS/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK"
B=${B_OVERRIDE:-$HOME/Documents/gen1recomp-modwork/backups/pins-trees-20261027}
[ -z "$(pgrep -f 'MacOS/love' || true)" ] || { echo "REFUSING: a game is running"; exit 2; }
mkdir -p "$B"
f=Gen3Elevation.lua
cmp -s "$GAME/lib/$f" "$QA/lib/$f" || { echo "game/QA differ before install: $f"; exit 3; }
cp "$GAME/lib/$f" "$B/$f"
luajit -bl "$SRC/lib/$f" /dev/null
cp "$SRC/lib/$f" "$GAME/lib/$f"; cp "$SRC/lib/$f" "$QA/lib/$f"
cmp -s "$SRC/lib/$f" "$GAME/lib/$f" && cmp -s "$SRC/lib/$f" "$QA/lib/$f" || { echo "MISMATCH $f"; exit 1; }
echo "installed Gen3Elevation, source = game = QA; backup $B (revert = copy it back)"
OWN_LIB_EXTRA="lib/Gen3PinData.lua lib/Gen3Elevation.lua lib/Gen3Relief.lua" bash "$R/tools/props/make_patch.sh"
