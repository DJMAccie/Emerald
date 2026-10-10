#!/usr/bin/env python3
"""cases.py indoor|outdoor -> a qa_run case list: one walkable spot per indoor
room, a 24-cell grid of spots per outdoor map."""
import sys,os,json,re,struct
sys.path.insert(0,os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','voxel_proto'))
import voxproto
G=voxproto.G
c=json.load(open(G+'/map_tree/census.json'));out=[]
for g in c['groups']:
  for m in g['maps']:
    h=json.load(open(G+'/map_tree/maps/%s/header.json'%m['slot']));W,H=h['width'],h['height']
    mid='EM_'+re.sub(r'(?<=[a-z])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])','_',m['id']).upper()
    if 'SECRET_BASE' in mid: continue
    # built interiors filed under the 'underground' map type
    built=any(k in mid for k in ('ABANDONED_SHIP','NEW_MAUVILLE','MAGMA_HIDEOUT','MIRAGE_TOWER')) and 'UNDERWATER' not in mid
    indoor=h['mapType'] in (8,9) or (h['mapType']==4 and built)
    if indoor!=(sys.argv[1]=='indoor'): continue
    if not indoor and h['mapType'] not in (1,2,3,5,6): continue
    cells=struct.unpack('<%dH'%(W*H),open(G+'/map_tree/maps/%s/grid.bin'%m['slot'],'rb').read())
    def free(x,y): return 0<=x<W and 0<=y<H and (cells[y*W+x]>>10&3)==0 and (cells[y*W+x]&0x3ff) not in (0,1)
    spots=[(W//2,H//2)] if indoor else [(x,y) for y in range(min(12,H//2),H,24) for x in range(min(12,W//2),W,24)]
    for sx,sy in spots:
      best=min(((abs(x-sx)+abs(y-sy),x,y) for y in range(H) for x in range(W) if free(x,y)),default=None)
      if best and (indoor or best[0]<10): out.append("{'%s',%d,%d}"%(mid,best[1],best[2]))
      elif not indoor: out.append("{'%s',%d,%d}"%(mid,sx,sy))
print(','.join(out))
