#!/bin/bash
# install_c2.sh   class C Sootopolis (crater banks as one rolling hill): Gen3Hills.lua (own file, copied from probe ps1) + ONE hunk in the CURRENT Gen3Rock.lua
# (the other class C session also changes Gen3Rock, so the hunk is applied to whatever the source has now, never a probe copy).
set -eu
R=$HOME/Documents/Emerald
SRC=$HOME/Documents/battle-art-notquiteog
AS="$HOME/Library/Application Support"
GAME="$AS/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
QA="$AS/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK"
B=$HOME/Documents/gen1recomp-modwork/backups/classc-sootopolis-20261026
PROBE=$R/tools/classc/ps1/lib
[ -z "$(pgrep -f 'MacOS/love' || true)" ] || { echo "REFUSING: a game is running"; exit 2; }
for f in Gen3Hills.lua Gen3Rock.lua; do cmp -s "$SRC/lib/$f" "$GAME/lib/$f" || { echo "source != game before install: $f"; exit 3; }; done
mkdir -p "$B"; for f in Gen3Hills.lua Gen3Rock.lua; do cp "$GAME/lib/$f" "$B/$f"; done
cp "$PROBE/Gen3Hills.lua" "$SRC/lib/Gen3Hills.lua"
python3 - "$SRC/lib/Gen3Rock.lua" <<'P'
import sys
p=sys.argv[1]; s=open(p).read()
old=" if not (M.enabled and mass and not mass.object and not mass.bank) then return false end"
new=" if not (M.enabled and mass and not mass.object and not (mass.bank and not V.require('Gen3Hills').bankOk(mass))) then return false end"
assert s.count(old)==1, 'Gen3Rock handles() line not found exactly once'
open(p,'w').write(s.replace(old,new))
P
for f in Gen3Hills.lua Gen3Rock.lua; do luajit -bl "$SRC/lib/$f" >/dev/null; cp "$SRC/lib/$f" "$GAME/lib/$f"; cp "$SRC/lib/$f" "$QA/lib/$f"; done
for f in Gen3Hills.lua Gen3Rock.lua; do cmp -s "$SRC/lib/$f" "$GAME/lib/$f" && cmp -s "$SRC/lib/$f" "$QA/lib/$f" || { echo "MISMATCH $f"; exit 1; }; done
echo "installed, source = game = QA (Gen3Hills.lua Gen3Rock.lua)"
OWN_LIB_EXTRA="lib/Gen3Hills.lua lib/Gen3Rock.lua" bash "$R/tools/props/make_patch.sh"
grep -c bankOk "$R/patches/battle-art-voxel-fork.patch"
