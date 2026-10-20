#!/bin/bash
# Headless geometry dumps (engine track E1): the in-game tools/autoloop/em_geo_driver.lua output, no game boot.
#
#   engine/geo.sh [<MAP>[=x,y] ...] [--maps FILE] --out DIR [--tree DIR | --rc COMMIT] [--driver COMMIT|FILE]
#                 [-j N] [--full] [--spots FILE] [--no-scripts] [--anim-steps N] [--luajit]
#   e.g.  engine/geo.sh --tree ~/Documents/Emerald/.autoloop/rc --maps maps.txt --out /tmp/geo -j 8
#
# Writes DIR/<MAP>.geo.gz and DIR/<MAP>.cells (the in-game driver's files) and DIR/headless.log ("[EM geo]"
# lines as in the game's run.log). One process per map, -j/--jobs at a time (default 8). Exit 0 when all ran.
#   --maps FILE   "MAP x y" lines (geo_batch.sh's format); MAP=x,y on the command line; a bare MAP takes its spot
#                 from --spots FILE, else the ledger's docs/ledger/{outdoor,cave}_spots.txt.
#   --tree DIR    the mod tree to build (DIR/lib, DIR/data), e.g. a fix worktree. --rc COMMIT: an rc commit
#                 (git archive into the engine cache). Default: the live rc tree ~/Documents/Emerald/.autoloop/rc.
#   --driver      the in-game driver to run (headless_geo.lua runs em_geo_driver.lua itself, unmodified): a commit
#                 of ~/Documents/Emerald or a file. Default: the main checkout's current file.
#   --full        the mod's FULL render distance: one spot covers the map (not what the game dumps).
#   --no-scripts  do not run the maps' enter scripts (their setmetatile edits: doors, tombs, Lilycove's rock).
#   --anim-steps N  advance Littleroot's tileset animation N steps first: only to reproduce dumps of the driver
#                 before d8c5a2d (it pinned the animation after its boot; Route 103 then matches at N=64).
#   --luajit      the system luajit instead of the game's LuaJIT (not byte-identical: %.1f ties differ).
# Compare: python3 engine/compare_geo.py A.geo.gz B.geo.gz, or engine/compare_all.py DIR_A DIR_B.
# Setup (idempotent, all outside git, in ~/Documents/Emerald/.autoloop/engine-cache): the engine payload the
# game runs (newest updates/gen1recomp-*.love of the real install, unzipped) and bin/emhost (a 40-line C host
# linked to the game's own Lua.framework).
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
AS="$HOME/Library/Application Support"
CACHE=${EM_ENGINE_CACHE:-$HOME/Documents/Emerald/.autoloop/engine-cache}
RCDIR=$HOME/Documents/Emerald/.autoloop/rc
APP_FW=/Applications/gen1recomp.app/Contents/Frameworks
MAPS=(); OUT=; RC=; DRV=; JOBS=8; EXTRA=(); USE_LUAJIT=
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT=$2; shift;;
    --rc|--tree) RC=$2; shift;;
    --maps) while read -r m x y _; do case "$m" in ''|\#*) ;; *) if [ -n "${y:-}" ]; then MAPS+=("$m=$x,$y"); else MAPS+=("$m"); fi;; esac; done < "$2"; shift;;
    --driver) DRV=$2; shift;;
    --jobs|-j) JOBS=$2; shift;;
    --full) EXTRA+=(--full);;
    --boot) EXTRA+=(--boot);;
    --no-scripts) EXTRA+=(--no-scripts);;
    --anim-steps) EXTRA+=(--anim-steps "$2"); shift;;
    --spots) EXTRA+=(--spots "$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"); shift;;
    --luajit) USE_LUAJIT=1;;
    -h|--help) sed -n "2,24p" "$0"; exit 0;;
    *) MAPS+=("$1");;
  esac
  shift
done
[ -n "$OUT" ] && [ ${#MAPS[@]} -gt 0 ] || { sed -n "2,24p" "$0"; exit 2; }
mkdir -p "$OUT" "$CACHE"; OUT=$(cd "$OUT" && pwd)

# 1. the engine payload the game runs
PAY=$(ls -t "$AS"/pokemon-love2d/updates/gen1recomp-*.love 2>/dev/null | head -1)
[ -n "$PAY" ] || { echo "no engine payload in $AS/pokemon-love2d/updates"; exit 3; }
VER=$(basename "$PAY" .love); VER=${VER#gen1recomp-}
PDIR=$CACHE/payload-$VER
if [ ! -f "$PDIR/src/core/game3/map.lua" ]; then
  rm -rf "$PDIR.tmp"; mkdir -p "$PDIR.tmp" && (cd "$PDIR.tmp" && unzip -q "$PAY") && mv "$PDIR.tmp" "$PDIR" || { echo "cannot unpack $PAY"; exit 3; }
fi
export EM_PAYLOAD=$PDIR

# 2. the host: the game's own LuaJIT
HOST=$CACHE/bin/emhost
if [ -z "$USE_LUAJIT" ]; then
  if [ ! -x "$HOST" ] || [ "$HERE/host/emhost.c" -nt "$HOST" ]; then
    mkdir -p "$CACHE/bin"
    clang -O2 -o "$HOST" "$HERE/host/emhost.c" -F"$APP_FW" -framework Lua -Wl,-rpath,"$APP_FW" || { echo "cannot build emhost"; exit 4; }
  fi
  RUN=("$HOST")
else
  RUN=(luajit)
fi

# 3. which rc tree
if [ -z "$RC" ]; then export EM_RC=$RCDIR
elif [ -d "$RC/lib" ]; then export EM_RC=$(cd "$RC" && pwd)
else
  SHA=$(git -C "$RCDIR" rev-parse --short "$RC" 2>/dev/null) || { echo "no rc commit $RC"; exit 5; }
  SNAP=$CACHE/rc-snap/$SHA
  if [ ! -d "$SNAP/lib" ]; then
    rm -rf "$SNAP.tmp"; mkdir -p "$SNAP.tmp" && git -C "$RCDIR" archive "$SHA" lib data | tar -x -C "$SNAP.tmp" && mv "$SNAP.tmp" "$SNAP"
  fi
  export EM_RC=$SNAP
fi
# 4. which in-game driver (headless_geo.lua runs it unmodified): default the main checkout's current file
EMERALD=$HOME/Documents/Emerald
if [ -n "$DRV" ] && [ ! -f "$DRV" ]; then
  DSHA=$(git -C "$EMERALD" rev-parse --short "$DRV" 2>/dev/null) || { echo "no driver commit $DRV"; exit 6; }
  mkdir -p "$CACHE/drivers"; DRV=$CACHE/drivers/em_geo_driver-$DSHA.lua
  git -C "$EMERALD" show "$DSHA:tools/autoloop/em_geo_driver.lua" > "$DRV" || exit 6
fi
[ -n "$DRV" ] && EXTRA+=(--driver "$(cd "$(dirname "$DRV")" && pwd)/$(basename "$DRV")")
DREV=$(git -C "$EMERALD" log -1 --format=%h -- tools/autoloop/em_geo_driver.lua 2>/dev/null)
RCREV=$(git -C "${EM_RC:-$RCDIR}" log -1 --format=%h 2>/dev/null)
echo "[geo.sh] rc $EM_RC (rc HEAD $RCREV) driver ${DRV:-main $DREV} payload $VER host ${RUN[0]##*/} jobs $JOBS maps ${#MAPS[@]}" | tee "$OUT/headless.log"

# 5. one process per map
T0=$(python3 -c 'import time;print(time.time())')
printf '%s\n' "${MAPS[@]}" | xargs -P "$JOBS" -I{} sh -c '"$@" >"$0/{}.log" 2>&1; echo "$? {}" >"$0/{}.rc"' "$OUT" "${RUN[@]}" "$HERE/headless_geo.lua" --quiet --out "$OUT" ${EXTRA[@]+"${EXTRA[@]}"} {}
FAIL=0
for m in "${MAPS[@]}"; do
  n=${m%%=*}
  grep -h "EM geo" "$OUT/$m.log" 2>/dev/null | tee -a "$OUT/headless.log"
  if [ "$(cut -d' ' -f1 "$OUT/$m.rc" 2>/dev/null)" != 0 ]; then FAIL=$((FAIL+1)); echo "[geo.sh] $m FAILED:"; tail -5 "$OUT/$m.log"; fi
  rm -f "$OUT/$m.rc"
done
T1=$(python3 -c 'import time;print(time.time())')
python3 -c "print('[geo.sh] %d maps, %d failed, wall %.1f s' % (${#MAPS[@]}, $FAIL, $T1-$T0))" | tee -a "$OUT/headless.log"
[ "$FAIL" = 0 ]
