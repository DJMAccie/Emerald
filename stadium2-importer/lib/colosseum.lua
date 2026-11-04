-- Pokemon Colosseum models for #252-386, pre-converted to DSM5 packs by
-- hoenn/make_hoenn_models.py (from the user's own Colosseum disc) into
-- this mod folder: colosseum/<variant>/<dex>.dsm. They flow through the
-- same Pack.parse -> Renderer path as the Stadium 2 packs, so Battle Art's
-- Gen 3 stage draws Hoenn Pokemon with no further special casing.
local Colosseum = {}
local modRef
local cache = {}
local present
Colosseum.FIRST, Colosseum.LAST = 252, 386

function Colosseum.bind(mod)
  modRef = mod
  cache, present = {}, nil
  return Colosseum
end

local function readOwn(path)
  if not (modRef and type(modRef.read) == "function") then return nil end
  local ok, bytes = pcall(modRef.read, modRef, path)
  if ok and type(bytes) == "string" and bytes ~= "" then return bytes end
  return nil
end

local function scan()
  if present ~= nil then return present end
  present = {}
  local ok, names = pcall(function() return modRef and modRef.list and modRef:list("colosseum/normal") end)
  if ok and type(names) == "table" then
    for _, name in ipairs(names) do
      local dex = tonumber(tostring(name):match("^(%d+)%.dsm$"))
      if dex then present[dex] = true end
    end
  end
  return present
end

function Colosseum.has(species)
  species = math.floor(tonumber(species) or 0)
  if species < Colosseum.FIRST or species > Colosseum.LAST then return false end
  local seen = scan()
  if next(seen) ~= nil then return seen[species] == true end
  -- no directory listing available: probe the file itself once
  if cache[species] == nil then
    cache[species] = readOwn(("colosseum/normal/%03d.dsm"):format(species)) or false
  end
  return cache[species] ~= false
end

function Colosseum.available()
  local seen = scan()
  if next(seen) ~= nil then return true end
  return Colosseum.has(Colosseum.FIRST) or Colosseum.has(255) or Colosseum.has(384)
end

function Colosseum.max()
  return Colosseum.available() and Colosseum.LAST or 251
end

-- Bytes of one pack; shiny falls back to the normal model when no rare_*
-- Colosseum model exists for the species.
function Colosseum.read(species, variant)
  species = math.floor(tonumber(species) or 0)
  if species < Colosseum.FIRST or species > Colosseum.LAST then return nil end
  local dir = variant == "shiny" and "shiny" or "normal"
  return readOwn(("colosseum/%s/%03d.dsm"):format(dir, species))
    or readOwn(("colosseum/normal/%03d.dsm"):format(species))
end

return Colosseum
