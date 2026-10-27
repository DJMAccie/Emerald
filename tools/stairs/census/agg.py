#!/usr/bin/env python3
# agg.py <dump dirs...> -> flights.tsv + census.md : groups stair cells into flights (connected cells, same builder/pair)
import sys,glob,collections
rows=[];done=set()
for d in sys.argv[1:]:
    for f in sorted(glob.glob(d+'/dump_*.txt')):
        for l in open(f):
            if l.startswith('#DONE'): done.add(l.split()[1]);continue
            p=l.split()
            if len(p)<9: continue
            kv=dict(x.split('=',1) for x in p[4:] if '=' in x)
            rows.append(dict(map=p[0],x=int(p[1]),y=int(p[2]),mid=p[3],**kv))
by=collections.defaultdict(list)
for r in rows: by[(r['map'],r['builder'].rstrip('*'),r['pair'])].append(r)
flights=[]
for (m,b,pair),cs in by.items():
    cs.sort(key=lambda r:(r['x'],r['y']));seen=set();pos={(r['x'],r['y']):r for r in cs}
    for r in cs:
        k=(r['x'],r['y'])
        if k in seen: continue
        st=[k];seen.add(k);grp=[]
        while st:
            c=st.pop();grp.append(pos[c])
            for dx,dy in((1,0),(-1,0),(0,1),(0,-1)):
                n=(c[0]+dx,c[1]+dy)
                if n in pos and n not in seen: seen.add(n);st.append(n)
        xs=[g['x'] for g in grp];ys=[g['y'] for g in grp]
        flights.append(dict(map=m,builder=b,pair=pair,n=len(grp),x0=min(xs),y0=min(ys),x1=max(xs),y1=max(ys),
          mids=','.join(sorted(set(g['mid'] for g in grp))),up=grp[0]['up'],rise=grp[0]['rise']))
flights.sort(key=lambda f:(f['pair'],f['builder'],f['map'],f['y0'],f['x0']))
with open('flights.tsv','w') as o:
    o.write('map\tbuilder\tpair\tcells\tx0\ty0\tx1\ty1\tmids\tup\trise\n')
    for f in flights: o.write('\t'.join(str(f[k]) for k in('map','builder','pair','n','x0','y0','x1','y1','mids','up','rise'))+'\n')
tab=collections.defaultdict(lambda:[0,0,set()])
for f in flights:
    t=tab[(f['pair'],f['builder'])];t[0]+=1;t[1]+=f['n'];t[2].add(f['map'])
with open('census.md','w') as o:
    o.write('# Stair census (tools/stairs/census, game lib)\n\n%d maps dumped, %d with stair cells, %d flights (connected groups of stair cells, same builder + tileset pair)\n\n'%(len(done),len(set(f['map'] for f in flights)),len(flights)))
    o.write('| tileset pair | builder | flights | cells | maps |\n|---|---|---|---|---|\n')
    for (pair,b),(n,c,ms) in sorted(tab.items()):
        o.write('| %s | %s | %d | %d | %d |\n'%(pair,b,n,c,len(ms)))
print(len(done),len(flights))
