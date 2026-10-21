#!/bin/bash
# v1_gate.sh <label>   final relief heights of the 7 signed (V1) maps: GAME lib vs the stage3 probe. Must be identical (sorted).
S=$(cd "$(dirname "$0")/.." && pwd); R=$HOME/Documents/Emerald; L=$1
GAME="$HOME/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
O=$S/$L; mkdir -p $O
export QA_ZOOM=-2 QA_LIMIT=400
FILES="Gen3Cave.lua Gen3Hills.lua Gen3Mass.lua Gen3Relief.lua Gen3ReliefData.lua"
printf 'EM_ROUTE111 21 62\nEM_ROUTE114 22 34\nEM_ROUTE113 44 7\n' > $O/m_1
printf 'EM_ROUTE115 19 16\nEM_FALLARBOR_TOWN 9 12\n' > $O/m_2
printf 'EM_ROUTE112 26 44\nEM_MT_CHIMNEY 22 20\n' > $O/m_3
one(){ v=$1; b=$2
  if [ "$v" = old ]; then src="$GAME"; else src="$S/probe"; fi
  QA_SRC="$src" EM_DRIVER="$R/tools/em_reliefh_driver.lua" EM_MAPS="$O/m_$b" EM_DUMP="$O/${v}_$b.txt" EM_DUMP_WAIT=300 \
    "$R/tools/qa_tryp.sh" "$FILES" "$O/out_${v}_$b" - 4 0 60 > "$O/${v}_$b.summary" 2>&1
}
export -f one; export S R GAME FILES O
for b in 1 2 3; do for v in old new; do echo "$v $b"; done; done | xargs -P 3 -L1 bash -c 'one $0 $1'
cat $O/old_?.txt | sort > $O/old_all.txt; cat $O/new_?.txt | sort > $O/new_all.txt
wc -l $O/old_all.txt $O/new_all.txt
# the probe prints extra debug (last column, MASS#/OFFHIST#/SKIP lines) that the game lib does not: compare the cell lines only
for v in old new; do awk '{NF=NF-1; print}' $O/${v}_all.txt | grep -v -E '^(MASS#|OFFHIST#|SKIP)' | sort > $O/${v}_cell.txt; done
wc -l $O/old_cell.txt $O/new_cell.txt
if cmp -s $O/old_cell.txt $O/new_cell.txt; then echo "V1 GATE: IDENTICAL"; else echo "V1 GATE: DIFFERENT"; diff $O/old_cell.txt $O/new_cell.txt | head -20; fi
echo done > $O/ALLDONE
