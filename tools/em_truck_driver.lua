-- POKEPORT_DRIVER: landmark capture sweep.
--
-- Cases are {map, x, y}; every case is shot at each level x each yaw, so a
-- change to a landmark model can be judged from the default 50 degree camera
-- (level 4) and from the free camera (level 7) all the way round.
--
-- EM_STAGED=<dir> loads the mod's lib/ modules from <dir> instead of the
-- installed copy (a worktree of the files under test), so a change can be
-- captured before anything is installed anywhere.
--
-- Run from ~/Documents/gen1recomp:
--   POKEPORT_DRIVER=<this> POKEPORT_IDENTITY=pokemon-love2d-rseqa POKEPORT_GAME=emerald \
--   SHOT_DIR=<abs dir> EM_CASES=<cases.lua> EM_LEVELS=<levels.lua> EM_YAWS=<yaws.lua> \
--   /Applications/gen1recomp.app/Contents/MacOS/love .
return function(game)
 local U=dofile('tests/drivers/util.lua')
 local dir=assert(os.getenv('SHOT_DIR'),'SHOT_DIR is required')
 assert(love.filesystem.getIdentity()=='pokemon-love2d-rseqa','refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local exports=game.mods and game.mods.exports or {}
 local export=exports.BATTLE_ART_VOXEL_FORK
 print('[TRK] battle art export:',export and 'yes' or 'NO')
 local ns=export and (export.gen3 or export.firered)
 local C=ns and ns.camera
 print('[TRK] gen3 camera:',C and 'yes' or 'NO')

 -- ---- staged module overlay (development only, never a shipped path)
 local staged=os.getenv('EM_STAGED')
 if staged and export and export.lib then
  local V=export.lib
  local live=V.require
  local overlay,stagedNames={},{}
  for _,name in ipairs({'SpriteVoxel','LandmarkModels','Gen3Scene'})do stagedNames[name]=true end
  local function fromDisk(name)
   if overlay[name]~=nil then return overlay[name] end
   local f=assert(io.open(staged..'/'..name..'.lua','r'),'staged module missing: '..name)
   local src=f:read('*a');f:close()
   local chunk=assert(load(src,'@staged/'..name..'.lua'))
   overlay[name]=chunk(V)
   return overlay[name]
  end
  -- Gen3Scene was loaded by the mod before this driver runs, so its staged
  -- copy is swapped into the live module table (every caller reaches the
  -- scene through that table) rather than required a second time.
  local Live=live('Gen3Scene')
  V.require=function(name) if stagedNames[name] then return fromDisk(name) end return live(name) end
  local stagedScene=fromDisk('Gen3Scene')
  for k,v in pairs(stagedScene)do Live[k]=v end
  local Landmarks=V.require('LandmarkModels')
  if Landmarks then Landmarks.log=(os.getenv('EM_LANDMARK_LOG')~='0') end
  print('[TRK] staged overlay from',staged,'scene draw',tostring(stagedScene.draw~=nil))
 elseif export and export.lib then
  -- Installed path: report what the mod's own landmark module builds. The
  -- scene may have built the model before this driver ran, so the cache is
  -- dropped and the build repeated with logging on.
  local ok,L=pcall(function() return export.lib.require('LandmarkModels') end)
  if ok and L then
   L.log=(os.getenv('EM_LANDMARK_LOG')~='0')
   local okS,S=pcall(require,'src.core.game3.ow_sprites')
   if okS and S then
    L.release()
    local mesh=L.mesh(94,S.getDraw(94))
    print('[TRK] installed landmark rebuild:',mesh and 'mesh built' or 'NO MESH')
   end
  end
  print('[TRK] installed landmark module:',ok and L and 'yes' or 'no')
 end

 local Map=require('src.core.game3.map');local Player=require('src.core.game3.player')
 local cases=os.getenv('EM_CASES') and dofile(os.getenv('EM_CASES')) or {{'EM_LITTLEROOT_TOWN',6,13}}
 local levels=os.getenv('EM_LEVELS') and dofile(os.getenv('EM_LEVELS')) or {4,7}
 local yaws=os.getenv('EM_YAWS') and dofile(os.getenv('EM_YAWS')) or {0}
 local shot=0
 for _,case in ipairs(cases) do
  local map,x,y=case[1],case[2],case[3]
  local ok,err=pcall(function() assert(Map.load(nil,game,map,{x=x,y=y,facing='down'})) end)
  print('[TRK] load',map,x,y,ok,err or '')
  if ok then
   pcall(Player.reset,x,y,'down')
   for _,yaw in ipairs(yaws) do
    for _,level in ipairs(levels) do
     if C then C.setLevel(level,game);C.yaw=yaw end
     U.wait(tonumber(os.getenv('EM_WAIT')) or 120)
     shot=shot+1
     local path=string.format('%s/p%02d_%02d_lvl%d_yaw%03d.png',dir,x,y,level,math.floor(yaw*180/math.pi+0.5))
     U.shot(game,path)
     print(string.format('[TRK] shot %d %s level %s yaw %.2f',shot,path,tostring(level),yaw))
    end
   end
  end
 end
 print('[TRK] done',shot,'shots')
 love.event.quit()
end
