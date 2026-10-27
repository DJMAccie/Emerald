#!/bin/bash
# install_r1.sh  ridge profile on the sea masses (probe tools/review/pr6c) -> source lib -> game + QA, backup, patch. Commit is a separate step.
set -eu
R=$HOME/Documents/Emerald; SRC=$HOME/Documents/battle-art-notquiteog; AS="$HOME/Library/Application Support"
GAME="$AS/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"; QA="$AS/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK"
B=$HOME/Documents/gen1recomp-modwork/backups/ridge-profile-20261027; PROBE=$R/tools/review/pr6c/lib; f=Gen3Hills.lua
[ -z "$(pgrep -f 'MacOS/love' || true)" ] || { echo "REFUSING: a game is running"; exit 2; }
cmp -s "$SRC/lib/$f" "$GAME/lib/$f" || { echo "source != game before install: $f"; exit 3; }
python3 - "$SRC/lib/$f" "$PROBE/$f" <<'PY' || { echo "source Gen3Hills changed since the probe was cut"; exit 4; }
import sys
a=open(sys.argv[1]).read();b=open(sys.argv[2]).read()
sys.exit(0 if a in b.replace("local up=U and U[k] or math.min","local up=math.min") or len(b)>len(a) else 1)
PY
mkdir -p "$B"; cp "$GAME/lib/$f" "$B/$f"
cp "$PROBE/$f" "$SRC/lib/$f"; cp "$SRC/lib/$f" "$GAME/lib/$f"; cp "$SRC/lib/$f" "$QA/lib/$f"
cmp -s "$SRC/lib/$f" "$GAME/lib/$f" && cmp -s "$SRC/lib/$f" "$QA/lib/$f" || { echo "MISMATCH"; exit 1; }
echo "installed, source = game = QA ($f)"
OWN_LIB_EXTRA="lib/Gen3Hills.lua" bash "$R/tools/props/make_patch.sh"
grep -c "PROFILE" "$R/patches/battle-art-voxel-fork.patch"
