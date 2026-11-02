-- Native-map checks and cache invalidation shared by the atmosphere modules

local V = ...

local CommunityVisuals = {}

function CommunityVisuals.crystalHD(map)
  return map and type(map.cellCollision) == "function"
end

function CommunityVisuals.crystalDepth(map)
  return CommunityVisuals.crystalHD(map)
end

function CommunityVisuals.invalidate()
  pcall(function() V.require("TowerGraveMist").invalidate() end)
  pcall(function() V.require("ForestAtmos").invalidate() end)
end

return CommunityVisuals
