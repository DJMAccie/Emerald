#!/usr/bin/env python3
# specs.py -> ../specs_all.txt  (MAP,x,y per class representative: capture position = just below the flight's lower end)
import collections
rows=[l.rstrip('\n').split('\t') for l in open('flights.tsv')][1:]
cls=collections.defaultdict(list)
for r in rows: cls[(r[2],r[1].split(':')[0],r[8])].append(r)
out=[];seenlad=set()
for k,v in sorted(cls.items()):
    pair,b,mids=k
    if b=='ladder':
        if pair in seenlad: continue
        seenlad.add(pair)
    # prefer the largest flight
    v=sorted(v,key=lambda r:-int(r[3]))
    pick=v[:2] if b=='generic' and len(v)>=8 else v[:1]
    for r in pick:
        m,x0,y0,x1,y1,up=r[0],int(r[4]),int(r[5]),int(r[6]),int(r[7]),r[9]
        if up=='0,1': px,py=x0,y0-1
        elif up=='-1,0': px,py=x1+1,y0
        elif up=='1,0': px,py=x0-1,y0
        else: px,py=x0,y1+1
        out.append('%s,%d,%d'%(m,max(0,px),max(0,py)))
open('../specs_all.txt','w').write('\n'.join(out)+'\n')
print(len(out))
