#!/bin/bash
# install_fly.sh   task 29 (Fly flight): source lib -> game + QA, backup, patch. Commit is a separate step.
# The source lib is the truth (edited in place): the two new files and the two hooked ones are copied to the game
# and to main QA. Refuses while the REAL game runs (QA runs of other sessions are fine: they use a private identity),
# and while the game's copies of the two hooked files are not the ones the hooks were written against.
set -eu
R=$HOME/Documents/Emerald
SRC=$HOME/Documents/battle-art-notquiteog
AS="$HOME/Library/Application Support"
GAME="$AS/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
QA="$AS/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK"
B=$HOME/Documents/gen1recomp-modwork/backups/flyover-20261026
FILES="Gen3FlyPath.lua Gen3FlyOver.lua Gen3Scene.lua Gen3Integration.lua"
# the game's copies the hooks were written against (sha1, 2026-10-26 20:06, after the caves one-liner)
SCENE_SHA=7aa18619e1a955fd0ddafc66b2cb2db97e0f3b57
INTEG_SHA=d7b6e5840ca2df74e96463a3b3980f346dad798d
for p in $(pgrep -f 'MacOS/love' || true); do
  ps eww -p "$p" 2>/dev/null | grep -q 'POKEPORT_IDENTITY=pokemon-love2d-rseqa' || { echo "REFUSING: the real game runs (pid $p)"; exit 2; }
done
[ "$(shasum "$GAME/lib/Gen3Scene.lua" | cut -d' ' -f1)" = "$SCENE_SHA" ] || { echo "game Gen3Scene.lua changed since the hooks were written: merge first"; exit 3; }
[ "$(shasum "$GAME/lib/Gen3Integration.lua" | cut -d' ' -f1)" = "$INTEG_SHA" ] || { echo "game Gen3Integration.lua changed since the hooks were written: merge first"; exit 3; }
for f in $FILES; do luajit -bl "$SRC/lib/$f" > /dev/null || { echo "does not compile: $f"; exit 4; }; done
grep -q "Gen3FlyOver" "$SRC/lib/Gen3Scene.lua" && grep -q "Gen3FlyOver" "$SRC/lib/Gen3Integration.lua" || { echo "the source hooks are missing"; exit 5; }
mkdir -p "$B"
for f in Gen3Scene.lua Gen3Integration.lua; do cp "$GAME/lib/$f" "$B/$f"; done
for f in $FILES; do cp "$SRC/lib/$f" "$GAME/lib/$f"; cp "$SRC/lib/$f" "$QA/lib/$f"; done
for f in $FILES; do cmp -s "$SRC/lib/$f" "$GAME/lib/$f" && cmp -s "$SRC/lib/$f" "$QA/lib/$f" || { echo "MISMATCH $f"; exit 1; }; done
echo "installed, source = game = QA ($FILES); originals in $B"
OWN_LIB_EXTRA="lib/Gen3FlyPath.lua lib/Gen3FlyOver.lua lib/Gen3Scene.lua lib/Gen3Integration.lua" bash "$R/tools/props/make_patch.sh"
echo "Gen3FlyOver hunks in the patch: $(grep -c 'Gen3FlyOver' "$R/patches/battle-art-voxel-fork.patch")"
