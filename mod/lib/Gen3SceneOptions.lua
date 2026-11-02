-- Shared presentation consumers for Game3
local V=...
local M={}
local Day=V.require('DayNight')
local Sky=V.require('Sky')
local AA=V.require('AntiAlias')
local R=V.require('Voxel3D')
local Underlay=V.require('WorldUnderlay')
local TiltShift=V.require('TiltShift')
local Community=V.require('CommunityVisuals')
M.invert=V.require('CameraSettings').invertY
M.tilt=V.require('ModSetting').new('tiltshift','T-SHIFT',{0,1,2,3},{'OFF','1','2','3'},3)
local Tour=V.require('TourMode')
local DebugWalk=V.require('DebugWalk')
M.tour=V.require('ModSetting').new('tour','TOUR',{false,true},{'OFF','ON'},1)
M.settings={V.require("SpatialUpscale").setting,AA.setting,Day.setting,Underlay.setting,Community.sky,M.invert,M.tilt,
 V.require('Water').setting,M.tour}

M.tiltDefault=2
function M.tiltAdopt()
 local ok,Pipelines=pcall(require,"src.render.Pipelines")
 if not (ok and Pipelines.get and Pipelines.get("tiltshift")) then return end
 local Game=package.loaded["src.core.Game"]
 local opts=Game and Game.save and Game.save.options
 if not opts then return end
 local bucket=opts.pipelines
 if type(bucket)~="table" or type(bucket.tiltshift)~="number" then
  Pipelines.setLevel("tiltshift",M.tiltDefault)
  if Pipelines.syncOptions then Pipelines.syncOptions(opts) end
 end
end

M.log=false
local focusAt,focusNow,focusSet,focusUnder,focusPrint,focusShown=nil,.5,false,nil,0,nil
local function focusTarget()
 local Voxel3D=V.require('Voxel3D')
 local G=V.require('Gen3Scene')
 local battle=false
 local wx,wz
 if battle and focusUnder then wx,wz=focusUnder[1],focusUnder[2]
 else
  local Player=require('src.core.game3.player')
  wx,wz=(Player.px or 0)+8,(Player.py or 0)+8
 end
 local wy=G.groundAt(wx,wz+8-.001)
 local _,y=Voxel3D.project(wx,wy,wz)
 local _,h=Voxel3D.size()
 if not (y and h and h>0) then return nil,battle end
 return y/h,battle
end
local function focusTrack()
 local y,battle=focusTarget()
 local onScreen=y and y>=0 and y<=1
 local target=onScreen and math.max(.2,math.min(.8,y)) or TiltShift.FOCUS_Y
 local t=love.timer.getTime()
 local dt=focusAt and math.min(math.max(t-focusAt,0),.1) or 0
 focusAt=t
 if focusSet then focusNow=focusNow+(target-focusNow)*(1-math.exp(-dt/.15))
 else focusNow,focusSet=target,true end
 TiltShift.setFocus(focusNow)
 if M.log and (t-focusPrint>=1 or math.abs(target-(focusShown or -1))>.02) then
  focusPrint,focusShown=t,target
  print(string.format('[tiltshift] focus %.3f target %.3f raw %.3f battle %s',focusNow,target,y or -1,tostring(battle)))
 end
end

function M.update(dt)
 Day.update(dt)
 V.require("ForestAtmos").update(dt)
 if not M.tiltAdopted then M.tiltAdopted=true; M.tiltAdopt() end
 Tour.update(DebugWalk.on())
end

function M.environment(indoor,background)
 Day.applyRig(not indoor)
 R.tint=Day.tint(not indoor)
 if indoor then return background end
 return Sky.dress({background[1],background[2],background[3],background[4] or 1})
end

function M.underlay(indoor,cx,cz,background)
 focusUnder={cx,cz}
 if indoor then return false end
 local mode=Underlay.selected()
 local color=mode=='black' and Underlay.COLORS.black or background
 return Underlay.draw(true,cx,cz,color)
end

function M.expand(w,h)return AA.expand(w,h)end
-- Emerald registers no tiltshift pipeline and never runs Pipelines.update: the level is set here.
local function tiltLevel()
 if V.require('Gen3Integration').level==6 then
  TiltShift.setLevel(0);return
 end
 local ok,Pipelines=pcall(require,"src.render.Pipelines")
 if ok and Pipelines.get and Pipelines.get("tiltshift") then
  TiltShift.setLevel(Pipelines.level("tiltshift") or 0)
 else
  TiltShift.setLevel(M.tilt:get())
 end
end
function M.finish(canvas,w,h)
 Tour.update(DebugWalk.on())
 tiltLevel()
 focusTrack()
 canvas=AA.resolve(canvas,w,h,'firered')
 canvas=TiltShift.apply(canvas)
 Tour.overlay(canvas,w,h)
 return canvas
end
function M.release()
 AA.invalidate();TiltShift.invalidate()
 R.tint={1,1,1};R.fog=nil
end
return M
