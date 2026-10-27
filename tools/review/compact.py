#!/usr/bin/env python3
# compact.py <batchdir> MAP,x,y ...  -> one image per spot: 2D crop | NOW L4/L6/L7 stacked (game_<spot> frames); used where NOW == OLD
import sys, os, glob
from PIL import Image
B=sys.argv[1]; S=B+'/sheets'
for spec in sys.argv[2:]:
    m,x,y=spec.split(','); f='%s/AB_%s_%s_%s.png'%(S,m,x,y)
    a=Image.open(f)
    out=Image.new('RGB',(640+640,1080),'black')
    c=a.crop((0,0,640,1080)); c.thumbnail((640,1080)); out.paste(c,(0,0))
    for i in range(3): out.paste(a.crop((1280,i*360,1920,(i+1)*360)),(640,i*360))
    out.save('%s/C_%s_%s_%s.png'%(S,m,x,y))
