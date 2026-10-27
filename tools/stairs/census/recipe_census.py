#!/usr/bin/env python3
# recipe_census.py -> recipes.tsv: offline replica of Gen3Stairs.prepare (pair + exact mid rows); landing/behaviour not checked
import sys,re,collections
sys.path.insert(0,'/Users/user/Documents/Emerald/tools/relief')
import emdata
src=open('/Users/user/Documents/battle-art-notquiteog/data/gen3_stairs.lua').read()
rec=[]
for m in re.finditer(r"\{pair='([^']+)',rows=\{(.*?)\}\s*,\s*(?:east|landing)",src):
    rows=[[int(x,16) for x in re.findall(r'0x([0-9A-Fa-f]+)',r)] for r in re.findall(r'\{([^{}]*)\}',m.group(2))]
    rec.append((m.group(1),rows))
rec.sort(key=lambda r:-len(r[1])*len(r[1][0]))
print(len(rec),'recipes')
man=emdata.manifest();norm={k[3:].replace('_','').upper():k for k in man}
_em=emdata.em_name
emdata.em_name=lambda i: norm.get(i.replace('_','').upper()) or _em(i)
out=[];cnt=collections.Counter()
for e in emdata.census()['maps']:
    try: L=emdata.Layout(e['id'])
    except Exception: continue
    used=set()
    for pair,rows in rec:
        if L.pair!=pair: continue
        w=len(rows[0]);h=len(rows)
        for y in range(L.h-h+1):
            for x in range(L.w-w+1):
                if any((x+i,y+j) in used for j in range(h) for i in range(w)): continue
                if all(L.metatile(x+i,y+j)==rows[j][i] for j in range(h) for i in range(w)):
                    for j in range(h):
                        for i in range(w): used.add((x+i,y+j))
                    out.append((L.em,pair,x,y,w,h,rec.index((pair,rows)))); cnt[pair]+=1
open('recipes.tsv','w').write('map\tpair\tx\ty\tw\th\trecipe\n'+''.join('%s\t%s\t%d\t%d\t%d\t%d\t%d\n'%o for o in out))
print(len(out),'recipe matches on',len(set(o[0] for o in out)),'maps')
for k,v in sorted(cnt.items()): print(v,k)
