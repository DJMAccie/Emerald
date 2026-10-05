import os,sys,glob,numpy as np
sys.path.insert(0,os.path.expanduser('~/Documents/gen1recomp-modwork/tools'))
from sheet import read_idx
G=os.path.expanduser("~/Library/Application Support/pokemon-love2d-rseqa/emerald/data/generated/gba/native/")
def load(pair):
    d=G+pair; out={}
    for t,idx in (('u','mids.idx'),('m','mids_mid.idx'),('o','mids_over.idx')):
        count,cols,rows,ids=read_idx(d+'/'+idx)
        f=glob.glob(d+'/atlas_%s_*.rgba'%t)
        if not f or not os.path.exists(d+'/'+idx): continue
        f=f[0]
        a=np.frombuffer(open(f,'rb').read(),np.uint8).reshape(rows*16,cols*16,4)
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
