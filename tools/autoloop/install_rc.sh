#!/bin/bash
# Install the autoloop's accepted fixes (for the user, after review):
#   tools/autoloop/install_rc.sh            show what would be installed (dry run)
#   tools/autoloop/install_rc.sh --yes      install
#   tools/autoloop/install_rc.sh --rollback <backup dir>   put the backed-up files back
# What it installs: only the files the loop changed, i.e. `git diff upstream..main` in .autoloop/rc (upstream = the
# real install the loop started from, kept in sync with other sessions' installs). Each file is copied into the real
# game, the main QA copy and the mod source (~/Documents/battle-art-notquiteog/lib), after backing up all three to
# ~/Documents/gen1recomp-modwork/backups/autoloop-<time>/. It refuses when the game is running, when rc is not synced
# with the current real install, or when a target file was changed by someone else since upstream (conflict).
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
RC=$ROOT/.autoloop/rc
AS="$HOME/Library/Application Support"
REAL="$AS/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK"
QA="$AS/pokemon-love2d-rseqa/mods/BATTLE_ART_VOXEL_FORK"
SRC="$HOME/Documents/battle-art-notquiteog"
MODE=${1:-dry}
if [ "$MODE" = "--rollback" ]; then
  B=${2:?backup dir}; [ -d "$B" ] || { echo "no backup dir $B"; exit 2; }
  pgrep -fl "MacOS/love" && { echo "close the game first"; exit 3; }
  for t in real qa src; do
    case $t in real) D=$REAL;; qa) D=$QA;; src) D=$SRC;; esac
    [ -d "$B/$t" ] && (cd "$B/$t" && find . -type f | while read -r f; do cp "$f" "$D/$f"; echo "restored $t/$f"; done)
  done
  echo "rollback done from $B"; exit 0
fi
FILES=$(git -C "$RC" diff --name-only upstream main)
[ -z "$FILES" ] && { echo "nothing to install: rc main has no loop commits over upstream"; exit 0; }
echo "loop commits:"; git -C "$RC" log --oneline upstream..main | sed 's/^/  /'
echo "files:"; echo "$FILES" | sed 's/^/  /'
# rc must be synced: the real install equals rc upstream for every file
STALE=0
for f in $FILES; do
  if ! git -C "$RC" show "upstream:$f" 2>/dev/null | cmp -s - "$REAL/$f"; then echo "  real $f changed since rc upstream (run tools/autoloop/rc.sh sync and re-gate)"; STALE=1; fi
  if [ -f "$SRC/$f" ] && ! git -C "$RC" show "upstream:$f" 2>/dev/null | cmp -s - "$SRC/$f"; then echo "  CONFLICT: mod source $f differs from the installed one (someone is editing it)"; STALE=1; fi
done
[ $STALE -eq 1 ] && { echo "refusing to install"; exit 4; }
[ "$MODE" = "--yes" ] || { echo "(dry run: add --yes to install)"; exit 0; }
pgrep -fl "MacOS/love" && { echo "close the game first (QA runs included)"; exit 3; }
B=$HOME/Documents/gen1recomp-modwork/backups/autoloop-$(date +%Y%m%d-%H%M%S)
for f in $FILES; do
  for t in real qa src; do
    case $t in real) D=$REAL;; qa) D=$QA;; src) D=$SRC;; esac
    if [ -f "$D/$f" ]; then mkdir -p "$B/$t/$(dirname "$f")"; cp "$D/$f" "$B/$t/$f"; fi
    mkdir -p "$D/$(dirname "$f")"; git -C "$RC" show "main:$f" > "$D/$f"
  done
done
for f in $FILES; do cmp -s "$REAL/$f" "$QA/$f" && cmp -s "$REAL/$f" "$SRC/$f" || { echo "copy check failed for $f"; exit 5; }; done
git -C "$RC" branch -f upstream main
echo "installed $(echo "$FILES" | wc -l | tr -d ' ') file(s); backup and rollback: tools/autoloop/install_rc.sh --rollback $B"
echo "next: OWN_LIB_EXTRA=\"$(echo $FILES | tr '\n' ' ')\" bash tools/props/make_patch.sh, commit the patch, push"
