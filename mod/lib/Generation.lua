-- Which cart is running, asked once and answered the same way everywhere

local Generation = {}

local cached

local function resolve()
  if cached ~= nil then return cached end
  local ok, GameVersion = pcall(require, "src.core.GameVersion")
  if not ok or type(GameVersion) ~= "table" then
    cached = false
    return cached
  end
  cached = GameVersion
  return cached
end

local number

function Generation.number()
  if number then return number end
  number = 1
  local GameVersion = resolve()
  if GameVersion and type(GameVersion.generation) == "function" then
    local ok, gen = pcall(GameVersion.generation)
    if ok and type(gen) == "number" then number = gen end
  end
  return number
end

function Generation.isGen3() return Generation.number() == 3 end

function Generation.version()
  local GameVersion = resolve()
  if not GameVersion or type(GameVersion.get) ~= "function" then return nil end
  local ok, id = pcall(GameVersion.get)
  if not ok or type(id) ~= "string" then return nil end
  return id
end

return Generation
