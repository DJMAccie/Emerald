#!/bin/bash
# dsport.sh [first task number]: run the P3 port plan's tasks through ~/bin/dsworker, one at a time, in
# ~/Documents/emerald3d-audit; compile + tests + commit after each; stop on the first failure.
set -u
PLAN=$HOME/Documents/Emerald/docs/proposals/P3-PORT-DSWORKER-PLAN-2026-11-01.md
OUT=$HOME/Documents/Emerald/.rewrite/night/p3port; mkdir -p "$OUT"
TREE=$HOME/Documents/emerald3d-audit
FIRST=${1:-1}
section(){ awk -v h="$1" 'BEGIN{p=0} /^## /{p=($0 ~ "^## "h"( |$)")} p' "$PLAN"; }
PRE=$(section PREAMBLE)
for n in $(seq "$FIRST" 10); do
  TASK=$(section "T$n")
  [ -n "$TASK" ] || { echo "no task T$n" >> "$OUT/run.log"; exit 2; }
  echo "=== T$n start $(date)" >> "$OUT/run.log"
  "$HOME/Documents/Emerald/tools/rewrite/dsworker_lift.sh" "$PRE

$TASK" > "$OUT/task_T$n.json" 2> "$OUT/task_T$n.err"
  python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(str(d.get('result',''))[:3000])" "$OUT/task_T$n.json" >> "$OUT/run.log" 2>&1
  cd "$TREE" || exit 3
  bad=0
  for f in lib/*.lua; do luajit -bl "$f" >/dev/null 2>&1 || { echo "COMPILE FAIL $f" >> "$OUT/run.log"; bad=1; }; done
  for t in tests/*_test.lua; do luajit "$t" >/dev/null 2>&1 || { echo "TEST FAIL $t" >> "$OUT/run.log"; bad=1; }; done
  if [ $bad -ne 0 ]; then echo "=== T$n FAILED gates, stopping $(date)" >> "$OUT/run.log"; exit 1; fi
  git add -A lib tests docs/port docs/PROVENANCE.md .gitignore data/relief/.gitkeep tools 2>/dev/null
  git commit -q -m "port T$n: $(sed -n "s/^## T$n //p" "$PLAN") (DeepSeek worker, plan docs/proposals/P3-PORT-DSWORKER-PLAN-2026-11-01.md in Emerald)" 2>>"$OUT/run.log" || echo "T$n: nothing to commit" >> "$OUT/run.log"
  echo "=== T$n done $(date) $(git log --oneline -1)" >> "$OUT/run.log"
done
echo "=== ALL DONE $(date)" >> "$OUT/run.log"
