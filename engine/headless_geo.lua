-- Headless geometry dump: runs the in-game driver tools/autoloop/em_geo_driver.lua ITSELF, unmodified, without
-- the game. Its output is therefore the driver's format and logic by construction (spot walk, ownership, capture,
-- settle), and follows every change made to the driver.
--   emhost engine/headless_geo.lua --out DIR [--driver FILE] [--spots FILE] [--full] [--boot] [--no-scripts]
--          [--anim-steps N] MAP[=x,y] [MAP ...]
-- What the driver gets from the game is stood in here (see engine/README.md):
--   game:_handleBootAction(new_game)  -> H.loadMap(start)          (the boot map's scripts run; no new-game UI)
--   U.wait(n) (tests/drivers/util.lua) -> n frames; a frame = Gen3Scene's prepare() (request -> stream -> build),
--                                          the part of Scene.draw that builds; with the frozen clock a build is
--                                          one frame. The camera's .active is set when the scene is ready.
--   Map.load(mod, game, id, opts)      -> H.loadMap(id, opts.x, opts.y)
--   game.mods.exports.BATTLE_ART_VOXEL_FORK -> {lib=V, gen3={camera=Gen3Integration's camera}}
--   EM_SETTLE defaults to 3 frames (a headless build is never in flight across frames).
-- Spots: MAP=x,y, else --spots FILE, else docs/ledger/{outdoor,cave}_spots.txt. --full: the mod's FULL render
-- distance (one spot covers the map). --boot: let the boot wait (90 frames in Littleroot) build Littleroot first,
-- as in the game (default: the boot map is loaded but not built; no difference found). --no-scripts: skip the maps'
-- enter scripts. --anim-steps N: advance Littleroot's tileset animation N steps first (the driver before
-- 20 Oct 18:30 pinned the animation only after its boot).
local here=debug.getinfo(1,'S').source:match('^@(.*)/[^/]*$') or '.'
package.path=here..'/lib/?.lua;'..package.path
local H=require('headless')

local HOME=os.getenv('HOME')
local args={maps={},out=nil,spots=nil,full=false,boot=false,animSteps=0,
 driver=HOME..'/Documents/Emerald/tools/autoloop/em_geo_driver.lua'}
do local i=1
 while i<=#arg do local a=arg[i]
  if a=='--out' then args.out=arg[i+1];i=i+1
  elseif a=='--spots' then args.spots=arg[i+1];i=i+1
  elseif a=='--driver' then args.driver=arg[i+1];i=i+1
  elseif a=='--anim-steps' then args.animSteps=tonumber(arg[i+1]);i=i+1
  elseif a=='--full' then args.full=true
  elseif a=='--boot' then args.boot=true
  elseif a=='--no-scripts' then args.noScripts=true
  elseif a=='--quiet' then args.quiet=true
  else args.maps[#args.maps+1]=a end
  i=i+1
 end
end
assert(args.out and #args.maps>0,'usage: headless_geo.lua --out DIR [--driver FILE] [--spots FILE] [--full] [--boot] [--no-scripts] MAP[=x,y] ...')

-- spots
local spotOf={}
local function readSpots(path)
 local f=io.open(path,'r');if not f then return end
 for l in f:lines()do local m,x,y=l:match('^(%S+)%s+(%d+)%s+(%d+)');if m and not spotOf[m] then spotOf[m]={tonumber(x),tonumber(y)} end end
 f:close()
end
if args.spots then readSpots(args.spots) end
readSpots(HOME..'/Documents/Emerald/docs/ledger/outdoor_spots.txt');readSpots(HOME..'/Documents/Emerald/docs/ledger/cave_spots.txt')
local lines={}
for _,a in ipairs(args.maps)do
 local m,x,y=a:match('^([^=]+)=(%d+),(%d+)$')
 if not m then local s=spotOf[a];assert(s,'no spot for '..a..' (give MAP=x,y or --spots FILE)');m,x,y=a,s[1],s[2] end
 lines[#lines+1]=('%s %d %d'):format(m,x,y)
end
os.execute('mkdir -p "'..args.out..'"')
local mapsFile=os.tmpname()
do local f=assert(io.open(mapsFile,'w'));f:write(table.concat(lines,'\n'),'\n');f:close() end

-- the driver's environment variables
local outDir=args.out:sub(1,1)=='/' and args.out or (io.popen('pwd'):read('*l')..'/'..args.out)
local ENV={EM_MAPS=mapsFile,EM_GEO_DIR=outDir,EM_SETTLE=os.getenv('EM_SETTLE') or '3',EM_MARGIN=os.getenv('EM_MARGIN')}
local getenv=os.getenv

local T0=os.clock()
H.boot()
if args.noScripts then H.SCRIPTS=false end
local V=H.V
local Scene=V.require('Gen3Scene')
local C=V.require('Gen3Integration')   -- exports.gen3.camera in the game
local Map=H.Map
if args.full then V.require('RenderDistance').setting:sync(false) end
local function upvalue(f,name)
 for i=1,255 do local n,v=debug.getupvalue(f,i);if not n then return nil end;if n==name then return v end end
end
local prepare=assert(upvalue(Scene.draw,'prepare'),'Gen3Scene.draw has no prepare upvalue')
local stub=H.stub
stub.clock.frozen=false

-- one game frame: the scene's prepare(), as Scene.draw (through Gen3Integration's FieldView.draw) runs it
local frames=0
local holdBoot=not args.boot
local function frame()
 frames=frames+1
 if holdBoot then C.active=false;return end
 -- the clock stands still while the frame builds (BuildBudget never yields); between frames it is CPU time
 stub.clock.t=os.clock();stub.clock.frozen=true
 local ok,res=xpcall(prepare,debug.traceback,H.game,1280,720,C)
 stub.clock.frozen=false
 if not ok then error(res,0) end
 C.active=res and true or false
end
local U={wait=function(n)for _=1,(n or 1)do frame()end end}

-- the game object the driver is handed
local game=H.game
game.mods.exports.BATTLE_ART_VOXEL_FORK={lib=V,gen3={camera=C},firered={camera=C}}
function game:_handleBootAction(a)
 local s=a and a.start or {}
 H.loadMap(s.map or 'EM_LITTLEROOT_TOWN',s.x or 10,s.y or 10,s.facing)
end
-- the game's Map.load, as far as the scene reads it (headless.lua H.loadMap); the driver's first Map.load ends
-- the boot hold
Map.load=function(mod,g,id,opts)
 opts=opts or {}
 holdBoot=false
 local def,err=H.loadMap(id,tonumber(opts.x) or 0,tonumber(opts.y) or 0,opts.facing)
 if H.scriptError then print('[EM headless] '..tostring(id)..' enter scripts failed: '..H.scriptError) end
 if not def then error(err,0) end
 return {mapId=id}
end

if args.animSteps>0 then
 local TA=require('src.core.game3.tileset_anim')
 H.Tiles.get(H.maps.EM_LITTLEROOT_TOWN.midLayout.pair)
 local pin=TA._enabled;TA._enabled=true
 for _=1,args.animSteps do TA.step() end
 TA._enabled=pin
end

-- load and run the driver, unmodified: its own globals, with dofile('tests/drivers/util.lua') and os.getenv
-- answered here
local src=assert(io.open(args.driver,'r')):read('*a')
local env=setmetatable({},{__index=_G})
env.dofile=function(p)if p=='tests/drivers/util.lua' then return U end return dofile(p)end
env.os=setmetatable({getenv=function(k)if ENV[k]~=nil then return ENV[k] end return getenv(k)end},{__index=os})
local chunk=assert(load(src,'@'..args.driver))
setfenv(chunk,env)
local driver=chunk()
local okRun,errRun=xpcall(function()driver(game)end,debug.traceback)
os.remove(mapsFile)
if not okRun then io.stderr:write(tostring(errRun),'\n');os.exit(1) end
if not args.quiet then
 local names={};for k,v in pairs(stub.unknown)do names[#names+1]=k..'='..v end;table.sort(names)
 print('[EM headless] love stand-ins reached: '..(#names>0 and table.concat(names,' ') or 'none'))
 local st={};for k in pairs(H.standins)do st[#st+1]=k end;table.sort(st)
 print('[EM headless] engine stand-ins: '..table.concat(st,' ')..('  frames %d  total %.1fs CPU'):format(frames,os.clock()-T0))
end
