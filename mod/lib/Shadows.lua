-- Global cast-shadow switch for both free roam and staged battles

local V = ...

local ModSetting = V.require("ModSetting")

local Shadows = {}

Shadows.setting = ModSetting.new("shadowQuality", "SHADOWS",
                                 { "high", "off" },
                                 { "ON", "OFF" })

function Shadows.enabled()
  return Shadows.setting:get() ~= "off"
end

function Shadows.off()
  return not Shadows.enabled()
end

return Shadows
