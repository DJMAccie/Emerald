# usage: instrument.py <mod_src_dir> <out_dir>   -> out_dir/main.lua, out_dir/lib/*.lua, out_dir/covmap.json
import sys,os,glob,json
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import lualex
SRC,OUT=sys.argv[1],sys.argv[2]
os.makedirs(OUT+'/lib',exist_ok=True)
OPEN={'function','do','if','repeat'};CLOSE={'end','until'}
cmap={};nid=0
def line(s,p): return s.count('\n',0,p)+1
for path in sorted(glob.glob(SRC+'/lib/*.lua')):
    base=os.path.basename(path)
    s=open(path,encoding='utf-8').read()
    toks=[t for t in lualex.lex(s) if t[0]!='comment']
    stack=[];match={};clauses={}
    for i,t in enumerate(toks):
        if t[0]=='kw' and t[1] in OPEN: stack.append(i)
        elif t[0]=='kw' and t[1] in CLOSE: match[stack.pop()]=i
        elif t[0]=='kw' and t[1] in('then','elseif','else'):
            top=stack[-1];assert toks[top][1]=='if',(base,line(s,t[2]))
            clauses.setdefault(top,[]).append(i)
    ins=[]
    def new(kind,a,b,name):
        global nid
        nid+=1;cmap[nid]=[base,kind,line(s,a),line(s,b),name];return nid
    ins.append((0,'__COV[%d]=1;'%new('chunk',0,len(s),base)))
    for i,t in enumerate(toks):
        if t[0]=='kw' and t[1]=='function':
            k=i+1
            while toks[k][1]!='(': k+=1
            nm=''.join(x[1] for x in toks[i+1:k])
            if not nm:
                p=toks[i-1][1];q=toks[i-2]
                if p=='=' and q[0]=='name': nm=q[1]
            if i and toks[i-1][1]=='local': nm='local '+nm
            k2=k
            while toks[k2][1]!=')': k2+=1
            ins.append((toks[k2][3],' __COV[%d]=1;'%new('func',toks[i][2],toks[match[i]][3],nm)))
    for ifi,cl in clauses.items():
        endi=match[ifi]
        for n,ci in enumerate(cl):
            if toks[ci][1]=='elseif': continue
            nxt=cl[n+1] if n+1<len(cl) else endi
            ins.append((toks[ci][3],' __COV[%d]=1;'%new(toks[ci][1],toks[ci][2],toks[nxt][2],'')))
    ins.sort(key=lambda x:-x[0])
    for p,txt in ins: s=s[:p]+txt+s[p:]
    open(OUT+'/lib/'+base,'w',encoding='utf-8').write(s)
m=open(SRC+'/main.lua',encoding='utf-8').read()
hook='''local __seen={}
__COV=setmetatable({},{__newindex=function(t,k,v) rawset(t,k,v) print('[COV] '..k) end})
'''
m=m.replace('local V = { mod = mod, path = mod.path }',hook+'local V = { mod = mod, path = mod.path }',1)
assert '__COV=' in m
open(OUT+'/main.lua','w',encoding='utf-8').write(m)
json.dump(cmap,open(OUT+'/covmap.json','w'))
print('ids',nid)
