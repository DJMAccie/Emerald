-- OLD-SIDE PROBE ADAPTER (dirty side: Emerald repo, verifier only; never copied into ~/Documents/emerald3d).
-- Builds the neutral probe table of emerald3d docs/specs/ProbeContract.md on top of TODAY's mod internals
-- (Gen3Scene, Gen3Elevation, Voxel3D, FlatMesh), so one gate driver can measure the old mod and the rewrite.
--   local probe = dofile('<this file>')(game)   -- also sets exports.<mod>.gen3.probe when that table already exists
-- Engine-side driver code (debug allowed); QA identity only; changes nothing in the game until onMesh is used.
return function(game)
 local ex=assert(game.mods.exports.BATTLE_ART_VOXEL_FORK,'old mod BATTLE_ART_VOXEL_FORK not loaded')
 local lib=ex.lib
 local Scene=lib.require('Gen3Scene')
 local E=lib.require('Gen3Elevation')
 local Levels=lib.require('TerrainLevels')
 local R=lib.require('Voxel3D')
 local C=(ex.gen3 or ex.firered).camera
 local okPin,Pin=pcall(lib.require,'Gen3PinData')
 local Map=require('src.core.game3.map')
 local P={}

 function P.builds()return Scene.builds or 0 end
 function P.started()return Scene.prepares or 0 end
 -- (started can stay ahead of completed for good when a build is dropped; then pending stays true: approximate)
 function P.pending()return (Scene.prepares or 0)>(Scene.builds or 0) end
 function P.active()return C.active and true or false end
 function P.window()
  local b=Scene.distance and Scene.distance.bounds
  if not b then return nil end
  return b[1],b[2],b[3],b[4]
 end
 function P.setLevel(level)C.setLevel(level,game)end
 function P.groundAt(px,pz)return Scene.groundAt(px,pz)end

 local function defOf(mapId)
  local d=Map.currentDef and Map.currentDef()
  if d and (mapId==nil or d.id==mapId) then return d end
  local okD,Dataset=pcall(require,'src.core.game3.dataset')
  d=okD and Dataset.map and Dataset.map(mapId)
  if d then Map.ensureMidLayout(game,mapId,d) end
  return d
 end
 local function pinsOf(mapId)
  local t={}
  for _,p in ipairs(okPin and Pin.MAPS[mapId] or {})do t[p[1]..':'..p[2]]=p[3] end
  return t
 end
 -- field(mapId): [y][x] -> {mid, cls, height, collision, kind, pin}; heights as the scene's floor field has them
 function P.field(mapId)
  local def=defOf(mapId);if not (def and def.midLayout) then return nil end
  local l=def.midLayout;local f=E.field(def);if not f then return nil end
  local pins=pinsOf(def.id);local out={}
  for y=0,l.height-1 do local row={};out[y]=row
   for x=0,l.width-1 do
    local c=f.cells[Levels.key(x,y)];local raw=l:cellAt(x,y)
    row[x]={mid=raw and raw.mid,collision=raw and raw.coll,cls=c and c.cls,height=c and c.height,
     kind=c and (c.floor and (c.kind or 'floor') or 'blocked') or 'none',pin=pins[x..':'..y]}
   end
  end
  return out
 end

 -- (Fortree's deck tiles count as bridges, as the h3 geometry driver had it)
 local DECK={general__fortree={[0x256]=1}}
 for t=0x210,0x21D do DECK.general__fortree[t]=1 end
 local pinCache={}
 function P.cell(x,y)
  local c=Scene.debugCell(x,y);if not c then return nil end
  local r=Scene.debugRaw(x,y) or {}
  local sk=r.shape and r.shape.kind or nil
  local g=r.stairs
  local stairs=nil
  if g then stairs={};if g.r then stairs.dir=g.r.east and 'E' or 'W';stairs.up=not g.r.down end end
  local fam=DECK[r.pair]
  local bridge=(r.shape and r.shape.underWater) or (r.collision==0 and r.floor and (r.floor.layer==15 or (fam and fam[r.mid]))) or (sk and sk:match('^deck'))
  local mass=r.mass and (type(r.mass)=='table' and (r.mass.id or 't') or r.mass) or nil
  local id=Scene.sceneDef and Scene.sceneDef.id
  local pins=id and pinCache[id];if id and not pins then pins=pinsOf(id);pinCache[id]=pins end
  return {mid=c.mid,kind=c.kind,collision=c.collision,prop=c.prop,base=c.base,
   column=c.col~=nil,bridge=bridge and true or false,stairs=stairs,
   drop=(r.floor and r.floor.drop) and {from=r.floor.drop[1],to=r.floor.drop[2]} or nil,
   mass=mass,cls=r.floor and r.floor.cls or nil,height=r.floor and r.floor.height or nil,
   pin=pins and pins[x..':'..y] or nil}
 end

 -- onMesh: wrap the two upload paths (Voxel3D.newMesh for scene meshes, FlatMesh.mesh for building/prop models)
 local fns={}
 local lineCache={}
 local function srcLine(info)
  local s=info.source or '';local key=s..':'..tostring(info.currentline)
  if lineCache[key]~=nil then return lineCache[key] end
  local text=false
  if s:sub(1,1)=='@' then
   local path=s:sub(2);local body
   local fh=io.open(path,'r');if fh then body=fh:read('*a');fh:close() end
   if not body and love.filesystem.getInfo(path) then body=love.filesystem.read(path) end
   if body then local n=0
    for line in (body..'\n'):gmatch('([^\n]*)\n')do n=n+1;if n==info.currentline then text=line;break end end
   end
  end
  lineCache[key]=text;return text
 end
 local LAYER={under='ground',roof='roof',canopy='canopy',over='over',plants='plants'}
 local function layerOf()
  local info=debug.getinfo(3,'nSl') or {}
  if info.name=='upload' then
   local _,name=debug.getlocal(3,1)
   return LAYER[name] or ('other:'..tostring(name))
  end
  local t=srcLine(info) or ''
  if t:find('cache.wood',1,true) or t:find('cache.leaves',1,true) then return 'tree' end
  if t:find('part.waters',1,true) then return 'water' end
  return 'other'
 end
 local wrapped=false
 local function wrap()
  if wrapped then return end;wrapped=true
  local orig=R.newMesh
  R.newMesh=function(verts,map,format)
   if #fns>0 then local layer=layerOf();for _,fn in ipairs(fns)do fn(layer,verts,map) end end
   return orig(verts,map,format)
  end
  local ok,FM=pcall(lib.require,'FlatMesh')
  if ok and type(FM)=='table' and type(FM.mesh)=='function' then
   local omesh=FM.mesh
   FM.mesh=function(f,n)
    if n and n>0 and #fns>0 then
     local verts={}
     for v=0,n/6-1 do local o=v*6;verts[v+1]={f[o+1],f[o+2],f[o+3],f[o+4],f[o+5],f[o+6]} end
     local idx={}
     for q=0,#verts/4-1 do local b=q*4;local m=#idx
      idx[m+1],idx[m+2],idx[m+3],idx[m+4],idx[m+5],idx[m+6]=b+1,b+2,b+3,b+1,b+3,b+4
     end
     for _,fn in ipairs(fns)do fn('model',verts,idx) end
    end
    return omesh(f,n)
   end
  end
 end
 function P.onMesh(fn)wrap();fns[#fns+1]=fn end

 -- (never create exports.gen3 here: old code picks its camera with `ex.gen3 or ex.firered`)
 if type(ex.gen3)=='table' then ex.gen3.probe=P end
 return P
end
