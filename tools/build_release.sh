#!/bin/bash
# Build the player zip from HEAD (committed files only) plus the wilds sprite PNGs from disk.
#   tools/build_release.sh [out.zip]     default: release/Emerald-3D.zip
set -eu
E="$(cd "$(dirname "$0")/.." && pwd)"; OUT="${1:-$E/release/Emerald-3D.zip}"; mkdir -p "$(dirname "$OUT")"
OUT="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"
W="$(mktemp -d)"; trap 'rm -r "$W"' EXIT
for p in mod:BATTLE_ART_VOXEL_FORK stadium2-importer:STADIUM2_IMPORTER overworld-wild-spawns:overworld_wild_spawns; do
  mkdir -p "$W/${p#*:}"
  git -C "$E" archive HEAD "${p%%:*}" | tar -x -C "$W/${p#*:}" --strip-components=1 \
    --exclude='tests' --exclude='tools' --exclude='.gitignore' --exclude='.modkitignore' --exclude='docs/[!l]*'
  find "$W/${p#*:}" -name '*.md' ! -name 'THIRD_PARTY_NOTICES.md' ! -name 'NOTICE.md' ! -name 'README.md' -delete
done
rsync -a --include '*/' --include '*.png' --exclude '*' "$E/overworld-wild-spawns/assets/" "$W/overworld_wild_spawns/assets/"
cp "$E/LICENSE" "$W/LICENSE"
rm -f "$OUT"; (cd "$W" && zip -qr -X "$OUT" . -x '.DS_Store')
echo "$OUT $(du -h "$OUT" | cut -f1)"
