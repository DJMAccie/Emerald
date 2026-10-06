#!/bin/bash
# fourcam.sh OUTDIR : captures OUTDIR/{p4,p7,p6,pt}/bNNN.png for OUTDIR/cases.lua
#   p4 = player's camera, p7 = turned orbit (yaw 0.9), p6 = low camera (yaw 0.5), pt = top-down (pitch 1.4)
OUT=$1; W=${EM_WAIT:-100}; T=$HOME/Documents/Emerald/tools/props
rm -f "$OUT/fourcam.done"
run(){ d=$OUT/$1; rm -rf "$d"; mkdir -p "$d"; cp "$OUT/cases.lua" "$OUT/manifest.json" "$d/"; shift
  env EM_WAIT=$W "$@" bash $T/audit_capture.sh "$d" > "$d.out" 2>&1; }
run p4 EM_LEVEL=4
run p7 EM_LEVEL=7 EM_YAW=0.9
run p6 EM_LEVEL=6 EM_YAW=0.5
run pt EM_LEVEL=7 EM_YAW=0 EM_PITCH=1.4 EM_DRIVER=$T/views_driver.lua
echo done > "$OUT/fourcam.done"
