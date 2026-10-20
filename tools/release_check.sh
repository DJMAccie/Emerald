#!/bin/bash
# Run every Tier 1 gate of docs/DONE.md in one go and write machine-readable results.
#   tools/release_check.sh [--out DIR] [--maps FILE] [--gates a,b,c] [--yaws "0 3.14"]
# --maps   "MAP x y" lines (default: docs/ledger/outdoor_spots.txt + cave_spots.txt = the full scope)
# --gates  sweep,magenta,stairs,repeat,load,defects,floats,sheets (default all; stairs+repeat share the cell dumps)
# --yaws   camera yaws of the sweep and magenta passes (default "0 3.14"); both levels 4 and 7 come from one run
# Output (DIR defaults to ~/Documents/gen1recomp-modwork/release-runs/<time>; outside git, it holds ROM-derived shots):
#   results.json (read by tools/ledger.py --audit-from), results.md, sheets/, one folder per gate with logs.
# Resumable: rerun with the same --out and finished batches are skipped. Read-only on the mod source: the
# magenta probe tree is generated into DIR and handed to qa_tryp.sh through QA_SRC. QA copies only, no installs.
# Runtime: about 1.5-2 h for the full scope, 10-15 min for 5 maps. Do not run other QA games meanwhile
# (the load-time gate is serial and wants a quiet machine; its result records the load average).
# Not scripted: the user's yes on the final sheet, frame time (no stored baseline), buried props (see results.json).
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
MOD=${MOD_SRC:-$HOME/Documents/battle-art-notquiteog}
BASE=$HOME/Documents/gen1recomp-modwork/baselines/heights-2026-10-20-fix-F025.txt
OUT=; MAPS=; GATES=sweep,magenta,stairs,repeat,load,defects,floats,sheets; YAWS="0 3.14"
while [ $# -gt 0 ]; do
  case $1 in --out) OUT=$2; shift 2;; --maps) MAPS=$2; shift 2;; --gates) GATES=$2; shift 2;; --yaws) YAWS=$2; shift 2;;
    *) echo "unknown argument $1"; exit 2;; esac
done
RUN_ID=$(date +%Y%m%d-%H%M%S)
[ -z "$OUT" ] && OUT=$HOME/Documents/gen1recomp-modwork/release-runs/$RUN_ID
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)
[ -f "$OUT/run_id" ] && RUN_ID=$(cat "$OUT/run_id") || echo "$RUN_ID" > "$OUT/run_id"
if [ -z "$MAPS" ]; then cat "$ROOT/docs/ledger/outdoor_spots.txt" "$ROOT/docs/ledger/cave_spots.txt" > "$OUT/maps.txt"; DEFAULT_SCOPE=1
else cp "$MAPS" "$OUT/maps.txt"; DEFAULT_SCOPE=0; fi
has(){ case ",$GATES," in *",$1,"*) return 0;; esac; return 1; }
C="python3 $ROOT/tools/release_collect.py"
export RC_STAGGER=20 RC_STAMP=$OUT/.last_start RC_FILES="Gen3Waterfall.lua"
unset RC_SRC
# config for the collector
python3 -I - "$OUT" "$RUN_ID" "$GATES" "$YAWS" "$DEFAULT_SCOPE" "$MOD" "$BASE" <<'PY'
import json, sys, subprocess
out, rid, gates, yaws, default, mod, base = sys.argv[1:8]
h = subprocess.run("cd '%s' && find lib data -name '*.lua' | sort | xargs shasum | shasum | cut -c1-12" % mod, shell=True, capture_output=True, text=True).stdout.strip()
json.dump({'run_id': rid, 'gates': gates.split(','), 'yaws': yaws.split(), 'default_scope': default == '1', 'mod_hash': h, 'baseline': base},
          open(out + '/config.json', 'w'), indent=1)
PY
batches(){ # batches NAME COUNT [--outdoor-only]  -> list of batch dirs on stdout
  $C batches "$OUT" "$@"; }
run_all(){ # run_all MODE "dirs" : xargs -P 3 over the batch dirs
  RC_MODE=$1 xargs -P 3 -n 1 "$ROOT/tools/release_batch.sh" <<<"$2"; }
echo "[release_check] run $RUN_ID  out $OUT  maps $(wc -l < "$OUT/maps.txt")  gates $GATES"
# ---- sweep and magenta: shots at levels 4 and 7, per yaw
if has magenta; then
  mkdir -p "$OUT/probe_tree/lib"; cp "$MOD/lib/Gen3Waterfall.lua" "$OUT/probe_tree/lib/"
  sed "s/^ local color=mode=='black' and Underlay.COLORS.black or background/ local color={1,0,1,1}   -- QA PROBE ONLY (never installed): holes show as magenta/" \
    "$MOD/lib/Gen3SceneOptions.lua" > "$OUT/probe_tree/lib/Gen3SceneOptions.lua"
  cmp -s "$MOD/lib/Gen3SceneOptions.lua" "$OUT/probe_tree/lib/Gen3SceneOptions.lua" && { echo "probe sed did not change Gen3SceneOptions.lua"; exit 3; }
fi
for Y in $YAWS; do
  if has sweep; then
    echo "[sweep] yaw $Y"; D=$(batches "sweep_y$Y" 15)
    RC_LEVEL=4,7 RC_YAW=$Y RC_WAIT=80 run_all views "$D"
  fi
  if has magenta; then
    echo "[magenta] yaw $Y"; D=$(batches "magenta_y$Y" 15)
    RC_SRC=$OUT/probe_tree RC_FILES="Gen3Waterfall.lua Gen3SceneOptions.lua" RC_LEVEL=4,7 RC_YAW=$Y RC_WAIT=80 run_all views "$D"
  fi
done
# ---- cell dumps (outdoor maps only): stairs/ledge audit from run 1, repeatability from run 1 vs 2
if has stairs || has repeat; then
  echo "[dump] run 1"; D=$(batches dump1 9 --outdoor-only); RC_LEVEL=4 RC_YAW=0 RC_WAIT=60 run_all dump "$D"
fi
if has repeat; then
  echo "[dump] run 2"; D=$(batches dump2 9 --outdoor-only); RC_LEVEL=4 RC_YAW=0 RC_WAIT=60 run_all dump "$D"
fi
# ---- floats (parallel is fine: only audit lines are read)
if has floats; then echo "[floats]"; D=$(batches floats 30); RC_LEVEL=4 RC_YAW=0 RC_WAIT=60 run_all floats "$D"; fi
# ---- load time: serial, alone, warm-up map first (the collector drops it)
if has load; then
  echo "[load] serial"; D=$(batches times 60 --warmup)
  for d in $D; do RC_MODE=times RC_LEVEL=4 RC_YAW=0 RC_WAIT=60 "$ROOT/tools/release_batch.sh" "$d"; done
fi
# ---- defect scan of the baked buildings (offline)
if has defects; then echo "[defects]"; python3 "$ROOT/tools/buildings/defect_scan.py" --out "$OUT/defects" --no-preview > "$OUT/defects.log" 2>&1; fi
$C finish "$OUT"
echo "[release_check] done: $OUT/results.json"
