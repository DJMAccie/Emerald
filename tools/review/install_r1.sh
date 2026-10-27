#!/bin/bash
# install_r1.sh  review pass round 1: Gen3Hills CLASS_A += EM_ROUTE117 (probe tools/review/pr4) -> source lib -> game + QA, backup, patch. Commit is a separate step.
set -eu
R=$HOME/Documents/Emerald; SRC=$HOME/Documents/battle-art-notquiteog; AS="$HOME/Library/Application Support"
GAME="$AS/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"; QA="$AS/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK"
B=$HOME/Documents/gen1recomp-modwork/backups/review-20261026; PROBE=$R/tools/review/pr4/lib; f=Gen3Hills.lua
[ -z "$(pgrep -f 'MacOS/love' || true)" ] || { echo "REFUSING: a game is running"; exit 2; }
cmp -s "$SRC/lib/$f" "$GAME/lib/$f" || { echo "source != game before install: $f"; exit 3; }
python3 - "$SRC/lib/$f" "$PROBE/$f" <<'PY' || { echo "source Gen3Hills changed since the probe was cut"; exit 4; }
import sys
a=open(sys.argv[1]).read();b=open(sys.argv[2]).read()
sys.exit(0 if b.replace("M.CLASS_A={'EM_ROUTE117',","M.CLASS_A={",1)==a else 1)
PY
mkdir -p "$B"; cp "$GAME/lib/$f" "$B/$f"
cp "$PROBE/$f" "$SRC/lib/$f"; cp "$SRC/lib/$f" "$GAME/lib/$f"; cp "$SRC/lib/$f" "$QA/lib/$f"
cmp -s "$SRC/lib/$f" "$GAME/lib/$f" && cmp -s "$SRC/lib/$f" "$QA/lib/$f" || { echo "MISMATCH"; exit 1; }
echo "installed, source = game = QA ($f)"
OWN_LIB_EXTRA="lib/Gen3Hills.lua" bash "$R/tools/props/make_patch.sh"
grep -c "EM_ROUTE117" "$R/patches/battle-art-voxel-fork.patch"
