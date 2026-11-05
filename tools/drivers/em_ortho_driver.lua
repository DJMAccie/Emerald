-- POKEPORT_DRIVER script: the "ortho45 art" capture. For each case it saves
--   MAP_x_y_ortho.png   the 3D scene from an ORTHOGRAPHIC camera looking north
--                       and down at 45 degrees (Voxel3D.debugOrtho), drawn
--                       with each surface's own texel as stored (Voxel3D.debugView
--                       "art": no sun, cast shadow, fog, tint, glow or contact
--                       darkening). This should match the 2D map art: u = x,
--                       v = z - height. Scale 2 canvas px per world px, centred on
--                       the cell's centre at the player's ground height.
-- Tilt-shift, AA, weather and day/night are OFF for the shot (their mod settings,
-- set through ModSetting:sync) and restored after. run.log's `[EM view] ...
-- active` line is printed per case, as in em_shape_driver.lua.
-- Check every case logs "active true" in run.log and the run ends "fallback 0".
-- Case: {MAP,px,py} or {MAP,px,py,cx,cy}: the player stands on (px,py) (walkable),
-- the picture is centred on (cx,cy) (default the player's cell), file MAP_cx_cy_ortho.png.
-- Before the shot the player and all objects/ghost actors are hidden (Player.setVisible,
-- Objects.forDraw, Ghosts.forDraw, restored after) and the map-name popup is dismissed.
-- Env: EM_NODARK=1 (dark caves: no flash circle), EM_CASES, EM_LEVELS, EM_YAW, EM_WAIT (qa_run.sh sets them).
-- Select it with EM_DRIVER=<this file> before tools/qa_try.sh.
-- Run from the engine root with the QA identity only.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 local dir=assert(os.getenv('SHOT_DIR'))
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local exports=game.mods and game.mods.exports or {}
 local export=exports.emerald_3d_voxel_mod
 print('[EM QA] battle art export:',export and 'yes' or 'NO')
 local ns=export and (export.gen3 or export.firered)
 local C=ns and ns.camera
 print('[EM QA] gen3 camera:',C and 'yes' or 'NO')
 local lib=export and export.lib
 local Voxel=lib and lib.require('Voxel3D')
 local Opts=lib and lib.require('Gen3SceneOptions')
 local tilt=Opts and Opts.tilt
 -- the other post passes that alter colour, each with its own mod setting
 local function setting(name)
  local ok,m=pcall(function() return lib.require(name) end)
  return ok and m and m.setting or nil
 end
 local aa=setting('AntiAlias')
 local weather=setting('Weather')
 local daytime=setting('DayNight')
 print('[EM ortho] voxel',Voxel and 'yes' or 'NO','tilt',tilt and 'yes' or 'NO',
  'aa',aa and 'yes' or 'NO','weather',weather and 'yes' or 'NO','daytime',daytime and 'yes' or 'NO')
 -- EM_STILL=1: foliage sway off, so two runs can be compared byte for byte
 if Voxel and os.getenv('EM_STILL') then Voxel.breeze=false end
 local Map=require('src.core.game3.map');local Player=require('src.core.game3.player')
 local cases=os.getenv('EM_CASES') and dofile(os.getenv('EM_CASES')) or {{'EM_LITTLEROOT_TOWN',10,10}}
 local wait=tonumber(os.getenv('EM_WAIT')) or 150
 local function shot(path)
  local f=io.open(path) if f then f:close(); path=path:gsub('%.png$','_'..(os.time()%1000)..'.png') end
  U.shot(game,path)
 end
 -- the ground under the player's cell, as the scene's actor placement reads it
 -- (see em_shape_driver.lua: probed after the map's scene is built)
 local function ground(case)
  if not Voxel then return 0 end
  local px,py=case[2]*16,case[3]*16
  local okG,g=pcall(function() return lib.require('Gen3Scene').groundAt(px+8,py+16-0.001) end)
  Voxel.debugGround=okG and g or 0
  print('[EM shape] ground',case[1],case[2],case[3],okG and g or 'ERR',tostring(g))
  return okG and g or 0
 end
 for _,case in ipairs(cases) do
  local ok,err=pcall(function() assert(Map.load(nil,game,case[1],{x=case[2],y=case[3],facing='down'})) end)
  print('[EM view] load',case[1],ok,err or '')
  if os.getenv('EM_NODARK') then pcall(function() local F=require('src.core.game3.field_view');F.setFlashLevel(0);F.setFlashRadius(5000);game.session.flashLevel=0 end) end -- dark caves: no flash circle
  if ok then
   pcall(Player.reset,case[2],case[3],'down')
   local levels=os.getenv('EM_LEVELS') and dofile(os.getenv('EM_LEVELS')) or {4}
   for li,level in ipairs(levels) do
    if C then C.setLevel(level,game);C.yaw=tonumber(os.getenv('EM_YAW')) or 0 end
    U.wait(wait)
    -- the 3D scene is built over many frames after a load (Rustboro ~9 s): wait for it
    for _=1,900 do if not C or C.active then break end;U.wait(1) end;U.wait(20)
    local g=ground(case)
    print('[EM view]',case[1],'level',level,'active',C and tostring(C.active),'rendered',C and C.rendered)
    -- the ortho shot is the same for every level (it has its own camera):
    -- take it once, on the first level
    if li==1 then
     -- case {MAP,px,py,cx,cy}: player on (px,py), picture centred on (cx,cy)
     local cx,cy=case[4] or case[2],case[5] or case[3]
     local saved={tilt=tilt and tilt:get(),aa=aa and aa:get(),weather=weather and weather:get(),
      daytime=daytime and daytime:get()}
     if tilt then tilt:sync(0) end
     if aa then aa:sync(0) end
     if weather then weather:sync('clear') end
     if daytime then daytime:sync('day') end
     -- no sprites: the player and every NPC/ghost are left out of the picture
     local Objects=package.loaded['src.core.game3.objects']
     local Ghosts=package.loaded['src.core.game3.ghosts']
     local savedVis,savedFor,savedGhost=Player.isVisible(),Objects and Objects.forDraw,Ghosts and Ghosts.forDraw
     Player.setVisible(false)
     if Objects then Objects.forDraw=function() return {} end end
     if Ghosts then Ghosts.forDraw=function() return {} end end
     if Voxel then
      Voxel.debugOrtho={x=cx*16+8,z=cy*16+8,y=g,scale=2}
      Voxel.debugView='art'
     end
     U.wait(15)
     -- the wooden map-name banner (map_name_popup: 12 frames in, 121 hold, 12 out)
     -- is dismissed here, after the wait, and is not shown again until a map change
     local NamePopup=package.loaded['src.ui.game3.map_name_popup']
     if NamePopup and NamePopup.dismiss then NamePopup.dismiss() end
     U.wait(2)
     local cw,ch=0,0
     if Voxel then cw,ch=Voxel.size() end
     local sw,sh=love.graphics.getDimensions()
     print(string.format('[EM ortho] %s %d %d view %d %d ground %s scale 2 window %dx%d canvas %sx%s',
      case[1],case[2],case[3],cx,cy,tostring(g),sw,sh,tostring(cw),tostring(ch)))
     shot(dir..'/'..case[1]..'_'..cx..'_'..cy..'_ortho.png')
     if Voxel then Voxel.debugOrtho=nil;Voxel.debugView=nil end
     Player.setVisible(savedVis)
     if Objects then Objects.forDraw=savedFor end
     if Ghosts then Ghosts.forDraw=savedGhost end
     if tilt and saved.tilt~=nil then tilt:sync(saved.tilt) end
     if aa and saved.aa~=nil then aa:sync(saved.aa) end
     if weather and saved.weather~=nil then weather:sync(saved.weather) end
     if daytime and saved.daytime~=nil then daytime:sync(saved.daytime) end
     U.wait(10)
    end
   end
  end
 end
 print('[EM QA] done')
 love.event.quit()
end
