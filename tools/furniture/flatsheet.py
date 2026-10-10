#!/usr/bin/env python3
"""flatsheet.py AUDITDIR -> AUDITDIR/flat_keys.txt and flatNN.png: one tile per
(tileset, metatile) of the audit's [FLAT] cells (blocked, built as nothing), each
drawn in its 5x5 surroundings, to sort furniture from walls and terrain by eye."""
import sys,os,re,json,collections
H=os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0,os.path.join(H,'..','buildings'));sys.path.insert(0,os.path.join(H,'..','voxel_proto'))
import bldmodel as M, voxproto
from PIL import Image,ImageDraw
S=sys.argv[1]
T={'c7c':'elite_four','c94':'battle_frontier','8b4':'pokemon_center','d24':'battle_pyramid','d84':'trainer_hill','d0c':'battle_arena','cf4':'battle_pike','dcc':'battle_tent','c44':'inside_ship','bfc':'trick_house_puzzle','cac':'battle_palace','9a4':'pokemon_day_care','95c':'cable_club','9bc':'facility','89c':'shop','af4':'brendans_mays_house','cdc':'battle_factory','d54':'mossdeep_game_corner','974':'seashore_house','cc4':'battle_dome','944':'oceanic_museum','d6c':'island_harbor','8fc':'pokemon_fan_club','db4':'battle_frontier_ranking_hall','adc':'lilycove_museum','de4':'mystery_events_house','a94':'inside_of_truck','dfc':'union_room','b84':'mauville_game_corner','98c':'pretty_petal_flower_shop','9d4':'bike_shop','b6c':'generic_building','b0c':'lab','bb4':'dewford_gym','b54':'sootopolis_gym','ac4':'contest','bcc':'mauville_gym','be4':'lavaridge_gym','c2c':'mossdeep_gym','c14':'fortree_gym',
'71c':'petalburg','764':'slateport','77c':'mauville','734':'rustboro','7c4':'fortree','7dc':'lilycove','7f4':'mossdeep','83c':'sootopolis','80c':'ever_grande','74c':'dewford','794':'lavaridge','7ac':'fallarbor','824':'pacifidlog','854':'battle_frontier_outside_west','86c':'battle_frontier_outside_east'}
G=voxproto.G;N=G+'/native'
c=json.load(open(G+'/map_tree/census.json'));slot={}
for g in c['groups']:
  for m in g['maps']: slot[m['id'].replace('_','').lower()]=m['slot']
def info(mp):
  h=json.load(open(G+'/map_tree/maps/%s/header.json'%slot[mp[3:].replace('_','').lower()]))
  sec=T.get(h['secondaryTileset'][-3:]);indoor=h['mapType'] in (8,9,4)
  if not sec: return None,indoor
  for pre in (['building__','general__'] if h['primaryTileset']!='ts_083df704' else ['general__','building__']):
    if os.path.isdir(N+'/'+pre+sec): return pre+sec,indoor
  return None,indoor
seen=collections.OrderedDict();count=collections.Counter();cells=set()
for l in open(S+'/run.log'):
  m=re.match(r'\[FLAT\] (\S+) (\d+) (\d+) (\w+)',l)
  if not m: continue
  mp,x,y,mid=m[1],int(m[2]),int(m[3]),m[4]
  if (mp,x,y) in cells: continue
  cells.add((mp,x,y))
  try: W,Hh,_=voxproto.map_cells(mp); p,indoor=info(mp)
  except Exception: continue
  if not p: continue
  if indoor and (mid=='001' or not(1<=x<W-1 and 2<=y<Hh-1)): continue
  if not indoor and int(mid,16)<0x200: continue
  k=(p,mid);count[k]+=1
  if k not in seen: seen[k]=(mp,x,y)
tiles=[];keys=[]
for (p,mid),(mp,x,y) in seen.items():
  W,Hh,_=voxproto.map_cells(mp)
  x0,y0=max(0,x-2),max(0,y-2);x1,y1=min(W-1,x+2),min(Hh-1,y+2)
  try: im=Image.fromarray(M.compose(p,mp,x0,y0,x1,y1)).convert('RGB')
  except Exception: continue
  im=im.resize((im.width*3,im.height*3),Image.NEAREST)
  d=ImageDraw.Draw(im);cx,cy=(x-x0)*48,(y-y0)*48
  d.rectangle((cx,cy,cx+47,cy+47),outline=(255,0,0),width=2)
  d.rectangle((0,0,239,12),fill=(0,0,0));d.text((2,0),'%d %s %s x%d'%(len(tiles),p.split('__')[1][:14],mid,count[(p,mid)]),fill=(255,255,0))
  tiles.append(im);keys.append('%d %s %s %s %d %d %d'%(len(tiles)-1,p,mid,mp,x,y,count[(p,mid)]))
open(S+'/flat_keys.txt','w').write('\n'.join(keys))
cols,rows_=6,4;tw,th=240,240;per=cols*rows_
for s in range(0,len(tiles),per):
  out=Image.new('RGB',(cols*tw,rows_*th),(30,30,30))
  for i,t in enumerate(tiles[s:s+per]):
    t.thumbnail((tw-4,th-4));out.paste(t,((i%cols)*tw,(i//cols)*th))
  out.save(S+'/flat%02d.png'%(s//per))
print(len(tiles))
