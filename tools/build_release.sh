#!/bin/bash
# Build the player zip from HEAD (committed files only) plus the wilds sprite PNGs from disk.
#   tools/build_release.sh [out.zip] [x.y.z]     default: release/Emerald-3D.zip; also writes <id>-<x.y.z>.zip per mod next to it
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
# One zip per mod for the GitHub release and the community mod index: files at the archive root, named
# <id>-<version>.zip. <version> is the release tag's x.y.z (the launcher and the index both read it from the tag).
VER="${2:-$(sed -n 's/.*"version": *"\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p' "$E/mod/manifest.json" | head -1)}"
[ -n "$VER" ] || { echo "no version: pass it as the second argument (x.y.z)"; exit 1; }
for id in BATTLE_ART_VOXEL_FORK STADIUM2_IMPORTER overworld_wild_spawns; do
  cp "$E/LICENSE" "$W/$id/LICENSE"
  Z="$(dirname "$OUT")/$id-$VER.zip"; rm -f "$Z"; (cd "$W/$id" && zip -qr -X "$Z" . -x '.DS_Store')
  echo "$Z $(du -h "$Z" | cut -f1)"
done
