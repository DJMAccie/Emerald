#!/bin/bash
# Rebuild patches/battle-art-voxel-fork.patch with ONLY the props/terrain work's
# files taken from the mod's working tree; every other file stays as it was in
# the last committed patch (same scheme as tools/buildings/make_patch.sh, other files).
#   tools/props/make_patch.sh            (from ~/Documents/Emerald)
set -euo pipefail
B=~/Documents/battle-art-notquiteog
E=~/Documents/Emerald
OWN_LIB="lib/Gen3Scene.lua lib/Gen3Mass.lua lib/Gen3Outdoor.lua lib/Gen3EmeraldShapes.lua lib/Gen3TileShape.lua lib/Gen3Objects.lua lib/Gen3Terrain.lua lib/CliffMasonry.lua lib/Gen3Elevation.lua lib/NativeTreeArt.lua lib/TreePresentation.lua"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
git -C "$B" archive HEAD | tar -x -C "$T"
git -C "$E" show HEAD:patches/battle-art-voxel-fork.patch > "$T/.last.patch"
(cd "$T" && git apply .last.patch) && rm "$T/.last.patch"
for f in $OWN_LIB; do cp "$B/$f" "$T/$f"; done
git -C "$B" add -A $OWN_LIB
# write to a temp file and move it into place only once it is a plausible, applying patch
# (an interrupted or overlapping run once left the committed patch empty)
NEW=$(mktemp)
git --git-dir="$B/.git" --work-tree="$T" diff HEAD > "$NEW"
if [ "$(wc -c < "$NEW")" -lt 1000000 ]; then echo "REFUSING: new patch is only $(wc -c < "$NEW") bytes"; rm -f "$NEW"; exit 1; fi
C=$(mktemp -d); git -C "$B" archive HEAD | tar -x -C "$C"
(cd "$C" && git init -q . && git apply --check "$NEW") || { echo "REFUSING: patch does not apply to the base"; rm -rf "$C" "$NEW"; exit 1; }
rm -rf "$C"
mv "$NEW" "$E/patches/battle-art-voxel-fork.patch"
echo "patch ok: $(grep -c '^diff' "$E/patches/battle-art-voxel-fork.patch") files"
