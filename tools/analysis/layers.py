import os,sys,glob,zlib,struct,numpy as np
def _raw(path):
    # the engine now stores its tile cache zlib-compressed (2026-10-05)
    b=open(path,'rb').read()
    return zlib.decompress(b) if b[:1]==b'\x78' else b
def read_idx(path):
    b=_raw(path)
    assert b[:4]==b'SVMI','bad mids.idx magic'
    count,cols,rows=struct.unpack_from('<HHH',b,6)
    return count,cols,rows,struct.unpack_from('<%dH'%count,b,12)
G=os.path.expanduser("~/Library/Application Support/pokemon-love2d-rseqa/emerald/data/generated/gba/native/")
def load(pair):
    d=G+pair; out={}
    for t,idx in (('u','mids.idx'),('m','mids_mid.idx'),('o','mids_over.idx')):
        count,cols,rows,ids=read_idx(d+'/'+idx)
        f=glob.glob(d+'/atlas_%s_*.rgba'%t)
        if not f or not os.path.exists(d+'/'+idx): continue
        f=f[0]
        a=np.frombuffer(_raw(f),np.uint8).reshape(rows*16,cols*16,4)
        out[t]=(a,cols,{m:i for i,m in enumerate(ids)})
    return out
def tile(L,t,mid):
    a,cols,m2s=L[t]; s=m2s.get(mid)
    if s is None: return None
    return a[(s//cols)*16:(s//cols)*16+16,(s%cols)*16:(s%cols)*16+16]
if __name__=='__main__':
    pair=sys.argv[1]; L=load(pair)
    for m in sys.argv[2:]:
        mid=int(m,16); r=[]
        for t in 'umo':
            x=tile(L,t,mid); r.append('%s:%s'%(t,'-' if x is None else int((x[...,3]>0).sum())))
        print(pair,m,' '.join(r))
