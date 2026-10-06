#!/bin/bash
# Rebuild patches/battle-art-voxel-fork.patch with ONLY the building work's
# files taken from the mod's working tree; every other file stays as it was in
# the last committed patch. Another agent edits the same mod repo, and its
# unfinished changes must not ride along in a building commit.
#   tools/buildings/make_patch.sh            (from ~/Documents/Emerald)
set -euo pipefail
B=~/Documents/battle-art-notquiteog
E=~/Documents/Emerald
OWN_LIB="lib/BuildingModels.lua lib/BuildingVoxels.lua lib/Gen3Civic.lua lib/LandmarkModels.lua lib/Gen3EmeraldInteriors.lua lib/Gen3Furniture.lua lib/InteriorDiorama.lua lib/Gen3PixelFurniture.lua lib/Gen3PixelFurnitureB.lua lib/Gen3Elevation.lua lib/Gen3Stairs.lua lib/Gen3EmeraldTerraces.lua lib/Gen3Integration.lua lib/TerrainLevels.lua lib/Gen3StairTerraces.lua lib/Gen3CyclingRoad.lua data/gen3_stairs.lua lib/Gen3CableCar.lua"
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
NEW="$T/.new.patch"
git --git-dir="$B/.git" --work-tree="$T" diff HEAD > "$NEW"
# never replace the patch with a broken one: it must be big, keep at least as
# many files as the last committed patch, and apply to a clean base
OLDN=$(git -C "$E" show HEAD:patches/battle-art-voxel-fork.patch | grep -c '^diff')
NEWN=$(grep -c '^diff' "$NEW")
SIZE=$(wc -c < "$NEW")
if [ "$SIZE" -lt 1000000 ] || [ "$NEWN" -lt "$OLDN" ]; then
  echo "REFUSED: new patch has $NEWN files / $SIZE bytes (last committed: $OLDN files)"; exit 1
fi
C=$(mktemp -d); git -C "$B" archive HEAD | tar -x -C "$C"
if ! (cd "$C" && git apply --check "$NEW"); then echo "REFUSED: new patch does not apply to a clean base"; rm -rf "$C"; exit 1; fi
rm -rf "$C"
mv "$NEW" "$E/patches/battle-art-voxel-fork.patch"
echo "patch ok: $NEWN files"
