# remove.py <mod_dir> <spec.json> : spec = [[file, name, line], ...] whole function statements to delete
import sys,os,json,re,subprocess
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import lualex
ROOT=sys.argv[1];spec=json.load(open(sys.argv[2]))
OPEN={'function','do','if','repeat'};CLOSE={'end','until'}
byfile={}
for f,name,line in spec: byfile.setdefault(f,[]).append((name,line))
bad=[]
for f,items in byfile.items():
    p=os.path.join(ROOT,'lib',f);s=open(p,encoding='utf-8').read()
    toks=[t for t in lualex.lex(s) if t[0]!='comment']
    stack=[];match={}
    for i,t in enumerate(toks):
        if t[0]=='kw' and t[1] in OPEN: stack.append(i)
        elif t[0]=='kw' and t[1] in CLOSE: match[stack.pop()]=i
    def ln(pos): return s.count('\n',0,pos)+1
    cuts=[]
    for name,line in items:
        short=name.split('.')[-1].split(':')[-1].replace('local ','')
        cand=[i for i,t in enumerate(toks) if t[1]=='function' and ln(t[2])==line]
        hit=None
        for i in cand:
            a=i;b=match[i]
            nxt=toks[i+1]
            if toks[i-1][1]=='local' and nxt[1]==short: a=i-1
            elif nxt[0]=='name':
                k=i+1
                while toks[k+1][1] in('.',':'): k+=2
                if toks[k][1]!=short: continue
            elif toks[i-1][1]=='=' and toks[i-2][1]==short:
                a=i-2
                while a>=2 and toks[a-1][1] in('.',':'): a-=2
                if toks[a-1][1]=='local': a-=1
                if toks[a-1][1] in('{',',',';'):   # table entry: take the trailing separator too
                    if toks[b+1][1] in(',',';'): b+=1
            else: continue
            hit=(a,b);break
        if not hit: bad.append((f,name,line,'no match'));continue
        A=toks[hit[0]][2];B=toks[hit[1]][3]
        # widen to whole lines when only whitespace is around
        ls=s.rfind('\n',0,A)+1; le=s.find('\n',B); le=len(s) if le<0 else le
        if s[ls:A].strip()=='' and s[B:le].strip()=='': A,B=ls,min(le+1,len(s))
        cuts.append((A,B,name))
    cuts.sort()
    for x,y in zip(cuts,cuts[1:]):
        if y[0]<x[1]: bad.append((f,y[2],0,'overlaps '+x[2]))
    for A,B,_ in sorted(set(cuts),reverse=True): s=s[:A]+s[B:]
    s=re.sub(r'\n{3,}','\n\n',s)
    open(p,'w',encoding='utf-8').write(s)
    r=subprocess.run(['luajit','-bl',p,'/dev/null'],capture_output=True,text=True)
    if r.returncode: bad.append((f,'COMPILE',0,r.stderr[:300]))
print('files',len(byfile),'functions',len(spec),'problems',len(bad))
for b in bad: print('  ',b)
