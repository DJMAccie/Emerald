#!/bin/bash
# install_a1.sh   class A round 1 (Gen3Hills CLASS_A: Routes 126/121/129/130, Sky Pillar, Mossdeep): probe pa2 -> source lib -> game + QA, backup, patch. Commit is a separate step.
set -eu
R=$HOME/Documents/Emerald
SRC=$HOME/Documents/battle-art-notquiteog
AS="$HOME/Library/Application Support"
GAME="$AS/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
QA="$AS/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK"
B=$HOME/Documents/gen1recomp-modwork/backups/class-a-r1-20261026
PROBE=$R/tools/classa/pa2/lib
f=Gen3Hills.lua
[ -z "$(pgrep -f 'MacOS/love' || true)" ] || { echo "REFUSING: a game is running"; exit 2; }
cmp -s "$SRC/lib/$f" "$GAME/lib/$f" || { echo "source != game before install: $f"; exit 3; }
# the probe is the source plus the CLASS_A block: refuse if the source moved since
python3 - "$SRC/lib/$f" "$PROBE/$f" <<'PY' || { echo "source Gen3Hills changed since the probe was cut"; exit 4; }
import sys,re
a=open(sys.argv[1]).read();b=open(sys.argv[2]).read()
i=b.index("\n-- (class A)");j=b.index("M.PARAMS.EM_SKY_PILLAR_OUTSIDE.HMAX=48")+len("M.PARAMS.EM_SKY_PILLAR_OUTSIDE.HMAX=48")
sys.exit(0 if b[:i]+b[j:]==a else 1)
PY
mkdir -p "$B"; cp "$GAME/lib/$f" "$B/$f"
cp "$PROBE/$f" "$SRC/lib/$f"; cp "$SRC/lib/$f" "$GAME/lib/$f"; cp "$SRC/lib/$f" "$QA/lib/$f"
cmp -s "$SRC/lib/$f" "$GAME/lib/$f" && cmp -s "$SRC/lib/$f" "$QA/lib/$f" || { echo "MISMATCH"; exit 1; }
echo "installed, source = game = QA ($f)"
OWN_LIB_EXTRA="lib/Gen3Hills.lua" bash "$R/tools/props/make_patch.sh"
grep -c "CLASS_A" "$R/patches/battle-art-voxel-fork.patch"
