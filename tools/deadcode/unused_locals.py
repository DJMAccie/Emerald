# unused_locals.py <mod_dir>: 'local a,b = expr' (not functions) whose names are never used in the file
import sys,os,glob,re
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import lualex
ROOT=sys.argv[1]
for p in sorted(glob.glob(ROOT+'/lib/*.lua')):
    if 'ReliefData' in p: continue
    s=open(p,encoding='utf-8').read();toks=[t for t in lualex.lex(s) if t[0]!='comment']
    cnt={}
    for k,t in enumerate(toks):
        if t[0]=='name' and not (k and toks[k-1][1] in('.',':')): cnt[t[1]]=cnt.get(t[1],0)+1
    for k,t in enumerate(toks):
        if t[1]!='local' or toks[k+1][1]=='function': continue
        names=[];j=k+1
        while toks[j][0]=='name':
            names.append(toks[j][1]);j+=1
            if toks[j][1]=='<': j+=3
            if toks[j][1]==',': j+=1
            else: break
        dead=[n for n in names if cnt.get(n,0)<=1 and n!='_']
        if dead and len(dead)==len(names):
            ln=s.count('\n',0,t[2])+1
            line=s.split('\n')[ln-1].strip()
            print('%s:%d  %s'%(os.path.basename(p),ln,line[:140]))
