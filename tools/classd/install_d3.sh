#!/bin/bash
# install_d3.sh   item 21 flat rock-edge strips: Gen3Relief STRIP rule (probe tools/classd/p4) -> source lib -> game + QA, backup, patch. Commit is a separate step.
set -eu
R=$HOME/Documents/Emerald
SRC=$HOME/Documents/battle-art-notquiteog
AS="$HOME/Library/Application Support"
GAME="$AS/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
QA="$AS/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK"
B=$HOME/Documents/gen1recomp-modwork/backups/rock-edge-strips-20261027
PROBE=$R/tools/classd/p4
f=Gen3Relief.lua
[ -z "$(pgrep -f 'MacOS/love' || true)" ] || { echo "REFUSING: a game is running"; exit 2; }
cmp -s "$SRC/lib/$f" "$GAME/lib/$f" && cmp -s "$SRC/lib/$f" "$QA/lib/$f" || { echo "source/game/QA differ before install: $f"; exit 3; }
del=$(diff "$SRC/lib/$f" "$PROBE/lib/$f" | grep -c '^<' || true)
[ "$del" = 0 ] || { echo "source $f changed since the probe was cut (-$del)"; exit 4; }
luajit -bl "$PROBE/lib/$f" >/dev/null
mkdir -p "$B"; cp "$GAME/lib/$f" "$B/$f"
cp "$PROBE/lib/$f" "$SRC/lib/$f"; cp "$SRC/lib/$f" "$GAME/lib/$f"; cp "$SRC/lib/$f" "$QA/lib/$f"
cmp -s "$SRC/lib/$f" "$GAME/lib/$f" && cmp -s "$SRC/lib/$f" "$QA/lib/$f" || { echo "MISMATCH $f"; exit 1; }
echo "installed, source = game = QA ($f)"
bash "$R/tools/props/make_patch.sh"
