-- Shared presentation consumers for Game3. No GB world/state facade patches.
local V=...
local M={}
local Day=V.require('DayNight')
local Sky=V.require('Sky')
local AA=V.require('AntiAlias')
local R=V.require('Voxel3D')
local Underlay=V.require('WorldUnderlay')
local TiltShift=V.require('TiltShift')
local Community=V.require('CommunityVisuals')
-- T-SHIFT is NOT a mod setting. The engine's render_pipelines registry already
-- gives the blur a ladder, an options row, hotkey 6 and persistence in
-- save.options.pipelines -- and that stored level is the one Pipelines.update
-- pushes into TiltShift every frame. A second, mod-owned row for the same
-- effect (this one used to sit here) could only ever disagree with it, and did:
-- the row said 2 while the engine's bucket said 0, so the blur never drew. The
-- engine's row is now the single control.
M.invert=V.require('CameraSettings').invertY
-- T-SHIFT for Emerald (no engine pipeline here, see tiltLevel): on by default.
M.tilt=V.require('ModSetting').new('tiltshift','T-SHIFT',{0,1,2,3},{'OFF','1','2','3'},3)
-- TOUR: walk through walls and keep scenes quiet, for screenshot review (see
-- TourMode.lua). Listed here, it reaches the OPTIONS menu through
-- Gen3Integration's sharedSettings like the rest of this list.
local Tour=V.require('TourMode')
M.tour=V.require('ModSetting').new('tour','TOUR',{false,true},{'OFF','ON'},1)
M.settings={V.require("SpatialUpscale").setting,AA.setting,Day.setting,Underlay.setting,Community.sky,M.invert,M.tilt,
 V.require('Water').setting,V.require('Weather').setting,M.tour}

-- The blur is part of the intended presentation, so the first time this runs
-- for a save that has never had a T-SHIFT level stored, start it at 2. The
-- engine has no `default` field for a pipeline level, which is why this lives
-- here; after this write the engine's own row and hotkey own the value, so
-- turning it OFF sticks.
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

-- The blur's sharp band follows the player's screen row. The subject is the
-- player's ground point, projected with this frame's view-projection and
-- smoothed over about 0.15 s; in a battle it is the centre the battle shot is
-- built around (the underlay is handed that point each frame). M.log prints
-- the focus once a second.
M.log=false
local focusAt,focusNow,focusSet,focusUnder,focusPrint,focusShown=nil,.5,false,nil,0,nil
local function focusTarget()
 local Voxel3D=V.require('Voxel3D')
 local G=V.require('Gen3Scene')
 local battle=V.require('CamControl').battleLive()
 local wx,wz
 if battle and focusUnder then wx,wz=focusUnder[1],focusUnder[2]
 else
  local Player=require('src.core.game3.player')
  wx,wz=(Player.px or 0)+8,(Player.py or 0)+8
 end
 -- the ground the camera itself uses for this point (Gen3Scene's R.orbitGround)
 local wy=G.groundAt(wx,wz+8-.001)
 local _,y=Voxel3D.project(wx,wy,wz)
 local _,h=Voxel3D.size()
 if not (y and h and h>0) then return nil,battle end
 return y/h,battle
end
local function focusTrack()
 local y,battle=focusTarget()
 -- off the frame (the low camera stands on the player's own eye, so the feet
 -- project below the bottom edge) there is no player to hold: keep the centre
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
 V.require("Weather").update(dt)
 V.require("ForestAtmos").update(dt)
 if not M.tiltAdopted then M.tiltAdopted=true; M.tiltAdopt() end
 Tour.update(M.tour:get())
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
 -- NATURE follows the native outdoor horizon. Native interior boundaries
 -- are authored by InteriorDiorama, so the underlay never fills a room.
 return Underlay.draw(true,cx,cz,color)
end

function M.expand(w,h)return AA.expand(w,h)end
-- The blur's level is set here, where the blur is drawn, every frame
-- (Emerald's game loop never runs Pipelines.update). In Emerald the engine has NO tiltshift pipeline registered (checked in QA:
-- Pipelines.get("tiltshift") is nil), so its row and hotkey do not exist
-- here and the mod's own T-SHIFT setting is the control. If an engine ever
-- registers the pipeline, its level wins.
local function tiltLevel()
 -- not in first person: the camera is the player's own eye, and the miniature blur's bands smeared
 -- every wall and rock near the eye and laid a haze band over the top of the view
 if V.require('Gen3Integration').level==6 and not V.require('CamControl').battleLive() then
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
 -- also every scene frame: the QA driver loop steps Game:update without the
 -- core.update hook, and a field frame always reaches here
 Tour.update(M.tour:get())
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
