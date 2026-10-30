#!/bin/bash
# install_ground.sh   task 34 (gap-free Hoenn under Fly): Gen3FlyGround + Gen3FlyOver + Gen3FlyPath and the world
# fill (assets/worldfill/, gitignored, from tools/worldfill/make_fill.py) -> game + QA.
# Without the fill the flight falls back to its task 29 carpet. Refuses while the REAL game runs (private QA copies
# are fine). The two hooked files (Gen3Scene, Gen3Integration) are task 29's: only checked, never copied.
set -eu
R=$HOME/Documents/Emerald
SRC=$HOME/Documents/battle-art-notquiteog
AS="$HOME/Library/Application Support"
GAME="$AS/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
QA="$AS/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK"
B=$HOME/Documents/gen1recomp-modwork/backups/flyground-$(date +%Y%m%d)
FILES="Gen3FlyPath.lua Gen3FlyOver.lua Gen3FlyGround.lua"
for p in $(pgrep -f 'MacOS/love' || true); do
  ps eww -p "$p" 2>/dev/null | grep -q 'POKEPORT_IDENTITY=pokemon-love2d-rseqa' || { echo "REFUSING: the real game runs (pid $p)"; exit 2; }
done
grep -q "Gen3FlyOver" "$GAME/lib/Gen3Scene.lua" && grep -q "Gen3FlyOver" "$GAME/lib/Gen3Integration.lua" || { echo "the game lacks the task 29 hooks"; exit 3; }
for f in $FILES; do luajit -bl "$SRC/lib/$f" > /dev/null || { echo "does not compile: $f"; exit 4; }; done
(cd "$SRC" && luajit tests/gen3_flypath_test.lua | tail -1 && luajit tests/gen3_flyground_test.lua | tail -1)
[ -f "$SRC/assets/worldfill/fill.bin" ] && [ -f "$SRC/assets/worldfill/placements.lua" ] || { echo "no world fill: run tools/worldfill/make_fill.py"; exit 5; }
mkdir -p "$B"
for f in $FILES; do [ -f "$GAME/lib/$f" ] && cp "$GAME/lib/$f" "$B/$f"; done
for D in "$GAME" "$QA"; do
  mkdir -p "$D/assets/worldfill"
  cp "$SRC/assets/worldfill/fill.bin" "$SRC/assets/worldfill/placements.lua" "$D/assets/worldfill/"
  for f in $FILES; do cp "$SRC/lib/$f" "$D/lib/$f"; done
done
for f in $FILES; do cmp -s "$SRC/lib/$f" "$GAME/lib/$f" && cmp -s "$SRC/lib/$f" "$QA/lib/$f" || { echo "MISMATCH $f"; exit 1; }; done
for f in fill.bin placements.lua; do
  cmp -s "$SRC/assets/worldfill/$f" "$GAME/assets/worldfill/$f" && cmp -s "$SRC/assets/worldfill/$f" "$QA/assets/worldfill/$f" || { echo "MISMATCH $f"; exit 1; }
done
echo "installed: source = game = QA ($FILES + assets/worldfill); originals in $B"
OWN_LIB_EXTRA="lib/Gen3FlyPath.lua lib/Gen3FlyOver.lua lib/Gen3FlyGround.lua lib/Gen3Scene.lua lib/Gen3Integration.lua" bash "$R/tools/props/make_patch.sh"
echo "Gen3FlyGround hunks in the patch: $(grep -c 'Gen3FlyGround' "$R/patches/battle-art-voxel-fork.patch")"
