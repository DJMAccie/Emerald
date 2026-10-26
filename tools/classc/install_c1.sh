#!/bin/bash
# install_c1.sh   class C (Jagged Pass on counted red relief clamp 16 + Sootopolis rim cap 32): probe pc1 -> source lib -> game + QA, backup, patch. Commit is a separate step.
set -eu
R=$HOME/Documents/Emerald
SRC=$HOME/Documents/battle-art-notquiteog
AS="$HOME/Library/Application Support"
GAME="$AS/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
QA="$AS/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK"
B=$HOME/Documents/gen1recomp-modwork/backups/classc-jagged-20261026
PROBE=$R/tools/classc/pc1/lib
FILES="Gen3RockTables.lua Gen3Relief.lua Gen3ReliefData.lua Gen3Rock.lua"
[ -z "$(pgrep -f 'MacOS/love' || true)" ] || { echo "REFUSING: a game is running"; exit 2; }
for f in $FILES; do cmp -s "$SRC/lib/$f" "$GAME/lib/$f" || { echo "source != game before install: $f"; exit 3; }; done
mkdir -p "$B"
for f in $FILES; do cp "$GAME/lib/$f" "$B/$f"; cp "$PROBE/$f" "$SRC/lib/$f"; done
for f in $FILES; do cp "$SRC/lib/$f" "$GAME/lib/$f" 2>/dev/null || true; cp "$SRC/lib/$f" "$QA/lib/$f"; done
for f in $FILES; do cmp -s "$SRC/lib/$f" "$GAME/lib/$f" && cmp -s "$SRC/lib/$f" "$QA/lib/$f" || { echo "MISMATCH $f"; exit 1; }; done
echo "installed, source = game = QA ($FILES)"
OWN_LIB_EXTRA="lib/Gen3RockTables.lua lib/Gen3Relief.lua lib/Gen3Rock.lua" bash "$R/tools/props/make_patch.sh"
