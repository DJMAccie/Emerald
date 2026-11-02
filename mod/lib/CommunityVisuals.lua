-- Optional Legendary Visuals community systems for Battle Art Voxel

local V = ...
local ModSetting = V.require("ModSetting")

local CommunityVisuals = {}

function CommunityVisuals.crystalHD(map)
  return map and type(map.cellCollision) == "function"
end

function CommunityVisuals.crystalDepth(map)
  return CommunityVisuals.crystalHD(map)
end

CommunityVisuals.pillars = ModSetting.new(
  "communityPillars", "LEGENDARY PILLARS",
  { "default", "separate", "bottom", "top" },
  { "BATTLE ART", "SEPARATE", "BOTTOM LINK", "TOP INTERLOCK" }
)

CommunityVisuals.masonry = ModSetting.new(
  "communityMasonry", "WALL & LEDGE COLOR",
  { "granite", "red", "sandstone", "slate" },
  { "GRANITE", "RED BRICK", "SANDSTONE", "SLATE" }
)

CommunityVisuals.caves = ModSetting.new(
  "communityCaves", "CAVES",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }
)

CommunityVisuals.tower = ModSetting.new(
  "communityTower", "TOWER VISUALS",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }
)

CommunityVisuals.towerWall = ModSetting.new(
  "communityTowerWall", "TOWER WALL",
  { "smoke_black", "storm_white", "pearl_white" },
  { "SMOKE BLACK", "STORM WHITE", "PEARL WHITE" }
)

CommunityVisuals.caveDetails = ModSetting.new(
  "communityCaveDetails", "CAVE DETAILS",
  { "off", "subtle", "full" }, { "OFF", "SUBTLE", "FULL" }
)

CommunityVisuals.caveSound = ModSetting.new(
  "communityCaveSound", "CAVE SOUND",
  { "off", "low", "mid" }, { "OFF", "LOW", "MID" }
)

CommunityVisuals.signs = ModSetting.new(
  "communitySigns", "SIGNS",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }
)

CommunityVisuals.grass = ModSetting.new(
  "communityGrass", "GRASS",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }
)

CommunityVisuals.cityGround = ModSetting.new(
  "communityCityGround", "CITY GROUND",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }
)

CommunityVisuals.roads = ModSetting.new(
  "communityRoads", "ROADS & BRIDGES",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }
)

CommunityVisuals.walls = ModSetting.new(
  "communityWalls", "WALLS & LEDGES",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }
)

CommunityVisuals.courtyards = ModSetting.new(
  "communityCourtyards", "FENCES & COURTS",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }
)

CommunityVisuals.sky = ModSetting.new(
  "communitySky", "SKY & BACKGROUND",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }
)

CommunityVisuals.forest = ModSetting.new(
  "communityForest", "VIRIDIAN FOREST",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }
)

CommunityVisuals.settings = {
  CommunityVisuals.pillars,
  CommunityVisuals.masonry,
  CommunityVisuals.tower,
  CommunityVisuals.towerWall,
  CommunityVisuals.caves,
  CommunityVisuals.caveDetails,
  CommunityVisuals.caveSound,
  CommunityVisuals.signs,
  CommunityVisuals.cityGround,
  CommunityVisuals.grass,
  CommunityVisuals.roads,
  CommunityVisuals.walls,
  CommunityVisuals.courtyards,
  CommunityVisuals.sky,
  CommunityVisuals.forest,
}

local KEYS = {}
for _, setting in ipairs(CommunityVisuals.settings) do
  KEYS[setting.key] = true
end

function CommunityVisuals.customCaves()
  return CommunityVisuals.caves:get() == "n64memory"
end

function CommunityVisuals.customTower()
  return CommunityVisuals.tower:get() == "n64memory"
end

function CommunityVisuals.caveDetailLevel()
  return CommunityVisuals.caveDetails:get()
end

function CommunityVisuals.customSky()
  return CommunityVisuals.sky:get() == "n64memory"
end

function CommunityVisuals.customForest()
  return CommunityVisuals.forest:get() == "n64memory"
end

function CommunityVisuals.invalidate()
  pcall(function() V.require("TowerGraveMist").invalidate() end)
  pcall(function() V.require("ForestAtmos").invalidate() end)
end

local function live(setting)
  local baseRow = setting.row
  setting.row = function(self)
    local row = baseRow(self)
    local baseStep = row.step
    row.step = function(game, dir)
      local result = baseStep(game, dir)
      CommunityVisuals.invalidate()
      return result
    end
    return row
  end
end

for _, setting in ipairs(CommunityVisuals.settings) do live(setting) end

return CommunityVisuals
