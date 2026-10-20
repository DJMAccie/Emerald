#!/bin/bash
# Release-candidate tree for the autoloop (docs/AUTOLOOP.md). The loop edits Lua ONLY here.
#   rc.sh init    create ~/Documents/gen1recomp-modwork/autoloop/rc from the REAL installed lib (branch upstream + main)
#   rc.sh sync    commit the current real install onto 'upstream' if it changed, merge it into 'main'
#   rc.sh files   lib files (bare names) where rc differs from the main QA copy -> the qa_tryp.sh file list
#   rc.sh dir     print the rc root (use as QA_SRC)
#   rc.sh status  branch, last commits, files differing from QA and from the real install
# Never writes into the real game, the main QA copy, or ~/Documents/battle-art-notquiteog.
set -eu
AS="$HOME/Library/Application Support"
REAL="$AS/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
QA="$AS/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK"
RC=${AUTOLOOP_RC:-$(cd "$(dirname "$0")/../.." && pwd)/.autoloop/rc}
g(){ git -C "$RC" "$@"; }
snapshot(){ # copy the real install's lib/ and data/ over the work tree (deletions included)
  rsync -a --delete --exclude .git "$REAL/lib/" "$RC/lib/"
  if [ -d "$REAL/data" ]; then rsync -a --delete "$REAL/data/" "$RC/data/"; fi
}
case ${1:-status} in
  init)
    [ -d "$RC/.git" ] && { echo "rc exists: $RC"; exit 0; }
    mkdir -p "$RC"; git init -q -b upstream "$RC"
    g config user.name autoloop; g config user.email autoloop@local
    snapshot; g add -A; g commit -qm "upstream: real install $(date +%F' '%H:%M)"
    g branch main; g switch -q main
    echo "rc created at $RC from $REAL"; g log --oneline -1 ;;
  sync)
    cur=$(g branch --show-current)
    [ -n "$(g status --porcelain)" ] && { echo "rc has uncommitted changes on $cur; commit or discard first"; exit 3; }
    g switch -q upstream; snapshot; g add -A
    if g diff --cached --quiet; then echo "upstream unchanged"; else
      g commit -qm "upstream: real install $(date +%F' '%H:%M)"; echo "upstream advanced:"; g log --oneline -1; fi
    g switch -q main
    if ! g merge -q --no-edit upstream; then echo "MERGE CONFLICT in rc main (upstream vs loop fixes):"; g diff --name-only --diff-filter=U; exit 4; fi
    [ "$cur" != main ] && g switch -q "$cur"; echo "rc main = upstream + $(g rev-list --count upstream..main) loop commit(s)" ;;
  files)
    # bare names for lib/, path for anything else (qa_tryp.sh's convention)
    { diff -rq "$RC/lib" "$QA/lib" 2>/dev/null | sed -n "s|^Files $RC/lib/\(.*\) and .* differ$|\1|p; s|^Only in $RC/lib: \(.*\)$|\1|p"
      [ -d "$RC/data" ] && diff -rq "$RC/data" "$QA/data" 2>/dev/null | sed -n "s|^Files $RC/\(data/.*\) and .* differ$|\1|p; s|^Only in $RC/data\(/*[^:]*\): \(.*\)$|data\1/\2|p"
    } | grep -v '^\.' | grep '\.lua$' | sort | tr '\n' ' '; echo ;;
  dir) echo "$RC" ;;
  status)
    echo "rc: $RC  branch $(g branch --show-current)"; g log --oneline -5
    echo "differs from QA: $("$0" files)"
    echo "differs from real install:"; diff -rq "$RC/lib" "$REAL/lib" | sed "s|$RC/||; s|$AS/||" | head -20 ;;
  *) echo "usage: rc.sh init|sync|files|dir|status"; exit 2 ;;
esac
