import json,glob,numpy as np,layers,collections,sys
C=json.load(open('comps.json'))
L={}
def comp_tile(pair,mid):
    if pair not in L:
        L[pair]=layers.load(pair) if glob.glob(layers.G+pair+'/atlas_u_*') else None
    Lp=L[pair]
    if not Lp: return None
    u=layers.tile(Lp,'u',mid)
    if u is None: return None
    u=u.astype(float)
    if 'o' in Lp:
        o=layers.tile(Lp,'o',mid)
        if o is not None:
            k=o[...,3:4]/255.0; u[...,:3]=o[...,:3]*k+u[...,:3]*(1-k)
    return u[...,:3]
def stats(comp):
    px=[]
    for x,y,mid in comp['cells']:
        t=comp_tile(comp['pair'],mid)
        if t is None: return None
        px.append(t.reshape(-1,3))
    p=np.concatenate(px); r,g,b=p[:,0],p[:,1],p[:,2]
    green=((g>r*1.1)&(g>b*1.05)).mean()
    blue=((b>r*1.15)&(b>=g)).mean()
    cells={(x,y) for x,y,_ in comp['cells']}
    inner=sum(1 for (x,y) in cells if sum((x+dx,y+dy) in cells for dx,dy in((1,0),(-1,0),(0,1),(0,-1)))>=3)/len(cells)
    return green,blue,inner
def rock(comp,s):
    if s is None: return False
    green,blue,inner=s
    return not comp['building'] and len(comp['cells'])>=4 and green<.15 and blue<.2 and inner>=.15
if __name__=='__main__':
    acc,rej=collections.Counter(),collections.Counter()
    res=[]
    for c in C:
        s=stats(c); ok=rock(c,s)
        (acc if ok else rej)[c['map']]+=len(c['cells'])
        res.append((c,s,ok))
    print('rock cells',sum(acc.values()),'rejected',sum(rej.values()))
    print('top rock maps',acc.most_common(15))
    
