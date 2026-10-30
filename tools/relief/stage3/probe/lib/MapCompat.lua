-- src.world.Map, when the engine will let a mod have it.
--
-- WHY THIS EXISTS. The mod's Gen 1/2 geometry is written against the engine's
-- Gen 1 map module: lib/VoxelScene, lib/Structures, lib/StaticGeometry,
-- lib/SkyLayer, lib/Backdrop and lib/WorldUnderlay all read Map.world,
-- Map.current and Map.isOutdoor for the map they are drawing. On a Gen 3 boot
-- that module is a dead patch -- Game3 has its own map (src.core.game3.map),
-- and the loader reports the Gen 1 one as "requires src.world.Map, which a
-- Gen 3 game never runs and no compat layer has no adapter for". Emerald is
-- layout "rse", and the engine's Gen 3 compat layer only serves "frlg", so
-- the guard fires for every Emerald session.
--
-- The require was INLINE in each of those files, so the guard did not just
-- deny the module -- it raised inside lib/VoxelScene, which lib/Voxel3D
-- requires, which lib/Gen3Scene requires, which is the whole of the Emerald
-- field and battle renderer. One denied Gen 1 module took the 3D game with
-- it, and the failure landed as "the staged battle quietly stops happening"
-- because the battle's own draw path is the first thing to ask for it.
--
-- WHAT IT DOES. Asks for the module once, keeps it if the engine hands it
-- over, and otherwise keeps a table with nothing in it and a flag. Callers
-- that can degrade (a height lookup, an optional classification) check
-- `available`; callers on a Gen 3 path do not run at all, because the Gen 3
-- runtime has its own map module and never asks these questions.
--
-- Deliberately not a shim: it does not pretend to be src.world.Map. A mod
-- that fakes the Gen 1 map under Game3 would be answering questions about a
-- world the running game does not have, which is the failure the engine's
-- guard exists to prevent. This only stops one denied module from taking the
-- rest of the mod down with it.
--
-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local MapCompat = { available = false }

local ok, module = pcall(require, "src.world.Map")
if not ok then
  local okTb, tb = pcall(function()
    local lines = {}
    for level = 2, 12 do
      local info = debug.getinfo(level, "Sl")
      if not info then break end
      lines[#lines + 1] = ("%s:%s"):format(info.short_src or "?",
                                           tostring(info.currentline))
    end
    return table.concat(lines, " <- ")
  end)
  print("[MapCompat] src.world.Map denied here: " .. tostring(okTb and tb))
end
if ok and type(module) == "table" then
  MapCompat.map = module
  MapCompat.available = true
else
  -- An empty table rather than nil, so a `Map.world` read on a path that was
  -- never supposed to run here answers nil instead of raising a second time.
  MapCompat.map = {}
  MapCompat.reason = tostring(module)
end

-- The engine's Gen 1 map module, or an empty table.
function MapCompat.get()
  return MapCompat.map
end

return MapCompat
