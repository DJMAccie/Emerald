#!/usr/bin/env python3
# sheet.py <capdir> <outdir> [specfile]  one sheet per spot: 2D crop (centred on the spot, 15x11 cells) | L4 | L6 | L7
import sys,os,glob,subprocess
sys.path.insert(0,'/Users/user/Documents/Emerald/tools/relief')
import emdata
from PIL import Image,ImageDraw
cap,out=sys.argv[1],sys.argv[2];os.makedirs(out,exist_ok=True)
man=emdata.manifest();norm={k[3:].replace('_','').upper():k for k in man}
_em=emdata.em_name
emdata.em_name=lambda i: norm.get(i.replace('_','').upper()) or _em(i)
specs=[l.strip() for l in open(sys.argv[3])] if len(sys.argv)>3 else None
W,H=640,360
for d in sorted(glob.glob(cap+'/game_*/')):
    d=d.rstrip('/');name=os.path.basename(d)[5:]
    m,x,y=name.rsplit('_',2);x=int(x);y=int(y)
    if specs and ('%s,%d,%d'%(m,x,y)) not in specs: continue
    dst=out+'/ST_%s.png'%name
    if os.path.exists(dst) and not os.environ.get('FORCE'): continue
    shots={}
    for lv in (4,6,7):
        fs=sorted(glob.glob('%s/*_%d*.png'%(d,lv)))
        if fs: shots[lv]=Image.open(fs[0]).convert('RGB').resize((W,H))
    if not shots: continue
    L=emdata.Layout(m)
    crop=out+'/crop_%s.png'%name
    subprocess.run(['python3','/Users/user/Documents/Emerald/skills/emerald-terrain/scripts/crop2d.py',L.slot,L.pair,
      str(max(0,x-7)),str(max(0,y-8)),str(min(L.w-1,x+7)),str(min(L.h-1,y+3)),crop,'2'],check=True)
    c=Image.open(crop).convert('RGB');c.thumbnail((W,H))
    sh=Image.new('RGB',(2*W,2*H),'black');sh.paste(c,(0,0))
    pos={4:(W,0),6:(0,H),7:(W,H)}
    for lv,im in shots.items():
        im=im.copy();dr=ImageDraw.Draw(im);dr.rectangle((0,0,300,16),fill=(0,0,0));dr.text((3,2),'%s %d,%d L%d'%(m,x,y,lv),fill=(255,255,0))
        sh.paste(im,pos[lv])
    sh.save(dst);print(dst)
