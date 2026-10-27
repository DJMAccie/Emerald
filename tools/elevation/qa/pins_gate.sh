#!/bin/bash
# pins_gate.sh <label> [files]   field dump (em_pins_driver: PIN/COUNT/GRID) of every pinned map, 3 QA games, out /tmp/<label>/pins_*.txt
# Compare two labels with: python3 tools/elevation/qa/grid_diff.py /tmp/<a> /tmp/<b>
R=$HOME/Documents/Emerald; L=$1; FILES=${2:-"Gen3Elevation.lua Gen3PinData.lua Gen3Blocks.lua Gen3Scene.lua TerrainLevels.lua"}
O=/tmp/$L; mkdir -p $O
[ -f $O/maps_aa ] || { for m in $(ls $R/docs/elevation/pins/EM_*.txt | xargs -n1 basename | sed 's/.txt//'); do awk -v m=$m 'NF>=3 && $1!~/^#/ && $3~/^[0-9]/ {print m, $1, $2; exit}' $R/docs/elevation/pins/$m.txt; done > $O/maps_all.txt; split -l 22 $O/maps_all.txt $O/maps_; }
one(){ b=$1
  EM_DRIVER=$R/tools/elevation/qa/em_pins_driver.lua EM_MAPS=$O/maps_$b EM_DUMP=$O/pins_$b.txt QA_LIMIT=360 \
    bash $R/tools/qa_tryp.sh "$FILES" $O/out_$b - 4 0 60 > $O/tryp_$b.log 2>&1
}
export -f one; export R O FILES
ls $O | sed -n 's/^maps_\(a.\)$/\1/p' | xargs -P 3 -I{} bash -c 'one {}'
cat $O/tryp_*.log
grep -h "^COUNT" $O/pins_*.txt | sort
