#!/bin/bash
# install_s1.sh  stair art is never a rock lid (probe tools/stairs/probe6, Gen3Rock.lua) -> source lib -> game + QA, backup, patch. Commit is a separate step.
set -eu
R=$HOME/Documents/Emerald; SRC=$HOME/Documents/battle-art-notquiteog; AS="$HOME/Library/Application Support"
GAME="$AS/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"; QA="$AS/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK"
B=$HOME/Documents/gen1recomp-modwork/backups/stairs-20261027; PROBE=$R/tools/stairs/probe6/lib; f=Gen3Rock.lua
[ -z "$(pgrep -f 'MacOS/love' || true)" ] || { echo "REFUSING: a game is running"; exit 2; }
cmp -s "$SRC/lib/$f" "$GAME/lib/$f" || { echo "source != game before install: $f"; exit 3; }
[ "$(diff "$SRC/lib/$f" "$PROBE/$f" | grep -c '^[<>]')" = 2 ] || { echo "probe differs from source by more than the one line"; exit 4; }
mkdir -p "$B"; cp "$GAME/lib/$f" "$B/$f"
cp "$PROBE/$f" "$SRC/lib/$f"; cp "$SRC/lib/$f" "$GAME/lib/$f"; cp "$SRC/lib/$f" "$QA/lib/$f"
cmp -s "$SRC/lib/$f" "$GAME/lib/$f" && cmp -s "$SRC/lib/$f" "$QA/lib/$f" || { echo "MISMATCH"; exit 1; }
echo "installed, source = game = QA ($f)"
OWN_LIB_EXTRA="lib/Gen3Rock.lua" bash "$R/tools/props/make_patch.sh"
grep -c "n.floor.step" "$R/patches/battle-art-voxel-fork.patch"
