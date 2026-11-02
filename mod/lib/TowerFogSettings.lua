-- Mt. Pyre fog controls

local V = ...
local ModSetting = V.require("ModSetting")

local TowerFogSettings = {}

TowerFogSettings.details = ModSetting.new(
  "towerDetails", "TOWER DETAILS",
  { "off", "subtle", "full" },
  { "OFF", "SUBTLE", "FULL" }, 3
)

TowerFogSettings.enabled = ModSetting.new(
  "towerFog", "TOWER FOG",
  { "off", "on" }, { "OFF", "ON" }, 2
)

TowerFogSettings.thickness = ModSetting.new(
  "towerFogThickness", "FOG THICKNESS",
  { "light", "normal", "thick", "heavy" },
  { "LIGHT", "NORMAL", "THICK", "HEAVY" }, 2
)

TowerFogSettings.speed = ModSetting.new(
  "towerFogSpeed", "FOG SPEED",
  { "slow", "normal", "fast" },
  { "SLOW", "NORMAL", "FAST" }, 2
)

local THICKNESS = {
  light  = { alpha = .72, height = .85 },
  normal = { alpha = 1.00, height = 1.00 },
  thick  = { alpha = 1.25, height = 1.15 },
  heavy  = { alpha = 1.45, height = 1.28 },
}

local SPEED = { slow = .55, normal = 1.00, fast = 1.45 }

function TowerFogSettings.thicknessMultipliers()
  local value = THICKNESS[TowerFogSettings.thickness:get()]
    or THICKNESS.normal
  return value.alpha, value.height
end

function TowerFogSettings.speedMultiplier()
  return SPEED[TowerFogSettings.speed:get()] or SPEED.normal
end

return TowerFogSettings
