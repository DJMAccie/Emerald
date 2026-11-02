-- Optional, user-supplied battle art
local V = ...

local ModSetting = V.require("ModSetting")
local BattleArt = {}
local SPECIES_BY_DEX = V.data("battle_species_dex_386")

BattleArt.setting = ModSetting.new("battleArt", "BATTLE ART",
  { "static", "animated", "rom" }, { "STATIC", "ANIMATED", "ROM" }, 2)
BattleArt.frontAnimationSetting = ModSetting.new("frontAnimatedSet", "ANIM FRONT GEN",
  { "gen3" }, { "GEN 3" })
BattleArt.backAnimationSetting = ModSetting.new("backAnimatedSet", "BACK ART SET",
  { "gen3" }, { "GEN 3" })
BattleArt.viewSetting = ModSetting.new("playerView", "PLAYER",
  { "front", "back" }, { "FRONT SPRITES", "BACK SPRITES" }, 2)
BattleArt.backPlacementSetting = ModSetting.new(
  "backPlacement", "BACK PLACEMENT",
  { "auto", "world", "ui" }, { "AUTO", "WORLD", "OG UI" })
BattleArt.trainerSetting = ModSetting.new(
  "trainerArtSet", "TRAINER ART",
  { "gen3" }, { "GEN 3" })
BattleArt.playerArtSetting = ModSetting.new(
  "playerArtSet", "PLAYER ART",
  { "png", "gen3", "ash", "gary", "red", "boy", "lass", "hilbert", "rom" },
  { "PNG", "GEN 3", "ASH", "GARY", "RED/GREEN", "BOY", "LASS", "HILBERT", "ROM" })
BattleArt.playerAnimationSetting = ModSetting.new(
  "playerAnimatedSet", "PLAYER ANIM",
  { "png", "gen3", "ash", "gary", "red",
    "ash_front", "misty_front", "brock_front", "bulma_front", "gary_front", "rom" },
  { "PNG", "GEN 3", "ASH", "GARY", "RED/GREEN",
    "ASH FRONT", "MISTY FRONT", "BROCK FRONT", "BULMA FRONT", "GARY FRONT", "ROM" }, 2)
BattleArt.duplicateSetting = ModSetting.new(
  "duplicateFix", "DUPLICATE FIX",
  { "battle_art", "modded" }, { "BATTLE ART", "MODDED" })

BattleArt.frontFlipSetting = ModSetting.new(
  "frontFlip", "FLIP FRONT SPRITE",
  { "battle_art", "default" }, { "BATTLE ART", "DEFAULT" })

function BattleArt.prefersModded()
  return V.crystalSpritesActive or BattleArt.duplicateSetting:get() == "modded"
end

function BattleArt.ownsSpeciesArt()
  return not BattleArt.prefersModded()
end

function BattleArt.ownsShinyArt()
  return BattleArt.ownsSpeciesArt()
end

local SHINY_ATTACK = {
  [2] = true, [3] = true, [6] = true, [7] = true,
  [10] = true, [11] = true, [14] = true, [15] = true,
}

function BattleArt.isShiny(battler)
  local mon = battler and (battler.mon or battler)
  if mon and (mon.personality~=nil or mon.isShiny~=nil)
      and V.require('Generation').isGen3() then
    return require('src.core.game3.summary_data').isShiny(mon)
  end
  local dvs = mon and mon.dvs
  if type(dvs) ~= "table" then return false end
  local attack = tonumber(dvs.attack)
  local defense = tonumber(dvs.defense)
  local speed = tonumber(dvs.speed)
  local special = tonumber(dvs.special)
  if defense ~= 10 or speed ~= 10 or special ~= 10
     or not SHINY_ATTACK[attack] then
    return false
  end

  local hp = (attack % 2) * 8 + (defense % 2) * 4
             + (speed % 2) * 2 + (special % 2)
  return dvs.hp == nil or tonumber(dvs.hp) == hp
end

function BattleArt.flipsPlayerFront()
  return BattleArt.frontFlipSetting:get() == "battle_art"
end

local cache = {}
local external = setmetatable({}, { __mode = "k" })
local metrics = setmetatable({}, { __mode = "k" })
local preparedData = setmetatable({}, { __mode = "k" })
local fittedFrameSets = setmetatable({}, { __mode = "k" })

local function speciesAlias(species)
  local number
  if type(species) == "number" then
    number = species
  elseif type(species) == "string" then
    number = tonumber(species:match("^#?0*(%d+)$"))
  end
  if number and number % 1 == 0 then
    return SPECIES_BY_DEX[number] or species
  end
  return species
end
BattleArt.speciesAlias = speciesAlias

local function slug(species)
  species = speciesAlias(species)
  local s = tostring(species or ""):lower()
  s = s:gsub("♀", "-f"):gsub("♂", "-m")
  s = s:gsub("['’%.]", "")
  s = s:gsub("[^%w]+", "-"):gsub("^-+", ""):gsub("-+$", "")
  return s
end
BattleArt.slug = slug

function BattleArt.playerSide()
  local crystal = V.crystalSpritesActive and V.mod.exports.crystalSprites
  if crystal and crystal.frontPrefEnabled then
    return crystal.frontPrefEnabled() and "front" or "back"
  end
  return BattleArt.viewSetting:get() == "back" and "back" or "front"
end

local function shinyPrefix(side, shiny)
  return BattleArt.ownsShinyArt() and shiny and "shiny/" or ""
end

-- Transform keeps mon.species; the engine hook records the copied shape.
function BattleArt.speciesFor(battler)
  local species = battler and (battler.__battleArtTransformed
                               or (battler.mon and battler.mon.species)) or nil
  if type(species) == "number" and V.require('Generation').isGen3() then
    local ok, Pokemon = pcall(require, 'src.core.game3.pokemon')
    if ok and type(Pokemon) == "table" and type(Pokemon.national) == "function" then
      local okN, national = pcall(Pokemon.national, species)
      if okN and tonumber(national) then species = tonumber(national) end
    end
  end
  return speciesAlias(species)
end

local function generationFolder(generation, side, shiny)
  if BattleArt.ownsShinyArt() and shiny then
    return generation .. "/shiny"
  end
  return generation
end

local function generationRelativePath(species, generation, side, shiny)
  if generation ~= "gen3" then return nil end
  local kind = side == "back" and "back-static" or "front-animated"
  return ("assets/battle/%s/%s/%s.png"):format(
    kind, generationFolder(generation, side, shiny), slug(species))
end
BattleArt.generationRelativePath = generationRelativePath

local function staticSpeciesRelativePath(species, side, shiny)
  if side == "back" then
    return generationRelativePath(
      species, BattleArt.backAnimationSetting:get(), "back", shiny)
  end
  return ("assets/battle/front-static/%s%s.png"):format(
    shinyPrefix("front", shiny), slug(species))
end
BattleArt.staticSpeciesRelativePath = staticSpeciesRelativePath

local function pathFor(species, side, shiny)
  local mode = BattleArt.setting:get()
  if mode == "rom" then return nil end
  if mode == "animated" then return nil end
  local rel = staticSpeciesRelativePath(species, side, shiny)
  local path = V.mod.assets:path(rel)
  return path, rel
end

local function staticPathFor(name, side)
  if BattleArt.setting:get() == "rom" then return nil end
  return V.mod.assets:path(
    ("assets/battle/%s-static/%s.png"):format(side, name))
end

local function rgbaKey(data, w, h)
  local corners = { {0, 0}, {w - 1, 0}, {0, h - 1}, {w - 1, h - 1} }
  local counts, values, order = {}, {}, {}
  for _, p in ipairs(corners) do
    local r, g, b = data:getPixel(p[1], p[2])
    local key = (math.floor(r * 255 + .5) * 65536)
              + (math.floor(g * 255 + .5) * 256)
              + math.floor(b * 255 + .5)
    counts[key] = (counts[key] or 0) + 1
    values[key] = { r, g, b }
    if counts[key] == 1 then order[#order + 1] = key end
  end
  local best, n = order[1], -1
  for _, k in ipairs(order) do
    local count = counts[k]
    if count > n then best, n = k, count end
  end
  return values[best]
end

local function displayMode()
  if V.require("Generation").isGen3() then return "gbc" end
  local ok, fx = pcall(require, "src.render.PaletteFX")
  return ok and fx and fx.mode or "gbc"
end
BattleArt.displayMode = displayMode

local function applyDisplayFilter(data, mode)
  if mode == "gbc_inv" then
    data:mapPixel(function(_, _, r, g, b, a)
      if a <= 0 then return r, g, b, a end
      return 1 - r, 1 - g, 1 - b, a
    end)
    return
  end
  if mode ~= "og" and mode ~= "og_inv" and mode ~= "classic" then return end
  local PaletteFX = require("src.render.PaletteFX")
  local colors = PaletteFX.effectiveColors(PaletteFX.GRAYS)
  data:mapPixel(function(_, _, r, g, b, a)
    if a <= 0 then return r, g, b, a end
    local luma = r * 0.2126 + g * 0.7152 + b * 0.0722
    local i = luma > 0.83 and 1 or luma > 0.5 and 2
              or luma > 0.17 and 3 or 4
    local c = colors[i]
    return c[1] / 255, c[2] / 255, c[3] / 255, a
  end)
end

function BattleArt.prepareData(data, mode)
  local made
  local ok = pcall(function()
    local w, h = data:getDimensions()
    if w < 1 or h < 1 then return end

    local opaque = true
    for y = 0, h - 1 do
      for x = 0, w - 1 do
        local _, _, _, a = data:getPixel(x, y)
        if a < 0.999 then opaque = false break end
      end
      if not opaque then break end
    end

    if opaque then
      local key = rgbaKey(data, w, h)
      local seen, stack, top = {}, {}, 0
      local function push(x, y)
        if x < 0 or y < 0 or x >= w or y >= h then return end
        local i = y * w + x
        if seen[i] then return end
        local r, g, b = data:getPixel(x, y)
        if math.abs(r - key[1]) > 0.5 / 255
           or math.abs(g - key[2]) > 0.5 / 255
           or math.abs(b - key[3]) > 0.5 / 255 then return end
        seen[i], top = true, top + 1
        stack[top] = i
      end
      for x = 0, w - 1 do push(x, 0); push(x, h - 1) end
      for y = 0, h - 1 do push(0, y); push(w - 1, y) end
      while top > 0 do
        local i = stack[top]; stack[top], top = nil, top - 1
        local x, y = i % w, math.floor(i / w)
        local r, g, b = data:getPixel(x, y)
        data:setPixel(x, y, r, g, b, 0)
        push(x - 1, y); push(x + 1, y); push(x, y - 1); push(x, y + 1)
      end
    end

    applyDisplayFilter(data, mode)

    local x0, x1, y0, y1 = w, -1, h, -1
    for y = 0, h - 1 do
      for x = 0, w - 1 do
        local _, _, _, a = data:getPixel(x, y)
        if a > 0.001 then
          if x < x0 then x0 = x end; if x > x1 then x1 = x end
          if y < y0 then y0 = y end; if y > y1 then y1 = y end
        end
      end
    end
    if x1 < x0 then return end
    made = love.graphics.newImage(data)
    made:setFilter("nearest", "nearest")
    external[made] = true
    preparedData[made] = data
    metrics[made] = { x0 = x0, x1 = x1, y0 = y0, y1 = y1,
                      w = w, h = h, padBottom = h - 1 - y1,
                      center = (x0 + x1 + 1) / 2 }
  end)
  return (ok and made) or nil
end

local function prepare(path, mode)
  local cacheKey = path .. "#" .. mode
  local hit = cache[cacheKey]
  if hit ~= nil then return hit or nil end
  local made
  local ok = pcall(function()
    made = BattleArt.prepareData(love.image.newImageData(path), mode)
  end)
  cache[cacheKey] = (ok and made) or false
  return made
end

function BattleArt.image(species, side, battler)
  if not BattleArt.ownsSpeciesArt() then return nil end
  local shiny = BattleArt.isShiny(battler)
  local path = pathFor(species, side, shiny)
  local image = path and prepare(path, displayMode()) or nil
  if image and side == "front" and metrics[image] then
    metrics[image].staticFront = true
  end
  return image
end

function BattleArt.namedImage(name, side)
  local path = staticPathFor(name, side)
  return path and prepare(path, displayMode()) or nil
end

local function currentGameSave()
  local ok, Game = pcall(require, "src.core.Game")
  if ok and type(Game) == "table" then
    return Game.save
  end
  return nil
end

local function chooseYourHeroBucket()
  local ok, other = pcall(function()
    return V.mod.find and V.mod.find("choose_your_hero")
  end)
  if ok and other and other.save and other.save.get then
    local readOK, bucket = pcall(function()
      return {
        player = other.save:get("player", "red"),
        rival = other.save:get("rival", "blue"),
      }
    end)
    if readOK then return bucket end
  end
  local save = currentGameSave()
  local md = save and save.modData
  if type(md) ~= "table" then return nil end
  local bucket = md.choose_your_hero
  if type(bucket) == "table" then return bucket end
  return nil
end

local function chooseYourHeroRival()
  local bucket = chooseYourHeroBucket()
  if type(bucket) == "table" and type(bucket.rival) == "string" then
    return bucket.rival
  end
  return "blue"
end

local function chooseYourHeroPlayer()
  local bucket = chooseYourHeroBucket()
  if type(bucket) == "table" and type(bucket.player) == "string" then
    return bucket.player
  end
  return "red"
end
BattleArt.chooseYourHeroPlayer = chooseYourHeroPlayer
BattleArt.chooseYourHeroRival = chooseYourHeroRival

function BattleArt.effectivePlayerAnimationSet()
  local selected = BattleArt.playerAnimationSetting:get()
  if selected == "red" then
    return chooseYourHeroPlayer() == "green" and "green" or "red"
  end
  return selected
end

function BattleArt.effectivePlayerArtSet()
  local selected = BattleArt.playerArtSetting:get()
  if selected == "red" then
    return chooseYourHeroPlayer() == "green" and "green" or "red"
  end
  return selected
end

local function yellowRivalFile(name)
  if type(name) ~= "string" then return nil end
  if name == "rival" then return "rival1f" end
  if name:match("^rival[123]$") then return name .. "f" end
  return nil
end

function BattleArt.trainerImage(name)
  if BattleArt.setting:get() == "rom" then return nil end
  local generation = BattleArt.trainerSetting:get()
  local function load(file)
    local rel = ("assets/battle/front-static/%s/%s.png"):format(
      generation, file)
    local path = V.mod.assets:path(rel)
    if not path then return nil end
    return prepare(path, displayMode())
  end
  if name == "prof-oak" then return load("prof-oak") end
  if name == "prof.oak" then return load("prof.oak") end
  if chooseYourHeroRival() == "yellow" then
    local femName = yellowRivalFile(name)
    if femName then
      return load(femName)
    end
  end
  return load(name)
end

function BattleArt.playerTrainerImage()
  local set = BattleArt.effectivePlayerArtSet()
  if set == "rom" then return nil end
  local function load(name)
    local rel = "assets/battle/back-static/" .. name
    local path = V.mod.assets:path(rel)
    return prepare(path, displayMode())
  end
  local function loadFirstAnimatedFrame(name)
    local rel = "assets/battle/back-animated/" .. name .. "player.png"
    local path = V.mod.assets:path(rel)
    if not path then return nil end
    local cacheKey = path .. "#first#" .. displayMode()
    local hit = cache[cacheKey]
    if hit ~= nil then return hit or nil end
    local made
    local ok = pcall(function()
      local sheet = love.image.newImageData(path)
      local width, height = sheet:getDimensions()
      if width < 5 or width % 5 ~= 0 or height < 1 then return end
      local frame = love.image.newImageData(width / 5, height)
      frame:paste(sheet, 0, 0, 0, 0, width / 5, height)
      made = BattleArt.prepareData(frame, displayMode())
    end)
    cache[cacheKey] = (ok and made) or false
    return made
  end
  if set == "png" then return load("player.png") end
  if set == "red" or set == "green" then
    return loadFirstAnimatedFrame(set) or load("player.png")
  end
  return load(set .. "player.png") or load("player.png")
end

function BattleArt.fitPreparedFrames(images, boxW, boxH, native)
  if type(images) ~= "table" or #images == 0 then return images end
  boxW, boxH = math.floor(tonumber(boxW) or 0), math.floor(tonumber(boxH) or 0)
  if boxW <= 0 or boxH <= 0 then return images end

  local cached = fittedFrameSets[images]
  local cacheKey = boxW .. "x" .. boxH .. (native and ":native" or "")
  if cached and cached[cacheKey] then return cached[cacheKey] end

  local x0, x1, y0, y1
  for _, image in ipairs(images) do
    local metric = metrics[image]
    if not (metric and preparedData[image]) then return images end
    x0 = x0 and math.min(x0, metric.x0) or metric.x0
    x1 = x1 and math.max(x1, metric.x1) or metric.x1
    y0 = y0 and math.min(y0, metric.y0) or metric.y0
    y1 = y1 and math.max(y1, metric.y1) or metric.y1
  end
  local unionW, unionH = x1 - x0 + 1, y1 - y0 + 1
  if unionW <= 0 or unionH <= 0 then return images end

  if native then
    boxW, boxH = math.max(boxW, unionW), math.max(boxH, unionH)
  end
  local scale = native and 1 or math.min(1, boxW / unionW, boxH / unionH)
  local drawW = math.max(1, math.min(boxW, math.floor(unionW * scale + 0.5)))
  local drawH = math.max(1, math.min(boxH, math.floor(unionH * scale + 0.5)))
  local destX = math.floor((boxW - drawW) / 2)
  local destY = native and 0 or boxH - drawH
  local fitted, ok = {}, true
  for _, image in ipairs(images) do
    local source = preparedData[image]
    local made
    ok = pcall(function()
      local sourceW, sourceH = source:getDimensions()
      local data = love.image.newImageData(boxW, boxH)
      for dy = 0, drawH - 1 do
        local sy = y0 + math.min(unionH - 1,
          math.floor(dy * unionH / drawH))
        for dx = 0, drawW - 1 do
          local sx = x0 + math.min(unionW - 1,
            math.floor(dx * unionW / drawW))
          if sx >= 0 and sy >= 0 and sx < sourceW and sy < sourceH then
            data:setPixel(destX + dx, destY + dy, source:getPixel(sx, sy))
          end
        end
      end

      local fx0, fx1, fy0, fy1 = boxW, -1, boxH, -1
      for py = 0, boxH - 1 do
        for px = 0, boxW - 1 do
          local _, _, _, alpha = data:getPixel(px, py)
          if alpha > 0.001 then
            if px < fx0 then fx0 = px end; if px > fx1 then fx1 = px end
            if py < fy0 then fy0 = py end; if py > fy1 then fy1 = py end
          end
        end
      end
      if fx1 < fx0 then error("empty fitted frame") end
      made = love.graphics.newImage(data)
      made:setFilter("nearest", "nearest")
      external[made], preparedData[made] = true, data
      metrics[made] = {
        x0 = fx0, x1 = fx1, y0 = fy0, y1 = fy1,
        w = boxW, h = boxH, padBottom = boxH - 1 - fy1,
        center = (fx0 + fx1 + 1) / 2,
      }
    end)
    if not (ok and made) then return images end
    fitted[#fitted + 1] = made
  end

  cached = cached or setmetatable({}, { __mode = "v" })
  fittedFrameSets[images], cached[cacheKey] = cached, fitted
  return fitted
end
function BattleArt.shareFrameAnchor(images, referenceIndex)
  local reference = images and images[referenceIndex or #images]
  local anchor = reference and metrics[reference]
  if not anchor then return false end
  for _, image in ipairs(images) do
    local metric = metrics[image]
    if not metric or metric.w ~= anchor.w or metric.h ~= anchor.h then
      return false
    end
  end
  for _, image in ipairs(images) do
    local metric = metrics[image]
    metric.center = anchor.center
    metric.y1 = anchor.y1
    metric.padBottom = anchor.padBottom
  end
  return true
end

return BattleArt
