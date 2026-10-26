# Contact sheet: every Fly user in three art sets (followsprites 4x4, HGSS 9-frame, PMD walk 8 dirs).
import sys,os
from PIL import Image,ImageDraw
W=os.path.expanduser('~/Library/Application Support/pokemon-love2d/mods/overworld_wild_spawns/assets/')
nats=[int(x) for x in open('nats.txt').read().split()]
names=open('names.txt').read().split()
S=2
rows=[]
for n,name in zip(nats,names):
    parts=[]
    p=W+'enhanced_overworld/followsprites/%03d-b-n.png'%n
    if not os.path.exists(p):
        import glob;g=sorted(glob.glob(W+'enhanced_overworld/followsprites/%03d-*-n.png'%n));p=g[0] if g else None
    if p: parts.append(Image.open(p).convert('RGBA'))
    p=W+'hgss/%d-normal-9.png'%n
    if os.path.exists(p):
        im=Image.open(p).convert('RGBA');w=im.size[0]
        strip=Image.new('RGBA',(w*9,w));[strip.paste(im.crop((0,i*w,w,(i+1)*w)),(i*w,0)) for i in range(9)];parts.append(strip)
    rows.append((n,name,parts))
H=sum(max([p.size[1] for p in parts]+[32])*S+18 for _,_,parts in rows)
Wd=900
out=Image.new('RGBA',(Wd,H),(120,170,220,255));d=ImageDraw.Draw(out);y=0
for n,name,parts in rows:
    d.text((4,y+2),'%d %s'%(n,name),fill=(0,0,0,255));x=110;h=max([p.size[1] for p in parts]+[32])*S
    for p in parts:
        q=p.resize((p.size[0]*S,p.size[1]*S),Image.NEAREST)
        if x+q.size[0]>Wd: q=q.crop((0,0,Wd-x,q.size[1]))
        out.paste(q,(x,y+14),q);x+=q.size[0]+20
    y+=h+18
out.save('/Users/user/Documents/Emerald/docs/faults/fly/SHEET_flyers_art_sets.png');print(out.size)
