#!/usr/bin/env python3
"""Compose the Slateport sailboat template (3x3 cells) and the pair template (3x4) from the cache."""
import glob, json, os, struct, zlib
from PIL import Image
C = os.path.expanduser("~/Library/Application Support/pokemon-love2d-rseqa/emerald/data/generated/gba")
PAIR = "general__slateport"
def raw(p):
    b=open(p,'rb').read()
    try: return zlib.decompress(b)
    except Exception: return b
d=os.path.join(C,"native",PAIR)
b=raw(os.path.join(d,"mids.idx")); count,cols,rows=struct.unpack_from("<HHH",b,6)
mids=struct.unpack_from("<%dH"%count,b,12); m2s={m:i for i,m in enumerate(mids)}
base=raw(glob.glob(os.path.join(d,"atlas_m_*.rgba"))[0]); aw=cols*16
ov=glob.glob(os.path.join(d,"atlas_o_*.rgba")); over=raw(ov[0]) if ov else None
TEMPLATE=[[0x338,0x339,0x33A],[0x340,0x341,0x342],[0x348,0x349,0x34A]]
def compose(grid,name):
    w,h=len(grid[0])*16,len(grid)*16
    im=Image.new("RGBA",(w,h),(0,0,0,0)); px=im.load()
    for r,row in enumerate(grid):
        for q,mid in enumerate(row):
            sl=m2s.get(mid)
            if sl is None: continue
            sx,sy=(sl%cols)*16,(sl//cols)*16
            for y in range(16):
                for x in range(16):
                    o=((sy+y)*aw+sx+x)*4
                    rr,gg,bb,aa=base[o],base[o+1],base[o+2],base[o+3]
                    if over is not None and over[o+3]:
                        k=over[o+3]/255
                        rr=int(over[o]*k+rr*(1-k)); gg=int(over[o+1]*k+gg*(1-k)); bb=int(over[o+2]*k+bb*(1-k)); aa=max(aa,over[o+3])
                    px[q*16+x,r*16+y]=(rr,gg,bb,aa)
    im.save(name); im.resize((w*10,h*10),Image.NEAREST).save(name.replace('.png','_x10.png'))
    print(name,im.size)
compose(TEMPLATE,"/tmp/sailboat.png")
