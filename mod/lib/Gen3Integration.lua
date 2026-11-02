-- FireRed's native display bypasses Pipelines
local V=...
local M={yaw=0,pitch=.16,level=3,rendered=0,active=false}
local recovery=V.require('RenderRecovery').new()
M.recovery=recovery
local ModSetting=V.require('ModSetting')
local Trees=V.require('TreePresentation')
local Distance=V.require('RenderDistance')
local mode=ModSetting.new('fireredCamera','2.5D CAMERA',{0,1,2,3,4,5,6,7},
 {'OFF','FULL','15','35','50','75','1ST','ROTATING 3RD'},4)
local function free()return M.level>=6 end
local dirs={'up','right','down','left'}
function M.worldDirection(dir,yaw)
 local offset=math.floor((yaw or 0)/(math.pi*.5)+.5)
 for i,d in ipairs(dirs)do if d==dir then return dirs[(i-1+offset)%4+1] end end
 return dir
end
local function pitchRange()if M.level==6 then return -1.1,1.1 end return -.6,.65 end
M.MOUSE_SENS=.0032 -- rad per mouse count, as Gen 1/2's FirstPerson
function M.look(dx,dy)
 if V.require('CameraSettings').invertY:get() then dy=-dy end
 local lo,hi=pitchRange()
 M.yaw=(M.yaw+dx)%(math.pi*2);M.pitch=math.max(lo,math.min(hi,M.pitch+dy))
end
function M.isActive()return M.active and free()end
function M.setLevel(level,game)
 recovery:reset()
 mode:setIndex(level+1,game);M.level=mode:get()
end
function M.install()
 local mod=V.mod
 local FieldView=require('src.core.game3.field_view')
 local Display=require('src.core.game3.display')
 local Player=require('src.core.game3.player')
 local Battle=require('src.core.game3.battle')
 local Tilt=require('src.render.Tilt')
 local Scene=V.require('Gen3Scene')
 local SceneOptions=V.require('Gen3SceneOptions')
 local BattleStage=V.require('Gen3Battle')
 local uninstallBattle=BattleStage.install()
 local draw,present,update=FieldView.draw,Display.present,Player.update
 local function ready(game)return recovery:ready(Scene.context and Scene.context()or game.session)end
 mode:read();M.level=mode:get();local schema=mod.options:define({Distance.setting:schema('Scenery distance: AUTO adapts to the platform; FULL includes the loaded connected maps. Distant scenery fades into the sky.'),BattleStage.setting:schema('Native battle sprites and attacks over the 2.5D field. Disable to use the original FireRed battle background.'),mode:schema('2.5D camera. Press 3 to cycle. In 1ST and rotating 3RD look with the mouse, the right stick or Q/E/R/F; left click is A, right click is B. Special field effects retain their original presentation.')})
 local nativeArt=V.require('NativeBattleArt');nativeArt.install()
 local interfaceArt=V.require('NativeInterfaceArt')
 local uninstallInterface=interfaceArt.install()
 local sharedSettings={Trees.props,Trees.surfaces,V.require('ModernBattleUI').setting,
  V.require('Shadows').setting,V.require('WorldCurve').setting,V.require('VoxelGrid').setting}
 for _,setting in ipairs(V.require("NativeAtmosphere").settings)do sharedSettings[#sharedSettings+1]=setting end
 for _,setting in ipairs(SceneOptions.settings)do sharedSettings[#sharedSettings+1]=setting end
 for _,setting in ipairs(interfaceArt.settings)do sharedSettings[#sharedSettings+1]=setting end
 for _,setting in ipairs(V.require('Gen3BattleOptions').settings)do sharedSettings[#sharedSettings+1]=setting end
 for _,setting in ipairs(V.require('Gen3BattleBackdrop').settings)do sharedSettings[#sharedSettings+1]=setting end
 for _,setting in ipairs(sharedSettings)do
  schema[#schema+1]=setting:schema(setting.key=='spatialUpscale' and V.require('SpatialUpscale').description or 'Shared renderer option; applies immediately to the native Gen 3 presentation.')
 end
 for _,setting in ipairs(nativeArt.settings())do schema[#schema+1]=setting:schema('Shared Battle Art sprite settings. ANIMATED uses installed atlases or bundled BW backs (dex 1–251); missing art falls back to static full-body images. ROM/MODDED preserves native/provider art.')end
 mod.options:define(schema)
 local Support=V.require('OptionSupport')
 V.require('InGameOptions').install(mod,Support.rows(schema,3),'BATTLE ART')
 mod.exports.optionSupport=Support.inventory(3)
 local function field(game)return game and game.phase=='field' and game.session and not Battle.isActive() end
 local function looking(game)return field(game) or game and game.phase=='quest_log' end
 local uninstallRecap=V.require('Gen3Recap').install(M)
 local Fly=V.require('Gen3FlyOver')
 local uninstallFly=Fly.install(M)
 FieldView.draw=function(game,w,h,opts)
  M.active=false
  pcall(V.require('LandmarkModels').syncCollision,M.level~=0 and field(game))
  if M.level==0 or not field(game) or not ready(game) or Scene.nativeRequired(game) then Fly.frame(false);return draw(game,w,h,opts) end
  local ok,result=pcall(Scene.draw,game,w,h,M)
  if not ok then
   recovery:failed(result);Scene.restore();Scene.invalidate()
   print('[Battle Art FireRed] scene fallback: '..tostring(result))
   if Fly.active() then Fly.abort('scene error: '..tostring(result)) end
  end
  if ok and result then Fly.frame(true);recovery:succeeded();M.active=true;M.rendered=M.rendered+1;return end
  Fly.frame(false)
  return draw(game,w,h,opts)
 end
 Display.present=function(game,...)
  if not field(game) then M.active=false end
  local battle=Battle.isActive() and BattleStage.enabled()
  if not battle and (M.level==0 or not field(game) or not ready(game) or Scene.nativeRequired(game)) then return present(game,...) end
  local level,angle=Tilt.level,Tilt.angle
  Tilt.level,Tilt.angle=0,0
  local ok,result=pcall(present,game,...)
  Tilt.level,Tilt.angle=level,angle
  if not ok then error(result,0) end
  return result
 end
 Player.update=function(game,input)
  if M.active and free() and field(game) and ready(game) and not Scene.nativeRequired(game) and input and input.isDown then
   local proxy=setmetatable({}, {__index=input})
   for _,method in ipairs({'isDown','wasPressed'})do
    if input[method] then
     local read=input[method]
     proxy[method]=function(_,key)
      for _,dir in ipairs(dirs)do if M.worldDirection(dir,M.yaw)==key then return read(input,dir) end end
      return read(input,key)
     end
    end
   end
   return update(game,proxy)
  end
  return update(game,input)
 end
 mod.hooks:wrap('input.key',function(next,game,ev)
  if ev.key=='3' and looking(game) then
   if ev.phase=='pressed' then M.setLevel((M.level+1)%8,game) end
   return true
  end
  return next(game,ev)
 end)
 -- Game3 never feeds mouse traffic to input.pointer, so LOVE's callbacks are wrapped.
 local mouseDX,mouseDY,captured,liveGame=0,0,false,nil
 local CLICK,held,wrapped={[1]='a',[2]='b'},{},{}
 local function releaseClicks()for b,t in pairs(held)do pcall(mod.input.release,mod.input,t);held[b]=nil end end
 local function wrapLove(name,claim)
  local inner=love[name];wrapped[name]=inner or false
  love[name]=function(...)if claim(...) then return end;if inner then return inner(...) end end
 end
 if love then
  wrapLove('mousemoved',function(_,_,dx,dy,touch)
   if captured and not touch then mouseDX,mouseDY=mouseDX+(dx or 0),mouseDY+(dy or 0);return true end
  end)
  wrapLove('mousepressed',function(_,_,button,touch)
   local btn=captured and not touch and CLICK[button]
   if btn and liveGame then
    local ok,token=pcall(mod.input.press,mod.input,liveGame,btn)
    if ok then held[button]=token end;return true
   end
  end)
  wrapLove('mousereleased',function(_,_,button)
   if held[button] then pcall(mod.input.release,mod.input,held[button]);held[button]=nil;return true end
  end)
 end
 local rawCentred={}
 local function padLook()
  local js=love and love.joystick;if not (js and js.getJoysticks) then return 0,0 end
  local bx,by=0,0
  for _,j in ipairs(js.getJoysticks())do
   local x,y=0,0
   if j:isGamepad() then x,y=j:getGamepadAxis('rightx'),j:getGamepadAxis('righty')
   elseif j:getAxisCount()>=4 then
    local okN,name=pcall(j.getName,j)
    if not (okN and type(name)=='string' and name:lower():find('accelerometer',1,true)) then
     local a3,a4,id=j:getAxis(3),j:getAxis(4),j:getID()
     rawCentred[id]=rawCentred[id] or (math.abs(a3)<.3 and math.abs(a4)<.3)
     if rawCentred[id] then x,y=a3,a4 end
    end
   end
   if math.abs(x)>math.abs(bx) then bx=x end;if math.abs(y)>math.abs(by) then by=y end
  end
  return bx,by
 end
 local stick={x=0,y=0}
 mod.hooks:wrap('input.gamepad',function(next,game,ev)
  if ev.phase=='axis' then
   if ev.axis=='rightx'then stick.x=tonumber(ev.value)or 0 elseif ev.axis=='righty'then stick.y=tonumber(ev.value)or 0 end
  elseif ev.phase=='removed'then stick.x,stick.y=0,0 end
  return next(game,ev)
 end)
 mod.hooks:wrap('core.update',function(next,game,dt,...)
  recovery:update(dt)
  SceneOptions.update(dt)
  liveGame=game
  if Fly.active() then local okFly,errFly=pcall(Fly.update,dt,game);if not okFly then Fly.abort(errFly) end end
  local want=looking(game) and free()
  if want and love.window and love.window.hasFocus then local ok,f=pcall(love.window.hasFocus);want=ok and f or false end
  if love.mouse and love.mouse.setRelativeMode then
   local ok,rel=pcall(love.mouse.getRelativeMode)
   if ok and rel~=want then pcall(love.mouse.setRelativeMode,want) end
  end
  captured=want
  if not want then releaseClicks() end
  if want and (mouseDX~=0 or mouseDY~=0) then M.look(mouseDX*M.MOUSE_SENS,mouseDY*M.MOUSE_SENS) end
  mouseDX,mouseDY=0,0
  if not (M.level==6) then local lo,hi=pitchRange();M.pitch=math.max(lo,math.min(hi,M.pitch)) end
  if looking(game) and free() then
   local function axis(v)return math.abs(v)>.18 and (v-(v>0 and .18 or -.18))/.82 or 0 end
   local elapsed=math.min(tonumber(dt)or 0,.1)
   local okP,px,py=pcall(padLook)
   local sx,sy=stick.x,stick.y
   if okP then if math.abs(px)>math.abs(sx) then sx=px end;if math.abs(py)>math.abs(sy) then sy=py end end
   M.look(axis(sx)*elapsed*2.2,axis(sy)*elapsed*1.5)
   local kb=love and love.keyboard
   if kb and kb.isDown then
    local function held(k)local ok,d=pcall(kb.isDown,k);return ok and d end
    local turn=(held('e') and 1 or 0)-(held('q') and 1 or 0)
    local tip=(held('f') and 1 or 0)-(held('r') and 1 or 0)
    if turn~=0 or tip~=0 then
     M.look(turn*elapsed*2.2,tip*elapsed*1.2)
    end
   end
  end
  return next(game,dt,...)
 end)
 for _,event in ipairs({'save.loaded','save.created'})do
  mod.events:on(event,function()V.require('DayNight').restore()end)
 end
 mod.events:on('save.writing',function()V.require('DayNight').store()end)
 local dragging=false
 mod.hooks:wrap('input.pointer',function(next,game,ev)
  if ev.source=='mouse' and looking(game) and free() then
   if ev.button==2 then
    dragging=ev.phase=='pressed';return true
   end
   if ev.phase=='moved' and dragging then M.look((ev.dx or 0)*.005,(ev.dy or 0)*.004);return true end
  else dragging=false end
  return next(game,ev)
 end)
 mod.events:on('mod.options_changed',function(payload)
  if payload and payload.mod==mod.id and payload.key==Distance.setting.key then Distance.setting:sync(payload.value);Scene.invalidate()end
  if payload and payload.mod==mod.id and payload.key==BattleStage.setting.key then BattleStage.setting:sync(payload.value) end
  if payload and payload.mod==mod.id then
   for _,setting in ipairs(sharedSettings)do if payload.key==setting.key then setting:sync(payload.value);Trees.changed(payload.key)end end
   for _,setting in ipairs(nativeArt.settings())do if payload.key==setting.key then setting:sync(payload.value)end end
  end
  if payload and payload.mod==mod.id and payload.key==mode.key then
   recovery:reset()
   mode:sync(payload.value);M.level=mode:get()
  end
 end)
 mod.hooks:wrap('core.quit_to_launcher',function(next,...)
  FieldView.draw,Display.present,Player.update=draw,present,update
  releaseClicks();captured=false
  if love and love.mouse and love.mouse.setRelativeMode then pcall(love.mouse.setRelativeMode,false) end
  for name,inner in pairs(wrapped)do love[name]=inner or nil end
  uninstallFly();uninstallInterface();uninstallBattle();uninstallRecap();Scene.release();return next(...)
 end)
 mod.exports.version=mod.version;mod.exports.lib=V
 mod.exports.gen3Camera=M
 mod.exports.battleTheme=V.require('BattleTheme')
 mod.exports.battlePresentation={modernUIEnabled=V.require('ModernBattleUI').enabled,
  }
 mod.exports.firered={camera=M,outdoor=true,battles=BattleStage,presentation='beta'}
 local gen3Namespace=mod.exports.firered
 for _,cart in ipairs{'emerald'}do mod.exports[cart]=gen3Namespace end
 mod.exports.gen3=gen3Namespace
 print('[Battle Art FireRed] native field and battle background adapters installed')
end
return M
