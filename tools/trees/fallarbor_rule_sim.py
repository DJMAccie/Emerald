import re,collections,sys
cells={}
for l in open('/Users/user/Documents/Emerald/.rewrite/baseline/w0a/EM_FALLARBOR_TOWN.cells'):
    p=l.split()
    if len(p)<5: continue
    cells[(int(p[1]),int(p[2]))]=p[3]
gold={}
for l in open('/Users/user/Documents/Emerald/.rewrite/night/p1b/draw_gold_fal.txt'):
    if l.startswith('I '):
        p=l.split(); vc=int(p[1]); m=re.search(r'\{([-\d.]+),([-\d.]+),([-\d.]+)\}',l)
        x,y,z=map(float,m.groups())
        c='G' if 5900<=vc<=6600 else 'H' if 11000<=vc<=11800 else 'A' if 9500<=vc<=10300 else None
        if c: gold[(x,z)]=c
GREEN={'206','207','20E','20F','26B','26C','273','274'}; ASH={'204','205','20C','20D','26D','26E','275','276'}
ROOT={'20F':'G','26B':'G','274':'G','20D':'A','26D':'A','276':'A'}
xs=range(-8,28); zs=range(-8,28)
inmap=lambda x,z: 0<=z<=27
def run(ringmode, fillmode, runpar):
    pred={}; fill=set()
    for z in zs:
        for x in xs:
            t=cells.get((x,z))
            if t not in GREEN and t not in ASH: continue
            up=cells.get((x,z-1))
            if not inmap(x,z) and ringmode=='evenodd':
                if x%2==0 and z%2==0: pred[(x*16, z*16+10)]='G' if t in GREEN else 'A'
                continue
            if t==up and fillmode: fill.add((x,z)); continue
            if t in ROOT: pred[(x*16, z*16+10)]=ROOT[t]
    claimed=set()
    for z in zs:
        if z%2: continue
        x=-8
        while x<=27:
            if (x,z) in fill:
                start=x
                while (x,z) in fill:
                    if (x-start+runpar)%2==0:
                        fam='H' if inmap(x,z) else ('G' if cells[(x,z)] in GREEN else 'A')
                        pred[(x*16+16, z*16+12)]=fam
                        for dx in (0,1):
                            for dz in (0,1): claimed.add((x+dx,z+dz))
                    x+=1
            else: x+=1
    for z in zs:
        for x in xs:
            if (x,z) in fill and (x,z) not in claimed:
                fam='H' if inmap(x,z) else ('G' if cells[(x,z)] in GREEN else 'A')
                pred[(x*16+16, z*16+12)]=fam
                for dx in (0,1):
                    for dz in (0,1): claimed.add((x+dx,z+dz))
    W=lambda p: -8*16<=p[0]<=28*16 and -8*16<=p[1]<=28*16
    gw={k:v for k,v in gold.items() if W(k)}
    hit=sum(1 for k,v in pred.items() if gw.get(k)==v)
    fp=[(k,v) for k,v in pred.items() if k not in gw]; miss=[(k,v) for k,v in gw.items() if k not in pred]
    reg=lambda k: 'north' if k[1]<0 else ('west' if k[0]<0 else 'map')
    return hit,len(gw),collections.Counter(reg(k) for k,v in fp),collections.Counter(reg(k) for k,v in miss),fp,miss
if __name__=='__main__':
    for rm in ('evenodd','root'):
        for fm in (True,False):
            for rp in (0,1):
                h,n,fp,miss,_,_=run(rm,fm,rp)
                print(f'ring={rm:8s} fill={fm!s:5s} runpar={rp}: hit {h}/{n}  fp {dict(fp)}  miss {dict(miss)}')
