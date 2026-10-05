import rockcls,render,numpy as np,collections,sys
from PIL import Image,ImageDraw
REP=6
def tilestats(pair,mid):
    t=rockcls.comp_tile(pair,mid)
    if t is None: return None
    p=t.reshape(-1,3);r,g,b=p[:,0],p[:,1],p[:,2]
    return ((g>r*1.1)&(g>b*1.05)).mean(),((b>r*1.15)&(b>=g)).mean()
def classify(mp):
    comps=[c for c in rockcls.C if c['map']==mp]
    if not comps: return set(),{}
    pair=comps[0]['pair']
    U={(x,y):mid for c in comps for x,y,mid in c['cells']}
    freq=collections.Counter(U.values())
    cand=set()
    for p,mid in U.items():
        s=tilestats(pair,mid)
        if s and freq[mid]>=REP and s[0]<.2 and s[1]<.25: cand.add(p)
    # components of candidates: size>=4 and thick
    rock=set();seen=set()
    for p in cand:
        if p in seen: continue
        st=[p];l=[];seen.add(p)
        while st:
            q=st.pop();l.append(q)
            for dx,dy in((1,0),(-1,0),(0,1),(0,-1)):
                n=(q[0]+dx,q[1]+dy)
                if n in cand and n not in seen: seen.add(n);st.append(n)
        inner=sum(1 for (x,y) in l if sum((x+dx,y+dy) in l for dx,dy in((1,0),(-1,0),(0,1),(0,-1)))>=3)/len(l)
        if len(l)>=4 and inner>=.15: rock.update(l)
    # a door-bearing original component that is mostly drawing is a building
    for c in comps:
        if c['building']:
            cells=[(x,y) for x,y,_ in c['cells']]
            share=sum(1 for p in cells if p in rock)/len(cells)
            if share<.6:
                for p in cells: rock.discard(p)
    return rock,U
if __name__=='__main__':
    tot=collections.Counter()
    maps=sorted({c['map'] for c in rockcls.C})
    for mp in maps:
        r,U=classify(mp)
        if r: tot[mp]=len(r)
    print('rock cells',sum(tot.values()));print(tot.most_common(25))
    for mp in sys.argv[1:]:
        r,U=classify(mp)
        render.render(mp,'t.png',1,(0,0,render.U[mp]['w'],render.U[mp]['h']))
        im=Image.open('t.png');d=ImageDraw.Draw(im)
        for (x,y) in U: d.rectangle([x*16,y*16,x*16+15,y*16+15],outline=(0,255,0) if (x,y) in r else (255,0,0),width=2)
        im.thumbnail((1000,1000));im.save('rep_'+mp+'.png')
