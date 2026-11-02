-- One of this mod's own settings

local V = ...

local ModSetting = {}
ModSetting.__index = ModSetting

local function modId()
  local mod = V.mod
  return (mod and mod.id) or "BATTLE_ART_VOXEL_FORK"
end

function ModSetting.new(key, label, values, labels, defaultIndex)
  return setmetatable({
    key = key, label = label, values = values, labels = labels,
    defaultIndex = defaultIndex or 1,
    index = nil, -- nil = not yet read back from the persisted options
  }, ModSetting)
end

local function indexOf(self, value)
  for i, v in ipairs(self.values) do
    if v == value then return i end
  end
  return self.defaultIndex or 1
end

function ModSetting:read()
  if self.index then return self.index end
  local mod = V.mod
  local value
  if mod and mod.options then
    local ok, got = pcall(mod.options.get, mod.options, self.key)
    if ok then value = got end
  end
  self.index = indexOf(self, value)
  return self.index
end

function ModSetting:get()
  return self.values[self:read()]
end

function ModSetting:level()
  return self:read() - 1
end

function ModSetting:setIndex(i, game)
  local n = #self.values
  i = ((i - 1) % n + n) % n + 1
  self.index = i
  local value, id = self.values[i], modId()
  local opts = game and ((game.save and game.save.options) or game.options)
  if opts then
    opts.modOptions = opts.modOptions or {}
    opts.modOptions[id] = opts.modOptions[id] or {}
    opts.modOptions[id][self.key] = value
  end
  local loader = game and game.mods
  if loader then
    loader.modOptions = loader.modOptions or {}
    loader.modOptions[id] = loader.modOptions[id] or {}
    loader.modOptions[id][self.key] = value
  end
  if game and game.writeOptions then pcall(game.writeOptions, game)
  elseif game and game.persistOptions then pcall(game.persistOptions, game) end
  return value
end

function ModSetting:cycle(game, dir)
  return self:setIndex(self:read() + (dir or 1), game)
end

function ModSetting:sync(value)
  self.index = indexOf(self, value)
end

function ModSetting:schema(help)
  local choices = {}
  for i, v in ipairs(self.values) do choices[i] = { self.labels[i], v } end
  if #self.values == 2 and self.values[1] == false then
    return { key = self.key, type = "toggle", label = self.label,
             default = self.values[self.defaultIndex or 1], help = help }
  end
  return { key = self.key, type = "choice", label = self.label,
             choices = choices, default = self.values[self.defaultIndex or 1],
             help = help }
end

return ModSetting
