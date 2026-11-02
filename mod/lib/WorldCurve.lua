-- Voxel world mode

local V = ...

local ModSetting = V.require("ModSetting")

local WorldCurve = {}

WorldCurve.KEY = "curve"
WorldCurve.LABEL = "V-CURVE"

WorldCurve.AMOUNTS = { 0, 0.05, 0.10, 0.18 }

WorldCurve.setting = ModSetting.new(WorldCurve.KEY, WorldCurve.LABEL,
                                    { 0, 1, 2, 3 },
                                    { "OFF", "1", "2", "3" })

function WorldCurve.level()
  return WorldCurve.setting:get() or 0
end

function WorldCurve.k(vh)
  local amount = WorldCurve.AMOUNTS[WorldCurve.level() + 1] or 0
  if amount <= 0 or not vh or vh <= 0 then return 0 end
  return amount / vh
end

function WorldCurve.drop(k, cx, cy, wx, wz)
  if k <= 0 then return 0 end
  local dx, dz = wx - cx, wz - cy
  return (dx * dx + dz * dz) * k
end

return WorldCurve
