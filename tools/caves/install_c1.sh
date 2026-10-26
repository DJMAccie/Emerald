#!/bin/bash
# install_c1.sh   cave rocks round 1 (classes U/L/S): Gen3Cave.lua whole + ONE line in Gen3Scene.lua of source, game and QA.
# Gen3Scene.lua in the source lib carries another session's work (fly), so it is edited in place by insertion, never overwritten,
# and the patch takes Gen3Scene from the last committed patch plus the same line (make_patch_c1.sh).
set -eu
R=$HOME/Documents/Emerald
SRC=$HOME/Documents/battle-art-notquiteog
AS="$HOME/Library/Application Support"
GAME="$AS/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
QA="$AS/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK"
B=$HOME/Documents/gen1recomp-modwork/backups/caves-20261026
PROBE=$R/tools/caves/probe/lib
[ -z "$(pgrep -f 'MacOS/love' || true)" ] || { echo "REFUSING: a game is running"; exit 2; }
cmp -s "$SRC/lib/Gen3Cave.lua" "$GAME/lib/Gen3Cave.lua" || { echo "source != game before install: Gen3Cave.lua"; exit 3; }
mkdir -p "$B"
cp "$GAME/lib/Gen3Cave.lua" "$B/Gen3Cave.lua"; cp "$GAME/lib/Gen3Scene.lua" "$B/Gen3Scene.lua"
for d in "$SRC" "$GAME" "$QA"; do cp "$PROBE/Gen3Cave.lua" "$d/lib/Gen3Cave.lua"; done
for d in "$SRC" "$GAME" "$QA"; do
python3 - "$d/lib/Gen3Scene.lua" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
call="V.require('Gen3Cave').settle(def,cells)"
if call in s: print('already', p); sys.exit(0)
a="  end\n end\n -- (a town's wall tiles are masonry (Gen3Masonry)"
assert s.count(a)==1, p
open(p,'w').write(s.replace(a,"  end\n  "+call+"\n end\n -- (a town's wall tiles are masonry (Gen3Masonry)"))
print('patched', p)
PY
done
cmp -s "$SRC/lib/Gen3Cave.lua" "$GAME/lib/Gen3Cave.lua" && cmp -s "$SRC/lib/Gen3Cave.lua" "$QA/lib/Gen3Cave.lua" || { echo MISMATCH; exit 1; }
echo "installed Gen3Cave + settle line (source, game, QA)"
OWN_LIB_EXTRA="lib/Gen3Cave.lua" bash "$R/tools/caves/make_patch_c1.sh"
