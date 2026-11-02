# report.py <covmap.json> <run.log>... : outermost never-hit spans per file
import sys,json,re,collections
cmap={int(k):v for k,v in json.load(open(sys.argv[1])).items()}
hit=set()
for p in sys.argv[2:]:
    for l in open(p,errors='replace'):
        m=re.match(r'\[COV\] (\d+)',l)
        if m: hit.add(int(m.group(1)))
byf=collections.defaultdict(list)
for i,(f,kind,a,b,name) in cmap.items(): byf[f].append((a,b,i,kind,name))
tot_dead=0;rows=[]
for f,items in byf.items():
    miss=[x for x in items if x[2] not in hit]
    # outermost: drop spans inside another missed span
    miss.sort(key=lambda x:(x[0],-x[1]))
    outer=[];end=-1
    for x in miss:
        if x[0]>=0 and x[1]<=end and outer and x[0]>=outer[-1][0]: continue
        outer.append(x);end=max(end,x[1])
    lines=sum(b-a+1 for a,b,*_ in outer)
    chunk_hit=any(x[2] in hit for x in items if x[3]=='chunk')
    rows.append((lines,f,outer,chunk_hit))
    tot_dead+=lines
rows.sort(reverse=True)
print('hit',len(hit),'of',len(cmap),' never-run lines ~',tot_dead)
for lines,f,outer,ch in rows:
    if lines==0: continue
    print('%-30s %5d %s'%(f,lines,'' if ch else '(MODULE NEVER LOADED)'))
    if '-v' in sys.argv[0:1] or True:
        for a,b,i,kind,name in sorted(outer,key=lambda x:-(x[1]-x[0]))[:int(__import__('os').environ.get('TOP','6'))]:
            print('      %5d-%-5d %-6s %s'%(a,b,kind,name))
