-- BATTLE ART VOXEL FORK: the Emerald 3D mod.
--
-- A voxel world drawn from Emerald's own tiles (walls, roofs, rock, water,
-- trees) with a free camera, Pokemon in the overworld and 3D battles with
-- Stadium 2 models. Emerald only: the engine runs Emerald as a Gen 3 game
-- that owns its own field pass, so this entry file does nothing but hand
-- that pass to lib/Gen3Integration.lua.
local mod = ...

-- ------- the mod namespace
--
-- lib/ modules require each other through V rather than package.path: a
-- mod directory is not on it, and may live inside a mounted .love archive
-- that plain require cannot reach.  Each module is loaded once, with V
-- passed in as its vararg (`local V = ...`).

local V = { mod = mod, path = mod.path }

local function chunkFor(rel)
  local source = mod:read(rel)
  if not source then
    error(("BATTLE_ART_VOXEL_FORK: %s is missing -- reinstall the mod"):format(rel), 0)
  end
  local chunk, err = load(source, "@" .. mod.path .. "/" .. rel)
  if not chunk then
    error(("BATTLE_ART_VOXEL_FORK: %s did not compile: %s"):format(rel, tostring(err)), 0)
  end
  return chunk
end

local modules = {}
local depth = 0
local STACK = {}
for n in ("OverworldBattle BattleScene BattleArena VoxelScene ChunkMesher Structures Buildings TerrainAtlas CommunityFlora CommunityVisuals TileShape MapCompat BattleCam BattleShots BattleDOF BattleHud BattlePics BattlePresentation BattleBillboard Gen6Backdrop BossBackdrop Pokeball SuccessStars EmberLegacyAudio LoadTimings VoxelMeshDisk StaticGeometry VoxelVisualObjects WorldFillProps Backdrop SkyLayer CharacterRenderers CaveAtmosphere3D CaveSconces TowerLobbyDetails TowerGraveMist LegendaryTowerExterior LegendaryTreeCache ForestDressing CavePerimeter SafariStatues SafariFoliage ShipHull GranitePillars ItemPokeballs SpriteBillboards Gen2Rocks Gen2FruitTrees Gen2Trees Gen2DepthTrees VoxelState"):gmatch("%S+") do STACK[n] = true end
local seen = {}
local function wrapModule(name, value)
  if type(value) ~= "table" then return value end
  for k, f in pairs(value) do
    if type(f) == "function" then
      local key = name .. "." .. tostring(k)
      value[k] = function(...)
        if not seen[key] then seen[key] = true; print("[USE] " .. key) end
        return f(...)
      end
    end
  end
  return value
end
function V.require(name)
  local hit = modules[name]
  if hit ~= nil then return hit end
  print("[REQ] " .. depth .. " lib " .. name)
  depth = depth + 1
  local ok, value = pcall(function() return chunkFor("lib/" .. name .. ".lua")(V) end)
  depth = depth - 1
  if not ok then error(value, 0) end
  if STACK[name] then value = wrapModule(name, value) end
  modules[name] = value
  return value
end

local dataFiles = {}
function V.data(name)
  local hit = dataFiles[name]
  if hit ~= nil then return hit end
  local value = chunkFor("data/" .. name .. ".lua")(V)
  dataFiles[name] = value
  return value
end

-- ------- field pass

-- The engine's Gen 3 game owns a native field pass (no render_pipelines).
if V.require("Generation").isGen3() then
  V.require("Gen3Integration").install()
end
