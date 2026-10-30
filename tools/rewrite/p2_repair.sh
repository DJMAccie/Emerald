#!/bin/bash
# p2_repair.sh — re-run the P2 field-gate batches that failed on the broken QA identity p2, then run the
# instrumented Route 113 probe (QA_SRC=/tmp/probe_src) and restore the clean tree in every QA identity.
# Needs the wider sandbox: it deletes and re-clones files under ~/Library/Application Support.
set -u
R=$HOME/Documents/Emerald
AS="$HOME/Library/Application Support"
echo "== removing the broken identity p2"
rm -rf "$AS/pokemon-love2d-rseqa-p2" /tmp/emerald-qa.pcopy.2 /tmp/emerald-qa.prun.2
for k in 2 5 6; do
  rm -rf /tmp/p2f$k
  bash $R/tools/rewrite/field_gate_all.sh $k $k 1
done
echo "== instrumented Route 113 probe"
rm -rf /tmp/r113_dbg_out /tmp/r113_dbg.txt
EM_MAP=EM_ROUTE113 EM_X0=12 EM_X1=18 EM_Y0=0 EM_Y1=11 EM_DUMP=/tmp/r113_dbg.txt \
  QA_SRC=/tmp/probe_src QA_DRIVER=$R/tools/rewrite/probe/cells_debug_driver.lua QA_LIMIT=300 \
  bash $R/tools/rewrite/clean_try.sh /tmp/r113_dbg_out - 4 0 60
echo "== restoring the clean tree in every QA identity"
for i in 1 2 3 4; do
  d="$AS/pokemon-love2d-rseqa-p$i/mods/EMERALD_3D"
  [ -d "$d" ] && rsync -a --delete --exclude '.git/' --exclude 'docs/' "$HOME/Documents/emerald3d/" "$d/" 2>/dev/null
done
echo "== done"
