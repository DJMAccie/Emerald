#!/bin/bash
# install_flyart.sh   task 32 (fly art per species): Gen3FlyOver/Gen3FlyPath + the baked flight sheets -> game + QA.
#   tools/fly/install_flyart.sh            installs the sheets that were NOT drawn for this mod (follower-mod flying
#                                          poses, PMD walk flyers): the 25 species with existing art
#   tools/fly/install_flyart.sh --drawn    also installs the 13 drawn species (only after the user approved their sheet)
# The sheets (assets/flyers/, gitignored) come from tools/flysprites/bake_flyers.py; without them, or for a species
# without a sheet, Gen3FlyOver draws the task 29 bird. Refuses while the REAL game runs (private QA copies are fine).
# The two hooked files (Gen3Scene, Gen3Integration) are task 29's and already installed: only checked, never copied.
set -eu
R=$HOME/Documents/Emerald
SRC=$HOME/Documents/battle-art-notquiteog
AS="$HOME/Library/Application Support"
GAME="$AS/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
QA="$AS/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK"
B=$HOME/Documents/gen1recomp-modwork/backups/flyart-20261026
FILES="Gen3FlyPath.lua Gen3FlyOver.lua"
DRAWN=0; [ "${1:-}" = "--drawn" ] && DRAWN=1
for p in $(pgrep -f 'MacOS/love' || true); do
  ps eww -p "$p" 2>/dev/null | grep -q 'POKEPORT_IDENTITY=pokemon-love2d-rseqa' || { echo "REFUSING: the real game runs (pid $p)"; exit 2; }
done
grep -q "Gen3FlyOver" "$GAME/lib/Gen3Scene.lua" && grep -q "Gen3FlyOver" "$GAME/lib/Gen3Integration.lua" || { echo "the game lacks the task 29 hooks"; exit 3; }
for f in $FILES; do luajit -bl "$SRC/lib/$f" > /dev/null || { echo "does not compile: $f"; exit 4; }; done
(cd "$SRC" && luajit tests/gen3_flypath_test.lua | tail -1)
[ -f "$SRC/assets/flyers/manifest.lua" ] || { echo "no baked sheets: run tools/flysprites/bake_flyers.py"; exit 5; }
mkdir -p "$B"
for f in $FILES; do cp "$GAME/lib/$f" "$B/$f"; done
[ -d "$GAME/assets/flyers" ] && cp -R "$GAME/assets/flyers" "$B/flyers-before" || true
# the sheets to install: every baked species, minus the drawn ones until approved
STAGE=$(mktemp -d); trap 'rm -rf "$STAGE"' EXIT
python3 - "$SRC/assets/flyers" "$STAGE" "$DRAWN" "$R/tools/flysprites/flyers.json" <<'PY'
import json, os, re, shutil, sys
src, dst, drawn, table = sys.argv[1], sys.argv[2], sys.argv[3] == '1', sys.argv[4]
skip = set() if drawn else {int(k) for k, v in json.load(open(table)).items() if not k.startswith('_') and v == 'drawn'}
for name in sorted(os.listdir(src)):
    m = re.match(r'(\d+)-(normal|shiny)\.png$', name)
    if m and int(m.group(1)) in skip:
        continue
    if name == 'manifest.lua':
        out = []
        for line in open(os.path.join(src, name)):
            m2 = re.match(r'\s*\[(\d+)\]=', line)
            if not (m2 and int(m2.group(1)) in skip):
                out.append(line)
        open(os.path.join(dst, name), 'w').write(''.join(out))
    elif m or name.endswith('.lua'):
        shutil.copy(os.path.join(src, name), os.path.join(dst, name))
print('staged', len(os.listdir(dst)), 'files; drawn species skipped:', sorted(skip))
PY
for D in "$GAME" "$QA"; do
  rm -rf "$D/assets/flyers"; mkdir -p "$D/assets/flyers"; cp "$STAGE"/* "$D/assets/flyers/"
  for f in $FILES; do cp "$SRC/lib/$f" "$D/lib/$f"; done
done
for f in $FILES; do cmp -s "$SRC/lib/$f" "$GAME/lib/$f" && cmp -s "$SRC/lib/$f" "$QA/lib/$f" || { echo "MISMATCH $f"; exit 1; }; done
cmp -s "$STAGE/manifest.lua" "$GAME/assets/flyers/manifest.lua" && cmp -s "$STAGE/manifest.lua" "$QA/assets/flyers/manifest.lua" || { echo "MISMATCH manifest"; exit 1; }
echo "installed ($([ $DRAWN = 1 ] && echo 'with' || echo 'without') the drawn species): source = game = QA ($FILES); originals in $B"
OWN_LIB_EXTRA="lib/Gen3FlyPath.lua lib/Gen3FlyOver.lua lib/Gen3Scene.lua lib/Gen3Integration.lua" bash "$R/tools/props/make_patch.sh"
echo "Gen3FlyOver hunks in the patch: $(grep -c 'Gen3FlyOver' "$R/patches/battle-art-voxel-fork.patch")"
