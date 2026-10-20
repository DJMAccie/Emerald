#!/usr/bin/env bash
# Run all tests/*_test.py suites with python3 -I and print a summary.
#   usage: tests/run_tests.sh [suite_test.py ...]
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root" || exit 2

suites=("$@")
if [ ${#suites[@]} -eq 0 ]; then
  suites=(tests/*_test.py)
fi

pass=0
fail=0
for t in "${suites[@]}"; do
  name=$(basename "$t")
  out=$(python3 -I "$t" 2>&1)
  rc=$?
  if [ $rc -eq 0 ] && ! printf '%s\n' "$out" | grep -qE '^FAIL'; then
    summary=$(printf '%s\n' "$out" | grep -oE '[0-9]+/[0-9]+ checks passed' | tail -1)
    printf 'PASS  %-36s %s\n' "$name" "$summary"
    pass=$((pass + 1))
  else
    printf 'FAIL  %-36s rc=%s\n' "$name" "$rc"
    printf '%s\n' "$out" | sed 's/^/        /'
    fail=$((fail + 1))
  fi
done

echo "== $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
