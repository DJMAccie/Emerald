#!/bin/bash
# tools/furniture/shot.sh <outdir> "<cases>" [level] [yaw] [wait]  -- qa_run.sh with the
# furniture driver (NPCs hidden, trainer sight off; EM_AUDIT=1 prints [AUD]/[FLAT] lines)
H=$(cd "$(dirname "$0")" && pwd)
EM_HIDE_NPCS=1 EM_DRIVER="$H/driver.lua" "$H/../qa_run.sh" "$@"
