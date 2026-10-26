#!/bin/bash
# install_c2.sh   cave rocks round 2 (Sky Pillar boulders at story state 2, wall caps): Gen3Cave.lua whole, source + game + QA, then the patch.
set -eu
R=$HOME/Documents/Emerald
SRC=$HOME/Documents/battle-art-notquiteog
AS="$HOME/Library/Application Support"
GAME="$AS/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
QA="$AS/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK"
B=$HOME/Documents/gen1recomp-modwork/backups/caves-r2-$(date +%Y%m%d)
PROBE=$R/tools/caves/probe/lib
[ -z "$(pgrep -f 'MacOS/love' || true)" ] || { echo "REFUSING: a game is running"; exit 2; }
cmp -s "$SRC/lib/Gen3Cave.lua" "$GAME/lib/Gen3Cave.lua" || { echo "source != game before install: Gen3Cave.lua"; exit 3; }
mkdir -p "$B"; cp "$GAME/lib/Gen3Cave.lua" "$B/Gen3Cave.lua"
for d in "$SRC" "$GAME" "$QA"; do cp "$PROBE/Gen3Cave.lua" "$d/lib/Gen3Cave.lua"; done
cmp -s "$SRC/lib/Gen3Cave.lua" "$GAME/lib/Gen3Cave.lua" && cmp -s "$SRC/lib/Gen3Cave.lua" "$QA/lib/Gen3Cave.lua" || { echo MISMATCH; exit 1; }
echo "installed Gen3Cave (source, game, QA)"
bash "$R/tools/caves/make_patch_c2.sh"
