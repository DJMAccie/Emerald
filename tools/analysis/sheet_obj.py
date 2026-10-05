import json,collections,numpy as np,layers,sys
from PIL import Image,ImageDraw
g=json.load(open('groups.json'))
skip=sys.argv[1].split(',') if len(sys.argv)>1 else []
seen=collections.OrderedDict()
cnt=collections.Counter(x['key'] for x in g)
import os
for x in sorted(g,key=lambda x:-cnt[x['key']]):
    if not __import__('glob').glob(layers.G+x['pair']+'/atlas_u_*'): continue
    if x['key'] in seen or any(x['key'].startswith(s) for s in skip): continue
    seen[x['key']]=x
items=list(seen.values())[:48]
Ls={}
def cut(L,mid,ground):
    t=layers.tile(L,'u',mid).astype(int); gr=layers.tile(L,'u',ground).astype(int) if ground is not None else None
    a=np.ones((16,16),bool)
    if gr is not None:
        a&=~(np.abs(t[...,:3]-gr[...,:3]).sum(2)==0)   # positional
    return t,a
S=4;tiles=[]
for x in items:
    L=Ls.get(x['pair']) or Ls.setdefault(x['pair'],layers.load(x['pair']))
    if 'u' not in L: continue
    cells=[(c[0],c[1],c[2]) for c in x['cells']]+[(c[0],c[1],c[2]) for c in x['tops']]
    xs=[c[0] for c in cells];ys=[c[1] for c in cells]
    x0,y0=min(xs),min(ys);w,h=max(xs)-x0+1,max(ys)-y0+1
    A=np.zeros((h*16,w*16,3),np.uint8)+[40,40,40];B=np.zeros((h*16,w*16,3),np.uint8)+[255,0,255]
    for cx,cy,mid in cells:
        t,a=cut(L,mid,x['ground'])
        A[(cy-y0)*16:(cy-y0)*16+16,(cx-x0)*16:(cx-x0)*16+16]=t[...,:3]
        bb=B[(cy-y0)*16:(cy-y0)*16+16,(cx-x0)*16:(cx-x0)*16+16];bb[a]=t[...,:3][a]
    im=Image.new('RGB',(2*64*S//2+8+ 0,0))
    pane=Image.new('RGB',(4*16*S*2//2*2+12, 4*16*S//2+14),(20,20,20))
    sc=2
    pane.paste(Image.fromarray(A.astype(np.uint8)).resize((w*16*sc,h*16*sc),Image.NEAREST),(2,12))
    pane.paste(Image.fromarray(B.astype(np.uint8)).resize((w*16*sc,h*16*sc),Image.NEAREST),(4*16*sc+8,12))
    ImageDraw.Draw(pane).text((2,0),'%dx %s g=%s'%(cnt[x['key']],x['key'][:30],'%03X'%x['ground'] if x['ground'] is not None else '-'),fill=(255,255,0))
    tiles.append(pane)
cols=4;pw,ph=tiles[0].size;rows=(len(tiles)+cols-1)//cols
sheet=Image.new('RGB',(cols*pw,rows*ph),(0,0,0))
for i,t in enumerate(tiles):sheet.paste(t,((i%cols)*pw,(i//cols)*ph))
sheet.save('objsheet.png');print(sheet.size,len(tiles))
