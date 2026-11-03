"""Validate height sources and coverage; optionally render readable per-tile previews."""
import collections
import json
import math
from pathlib import Path
import re
import sys

ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'docs/elevation/draw/claude_heightmaps'
TYPES={'flat','water','object','ramp','stairs','waterfall','wall','void'}
DIRECTIONS={'N','S','E','W','NE','NW','SE','SW'}


def check():
    world=json.loads((ROOT/'tools/tilerules/input/world.json').read_text())
    maps={m['id']:m for m in world['maps']}
    aliases={}
    for line in (SRC.parent/'_same.txt').read_text().splitlines():
        if '=' in line:
            a,bs=line.split('=',1)
            for b in bs.split(','): aliases[b.strip()]=a.strip()
    errors=[];report={};total=0
    for p in sorted(SRC.glob('EM_*.json')):
        d=json.loads(p.read_text());W,H=d['width'],d['height'];issues=[]
        try:
            assert W>0 and H>0
            for field in ('type','height_map','ramp','source'):
                assert len(d[field])==H and all(len(row)==W for row in d[field]),field+' dimensions'
            if p.stem in maps:
                m=maps[p.stem];assert W<=m['w']<=W+1 and H<=m['h']<=H+1,'cartridge dimensions'
            for y,row in enumerate(d['type']):
                for x,t in enumerate(row):
                    total+=1;assert t in TYPES,(x,y,t)
                    h,r=d['height_map'][y][x],d['ramp'][y][x]
                    if t in ('wall','void'): assert h is None and r is None,(x,y,'no ground')
                    else:
                        assert isinstance(h,(int,float)) and math.isfinite(h),(x,y,'missing height')
                        if t in ('ramp','stairs','waterfall'):
                            assert r and len(r)==3 and r[2] in DIRECTIONS,(x,y,'direction')
                            assert all(isinstance(v,(int,float)) and math.isfinite(v)for v in r[:2])and r[0]<r[1],(x,y,'edges')
                            assert abs(h-(r[0]+r[1])/2)<.001,(x,y,'centre disagrees with edges')
                            if t!='waterfall' and r[1]-r[0]>2:issues.append({'kind':'steep-ramp','x':x,'y':y,'edges':r})
                        else: assert r is None,(x,y,'ramp on flat ground')
            if d.get('generator') and m['pair'].startswith('general__'):
                plain={1,2,0x1c,0x11c}
                for y in range(H):
                    for x in range(W):
                        a=m['cells'][y*m['w']+x]
                        if a&1023 not in plain or (a>>10)&3:continue
                        for dx,dy in ((1,0),(0,1)):
                            X,Y=x+dx,y+dy
                            if X>=W or Y>=H:continue
                            b=m['cells'][Y*m['w']+X]
                            if b&1023 in plain and (b>>10)&3==0 and a>>12==b>>12:
                                assert d['height_map'][y][x]==d['height_map'][Y][X],(x,y,'unbanded grass/sand height change')
            for x,y,h in d.get('user_marks',[]):
                assert abs(d['height_map'][y][x]-h)<.001,(x,y,'user mark changed')
        except AssertionError as e: errors.append(p.stem+': '+str(e))
        report[p.stem]={'tiles':W*H,'types':dict(collections.Counter(t for row in d['type']for t in row)),
                        'sources':dict(collections.Counter(s for row in d['source']for s in row)),
                        'warnings':d.get('warnings',[]),'review':issues}
    required=[m for m in world['maps']if m['type'] in (1,2,3,4,5,6)]
    for m in required:
        name=aliases.get(m['id'],m['id'])
        if name not in report: errors.append('Missing terrain map '+m['id'])
        elif m['id'] in aliases:
            d=json.loads((SRC/(name+'.json')).read_text())
            if not(d['width']<=m['w']<=d['width']+1 and d['height']<=m['h']<=d['height']+1):errors.append('Alias size '+m['id'])
    baked=(ROOT/'mod/data/gen3_heightmaps.lua').read_text()
    for name,W,H,cells in re.findall(r'(EM_[A-Z0-9_]+)=\{(\d+),(\d+),\[\[\n(.*?)\]\]\}',baked,re.S):
        if len(cells.split())!=int(W)*int(H): errors.append('Baked token count '+name)
    result={'maps':len(report),'aliases':len(aliases),'required_terrain_maps':len(required),'tiles':total,'errors':errors,'maps_detail':report}
    (SRC/'_audit.json').write_text(json.dumps(result,indent=2)+'\n')
    print('%d maps + %d aliases, %d tiles, %d required terrain maps: %d errors'%(len(report),len(aliases),total,len(required),len(errors)))
    for error in errors: print(error)
    if errors:raise SystemExit(1)
    return report


def previews(names):
    from PIL import Image,ImageDraw,ImageFont
    world=json.loads((ROOT/'tools/tilerules/input/world.json').read_text());maps={m['id']:m for m in world['maps']}
    font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Bold.ttf',16)
    small=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',10)
    vec={'N':(0,-1),'S':(0,1),'E':(1,0),'W':(-1,0),'NE':(1,-1),'NW':(-1,-1),'SE':(1,1),'SW':(-1,1)}
    rendered=0
    for name in names:
        if name not in maps:continue
        d=json.loads((SRC/(name+'.json')).read_text())
        if not d.get('generator'):continue
        m=maps[name];W,H=d['width'],d['height'];S=48
        atlas=ROOT/'tools/tilerules/input/atlases'/m['pair']
        meta=json.loads((atlas/'meta.json').read_text());aw,ah=meta['cols']*16,meta['rows']*16
        layers=[Image.frombytes('RGBA',(aw,ah),(atlas/('atlas_'+t+'.rgba')).read_bytes())for t in 'umo']
        art=layers[0]
        for layer in layers[1:]: art=Image.alpha_composite(art,layer)
        slots={int(mid):i for i,mid in enumerate((atlas/'ids.txt').read_text().split())}
        im=Image.new('RGB',(W*S,H*S))
        for y in range(H):
            for x in range(W):
                slot=slots[m['cells'][y*m['w']+x]&1023];sx,sy=slot%meta['cols']*16,slot//meta['cols']*16
                im.paste(art.crop((sx,sy,sx+16,sy+16)).resize((S,S),Image.Resampling.NEAREST),(x*S,y*S))
        draw=ImageDraw.Draw(im)
        for y in range(H):
            for x in range(W):
                h=d['height_map'][y][x];r=d['ramp'][y][x];s=d['source'][y][x]
                if h is None:continue
                color='#ffdc65' if s=='mark' else '#ffad6b'if s in ('mark-split','ramp-neighbours') else 'white'
                label='%g'%round(h,2)
                if r:
                    dx,dy=vec[r[2]];cx,cy=x*S+24,y*S+22
                    end=(cx+dx*13,cy+dy*13);start=(cx-dx*10,cy-dy*10)
                    draw.line([start,end],fill=color,width=3)
                    draw.line([end,(end[0]-dx*6+dy*5,end[1]-dy*6-dx*5)],fill=color,width=2)
                    draw.line([end,(end[0]-dx*6-dy*5,end[1]-dy*6+dx*5)],fill=color,width=2)
                    label='%g:%g'%(round(r[0],1),round(r[1],1));draw.text((x*S+2,y*S+34),label,font=small,fill=color,stroke_width=1,stroke_fill='black')
                else:draw.text((x*S+S/2,y*S+S/2),label,font=font,anchor='mm',fill=color,stroke_width=2,stroke_fill='black')
                draw.rectangle((x*S,y*S,(x+1)*S,(y+1)*S),outline='#555555',width=1)
                if x%5==0 and y%5==0:draw.text((x*S+2,y*S+1),'%d,%d'%(x,y),font=small,fill='#88ffff',stroke_width=1,stroke_fill='black')
        im.save(SRC/(name+'_preview.png'));rendered+=1
    print('Rendered %d previews'%rendered)


if __name__=='__main__':
    report=check()
    if '--previews' in sys.argv:
        names=[s for s in sys.argv[1:]if s.startswith('EM_')]
        previews(names or report)
