#!/bin/bash
# sheet.sh <dir> <out.png> [cols=2]  -- contact sheet of a capture dir's PNGs, in capture order
d=$1; out=$2; cols=${3:-2}
files=$(ls -tr $d/*.png); n=$(echo "$files" | wc -l | tr -d ' ')
args=""; for f in $files; do args="$args -i $f"; done
lay=$(python3 -c "
n,c=$n,$cols
print('|'.join('%s_%s'%('+'.join(['w0']*(j%c)) or '0','+'.join(['h0']*(j//c)) or '0') for j in range(n)))")
ffmpeg -loglevel error -y $args -filter_complex "xstack=inputs=$n:layout=$lay:fill=black,scale=1600:-1" $out
