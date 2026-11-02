# callers.py name [name...]: reference sites in head/lib, marked RUN if the innermost span around it ran
import sys,os,glob,re,json,bisect
D='/tmp/deadscan';cmap={int(k):v for k,v in json.load(open(D+'/probe/covmap.json')).items()}
hit=set()
for p in glob.glob(D+'/run/*/run.log'):
    for l in open(p,errors='replace'):
        m=re.match(r'\[COV\] (\d+)',l)
        if m: hit.add(int(m.group(1)))
spans={}
for i,(f,k,a,b,n) in cmap.items(): spans.setdefault(f,[]).append((a,b,i))
def ran(f,line):
    best=None
    for a,b,i in spans.get(f,[]):
        if a<=line<=b and (best is None or b-a<best[1]-best[0]): best=(a,b,i)
    return best and best[2] in hit
for name in sys.argv[1:]:
    short=name.split('.')[-1]
    print('==',name)
    for p in sorted(glob.glob(D+'/head/lib/*.lua')):
        f=os.path.basename(p)
        for ln,l in enumerate(open(p,errors='replace'),1):
            if re.search(r'[.:]'+short+r'\b|\b'+short+r'\s*\(|["\']'+short+r'["\']',l) and not re.match(r'\s*(local\s+)?function\s+[\w.:]*\b'+short+r'\s*\(',l):
                print('   %-4s %s:%d  %s'%('RUN' if ran(f,ln) else '-',f,ln,l.strip()[:110]))
