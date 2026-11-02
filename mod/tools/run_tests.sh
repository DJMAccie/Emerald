#!/usr/bin/env bash
# Run every tests/*_test.lua from the mod root; any failure fails the run.
#   usage: tools/run_tests.sh [engine-root]   (engine root = ../gen1recomp, for tests.modkit and src/)
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root" || exit 2
engine="${1:-}"
[ -n "$engine" ] && export LUA_PATH="$engine/?.lua;$engine/?/init.lua;;"
export DS_MOD_PATH=.
TO=; command -v timeout >/dev/null && TO="timeout 300"
pass=0; fail=0
for t in tests/*_test.lua; do
  name=$(basename "$t")
  log=$(mktemp)
  $TO luajit "$t" > "$log" 2>&1
  rc=$?
  if [ $rc -eq 0 ] && ! grep -qE '^FAIL' "$log"; then
    printf 'PASS  %-52s %s\n' "$name" "$(grep -oE '[0-9]+/[0-9]+ checks passed' "$log" | tail -1)"
    pass=$((pass + 1))
  else
    printf 'FAIL  %-52s rc=%s\n' "$name" "$rc"
    { grep -E '^FAIL' "$log" || tail -3 "$log"; } | head -3 | sed 's/^/        /'
    fail=$((fail + 1))
  fi
  rm -f "$log"
done
echo "== $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
