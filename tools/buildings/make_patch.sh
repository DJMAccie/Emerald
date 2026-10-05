#!/bin/bash
# Rebuild patches/battle-art-voxel-fork.patch with ONLY the building work's
# files taken from the mod's working tree; every other file stays as it was in
# the last committed patch. Another agent edits the same mod repo, and its
# unfinished changes must not ride along in a building commit.
#   tools/buildings/make_patch.sh            (from ~/Documents/Emerald)
set -euo pipefail
B=~/Documents/battle-art-notquiteog
E=~/Documents/Emerald
OWN_LIB="lib/BuildingModels.lua lib/BuildingVoxels.lua lib/Gen3Civic.lua lib/LandmarkModels.lua lib/Gen3EmeraldInteriors.lua lib/Gen3Furniture.lua lib/InteriorDiorama.lua lib/Gen3PixelFurniture.lua lib/Gen3PixelFurnitureB.lua lib/Gen3Elevation.lua lib/Gen3Stairs.lua lib/Gen3EmeraldTerraces.lua lib/Gen3Integration.lua"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
# base tree + the last committed patch
git -C "$B" archive HEAD | tar -x -C "$T"
git -C "$E" show HEAD:patches/battle-art-voxel-fork.patch > "$T/.last.patch"
(cd "$T" && git apply .last.patch) && rm "$T/.last.patch"
# overlay the building files
for f in $OWN_LIB; do cp "$B/$f" "$T/$f"; done
rsync -a --delete "$B/data/buildings/" "$T/data/buildings/"
# new model files must be known to the index for `diff HEAD` to list them
git -C "$B" add -A data/buildings $OWN_LIB
git --git-dir="$B/.git" --work-tree="$T" diff HEAD > "$E/patches/battle-art-voxel-fork.patch"
# it must apply to a clean base
C=$(mktemp -d); git -C "$B" archive HEAD | tar -x -C "$C"
(cd "$C" && git apply --check "$E/patches/battle-art-voxel-fork.patch") && echo "patch ok: $(grep -c '^diff' "$E/patches/battle-art-voxel-fork.patch") files"
rm -rf "$C"
