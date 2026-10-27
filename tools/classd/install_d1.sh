#!/bin/bash
# install_d1.sh   class D card H1: Gen3Scene ledge-corner smoothing (probe tools/classd/p1) -> source lib -> game + QA, backup, patch. Commit is a separate step.
set -eu
R=$HOME/Documents/Emerald
SRC=$HOME/Documents/battle-art-notquiteog
AS="$HOME/Library/Application Support"
GAME="$AS/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
QA="$AS/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK"
B=$HOME/Documents/gen1recomp-modwork/backups/class-d-h1-20261027
PROBE=$R/tools/classd/p1/lib
f=Gen3Scene.lua
[ -z "$(pgrep -f 'MacOS/love' || true)" ] || { echo "REFUSING: a game is running"; exit 2; }
cmp -s "$SRC/lib/$f" "$GAME/lib/$f" && cmp -s "$SRC/lib/$f" "$QA/lib/$f" || { echo "source/game/QA differ before install: $f"; exit 3; }
python3 - "$SRC/lib/$f" "$PROBE/$f" <<'PY' || { echo "source Gen3Scene changed since the probe was cut"; exit 4; }
import sys
a=open(sys.argv[1]).read();b=open(sys.argv[2]).read()
old="    local a,b,d,e=open(cells[(i-1)..':'..(j-1)]),open(cells[i..':'..(j-1)]),open(cells[(i-1)..':'..j]),open(cells[i..':'..j])\n"
i=b.index("    local ka,kb,kd,ke=");j=b.index("    if a and b and d and e then",i)
sys.exit(0 if b[:i]+old+b[j:]==a else 1)
PY
mkdir -p "$B"; cp "$GAME/lib/$f" "$B/$f"
cp "$PROBE/$f" "$SRC/lib/$f"; cp "$SRC/lib/$f" "$GAME/lib/$f"; cp "$SRC/lib/$f" "$QA/lib/$f"
cmp -s "$SRC/lib/$f" "$GAME/lib/$f" && cmp -s "$SRC/lib/$f" "$QA/lib/$f" || { echo "MISMATCH"; exit 1; }
echo "installed, source = game = QA ($f)"
bash "$R/tools/props/make_patch.sh"
