#!/bin/bash
# (caves round 1 variant of tools/props/make_patch.sh: only OWN_LIB_EXTRA files are taken whole; Gen3Scene gets the settle line)
# Rebuild patches/battle-art-voxel-fork.patch with ONLY the props/terrain work's
# files taken from the mod's working tree; every other file stays as it was in
# the last committed patch (same scheme as tools/buildings/make_patch.sh, other files).
#   tools/props/make_patch.sh            (from ~/Documents/Emerald)
set -euo pipefail
B=~/Documents/battle-art-notquiteog
E=~/Documents/Emerald
# OWN_LIB_EXTRA="lib/A.lua lib/B.lua" adds files for one run (another session's builder files)
OWN_LIB="${OWN_LIB_EXTRA:-}"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
git -C "$B" archive HEAD | tar -x -C "$T"
git -C "$E" show HEAD:patches/battle-art-voxel-fork.patch > "$T/.last.patch"
(cd "$T" && git apply .last.patch) && rm "$T/.last.patch"
for f in $OWN_LIB; do cp "$B/$f" "$T/$f"; done
# Gen3Scene.lua: the committed patch version plus the one settle line (the source copy holds the fly session's work)
python3 - "$T/lib/Gen3Scene.lua" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
call="V.require('Gen3Cave').settle(def,cells)"
a="  end\n end\n -- (a town's wall tiles are masonry (Gen3Masonry)"
assert call not in s and s.count(a)==1
open(p,'w').write(s.replace(a,"  end\n  "+call+"\n end\n -- (a town's wall tiles are masonry (Gen3Masonry)"))
PY
git -C "$B" add -A $OWN_LIB
# write to a temp file and move it into place only once it is a plausible, applying patch
# (an interrupted or overlapping run once left the committed patch empty)
NEW=$(mktemp)
git --git-dir="$B/.git" --work-tree="$T" diff HEAD > "$NEW"
if [ "$(wc -c < "$NEW")" -lt 1000000 ]; then echo "REFUSING: new patch is only $(wc -c < "$NEW") bytes"; rm -f "$NEW"; exit 1; fi
C=$(mktemp -d); git -C "$B" archive HEAD | tar -x -C "$C"
(cd "$C" && git init -q . && git apply --check "$NEW") || { echo "REFUSING: patch does not apply to the base"; rm -rf "$C" "$NEW"; exit 1; }
rm -rf "$C"
mv "$NEW" "$E/patches/battle-art-voxel-fork.patch"
echo "patch ok: $(grep -c '^diff' "$E/patches/battle-art-voxel-fork.patch") files"
