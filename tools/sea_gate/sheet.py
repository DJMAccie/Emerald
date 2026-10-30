import sys
from PIL import Image, ImageDraw
S=sys.argv[1]
names=['EM_SLATEPORT_CITY','EM_SOUTHERN_ISLAND_EXTERIOR','EM_EVER_GRANDE_CITY','EM_BATTLE_FRONTIER_OUTSIDE_EAST','EM_ROUTE110','EM_ROUTE119','EM_ROUTE104','EM_ROUTE123','EM_MOSSDEEP_CITY','EM_ROUTE114']
W,H=640,360
for lv in (7,4):
  for part,grp in enumerate((names[:5],names[5:])):
    sh=Image.new('RGB',(2*W,H*len(grp)),'black')
    for i,n in enumerate(grp):
        for j,d in enumerate(('shots_control','shots_sea')):
            im=Image.open(f'{S}/{d}/{n}_{lv}.png').convert('RGB').resize((W,H))
            dr=ImageDraw.Draw(im); dr.rectangle((0,0,330,16),fill=(0,0,0)); dr.text((3,2),f"{'BEFORE' if j==0 else 'AFTER (sea pin)'}  {n}",fill=(255,255,0))
            sh.paste(im,(j*W,i*H))
    sh.save(f'{S}/sheets/level{lv}_part{part+1}.png')
print('ok')
