-- POKEPORT_DRIVER script: cold-map frame timing. Boots EM_LITTLEROOT_TOWN at
-- 10,10 (timed from the boot call itself), then for each case in EM_CASES
-- times Map.load and the next 240 frames one at a time. A frame is the wall
-- interval between two consecutive resumes of this driver (one main-loop
-- update plus its draw). No screenshots except one per map at the end.
-- Camera level 4 as em_shape_driver does. Env: EM_CASES (cases file).
-- Run from the engine root with the QA identity only.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 local dir=assert(os.getenv('SHOT_DIR'))
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 print('[EM cold] vsync',tostring(love.window.getVSync()),'fps-at-start',string.format('%.1f',love.timer.getFPS()))
 local Map=require('src.core.game3.map');local Player=require('src.core.game3.player')
 local cases=os.getenv('EM_CASES') and dofile(os.getenv('EM_CASES')) or {}
 local FRAMES=240
 local function camera()
  local export=game.mods and game.mods.exports and game.mods.exports.BATTLE_ART_VOXEL_FORK
  local ns=export and (export.gen3 or export.firered)
  return ns and ns.camera
 end
 local function measure(name,x,y,loadFn)
  local C=camera()
  local base=C and C.rendered or 0
  local t0=love.timer.getTime()
  local ok,err=pcall(loadFn)
  local t1=love.timer.getTime()
  local tload=t1-t0
  print('[EM view] load',name,ok,err or '')
  if C then C.setLevel(4,game) end
  local prev=t1
  local d={}
  local first3d,first3dMs=nil,nil
  local acc=tload
  for f=1,FRAMES do
   U.wait(1)
   local now=love.timer.getTime()
   d[f]=now-prev;prev=now
   acc=acc+d[f]
   if not first3d and C and C.active and C.rendered>base then first3d=f;first3dMs=acc*1000 end
  end
  local sorted={}
  local sum60,over33,over100,max,at=0,0,0,0,0
  for f=1,FRAMES do
   local v=d[f]
   if f<=60 then sum60=sum60+v end
   if v>0.033 then over33=over33+1 end
   if v>0.1 then over100=over100+1 end
   if v>max then max=v;at=f end
   sorted[f]=f
  end
  table.sort(sorted,function(a,b) return d[a]>d[b] end)
  local copy={} for i=1,FRAMES do copy[i]=d[i] end table.sort(copy)
  local med=(copy[120]+copy[121])/2
  print(string.format('[EM cold] %s load_ms %.1f first3d_frame %s first3d_ms %s max_frame_ms %.1f at_frame %d frames_over_33ms %d frames_over_100ms %d sum_first_60_ms %.1f median_ms %.2f',
   name,tload*1000,tostring(first3d or 'none'),first3dMs and string.format('%.1f',first3dMs) or 'none',max*1000,at,over33,over100,sum60*1000,med*1000))
  local top={}
  for i=1,5 do top[#top+1]=string.format('%d:%.1f',sorted[i],d[sorted[i]]*1000) end
  print('[EM cold] top5',name,table.concat(top,' '))
  print('[EM view]',name,'level 4 active',C and tostring(C.active) or 'NO-CAMERA','rendered',C and C.rendered or 'NO-CAMERA')
  U.shot(game,dir..'/'..name..'_cold.png')
 end
 -- boot map, timed from the boot call
 measure('EM_LITTLEROOT_TOWN(boot)',10,10,function()
  game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 end)
 for _,case in ipairs(cases) do
  measure(case[1],case[2],case[3],function()
   assert(Map.load(nil,game,case[1],{x=case[2],y=case[3],facing='down'}))
   pcall(Player.reset,case[2],case[3],'down')
  end)
 end
 print('[EM QA] done')
 love.event.quit()
end
