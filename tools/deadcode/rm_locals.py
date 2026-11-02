# rm_locals.py <mod_dir> : delete unused 'local ... = expr' statements listed by unused_locals.py (one statement each)
import sys,os,subprocess,re
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import lualex
ROOT=sys.argv[1]
out=subprocess.run(['python3',os.path.dirname(os.path.abspath(__file__))+'/unused_locals.py',ROOT],capture_output=True,text=True).stdout
todo={}
for l in out.splitlines():
    f,ln=l.split()[0].split(':');todo.setdefault(f,[]).append(int(ln))
OPEN={'(','{','['};CLOSE={')','}',']'}
for f,lines in todo.items():
    p=ROOT+'/lib/'+f;s=open(p).read();toks=[t for t in lualex.lex(s) if t[0]!='comment']
    L=lambda pos:s.count('\n',0,pos)+1
    cuts=[]
    for ln in lines:
        k=next(i for i,t in enumerate(toks) if t[1]=='local' and L(t[2])==ln)
        j=k+1
        while toks[j][0]=='name' and toks[j+1][1]==',': j+=2
        end=j
        if j+1<len(toks) and toks[j+1][1]=='=':
            d=0;b=0;m=j+2
            while True:
                t=toks[m]
                if t[1] in OPEN: d+=1
                elif t[1] in CLOSE: d-=1
                elif t[1] in('function','do','if','repeat'): b+=1
                elif t[1] in('end','until'): b-=1
                nxt=toks[m+1] if m+1<len(toks) else None
                if d==0 and b==0 and (nxt is None or (L(nxt[2])>L(t[3]-1) and t[1] not in('..','+','-','*','/','and','or','=',',','==','~=','<','>','<=','>=') and nxt[1] not in('..','+','-','*','/','and','or',',','==','~=','<','>','<=','>=',')','}',']','.',':','(','[','{'))): break
                if nxt and nxt[1]==';' and d==0 and b==0: m+=1;break
                m+=1
            end=m
        A=toks[k][2];B=toks[end][3]
        ls=s.rfind('\n',0,A)+1;le=s.find('\n',B);le=len(s) if le<0 else le
        if s[ls:A].strip()=='' and s[B:le].strip()=='': A,B=ls,le+1
        cuts.append((A,B))
    for A,B in sorted(cuts,reverse=True): s=s[:A]+s[B:]
    open(p,'w').write(s)
    r=subprocess.run(['luajit','-bl',p,'/dev/null'],capture_output=True,text=True)
    print(f,len(lines),'OK' if r.returncode==0 else 'COMPILE FAIL '+r.stderr[:200])
