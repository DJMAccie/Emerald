#!/bin/bash
cd "$(cd "$(dirname "$0")/../.." && pwd)"
P=${PROBE:-/tmp/deadscan/probe}; O=${OUTROOT:-/tmp/deadscan/covmaps}
FILES=$(cat /tmp/deadscan/files.txt); mkdir -p $O; rm -f $O/DONE
export QA_SRC=$P QA_LIMIT=400
for b in /tmp/deadscan/allmaps/b*.txt; do n=$(basename $b .txt)
  grep -q "^shots" $O/$n.out 2>/dev/null && continue
  ( tools/qa_tryp.sh "$FILES" $O/$n "$(cat $b)" 4 0 5 > $O/$n.out 2>&1; rm -f $O/$n/*.png; echo "$n $(tail -1 $O/$n.out) loadfail=$(grep -c "load.*false" $O/$n/run.log)" >> $O/DONE ) &
  sleep 2
done
wait; echo ALLDONE >> $O/DONE
