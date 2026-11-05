#!/usr/bin/env bash
# Run every tests/*_test.lua; any failure fails the run.
#   usage: mod/models/tools/run_tests.sh [engine-root]   (default ../../../gen1recomp)
# The tests require mods.emerald_3d_voxel_mod.models.*, so this builds a temp root: the engine's files plus
# mods/emerald_3d_voxel_mod -> the mod root. ROM tests read STADIUM2_ROM (default: the ROM the game imported).
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"     # mod/models
modroot="$(cd "$here/.." && pwd)"                            # mod
engine="$(cd "${1:-$modroot/../gen1recomp}" && pwd)" || exit 2
: "${STADIUM2_ROM:=$HOME/Library/Application Support/pokemon-love2d/mods/emerald_3d_voxel_mod/baseroms/stadium2.z64}"
export STADIUM2_ROM
root=$(mktemp -d); trap 'rm -rf "$root"' EXIT
for e in "$engine"/* ; do [ "$(basename "$e")" = mods ] || ln -s "$e" "$root/"; done
mkdir "$root/mods"; ln -s "$modroot" "$root/mods/emerald_3d_voxel_mod"
cd "$root" || exit 2
pass=0; fail=0
for t in mods/emerald_3d_voxel_mod/models/tests/*_test.lua; do
  name=$(basename "$t"); log=$(mktemp)
  perl -e 'alarm 300; exec @ARGV' luajit "$t" > "$log" 2>&1; rc=$?
  if [ $rc -eq 0 ] && ! grep -qE '^FAIL' "$log"; then
    printf 'PASS  %s\n' "$name"; pass=$((pass + 1))
  else
    printf 'FAIL  %-52s rc=%s\n' "$name" "$rc"
    { grep -E 'FAIL' "$log" || tail -3 "$log"; } | head -3 | sed 's/^/        /'
    fail=$((fail + 1))
  fi
  rm -f "$log"
done
echo "== $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
