#!/bin/bash
# (caves round 2 variant of tools/props/make_patch.sh: only lib/Gen3Cave.lua is taken whole from the working tree;
# every other file stays as in the last committed patch. Round 1's Gen3Scene settle line is already in the committed patch.)
set -euo pipefail
B=~/Documents/battle-art-notquiteog
E=~/Documents/Emerald
OWN_LIB="lib/Gen3Cave.lua"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
git -C "$B" archive HEAD | tar -x -C "$T"
git -C "$E" show HEAD:patches/battle-art-voxel-fork.patch > "$T/.last.patch"
(cd "$T" && git apply .last.patch) && rm "$T/.last.patch"
grep -q "Gen3Cave').settle" "$T/lib/Gen3Scene.lua" || { echo "REFUSING: the committed patch's Gen3Scene has no settle line"; exit 1; }
for f in $OWN_LIB; do cp "$B/$f" "$T/$f"; done
git -C "$B" add -A $OWN_LIB
NEW=$(mktemp)
git --git-dir="$B/.git" --work-tree="$T" diff HEAD > "$NEW"
if [ "$(wc -c < "$NEW")" -lt 1000000 ]; then echo "REFUSING: new patch is only $(wc -c < "$NEW") bytes"; rm -f "$NEW"; exit 1; fi
C=$(mktemp -d); git -C "$B" archive HEAD | tar -x -C "$C"
(cd "$C" && git init -q . && git apply --check "$NEW") || { echo "REFUSING: patch does not apply to the base"; rm -rf "$C" "$NEW"; exit 1; }
rm -rf "$C"
mv "$NEW" "$E/patches/battle-art-voxel-fork.patch"
echo "patch ok: $(grep -c '^diff' "$E/patches/battle-art-voxel-fork.patch") files"
