-- Headless host for the voxel mod's Gen 3 scene builder (engine track E1, docs/AUTOLOOP.md).
--
-- Runs the mod's REAL Lua (the release-candidate tree, read only) under plain LuaJIT, on the REAL engine
-- modules of the payload the game runs (map data, layouts, tilesets, collision), with stand-ins only where
-- the game provides a live object: LOVE itself (lib/love_stub.lua), the map loader's side effects
-- (H.loadMap), the player position, and the mod loader (H.mod / V). Nothing in the mod tree is edited.
--
--   local H=require('headless'); H.boot(); H.loadMap('EM_ROUTE103',12,10); local scene=H.Scene
local P=require('paths')
local H={P=P,standins={}}

local function readFile(path)
 local f=io.open(path,'rb');if not f then return nil end
 local s=f:read('*a');f:close();return s
end
H.readFile=readFile

-- ---------------------------------------------------------------- engine stand-ins
-- Engine modules the scene builder reaches whose real code drives a live game (input, scripts, audio,
-- sprites on screen). Each stand-in exposes only state the builder reads; H.standins counts the loads.
local STANDIN={}
-- The player: Gen3Scene.request reads Player.px/py (the build window is centred on it); the real module
-- pulls in movement, field effects and scripting. Map.load's Player.reset is mirrored in H.loadMap.
STANDIN['src.core.game3.player']=function()
 return {px=0,py=0,cellX=0,cellY=0,facing='down',elevation=3,moving=false,progress=0,spriteYOffset=0,
  reset=function(x,y,facing)end}
end

local function installStandins()
 for name,make in pairs(STANDIN)do
  package.preload[name]=function()H.standins[name]=(H.standins[name] or 0)+1;return make()end
 end
end

-- ---------------------------------------------------------------- options (QA identity, read only)
local function readOptions()
 local src=readFile(P.OPTIONS)
 local ok,t=false,nil
 if src then local f=load(src,'@options.lua','t',{});if f then ok,t=pcall(f)end end
 if not ok or type(t)~='table' then error('cannot read options '..P.OPTIONS) end
 return t
end

-- ---------------------------------------------------------------- the mod object and V (mod main.lua)
local function makeMod(options)
 local id='BATTLE_ART_VOXEL_FORK'
 local stored=(options.modOptions or {})[id] or {}
 local defaults={}
 local QA_MOD=os.getenv('HOME')..'/Library/Application Support/pokemon-love2d-rseqa/mods/'..id
 local mod={id=id,path=P.MOD_PATH,version='headless',exports={},cache=nil}
 local function hookTable(kind)
  return setmetatable({},{__index=function(_,k)return function()return function()end end end})
 end
 mod.options={
  get=function(self,key)local v=stored[key];if v==nil then v=defaults[key] end;return v end,
  define=function(self,schema)for _,row in ipairs(schema or {})do if row.key and defaults[row.key]==nil then defaults[row.key]=row.default end end;return schema end,
 }
 -- mod:read(rel): the rc tree first (lib/, data/), then the QA install (assets/, main.lua)
 function mod:read(rel)return readFile(P.RC..'/'..rel) or readFile(QA_MOD..'/'..rel)end
 mod.hooks={wrap=function()return function()end end,on=function()end}
 mod.events={on=function()end,emit=function()end}
 mod.input={press=function()end,release=function()end}
 mod.log=function()end
 mod.find=function()return nil end
 mod.assets={path=function(_,rel)return QA_MOD..'/'..rel end,image=function()return nil end}
 return mod
end

local function makeV(mod)
 local V={mod=mod,path=mod.path}
 local modules,dataFiles={},{}
 local function chunkFor(rel)
  local source=mod:read(rel)
  if not source then error(('BATTLE_ART_VOXEL_FORK: %s is missing'):format(rel),0) end
  local chunk,err=load(source,'@'..mod.path..'/'..rel)
  if not chunk then error(('BATTLE_ART_VOXEL_FORK: %s did not compile: %s'):format(rel,tostring(err)),0) end
  return chunk
 end
 function V.require(name)
  local hit=modules[name];if hit~=nil then return hit end
  local value=chunkFor('lib/'..name..'.lua')(V)
  modules[name]=value
  return value
 end
 function V.data(name)
  local hit=dataFiles[name];if hit~=nil then return hit end
  local value=chunkFor('data/'..name..'.lua')(V)
  dataFiles[name]=value
  return value
 end
 V._modules=modules
 return V
end

-- ---------------------------------------------------------------- boot
function H.boot()
 package.path=P.PAYLOAD..'/?.lua;'..P.PAYLOAD..'/?/init.lua;'..package.path
 local stub=require('love_stub')
 H.stub=stub
 _G.love=stub.love
 installStandins()
 local GV=require('src.core.GameVersion');GV.set('emerald')
 local Versions=require('src.import.gba.versions');Versions.select('emerald')
 local Dataset=require('src.core.game3.dataset')
 Dataset.cacheRootOverride=P.GBA
 Dataset.mountExtractRoots()
 local cache=Dataset.cache()
 local maps=Dataset.buildMaps()
 Dataset.attachMidLayouts(maps,cache)
 -- tile behaviours (ExtractScripts.loadBundle installs the same pack)
 do local src=cache:read(P.GBA..'/objects/pack.lua')
  local objects=src and load(src,'@pack.lua','t',{})()
  require('src.core.game3.scripting.interaction_scripts').install(objects)
 end
 local Tiles=require('src.core.game3.tileset_native')
 Tiles.install(cache,nil)
 -- the in-game driver's pins (em_geo_driver.lua): rng (Mirage Tower hidden) and tileset animation off
 require('src.core.game3.rng').Random=function()return 0 end
 require('src.core.game3.tileset_anim')._enabled=false
 H.cache,H.maps,H.Tiles=cache,maps,Tiles
 H.Map=require('src.core.game3.map')
 H.Player=require('src.core.game3.player')
 H.options=readOptions()
 H.game={data={maps=maps,tilesets={}},session={map=nil,flashLevel=0},phase='field',options=H.options,
  mods={exports={},modOptions=H.options.modOptions or {}}}
 H.mod=makeMod(H.options)
 H.game.mods.exports[H.mod.id]=H.mod.exports
 H.V=makeV(H.mod)
 return H
end

-- ---------------------------------------------------------------- Map.load, the parts the scene reads
-- (engine map.lua Map.load: current map, its def and layout, depth-1 neighbours, the player reset to the
-- spot, the world rectangle recomputed on the next request; scripts, objects, audio, weather are not run)
function H.loadMap(id,x,y,facing)
 local Map,Player=H.Map,H.Player
 local def=H.maps[id];if not def then return nil,'no map '..tostring(id) end
 Map._announced=id
 Map.current=id
 Map._loadedLayouts={[id]=true}
 Map._worldRoot=nil
 Map.ensureMidLayout(H.game,id,def)
 Map._def=def;Map._currentDef=def
 Map.loadNeighborsDepth1(H.game,def)
 H.game.session.map=id;H.game.session.x=x;H.game.session.y=y
 Player.facing=facing or 'down'
 Player.cellX,Player.cellY=x,y
 Player.px,Player.py=x*16,y*16
 Player.targetX,Player.targetY=x,y
 Player.moving=false
 -- pokefirered/src/fieldmap.c:93: a map load drops the scripted tile edits of the last visit
 local Field=require('src.core.game3.field')
 Field._session=H.game.session;Field._game=H.game
 Field.clearMetatiles(def.midLayout)
 local okC,Collision=pcall(require,'src.core.game3.collision')
 if okC and Collision.bindMap then pcall(Collision.bindMap,H.game,id,def) end
 -- the map's enter scripts, as Map.load runs them (ON_TRANSITION, ON_LOAD, ON_RESUME, ON_WARP_INTO_MAP) on the
 -- engine's own script VM with a fresh new-game flag store: their setmetatile edits (doors, tombs, Lilycove's
 -- cave rock...) are layout overrides the builder reads. ON_FRAME (cutscenes) is not run.
 H.scriptError=nil
 if H.SCRIPTS~=false then
  local ok,err=pcall(function()
   local Space=require('src.core.game3.scripting.space')
   Space.ensureBundle(nil)
   Space.attachEventsToMaps({[id]=def},Space.bundle)
   Space.activate(nil,id,H.game,nil)
   Space.runEnterScripts(nil,id,H.game,nil,{})
  end)
  if not ok then H.scriptError=tostring(err) end
 end
 return def
end
return H
