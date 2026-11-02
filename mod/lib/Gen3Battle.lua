-- Presentation seam for the native FRLG battle engine
local V=...
local M={active=false,rendered=0}
M.ORBIT_TIME=0.30
M.log=false
local logClock=0
local setting=V.require('ModSetting').new('battles','3D-BTL',
 {true,false},{'ON','OFF'})
local read=setting.read
function setting:read()
 if not self.index and V.mod and V.mod.options then
  local value=V.mod.options:get('battles')
  if value==nil then
   local old=V.mod.options:get('fireredBattleStage')
   if type(old)=='boolean' then
    self.defaultIndex=old and 1 or 2;self:sync(old)
   end
  end
 end
 return read(self)
end
M.setting=setting
function M.enabled()return setting:get()==true end
function M.openYaw(x,y,walkable)
 local best,yaw=-math.huge,0
 for i,d in ipairs({{0,-1},{1,0},{0,1},{-1,0}})do
  local score=0
  for n=1,9 do for lateral=-2,2 do
   if walkable(x+d[1]*n+d[2]*lateral,y+d[2]*n-d[1]*lateral)then score=score+10-n end
  end end
  if score>best then best,yaw=score,(i-1)*math.pi/2 end
 end
 return yaw
end
function M.openArea(x,y,walkable)
 local best,center=-math.huge,{x*16+8,y*16+8}
 for oy=-5,5 do for ox=-5,5 do
  local cx,cy=x+ox,y+oy
  if walkable(cx,cy)then
   local score=-(ox*ox+oy*oy)*.7
   for dy=-3,3 do for dx=-3,3 do
    if walkable(cx+dx,cy+dy)then score=score+1 end
   end end
   if score>best then best,center=score,{cx*16+8,cy*16+8}end
  end
 end end
 return center
end
local function stickAxis(name)
 local ok,list=pcall(love.joystick.getJoysticks)
 if not ok then return 0 end
 for _,js in ipairs(list or {})do
  if js:isGamepad() then
   local v=js:getGamepadAxis(name) or 0
   if math.abs(v)>.18 then return (v-(v>0 and .18 or -.18))/.82 end
  end
 end
 return 0
end
local function sceneShot(camera, name, cut)
 local BattleShots=V.require('BattleShots')
 local yaw,pitch=BattleShots.scene(name)
 local o=camera.orbit;if not o then o={yaw=0,pitch=0};camera.orbit=o end
 o.shotYaw=yaw%(math.pi*2)
 if o.shotYaw>math.pi then o.shotYaw=o.shotYaw-math.pi*2 end
 o.shotPitch=pitch
 if cut then o.yaw,o.pitch=o.shotYaw,o.shotPitch end
 return true
end


M.CAM={dist=80,height=26,look=36,lookY=-12,fov=38,pitchUnits=40}
M.MARGIN={left=.04,right=.96,top=.06}
local FRAME_ASPECT=1280/720

local function placements(camera)
 local Models=V.require('Gen3StadiumModels')
 local SM=V.require('StadiumModels')
 local Scene=V.require('Gen3Scene')
 local cx,cz=camera.center[1],camera.center[2]
 local yaw=camera.arenaYaw or camera.yaw or 0
 local dx,dz=math.sin(yaw),-math.cos(yaw)
 local arena={player={cx-dx*18,cz-dz*18},enemy={cx+dx*26,cz+dz*26}}
 local ok,pl=pcall(SM.placements,arena,Scene.groundAt(cx,cz),{player={},enemy={}},Models.battle())
 return ok and pl or {}
end

local function boxOf(pl)
 local m=pl.modelMatrix
 local k=m[6]
 local okm,met=pcall(function()return pl.instance:metrics()end)
 local H,W=14*k,8*k
 if okm and type(met)=='table' and tonumber(met.height) then
  H=met.height*k
  W=(tonumber(met.width) or met.height*.5)*k
 end
 return {x=m[4],y=m[8],z=m[12],H=H,r=W/2}
end

local function actorsOf(camera)
 local P=placements(camera)
 local out={}
 for _,side in ipairs({'player','enemy'})do
  local pl=P[side]
  if pl then
   local m=pl.modelMatrix
   local okm,met=pcall(function()return pl.instance:metrics()end)
   local H=okm and type(met)=='table' and tonumber(met.height) or nil
   if H and H>0 then H=H*m[6] else H=nil end
   out[#out+1]={x=m[4],z=m[12],H=H,side=side}
  end
 end
 return out
end

local function stageView(cx,cz,h)
 local rest=M.restYaw or V.require('BattleShots').SCENE_RAKE or 0
 return {battle=true,center={cx,cz},yaw=h,arenaYaw=h-rest}
end

local function frameOf(box,project)
 local l,r,t,fx,fy,hx,hy=1e9,-1e9,1e9
 for _,dy in ipairs({0,box.H})do
  for _,ox in ipairs({-box.r,box.r})do for _,oz in ipairs({-box.r,box.r})do
   local sx,sy=project(box.x+ox,box.y+dy,box.z+oz)
   if not sx then return nil end
   if sx<l then l=sx end
   if sx>r then r=sx end
   if sy<t then t=sy end
  end end
 end
 local gx,gy=project(box.x,box.y,box.z)
 local hx2,hy2=project(box.x,box.y+box.H,box.z)
 if not (gx and hx2) then return nil end
 return {left=l,right=r,top=t,fx=gx,fy=gy,hx=hx2,hy=hy2}
end

local function projectorOf(vp)
 return function(x,y,z)
  local cw=vp[13]*x+vp[14]*y+vp[15]*z+vp[16]
  if cw<=0 then return nil end
  return (vp[1]*x+vp[2]*y+vp[3]*z+vp[4])/cw*.5+.5,(vp[5]*x+vp[6]*y+vp[7]*z+vp[8])/cw*.5+.5
 end
end

local function restProjector(camera,dist)
 local Scene=V.require('Gen3Scene')
 local Mat4=V.require('Mat4')
 local c=M.CAM
 local cx,cz=camera.center[1],camera.center[2]
 local yaw=(camera.arenaYaw or 0)+(V.require('BattleShots').SCENE_RAKE or 0)
 local dx,dz=math.sin(yaw),-math.cos(yaw)
 local ground=Scene.groundAt(cx,cz)
 local height=c.height -- the rest pose: pitch .38, no cut lift
 local eye={cx-dx*dist,ground+height,cz-dz*dist}
 local focus={cx+dx*c.look,ground+c.lookY,cz+dz*c.look}
 local proj=Mat4.perspective(math.rad(c.fov),FRAME_ASPECT,math.max(1,dist*.05),dist*4+4096)
 return projectorOf(Mat4.mul(Mat4.mul(Mat4.scale(1,-1,1),proj),Mat4.lookAt(eye,focus,{0,1,0})))
end

function M.fit(camera)
 local boxes={}
 for _,side in ipairs({'player','enemy'})do
  local pl=placements(camera)[side]
  if pl then boxes[#boxes+1]=boxOf(pl) end
 end
 if #boxes==0 then return M.CAM.dist end
 local M_=M.MARGIN
 for d=M.CAM.dist,200 do
  local project=restProjector(camera,d)
  local ok=true
  for _,box in ipairs(boxes)do
   local f=frameOf(box,project)
   if not f or f.left<M_.left or f.right>M_.right or f.top<M_.top then ok=false break end
  end
  if ok then return d end
 end
 return 200
end

function M.report(camera)
 local vp=V.require('Voxel3D').vp
 if not vp then return end
 local project=projectorOf(vp)
 local pl=placements(camera)
 local parts={}
 for _,side in ipairs({'enemy','player'})do
  if pl[side] then
   local f=frameOf(boxOf(pl[side]),project)
   if f then parts[#parts+1]=string.format('%s feet %.3f,%.3f head %.3f,%.3f x %.3f..%.3f top %.3f',side,f.fx,f.fy,f.hx,f.hy,f.left,f.right,f.top) end
  else
   parts[#parts+1]=side..' (no model)'
  end
 end
 print(string.format('[BB1] frame=%d yaw=%.1f arenaYaw=%.1f dist=%.1f | %s',M.frame or 0,math.deg(camera.yaw or 0),math.deg(camera.arenaYaw or 0),camera.dist or 0,table.concat(parts,' | ')))
 print(string.format('[BB1] orbit yaw=%.2f shotYaw=%.2f pitch=%.2f shot=%s',math.deg(camera.orbit and camera.orbit.yaw or 0),math.deg(camera.orbit and camera.orbit.shotYaw or 0),math.deg(camera.orbit and camera.orbit.pitch or 0),tostring(V.require('BattleShots').state().shot)))
end

local function signals()
 local Models=V.require('Gen3StadiumModels')
 local sig={}
 local pend=Models.pendingMove
 if pend and pend~=M.lastPend then
  M.lastPend=pend;sig.launch=true;sig.attackerPlayer=pend.player~=false
 end
 local b=Models.battle()
 if b then
  local hs=b.hitSerial
  if hs then
   local sum=(hs.player or 0)+(hs.enemy or 0)
   if M.hitSum and sum~=M.hitSum then sig.hit=true end
   M.hitSum=sum
  end
  sig.faint=((b.player and b.player.fainted) or (b.enemy and b.enemy.fainted)) and true or nil
 end
 return sig
end

function M.orbit(camera,dt)
 dt=math.min(tonumber(dt) or 0,.1)
 local kb=love.keyboard
 local dx=stickAxis('rightx')*2.2+((kb.isDown(']') and 1 or 0)-(kb.isDown('[') and 1 or 0))*1.6
 local dy=stickAxis('righty')*1.5
 if V.require('CameraSettings').invertY:get() then dy=-dy end
 local o=camera.orbit or {yaw=0,pitch=0};camera.orbit=o
 local BattleShots=V.require('BattleShots')
 local battle=require('src.core.game3.battle')._st
 local okU,errU=pcall(BattleShots.update,battle,dt,function(name,cut)return sceneShot(camera,name,cut)end,signals())
 if not okU and M.log and not M.updateErr then M.updateErr=true;print('[BB1] BattleShots.update error: '..tostring(errU))end
 local shotYaw=o.shotYaw or 0
 local shotPitch=o.shotPitch or 0
 local k=1-math.exp(-dt/M.ORBIT_TIME)
 if dx~=0 then o.yaw=math.max(-math.pi,math.min(math.pi,(o.yaw or 0)+dx*dt))
 else o.yaw=(o.yaw or 0)+(shotYaw-(o.yaw or 0))*k end
 if dy~=0 then o.pitch=math.max(-.26,math.min(.37,(o.pitch or 0)+dy*dt))
 else o.pitch=(o.pitch or 0)+(shotPitch-(o.pitch or 0))*k end
 if math.abs((o.yaw or 0)-shotYaw)<.002 then o.yaw=shotYaw end
 if math.abs((o.pitch or 0)-shotPitch)<.002 then o.pitch=shotPitch end
 camera.yaw=((camera.arenaYaw or 0)+o.yaw)%(math.pi*2)
 camera.pitch=.38+o.pitch
end
function M.install()
 setting:read()
 local Battle=require('src.core.game3.battle')
 local Bg=require('src.core.game3.battle.bg')
 local Display=require('src.core.game3.display')
 local Renderer=require('src.render.Renderer')
 local Scene=V.require('Gen3Scene')
 local original,bg=Battle.draw,Bg.draw
 local Hud=V.require('Gen3BattleHud')
 local uninstallHud=Hud.install(M)
 M.hud=Hud
 local Models=V.require('Gen3StadiumModels')
 local uninstallModels=Models.install()
 local drawing=false
 local recovery=V.require('RenderRecovery').new()
 local camera={level=7,yaw=0,pitch=.38,battle=true}
 M.camera=camera
 V.require('BattleShots').setSceneSink(function(name,cut)
  return sceneShot(camera,name,cut) end)
 local battleState
 Bg.draw=function(...)
  if drawing then return true end
  return bg(...)
 end
 Battle.draw=function(game,w,h)
  M.active=false;Hud.reset();M.frame=(M.frame or 0)+1
  recovery:update(love.timer.getDelta())
  if not M.enabled() or not Battle.isActive() or not recovery:ready(Battle._st) or Display.planesBroken
     or Scene.nativeRequired(game) then Models.drawing=false;return original(game,w,h)end
  if battleState~=Battle._st then
   Models.reset()
   local Player=require('src.core.game3.player')
   local Collision=require('src.core.game3.collision')
   local px,py=math.floor((Player.px or 0)/16),math.floor((Player.py or 0)/16)
   local center=M.openArea(px,py,Collision.isWalkable)
   local yaw=M.openYaw(math.floor(center[1]/16),math.floor(center[2]/16),Collision.isWalkable)
   local mapId=tostring(require('src.core.game3.map').current)
   local pick=V.require('Gen3BattleStage').choose({center=center,yaw=yaw,
    anchor={px*16+8,py*16+8},height=M.CAM.height,view=stageView,actors=actorsOf,fit=M.fit,
    log=M.log})
   if pick.none then print('[Battle Art] no clear battle stage at '..mapId..' '..px..','..py) end
   camera.center=pick.center
   camera.yaw=pick.yaw
   camera.arenaYaw=camera.yaw-(M.restYaw
     or V.require('BattleShots').SCENE_RAKE or 0)
   camera.pitch=.38;camera.orbit={yaw=0,pitch=0}
   camera.dist=M.CAM.dist;camera.height=M.CAM.height;camera.look=M.CAM.look;camera.lookY=M.CAM.lookY;camera.fov=M.CAM.fov
   M.hitSum=nil;M.lastPend=nil
   V.require('BattleShots').reset()
   local yaw,pitch=V.require('BattleShots').scene('wide')
   camera.orbit.shotYaw,camera.orbit.shotPitch=yaw,pitch
   camera.orbit.yaw,camera.orbit.pitch=yaw,pitch
   battleState=Battle._st
  end
  M.orbit(camera,love.timer.getDelta())
  camera.dist=math.max(camera.dist or M.CAM.dist,M.fit(camera))
  camera.plate=V.require('UiBackplates').arenaWhite() and {color={1,1,1,1}} or nil
  Models.update(love.timer.getDelta())
  local G=love.graphics
  local ui=G.getCanvas()
  local ok,ready=pcall(function()
   Renderer:beginWorldPass()
   local vw,vh=Renderer:worldViewSize()
   return Scene.draw(game,vw,vh,camera)
  end)
  Scene.restore()
  Renderer:endWorldPass()
  G.setCanvas(ui)
  if not ok or not ready then
   Renderer.worldActive=false;Renderer:setWorldOverride(nil)
   if not ok then
    recovery:failed(ready);Scene.invalidate();print('[Battle Art FireRed] battle stage fallback: '..tostring(ready))
   end
   return original(game,w,h)
  end
  Renderer.uiOpaque=false
  recovery:succeeded()
  G.clear(0,0,0,0)
  M.active=true;M.rendered=M.rendered+1
  if M.log then
   logClock=logClock+(love.timer.getDelta() or 0)
   if logClock>=1 then logClock=0;M.report(camera)end
   local bs=V.require('BattleShots')
   local shotNow=bs.state().shot
   if shotNow~=M.lastShot then M.lastShot=shotNow;print(string.format('[BB1] frame=%d shot -> %s',M.frame or 0,tostring(shotNow))) end
  end
  drawing=true;Models.drawing=true;Hud.begin()
  local restoreNative=Models.hideNative()
  local drawn,err=pcall(original,game,w,h)
  restoreNative()
  drawing=false;Models.drawing=false;Hud.finish()
  if not drawn then error(err,0)end
 end
 return function()
  uninstallHud();uninstallModels();Battle.draw=original;Bg.draw=bg;M.active=false
 end
end
return M
