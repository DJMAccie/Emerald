#!/bin/bash
# install_b1.sh   class B round 2 install (probe p3 -> source lib -> game + QA), backup, patch. Commit is a separate step.
set -eu
R=$HOME/Documents/Emerald
SRC=$HOME/Documents/battle-art-notquiteog
AS="$HOME/Library/Application Support"
GAME="$AS/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
QA="$AS/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK"
B=$HOME/Documents/gen1recomp-modwork/backups/sea-rock-r2-20261025
PROBE=$R/tools/searock/p5/lib
FILES="Gen3Rock.lua Gen3Mass.lua"
[ -z "$(pgrep -f 'MacOS/love' || true)" ] || { echo "REFUSING: a game is running"; exit 2; }
for f in $FILES; do cmp -s "$SRC/lib/$f" "$GAME/lib/$f" || { echo "source != game before install: $f"; exit 3; }; done
mkdir -p "$B"
for f in $FILES; do cp "$GAME/lib/$f" "$B/$f"; cp "$PROBE/$f" "$SRC/lib/$f"; done
for f in $FILES; do cp "$SRC/lib/$f" "$GAME/lib/$f"; cp "$SRC/lib/$f" "$QA/lib/$f"; done
for f in $FILES; do cmp -s "$SRC/lib/$f" "$GAME/lib/$f" && cmp -s "$SRC/lib/$f" "$QA/lib/$f" || { echo "MISMATCH $f"; exit 1; }; done
echo "installed, source = game = QA ($FILES)"
OWN_LIB_EXTRA="lib/Gen3Rock.lua lib/Gen3Mass.lua" bash "$R/tools/props/make_patch.sh"
echo "patch files: $(grep -c '^diff' "$R/patches/battle-art-voxel-fork.patch")"; grep -c "FLANKRUN" "$R/patches/battle-art-voxel-fork.patch"
