import sys,re,os,glob
from collections import defaultdict
P=sys.argv[1]
man=open(os.path.expanduser('~/Library/Application Support/pokemon-love2d-rseqa/emerald/data/generated/gba/native/manifest.lua')).read()
info={a:(b,int(c),int(d)) for a,b,c,d in re.findall(r'\["(EM_[A-Z0-9_]+)"\] = \{ pair = "([a-z_0-9]+)", width = (\d+), height = (\d+)',man)}
GEN={0xAF,0xCF}
SEC={'cave':{0x204,0x363},'meteor_falls':{0x202},'mirage_tower':{0x204},'navel_rock':{0x204,0x37B},'lavaridge':{0x2AF},'sootopolis':{0x244,0x245},'facility':{0x328,0x329}}
maps=defaultdict(dict)
for f in glob.glob(P+'/st/dump*.txt'):
    for l in open(f):
        p=l.split()
        try: maps[p[0]][(int(p[1]),int(p[2]))]=(int(p[3],16),p[4],p[5][5:],float(p[8][5:]) if p[8][5:] not in ('nil','') else 0.0)
        except Exception: pass
flat=[];ok=0;odd=[]
for mp,cells in sorted(maps.items()):
    pair,W,H=info.get(mp,('',0,0));sec=pair.split('__')[-1]
    def stair(k):
        c=cells.get(k)
        if not c or c[2] in ('7','255'): return False
        if k[0]<0 or k[1]<0 or k[0]>=W-1 or k[1]>=H-1: return False
        return c[1] in('steps',) or (pair.startswith('general__') and c[0] in GEN) or c[0] in SEC.get(sec,())
    seen=set()
    for k in sorted(cells):
        if k in seen or not stair(k): continue
        strip=[];st=[k];seen.add(k)
        while st:
            q=st.pop();strip.append(q)
            for d in ((1,0),(-1,0),(0,1),(0,-1)):
                n=(q[0]+d[0],q[1]+d[1])
                if n not in seen and stair(n): seen.add(n);st.append(n)
        xs=[q[0] for q in strip];ys=[q[1] for q in strip]
        def floor(pts):
            v=[cells[q][3] for q in pts if q in cells and cells[q][2] not in('7','255') and not stair(q)]
            return (sum(v)/len(v)) if v else None
        n=floor([(x,min(ys)-1) for x in set(xs)]);s=floor([(x,max(ys)+1) for x in set(xs)])
        w=floor([(min(xs)-1,y) for y in set(ys)]);e=floor([(max(xs)+1,y) for y in set(ys)])
        rows=max(ys)-min(ys)+1;cols=max(xs)-min(xs)+1
        if n is not None and s is not None:
            if abs(n-s)<1: flat.append((mp,k,rows,cols,'N-S',n,s))
            elif n<s: odd.append((mp,k,rows,cols,'north lower',n,s))
            else: ok+=1
        elif w is not None and e is not None:
            if abs(w-e)<1: flat.append((mp,k,rows,cols,'E-W',w,e))
            else: ok+=1
        else: odd.append((mp,k,rows,cols,'one end blocked',n if n is not None else w,s if s is not None else e))
print('ok',ok,'flat',len(flat),'odd',len(odd))
bym=defaultdict(list)
for r in flat: bym[r[0]].append(r)
print('== stairs joining floors at the same height ==')
for m,v in sorted(bym.items()): print(m,len(v),[(r[1],'%dx%d'%(r[3],r[2]),r[4],r[5]) for r in v][:6])
print('== odd ==')
for r in odd: print(r)
