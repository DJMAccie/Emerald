#!/bin/bash
# try.sh "<lib files>" <outdir> "<cases>" [levels=4] [yaw=0]
# Try mod source files in a private QA copy with the user's zoom (-2) and NPCs hidden.
cd ~/Documents/Emerald
QA_ZOOM=${QA_ZOOM:--2} EM_HIDE_NPCS=1 EM_DRIVER=$HOME/Documents/Emerald/tools/furniture/driver.lua tools/qa_tryp.sh "$1" "$2" "$3" "${4:-4}" "${5:-0}" 60
