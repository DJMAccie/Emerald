#!/bin/bash
# install_d2.sh   task 20 camera collision: Gen3CamClear (new) + Gen3Scene hooks (probe tools/classd/p2) -> source lib -> game + QA, backup, patch. Commit is a separate step.
set -eu
R=$HOME/Documents/Emerald
SRC=$HOME/Documents/battle-art-notquiteog
AS="$HOME/Library/Application Support"
GAME="$AS/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
QA="$AS/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK"
B=$HOME/Documents/gen1recomp-modwork/backups/camera-collision-20261027
PROBE=$R/tools/classd/p2
f=Gen3Scene.lua
[ -z "$(pgrep -f 'MacOS/love' || true)" ] || { echo "REFUSING: a game is running"; exit 2; }
cmp -s "$SRC/lib/$f" "$GAME/lib/$f" && cmp -s "$SRC/lib/$f" "$QA/lib/$f" || { echo "source/game/QA differ before install: $f"; exit 3; }
# the probe must be the source plus exactly the camera hooks (9 added lines, none removed)
add=$(diff "$SRC/lib/$f" "$PROBE/lib/$f" | grep -c '^>' || true); del=$(diff "$SRC/lib/$f" "$PROBE/lib/$f" | grep -c '^<' || true)
[ "$add" = 9 ] && [ "$del" = 0 ] || { echo "source Gen3Scene changed since the probe was cut (+$add -$del)"; exit 4; }
(cd "$PROBE" && luajit tests/gen3_camclear_test.lua)
mkdir -p "$B"; cp "$GAME/lib/$f" "$B/$f"
for t in lib/Gen3Scene.lua lib/Gen3CamClear.lua; do
  cp "$PROBE/$t" "$SRC/$t"; cp "$SRC/$t" "$GAME/$t"; cp "$SRC/$t" "$QA/$t"
  cmp -s "$SRC/$t" "$GAME/$t" && cmp -s "$SRC/$t" "$QA/$t" || { echo "MISMATCH $t"; exit 1; }
done
cp "$PROBE/tests/gen3_camclear_test.lua" "$SRC/tests/gen3_camclear_test.lua"
echo "installed, source = game = QA (Gen3Scene.lua Gen3CamClear.lua)"
OWN_LIB_EXTRA="lib/Gen3CamClear.lua tests/gen3_camclear_test.lua" bash "$R/tools/props/make_patch.sh"
