-- EMERALD 3D VOXEL MOD
local mod = ...

local V = { mod = mod, path = mod.path }

local function chunkFor(rel)
  local source = mod:read(rel)
  if not source then
    error(("emerald_3d_voxel_mod: %s is missing -- reinstall the mod"):format(rel), 0)
  end
  local chunk, err = load(source, "@" .. mod.path .. "/" .. rel)
  if not chunk then
    error(("emerald_3d_voxel_mod: %s did not compile: %s"):format(rel, tostring(err)), 0)
  end
  return chunk
end

local modules = {}
function V.require(name)
  local hit = modules[name]
  if hit ~= nil then return hit end
  local value = chunkFor("lib/" .. name .. ".lua")(V)
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

-- A part's main.lua returns its entry function, which runs here.
local function entry(rel)
  local fn = chunkFor(rel)(mod)
  assert(type(fn) == "function", rel .. " must return a function")
  return fn(mod)
end

-- Each part publishes its own settings rows and the engine's define replaces the
-- whole schema, so keep one list under this mod and none of the parts' rows is lost.
local defineRows = mod.options.define
local rows, seen = {}, {}
mod.options.define = function(_, schema)
  for _, row in ipairs(schema) do
    if not seen[row.key] then seen[row.key] = true; rows[#rows + 1] = row end
  end
  return defineRows(mod.options, rows)
end

-- Wild Pokemon walk the routes first, the voxel world takes the field, then the battle models are served.
entry("wilds/main.lua")
if V.require("Generation").isGen3() then
  V.require("Gen3Integration").install()
end
entry("models/main.lua")
