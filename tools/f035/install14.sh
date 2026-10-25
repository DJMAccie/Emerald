#!/bin/bash
# install14.sh   Task 14 install (probe tree -> source lib -> game + QA), backup, patch, checks.
# Standing rule: back up the real files, copy into BOTH the game and QA, diff must be empty, then regenerate
# the patch. Nothing is committed here (the Emerald repo commit is a separate step).
set -eu
R=$HOME/Documents/Emerald
SRC=$HOME/Documents/battle-art-notquiteog
AS="$HOME/Library/Application Support"
GAME="$AS/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
QA="$AS/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK"
B=$HOME/Documents/gen1recomp-modwork/backups/trees-general-20261021
PROBE=$R/tools/f035/probe/lib
FILES="Gen3TreeStamps.lua Gen3Rock.lua Gen3Relief.lua Gen3Elevation.lua"
[ -z "$(pgrep -f 'MacOS/love' || true)" ] || { echo "REFUSING: a game is running"; exit 2; }
mkdir -p "$B"
for f in $FILES; do
  cp "$GAME/lib/$f" "$B/$f"                 # backup of the installed versions
  cp "$PROBE/$f" "$SRC/lib/$f"              # the gated probe files become the source
done
for f in $FILES; do
  cp "$SRC/lib/$f" "$GAME/lib/$f"
  cp "$SRC/lib/$f" "$QA/lib/$f"
done
for f in $FILES; do
  cmp -s "$SRC/lib/$f" "$GAME/lib/$f" || { echo "MISMATCH source/game $f"; exit 1; }
  cmp -s "$SRC/lib/$f" "$QA/lib/$f" || { echo "MISMATCH source/QA $f"; exit 1; }
done
echo "installed, source = game = QA ($FILES)"
OWN_LIB_EXTRA="lib/Gen3TreeStamps.lua lib/Gen3Rock.lua lib/Gen3Relief.lua lib/Gen3Elevation.lua" \
  bash "$R/tools/props/make_patch.sh"
echo "--- patch mentions:"
grep -c "crownFloor" "$R/patches/battle-art-voxel-fork.patch" || true
grep -c "M.tileArt=tile" "$R/patches/battle-art-voxel-fork.patch" || true
echo "--- patch files: $(grep -c '^diff' "$R/patches/battle-art-voxel-fork.patch")"
