#!/bin/bash
# install_sea.sh   Mossdeep sink (floor field -16, shoal at 0): probe psea2 -> source lib -> game + QA, backup, patch. Commit is a separate step.
set -eu
R=$HOME/Documents/Emerald
SRC=$HOME/Documents/battle-art-notquiteog
AS="$HOME/Library/Application Support"
GAME="$AS/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
QA="$AS/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK"
B=$HOME/Documents/gen1recomp-modwork/backups/mossdeep-sink-20261026
PROBE=$R/tools/classa/psea2/lib
FILES="Gen3Scene.lua Gen3Elevation.lua"
[ -z "$(pgrep -f 'MacOS/love' || true)" ] || { echo "REFUSING: a game is running"; exit 2; }
for f in $FILES; do cmp -s "$SRC/lib/$f" "$GAME/lib/$f" || { echo "source != game before install: $f"; exit 3; }; done
mkdir -p "$B"
for f in $FILES; do cp "$GAME/lib/$f" "$B/$f"; done
cp "$PROBE/Gen3Elevation.lua" "$SRC/lib/Gen3Elevation.lua"
# Gen3Scene: drop the c.base-only Mossdeep rule (9f3be1c) by string edit on the CURRENT source (other sessions edit it)
python3 - "$SRC/lib/Gen3Scene.lua" <<'PY'
import sys
p=sys.argv[1];s=open(p).read()
a=s.index(" -- Mossdeep's shoal (0x19E/0x124/0x1AE, rated 16)");b=s.index(" mark('objects')",a)
open(p,'w').write(s[:a]+s[b:])
PY
for f in $FILES; do cp "$SRC/lib/$f" "$GAME/lib/$f"; cp "$SRC/lib/$f" "$QA/lib/$f"; done
for f in $FILES; do cmp -s "$SRC/lib/$f" "$GAME/lib/$f" && cmp -s "$SRC/lib/$f" "$QA/lib/$f" || { echo "MISMATCH $f"; exit 1; }; done
echo "installed, source = game = QA ($FILES)"
bash "$R/tools/props/make_patch.sh"
grep -c "SINK_MAPS" "$R/patches/battle-art-voxel-fork.patch"
