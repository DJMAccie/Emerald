-- Probe for the E2 design (no geometry): do two maps' floor heights agree from every viewpoint?
--   emhost engine/probes/align_views.lua [--json OUT] MAP [MAP ...]   (default: the ledger's outdoor maps)
-- For each root map, the builder's own path: Map.refreshWorld (AUTO reach), Gen3Boundary.regions, every
-- region's floor field (Gen3Elevation.field) and TerrainLevels.align (offsets from the root's seams).
-- Then for every pair of maps seen together from several roots, compares their relative offset across roots.
local here=debug.getinfo(1,'S').source:match('^@(.*)/probes/[^/]*$') or '.'
package.path=here..'/lib/?.lua;'..package.path
local H=require('headless')
local maps,json={},nil
do local i=1;while i<=#arg do if arg[i]=='--json' then json=arg[i+1];i=i+1 else maps[#maps+1]=arg[i] end;i=i+1 end end
if #maps==0 then
 for l in io.lines(os.getenv('HOME')..'/Documents/Emerald/docs/ledger/outdoor_spots.txt')do local m=l:match('^(%S+)');if m then maps[#maps+1]=m end end
end
H.boot()
local V=H.V
local Elev=V.require('Gen3Elevation')
local Levels=V.require('TerrainLevels')
local Boundary=V.require('Gen3Boundary')
local radius=32 -- AUTO on desktop
local views={}   -- views[root][mapId]=offset
for _,root in ipairs(maps)do
 local def=H.maps[root]
 if def and def.midLayout then
  H.loadMap(root,0,0)
  H.Map.refreshWorld(H.game,radius*2+12,radius*2+12,root)
  Boundary.clear()
  local regions=Boundary.regions(def,H.Map.world)
  for _,r in ipairs(regions)do r.floorField=Elev.field(r.def) end
  Levels.align(regions)
  local v={}
  for _,r in ipairs(regions)do v[r.def.id]=r.floorOffset end
  views[root]=v
 end
end
-- pairs (A,B) seen from >=2 roots: relative offset off(B)-off(A) per root
local pairsSeen,disagree,total={}, {},0
local ids={};for id in pairs(views)do ids[#ids+1]=id end;table.sort(ids)
local rel={}
for _,root in ipairs(ids)do local v=views[root]
 local ms={};for m in pairs(v)do ms[#ms+1]=m end;table.sort(ms)
 for i=1,#ms do for j=i+1,#ms do local a,b=ms[i],ms[j]
  local k=a..'|'..b;rel[k]=rel[k] or {};rel[k][#rel[k]+1]={root,v[b]-v[a]}
 end end
end
local keys={};for k in pairs(rel)do keys[#keys+1]=k end;table.sort(keys)
local multi,bad=0,0
local out={}
for _,k in ipairs(keys)do local list=rel[k]
 if #list>=2 then multi=multi+1
  local seen={};local n=0;for _,e in ipairs(list)do if not seen[e[2]] then seen[e[2]]=true;n=n+1 end end
  if n>1 then bad=bad+1
   local parts={};for _,e in ipairs(list)do parts[#parts+1]=e[1]:gsub('^EM_','')..'='..e[2] end
   out[#out+1]=k:gsub('EM_','')..'  '..table.concat(parts,' ')
  end
 end
end
print(('[align] roots %d, map pairs seen from 2+ roots %d, pairs whose relative height differs by root %d'):format(#ids,multi,bad))
for _,l in ipairs(out)do print('  '..l) end
if json then local f=io.open(json,'w');f:write('{"roots":'..#ids..',"pairs":'..multi..',"disagree":'..bad..'}\n');f:close() end
