-- Cave and sky options for Battle Art Voxel

local V = ...
local ModSetting = V.require("ModSetting")

local CommunityVisuals = {}

function CommunityVisuals.crystalHD(map)
  return map and type(map.cellCollision) == "function"
end

function CommunityVisuals.crystalDepth(map)
  return CommunityVisuals.crystalHD(map)
end

CommunityVisuals.caves = ModSetting.new(
  "communityCaves", "CAVES",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }
)

CommunityVisuals.caveDetails = ModSetting.new(
  "communityCaveDetails", "CAVE DETAILS",
  { "off", "subtle", "full" }, { "OFF", "SUBTLE", "FULL" }
)

CommunityVisuals.sky = ModSetting.new(
  "communitySky", "SKY & BACKGROUND",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }
)

function CommunityVisuals.customCaves()
  return CommunityVisuals.caves:get() == "n64memory"
end

function CommunityVisuals.caveDetailLevel()
  return CommunityVisuals.caveDetails:get()
end

function CommunityVisuals.customSky()
  return CommunityVisuals.sky:get() == "n64memory"
end

function CommunityVisuals.invalidate()
  pcall(function() V.require("TowerGraveMist").invalidate() end)
  pcall(function() V.require("ForestAtmos").invalidate() end)
end

return CommunityVisuals
