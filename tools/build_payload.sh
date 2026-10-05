#!/usr/bin/env bash
# Package the Emerald-facade engine patch as an in-place update payload by
# overlaying the changed files onto the official 0.3.36 payload.
#
# The stock app boots the newest payload under
# ~/Library/Application Support/pokemon-love2d/updates/ whose engine version is
# newer than its bundled one (src/update/Boot.lua: Boot.select), so a
# "0.3.37-rse.N" pre-release wins over the installed 0.3.36 and is itself
# superseded by a real 0.3.37 from the project's updater.
#
#   tools/build_payload.sh <base.love> <engine-checkout> <version> <out.love>
set -euo pipefail
base="${1:?base .love}"; src="${2:?engine checkout}"; version="${3:?version e.g. 0.3.37-rse.1}"; out="${4:?out.love}"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
cp "$base" "$stage/payload.love"
mkdir -p "$stage/overlay/src/mods" "$stage/overlay/src/core"
cp "$src/src/mods/Gen3Compat.lua" "$stage/overlay/src/mods/Gen3Compat.lua"
cp "$src/src/core/Game3.lua" "$stage/overlay/src/core/Game3.lua"
unzip -p "$base" src/core/Version.lua > "$stage/overlay/src/core/Version.lua"
python3 - "$stage/overlay/src/core/Version.lua" "$version" <<'EOF'
import re, sys
p, v = sys.argv[1], sys.argv[2]
s = open(p).read()
s2, n = re.subn(r'(engine\s*=\s*)"[^"]*"', r'\1"%s"' % v, s, count=1)
assert n == 1, "engine field not found"
open(p, 'w').write(s2)
EOF
( cd "$stage/overlay" && zip -q -X "$stage/payload.love" src/mods/Gen3Compat.lua src/core/Game3.lua src/core/Version.lua )
mv "$stage/payload.love" "$out"
echo "wrote $out ($(du -h "$out" | cut -f1)) engine=$version"
unzip -p "$out" src/core/Version.lua | grep -E 'engine\s*=' | head -1
unzip -p "$out" src/mods/Gen3Compat.lua | grep -c 'rse = true' | sed 's/^/rse facade lines: /'
