#!/bin/bash
# field_gate.sh <label> [maps_file]
# P2 gate for EMERALD_3D: the neutral field probe (docs/specs/ProbeContract.md) over the 64 pinned maps,
# compared with the M0 baseline (.rewrite/baseline/s4a/gates). 3 QA copies in parallel, like pins_gate.sh.
# Out: /tmp/<label>/{pins_*.txt,cls_*.txt} + a summary on stdout.
R=$HOME/Documents/Emerald; L=${1:?label}; MF=${2:-}
O=/tmp/$L; mkdir -p $O
BASE=$R/.rewrite/baseline/s4a/gates
if [ ! -f $O/maps_aa ] || [ -n "$MF" ]; then
  if [ -n "$MF" ]; then cp "$MF" $O/maps_all.txt; else
    for m in $(ls $R/docs/elevation/pins/EM_*.txt | xargs -n1 basename | sed 's/.txt//'); do
      awk -v m=$m 'NF>=3 && $1!~/^#/ && $3~/^[0-9]/ {print m, $1, $2; exit}' $R/docs/elevation/pins/$m.txt
    done > $O/maps_all.txt
  fi
  split -l 16 $O/maps_all.txt $O/maps_
fi
run(){ kind=$1; b=$2
  EM_KIND=$kind EM_MAPS=$O/maps_$b EM_DUMP=$O/${kind}_$b.txt QA_LIMIT=400 \
    QA_DRIVER=$R/tools/elevation/qa/em_field_probe_driver.lua \
    bash $R/tools/rewrite/clean_try.sh $O/out_${kind}_$b - 4 0 60 > $O/tryp_${kind}_$b.log 2>&1
}
export -f run; export R O
for kind in pins cls; do
  echo "== $kind"
  ls $O | sed -n 's/^maps_\(a.\)$/\1/p' | xargs -P 3 -I{} bash -c 'run '"$kind"' {}'
  cat $O/tryp_${kind}_*.log | grep -E "WATCHDOG|error|fallback|shots" | tail -5
done
echo "== COUNT lines where new differs from baseline:"
diff <(sort $BASE/G01.txt) <(grep -h "^COUNT" $O/pins_*.txt | sort) | head -40
echo "== new COUNT lines with diff!=0:"
grep -h "^COUNT" $O/pins_*.txt | grep -v "diff=0" | head -20
echo "== grid diff vs baseline:"
python3 $R/tools/elevation/qa/grid_diff.py $BASE $O 3
echo "== class diff vs baseline:"
python3 $R/tools/elevation/qa/cls_diff.py $BASE $O
