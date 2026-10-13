-- POKEPORT_DRIVER script: like em_views_driver.lua, but for each case and level
-- it saves three shots:
--   MAP_level.png        normal rendering, exactly as the mod draws it
--   MAP_level_clay.png   clay: every world surface plain grey, shaded only by
--                        face direction (tops 0.92, sides 0.30 to 0.70), a
--                        45% darkening in cast shadow, and slightly lighter
--                        high ground. No texture, tint, fog or glass.
--   MAP_level_depth.png  depth: grey by height relative to the player's own
--                        ground (Voxel3D.debugGround, set per case): -32 px
--                        black, +96 px white, linear; a dark line every 16 px,
--                        and a thick, much darker line at the player's floor.
-- Sprites and characters keep their texture in both shape views.
-- Tilt-shift is OFF for the clay and depth shots (the mod's T-SHIFT setting,
-- set through ModSetting:sync, which does not persist) and restored after.
-- Check every case logs "active true" in run.log and the run ends "fallback 0".
-- Env: EM_CASES, EM_LEVELS, EM_YAW, EM_WAIT (qa_run.sh sets them);
-- EM_STILL=1 turns foliage sway off so two runs can be compared byte for byte.
-- Run from the engine root with the QA identity only.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 local dir=assert(os.getenv('SHOT_DIR'))
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local exports=game.mods and game.mods.exports or {}
 local export=exports.BATTLE_ART_VOXEL_FORK
 print('[EM QA] battle art export:',export and 'yes' or 'NO')
 local ns=export and (export.gen3 or export.firered)
 local C=ns and ns.camera
 print('[EM QA] gen3 camera:',C and 'yes' or 'NO')
 local lib=export and export.lib
 local Voxel=lib and lib.require('Voxel3D')
 local Opts=lib and lib.require('Gen3SceneOptions')
 local tilt=Opts and Opts.tilt
 print('[EM shape] voxel',Voxel and 'yes' or 'NO','tilt',tilt and 'yes' or 'NO')
 -- EM_STILL=1: foliage sway off, so two runs of the same code can be compared byte for byte
 if Voxel and os.getenv('EM_STILL') then Voxel.breeze=false end
 local Map=require('src.core.game3.map');local Player=require('src.core.game3.player')
 local cases=os.getenv('EM_CASES') and dofile(os.getenv('EM_CASES')) or {{'EM_LITTLEROOT_TOWN',10,10}}
 local wait=tonumber(os.getenv('EM_WAIT')) or 150
 local function shot(path)
  local f=io.open(path) if f then f:close(); path=path:gsub('%.png$','_'..(os.time()%1000)..'.png') end
  U.shot(game,path)
 end
 for _,case in ipairs(cases) do
  local ok,err=pcall(function() assert(Map.load(nil,game,case[1],{x=case[2],y=case[3],facing='down'})) end)
  print('[EM view] load',case[1],ok,err or '')
  if ok then
   pcall(Player.reset,case[2],case[3],'down')
   -- depth and clay are measured from the player's own floor: the ground
   -- under the player's cell, as the scene's actor placement reads it
   -- (probed after the scene of this map has been built: asked right after
   -- the load it answered from the previous map, or 0)
   local function ground()
    if not Voxel then return end
    local px,py=case[2]*16,case[3]*16
    local okG,g=pcall(function() return lib.require('Gen3Scene').groundAt(px+8,py+16-0.001) end)
    Voxel.debugGround=okG and g or 0
    print('[EM shape] ground',case[1],case[2],case[3],okG and g or 'ERR',tostring(g))
   end
   for _,level in ipairs(os.getenv('EM_LEVELS') and dofile(os.getenv('EM_LEVELS')) or {4}) do
    if C then C.setLevel(level,game);C.yaw=tonumber(os.getenv('EM_YAW')) or 0 end
    U.wait(wait)
    -- the scene of a new map is built over many frames now (flat map meanwhile): wait for it
    for _=1,900 do if not C or C.active then break end;U.wait(1) end;U.wait(20)
    ground()
    print('[EM view]',case[1],'level',level,'active',C and tostring(C.active),'rendered',C and C.rendered)
    local base=dir..'/'..case[1]..'_'..level
    -- normal: exactly what the unmodified mod draws
    shot(base..'.png')
    -- clay and depth: field set, T-SHIFT off, a few frames for the switch
    local saved=tilt and tilt:get()
    if tilt then tilt:sync(0) end
    for _,mode in ipairs({'clay','depth'}) do
     if Voxel then Voxel.debugView=mode end
     U.wait(10)
     print('[EM shape]',case[1],level,mode,'set',Voxel and tostring(Voxel.debugView) or 'NO-VOXEL')
     shot(base..'_'..mode..'.png')
    end
    if Voxel then Voxel.debugView=nil end
    if tilt and saved~=nil then tilt:sync(saved) end
    U.wait(10)
   end
  end
 end
 print('[EM QA] done')
 love.event.quit()
end
