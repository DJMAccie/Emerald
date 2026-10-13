import sys,re,os,glob
from collections import defaultdict, Counter
# Reads the cell dumps of tools/em_cells_driver.lua (<dir>/st/dump*.txt) and checks
#  (1) every staircase: joins floors at different heights (ok), the same height (flat),
#      the north floor lower than the south (reversed, N-S only), or one end blocked (odd);
#  (2) every walkable 4-neighbour pair more than one level (16 px) apart, with neither cell a
#      stair, ladder, ledge, rail, bridge/deck or water (cliff pairs = impossible height jumps).
# Writes <dir>/stairs_all.tsv and <dir>/cliff_pairs.tsv. Old dumps (no flags) still work.
# usage: stairs_audit.py <dir>
P=sys.argv[1]
man=open(os.path.expanduser('~/Library/Application Support/pokemon-love2d-rseqa/emerald/data/generated/gba/native/manifest.lua')).read()
info={a:(b,int(c),int(d)) for a,b,c,d in re.findall(r'\["(EM_[A-Z0-9_]+)"\] = \{ pair = "([a-z_0-9]+)", width = (\d+), height = (\d+)',man)}
GEN={0xAF,0xCF}
SEC={'cave':{0x204,0x363},'meteor_falls':{0x202},'mirage_tower':{0x204},'navel_rock':{0x204,0x37B},'lavaridge':{0x2AF},'sootopolis':{0x244,0x245},'facility':{0x328,0x329}}
CAVE_PAIRS={'general__cave','general__meteor_falls','general__mirage_tower','general__navel_rock','general__lavaridge','general__pacifidlog','general__rusturf_tunnel','secret_base__secret_base_yellow_cave'}
def place(mp,pair):
    if pair.startswith('building__'): return 'indoor'
    if any(k in mp for k in ('EXTERIOR','OUTSIDE','ROUTE','CITY','TOWN','JAGGED_PASS','SAFARI','NAVEL_ROCK_TOP','BIRTH_ISLAND')): return 'outdoor'
    if pair in CAVE_PAIRS or 'CAVE' in mp: return 'cave'
    if pair in ('general__facility','general__inside_ship','general__contest'): return 'indoor'
    return 'outdoor'
maps=defaultdict(dict)
for f in sorted(glob.glob(P+'/st/dump*.txt')):
    for l in open(f):
        p=l.split()
        try:
            flags={}
            for t in p[9:]:
                if '=' in t:
                    k,v=t.split('=',1); flags[k]=v
            maps[p[0]][(int(p[1]),int(p[2]))]=(int(p[3],16),p[4],p[5][5:],float(p[8][5:]) if p[8][5:] not in ('nil','') else 0.0,
                {'stairs':flags.get('stairs')=='1','ladder':flags.get('ladder')=='1','ledge':flags.get('ledge')=='1',
                 'rail':flags.get('rail')=='1','bridge':flags.get('bridge')=='1','door':flags.get('door')=='1','sdir':flags.get('sdir','-'),'elev':flags.get('elev','nil')})
        except Exception: pass
# ---- (1) staircases
flat=[];ok=0;odd=[];rev=[];rows_out=[];cnt=Counter();per=defaultdict(Counter)
for mp,cells in sorted(maps.items()):
    pair,W,H=info.get(mp,('',0,0));sec=pair.split('__')[-1]
    def stair(k):
        c=cells.get(k)
        if not c: return False
        if c[4]['stairs']: return True
        if c[2] in ('7','255'): return False
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
        # E-W is tested too: a flight is flat only if every axis that has floors on both sides is level
        axes=[]
        if n is not None and s is not None: axes.append(('N-S',n,s))
        if w is not None and e is not None: axes.append(('E-W',w,e))
        differ=[a for a in axes if abs(a[1]-a[2])>=1]
        # a flight with a warp (door cell) in it leads to another map: its far end is no floor here
        warp=any(cells[q][4]['door'] for q in strip if q in cells)
        note=''
        if warp:
            cls='odd';axis='warp';note='warp in flight';a=n if n is not None else w;b=s if s is not None else e
            odd.append((mp,k,rows,cols,'warp in flight',a,b))
        elif differ:
            ax,a,b=differ[0]
            if ax=='N-S' and a<b: cls='reversed';rev.append((mp,k,rows,cols,'N-S',n,s))
            else: cls='ok';ok+=1
            axis=ax
        elif axes:
            cls='flat';axis=axes[0][0];a,b=axes[0][1],axes[0][2];flat.append((mp,k,rows,cols,axis,a,b))
        else:
            cls='odd';axis='one-end';a=n if n is not None else w;b=s if s is not None else e
            odd.append((mp,k,rows,cols,'one end blocked',a,b))
        if cls=='reversed': a,b=n,s
        if cls=='odd' and not warp: a,b=(n if n is not None else w),(s if s is not None else e)
        cnt[cls]+=1
        if cls!='ok': per[mp][cls]+=1
        fa='' if a is None else '%.0f'%a; fb='' if b is None else '%.0f'%b
        f0=min(strip,key=lambda q:(q[1],q[0]))
        rows_out.append((mp,f0[0],f0[1],rows,cols,axis,fa,fb,cls,pair,place(mp,pair),note))
print('ok',ok,'flat',len(flat),'odd',len(odd)+len(rev),'(odd includes reversed %d)'%len(rev))
print('by class:',dict(cnt))
print('== stairs joining floors at the same height ==')
bym=defaultdict(list)
for r in flat: bym[r[0]].append(r)
for m,v in sorted(bym.items()): print(m,len(v),[(r[1],'%dx%d'%(r[3],r[2]),r[4],r[5]) for r in v][:6])
print('== odd ==')
for r in odd: print(r)
print('== reversed (north floor lower than south) ==')
for r in rev: print(r)
print('== staircases by place and class (ok/flat/reversed/odd) ==')
pc=Counter()
for r in rows_out: pc[(r[10],r[8])]+=1
for pl in ('outdoor','cave','indoor'): print(pl,' '.join('%s %d'%(c,pc[(pl,c)]) for c in ('ok','flat','reversed','odd')))
with open(P+'/stairs_all.tsv','w') as f:
    f.write('map\tx\ty\trows\tcols\taxis\tfloor_a\tfloor_b\tclass\ttileset\tplace\tnote\n')
    for r in rows_out: f.write('\t'.join(str(v) for v in r)+'\n')
# ---- (2) impossible height jumps between walkable neighbours
def is_stair(mp,pair,sec,c):
    return c[4]['stairs'] or c[1]=='steps' or (pair.startswith('general__') and c[0] in GEN) or c[0] in SEC.get(sec,())
cl_rows=[];cl_per=Counter();bl_per=Counter();bl_rows=[];cl_pl=Counter();bl_pl=Counter()
def crossable(ea,eb):
    # pokefirered/src/event_object_movement.c:8346 via game3/collision.lua elevationMismatchOn:
    # a step from a cell of nibble ea onto eb is refused when ea and eb are both not 0 or 15 and differ
    if ea not in (0,15) and eb not in (0,15) and ea!=eb: return False
    return True
def nib(v):
    try: return int(v)
    except Exception: return None
for mp,cells in sorted(maps.items()):
    pair,W,H=info.get(mp,('',0,0));sec=pair.split('__')[-1]
    def ok_cell(k):
        c=cells.get(k)
        if not c or not(0<=k[0]<W and 0<=k[1]<H): return False
        if c[2] not in('0','nil'): return False
        if c[1] in('water','tree'): return False
        f=c[4]
        if f['ladder'] or f['ledge'] or f['rail'] or f['bridge'] or is_stair(mp,pair,sec,c): return False
        return True
    for k in sorted(cells):
        if not ok_cell(k): continue
        for d in ((1,0),(0,1)):
            q=(k[0]+d[0],k[1]+d[1])
            if ok_cell(q):
                dh=cells[q][3]-cells[k][3]
                if abs(dh)>16.01:
                    row=(mp,k[0],k[1],'%g'%cells[k][3],cells[k][1],q[0],q[1],'%g'%cells[q][3],cells[q][1],'%g'%dh,pair,place(mp,pair),
                         cells[k][4]['elev'],cells[q][4]['elev'])
                    if crossable(nib(cells[k][4]['elev']),nib(cells[q][4]['elev'])):
                        cl_per[mp]+=1;cl_pl[place(mp,pair)]+=1;cl_rows.append(row)
                    else:
                        bl_per[mp]+=1;bl_pl[place(mp,pair)]+=1;bl_rows.append(row)
with open(P+'/cliff_pairs.tsv','w') as f:
    f.write('map\tx1\ty1\tbase1\tkind1\tx2\ty2\tbase2\tkind2\tdh\ttileset\tplace\telev1\telev2\n')
    for r in cl_rows: f.write('\t'.join(str(v) for v in r)+'\n')
with open(P+'/cliff_blocked.tsv','w') as f:
    f.write('map\tx1\ty1\tbase1\tkind1\tx2\ty2\tbase2\tkind2\tdh\ttileset\tplace\telev1\telev2\n')
    for r in bl_rows: f.write('\t'.join(str(v) for v in r)+'\n')
print('== walkable height jumps > 16 px (cliff pairs) ==')
print('total',sum(cl_per.values()),'maps',len(cl_per),' by place:',dict(cl_pl))
print('blocked by elevation (a cliff the game enforces): total',sum(bl_per.values()),'maps',len(bl_per),' by place:',dict(bl_pl))
for m,nn in sorted(bl_per.items(),key=lambda kv:-kv[1]): print('  blocked',m,nn)
for m,nn in sorted(cl_per.items(),key=lambda kv:-kv[1]): print(m,nn)
