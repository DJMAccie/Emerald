#!/bin/bash
# tools/furniture/batch.sh OUTROOT LIST -- seven views per room.
# LIST lines: id|{'MAP',x,y}|{'MAP',x,y}  (head-height case | low-view case)
# writes OUTROOT/rooms/np_<id>_top.png (player cam + 2 orbits) and _low.png (4 low views)
H=$(cd "$(dirname "$0")" && pwd); O=$1; L=$2; mkdir -p "$O/rooms"
A=$(cut -d'|' -f2 "$L" | paste -sd, -); B=$(cut -d'|' -f3 "$L" | paste -sd, -)
EM_INDEXED=1 "$H/shot.sh" "$O/v4" "$A" 4 0 >/dev/null &
EM_INDEXED=1 "$H/shot.sh" "$O/v7a" "$A" 7 0.7 >/dev/null &
EM_INDEXED=1 "$H/shot.sh" "$O/v7b" "$A" 7 -0.7 >/dev/null &
wait
for y in 0 1.57 3.14 -1.57; do EM_INDEXED=1 "$H/shot.sh" "$O/v6_$y" "$B" 6 $y >/dev/null & done; wait
python3 - "$O" "$L" <<'PY'
import sys,glob
from PIL import Image
O,L=sys.argv[1:3]
ids=[l.split('|')[0] for l in open(L) if l.strip()]
def get(d,i):
    f=sorted(glob.glob('%s/%s/b*.png'%(O,d)))
    return Image.open(f[i]).convert('RGB').resize((1280,720)) if i<len(f) else Image.new('RGB',(1280,720))
for i,n in enumerate(ids):
    t=Image.new('RGB',(2560,1440)); k=0
    for j,d in enumerate(['v4','v7a','v7b']):
        im=get(d,i); t.paste(im,((j%2)*1280,(j//2)*720))
    t.save('%s/rooms/np_%s_top.png'%(O,n))
    t=Image.new('RGB',(2560,1440))
    for j,y in enumerate(['0','1.57','3.14','-1.57']):
        t.paste(get('v6_'+y,i),((j%2)*1280,(j//2)*720))
    t.save('%s/rooms/np_%s_low.png'%(O,n)); print(n,'ok')
PY
