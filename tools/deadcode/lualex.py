import re
KW={'and','break','do','else','elseif','end','false','for','function','goto','if','in','local','nil','not','or','repeat','return','then','true','until','while'}
NAME=re.compile(r'[A-Za-z_][A-Za-z0-9_]*')
NUM=re.compile(r'0[xX][0-9a-fA-F]*(?:\.[0-9a-fA-F]*)?(?:[pP][+-]?\d+)?(?:ULL|LL|ull|ll|i)?|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?(?:ULL|LL|ull|ll|i)?')
OPS=['...','..','==','~=','<=','>=','::','<<','>>','//']
def lex(s):
    """yield (kind,value,start,end); kinds: name kw num str op comment"""
    i=0;n=len(s);out=[]
    while i<n:
        c=s[i]
        if c in ' \t\r\n': i+=1;continue
        if s.startswith('--',i):
            m=re.match(r'--\[(=*)\[',s[i:])
            if m:
                close=']'+m.group(1)+']';j=s.find(close,i+len(m.group(0)))
                j=n if j<0 else j+len(close)
            else:
                j=s.find('\n',i);j=n if j<0 else j
            out.append(('comment',s[i:j],i,j));i=j;continue
        m=re.match(r'\[(=*)\[',s[i:i+64]) if c=='[' else None
        if m:
            close=']'+m.group(1)+']';j=s.find(close,i+len(m.group(0)));j=n if j<0 else j+len(close)
            out.append(('str',s[i:j],i,j));i=j;continue
        if c in '"\'':
            j=i+1
            while j<n and s[j]!=c:
                if s[j]=='\\':
                    j+=2 if not s.startswith('\\z',j) else 2
                    continue
                if s[j]=='\n': break
                j+=1
            j+=1;out.append(('str',s[i:j],i,j));i=j;continue
        if c.isdigit() or (c=='.' and i+1<n and s[i+1].isdigit()):
            m=NUM.match(s,i);out.append(('num',m.group(0),i,m.end()));i=m.end();continue
        m=NAME.match(s,i)
        if m:
            v=m.group(0);out.append(('kw' if v in KW else 'name',v,i,m.end()));i=m.end();continue
        for op in OPS:
            if s.startswith(op,i): out.append(('op',op,i,i+len(op)));i+=len(op);break
        else:
            out.append(('op',c,i,i+1));i+=1
    return out
def strval(tok):
    v=tok[1]
    if v[0] in '"\'': return v[1:-1]
    m=re.match(r'\[(=*)\[\n?',v); return v[len(m.group(0)):-(len(m.group(1))+2)]
