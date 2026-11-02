-- A conservative world-space draw/build budget for the voxel neighborhood

local V = ...

local ModSetting = V.require("ModSetting")
local RenderDistance = {}

RenderDistance.setting = ModSetting.new(
  "renderDistance", "R.DIST",
  { "auto", 16, 32, 64, false },
  { "AUTO", "LOW", "MEDIUM", "FAR", "FULL" },
  1)

RenderDistance.forceFull=false

function RenderDistance.radius()
  if RenderDistance.forceFull then return nil end
  local ok, cells = pcall(RenderDistance.setting.get, RenderDistance.setting)
  if not ok or cells == false then return nil end
  if cells == "auto" then
    local okP, platform = pcall(require, "src.core.Platform")
    local caps = okP and platform.detect and platform.detect() or {}
    cells = (caps.mobile or caps.console or caps.nx) and 16 or 32
  end
  cells = tonumber(cells)
  if not cells then return nil end
  return math.max(16, math.min(64, cells)) * 16
end

function RenderDistance.haze(color,extent,origin,bounds)
 if not RenderDistance.radius() and bounds and origin then
  return {color=color,start=.8,density=16,heightK=0,origin=origin,bounds=bounds}
 end
 local radius=RenderDistance.radius() or extent or 1536
 local edge=math.max(96,radius-96)
 return {color=color,start=edge*.9,density=7/(edge*.1),heightK=0,origin=origin}
end
return RenderDistance
