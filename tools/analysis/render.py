import os,sys,json,struct,glob
import numpy as np
from PIL import Image,ImageDraw
G=os.path.expanduser("~/Library/Application Support/pokemon-love2d-rseqa/emerald/data/generated/gba")
census=json.load(open(G+'/map_tree/census.json'))
slots={}
for g in census['groups']:
    for m in g['maps']: slots[m['id'].lower()]=m['slot']
U=json.load(open(os.path.dirname(__file__)+'/unknown.json'))
_atl={}
def atlas(pair):
    if pair in _atl: return _atl[pair]
    d=G+'/native/'+pair
    raw=open(d+'/mids.idx','rb').read()
    sys.path.insert(0,os.path.expanduser('~/Documents/gen1recomp-modwork/tools'))
    from sheet import read_idx
    count,cols,rows,ids=read_idx(d+'/mids.idx')
    aw,ah=cols*16,rows*16
    img=None
    for t in 'umo':
        f=glob.glob(d+'/atlas_%s_*.rgba'%t)
        if not f: continue
        a=np.frombuffer(open(f[0],'rb').read(),np.uint8).reshape(ah,aw,4).astype(np.float32)
        if img is None: img=a.copy()
        else:
            k=a[...,3:4]/255.0; img[...,:3]=a[...,:3]*k+img[...,:3]*(1-k); img[...,3]=np.maximum(img[...,3],a[...,3])
    _atl[pair]=(img,cols,{m:i for i,m in enumerate(ids)})
    return _atl[pair]
def render(mid_id,out,scale=3,crop=None):
    e=U[mid_id]; k=mid_id[3:].replace('_','').lower(); slot=slots.get(k) or next(v for kk,v in slots.items() if kk.replace('_','')==k)
    hdr=json.load(open(G+'/map_tree/maps/%s/header.json'%slot))
    W,H=hdr['width'],hdr['height']
    cells=struct.unpack('<%dH'%(W*H),open(G+'/map_tree/maps/%s/grid.bin'%slot,'rb').read())
    img,cols,m2s=atlas(e['pair'])
    can=np.zeros((H*16,W*16,3),np.uint8)
    for y in range(H):
        for x in range(W):
            s=m2s.get(cells[y*W+x]&0x3ff)
            if s is None: continue
            sx,sy=(s%cols)*16,(s//cols)*16
            can[y*16:y*16+16,x*16:x*16+16]=img[sy:sy+16,sx:sx+16,:3]
    im=Image.fromarray(can).resize((W*16*scale,H*16*scale),Image.NEAREST)
    d=ImageDraw.Draw(im)
    col={'u':(255,0,0),'r':(0,120,255)}
    for x,y,t in e['cells']:
        c=col.get(t)
        if c: d.rectangle([x*16*scale,y*16*scale,(x+1)*16*scale-1,(y+1)*16*scale-1],outline=c,width=2)
        if t=='u': d.text((x*16*scale+2,y*16*scale+2),'%03X'%(cells[y*W+x]&0x3ff),fill=(255,255,0))
    if crop: im=im.crop(tuple(v*16*scale for v in crop))
    im.save(out)
if __name__=='__main__':
    a=sys.argv; crop=tuple(map(int,a[3].split(','))) if len(a)>3 else None
    render(a[1],a[2],3,crop)
