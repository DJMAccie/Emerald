#!/usr/bin/env python3
# warp_census.py -> warps.tsv: every map cell whose metatile behaviour is a stair warp (0x6A-0x6F), offline from map data
import sys,collections
sys.path.insert(0,'/Users/user/Documents/Emerald/tools/relief')
import emdata
man=emdata.manifest();norm={k[3:].replace('_','').upper():k for k in man}
_em=emdata.em_name
emdata.em_name=lambda i: norm.get(i.replace('_','').upper()) or _em(i)
out=[];cnt=collections.Counter()
for e in emdata.census()['maps']:
    try: L=emdata.Layout(e['id'])
    except Exception as ex: print('skip',e['id'],ex); continue
    for y in range(L.h):
        for x in range(L.w):
            b=L.behaviour(x,y)
            if 0x6A<=b<=0x6F:
                out.append((L.em,L.pair,x,y,L.metatile(x,y),b)); cnt[(L.pair,b)]+=1
open('warps.tsv','w').write('map\tpair\tx\ty\tmid\tbeh\n'+''.join('%s\t%s\t%d\t%d\t%03X\t%02X\n'%o for o in out))
print(len(out),'stair-warp cells on',len(set(o[0] for o in out)),'maps')
for k,v in sorted(cnt.items()): print(v,k)
