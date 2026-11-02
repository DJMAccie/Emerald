-- Runtime playback for authoring-time GIF conversions
local V = ...

local BattleArt = V.require("BattleArt")
local SETS = { gen3 = V.data("animated_battle_sprites_gen3") }
local BACK_SETS = { gen3 = V.data("animated_battle_backs_gen3") }
local SHINY_SETS = { gen3 = V.data("animated_battle_sprites_gen3_shiny") }
local PLAYER_SETS = V.data("animated_player_trainers")
local AnimatedBattleArt = {}

local loaded, loadOrder = {}, {}
local LOAD_LIMIT = 6

local function forgetFromOrder(def)
  for i = #loadOrder, 1, -1 do
    if loadOrder[i] == def then table.remove(loadOrder, i) end
  end
end

local function remember(def, mode, frames)
  forgetFromOrder(def)
  loaded[def] = { mode = mode, frames = frames }
  loadOrder[#loadOrder + 1] = def
  if #loadOrder > LOAD_LIMIT then
    local old = table.remove(loadOrder, 1)
    loaded[old] = nil
  end
end

local function atlasPath(def)
  local path = def and def.image and V.mod.assets:path(def.image)
  return path
end

local function decodeFrames(def, mode, source)
  local result
  local ok = pcall(function()
    local sheet
    if source then
      if type(source) == "string" then
        sheet = love.image.newImageData(source)
      elseif type(source.newImageData) == "function" then
        sheet = source:newImageData()
      else
        return
      end
    else
      local path = atlasPath(def)
      if not path then return end
      sheet = love.image.newImageData(path)
    end
    if not sheet then return end
    local sheetW, sheetH = sheet:getDimensions()
    local frames = {}
    local cells = def.cells
    local autoColumns = tonumber(def.autoColumns)
    local count = cells and #cells or autoColumns or assert(tonumber(def.frames))
    if count < 1 then return end
    -- Select only an exact sheet layout; never slice an old atlas with tight cells.
    local layout = def
    if def.legacyLayout and not cells and not autoColumns then
      local columns = assert(tonumber(def.columns))
      local rows = math.ceil(count / columns)
      local function matches(candidate)
        return sheetW == candidate.width * columns
          and sheetH == candidate.height * rows
      end
      if not matches(def) then
        if not matches(def.legacyLayout) then return end
        layout = def.legacyLayout
      end
    end
    local autoWidth
    if autoColumns then
      if autoColumns % 1 ~= 0 or sheetW % autoColumns ~= 0 then return end
      autoWidth = sheetW / autoColumns
    end
    for index = 0, count - 1 do
      local x, y, width, height
      if cells then
        local c = cells[index + 1]
        x, y = tonumber(c.x) or 0, tonumber(c.y) or 0
        width, height = assert(tonumber(c.width)), assert(tonumber(c.height))
      elseif autoColumns then
        x, y = index * autoWidth, 0
        width, height = autoWidth, sheetH
      else
        width = assert(tonumber(layout.width))
        height = assert(tonumber(layout.height))
        local columns = assert(tonumber(def.columns))
        x = (index % columns) * width
        y = math.floor(index / columns) * height
      end
      if width < 1 or height < 1 or x < 0 or y < 0
         or x + width > sheetW or y + height > sheetH then return end
      local cell = love.image.newImageData(width, height)
      cell:paste(sheet, 0, 0, x, y, width, height)
      local image = BattleArt.prepareData(cell, mode)
      if not image then return end
      frames[#frames + 1] = image
    end
    if #frames == count then
      if def.stableAnchor then
        BattleArt.shareFrameAnchor(frames, #frames)
      end
      result = frames
    end
  end)
  return ok and result or nil
end

local function loadFrames(def, mode)
  local hit = loaded[def]
  if hit and hit.mode == mode then return hit.frames end
  local result = decodeFrames(def, mode)
  if not result then return nil end
  remember(def, mode, result)
  return result
end

function AnimatedBattleArt.playerTrainerPicture(progress)
 local mode=BattleArt.setting:get()
 if mode=='rom' then return nil end
 if mode=='static'then return BattleArt.playerTrainerImage()end
 local selected=BattleArt.effectivePlayerAnimationSet()
 if selected=='png'then return BattleArt.namedImage('player','back')end
 local def=selected~='rom' and PLAYER_SETS[selected] or nil
 local frames=def and loadFrames(def,BattleArt.displayMode())
 if not frames or #frames==0 then return nil end
 progress=math.max(0,math.min(72,tonumber(progress)or 0))
 local index=progress<=0 and 1 or math.min(#frames,
  2+math.floor(math.max(0,progress-1)*math.max(1,#frames-1)/72))
 return frames[index]
end

local function definition(battler, side)
  if not BattleArt.ownsSpeciesArt() then return nil end
  local species = BattleArt.speciesFor(battler)
  local key = species and tostring(BattleArt.speciesAlias(species)):upper()
  local setting = side == "back" and BattleArt.backAnimationSetting
                                  or BattleArt.frontAnimationSetting
  local generation = setting:get()
  local collections = side == "back" and BACK_SETS or SETS
  local selected = collections[generation]
  local detectedShiny = BattleArt.isShiny(battler)
  local shiny = detectedShiny and BattleArt.ownsShinyArt()
  -- Shiny and normal atlases differ in size and timing: never swap only the filename.
  if shiny and SHINY_SETS[generation] then
    selected = SHINY_SETS[generation]
  end
  local bySide = selected and key and selected[key]
  local def = bySide and bySide[side] or nil
  return def
end
AnimatedBattleArt.definitionFor = definition
function AnimatedBattleArt.picture(mon,side)
  if not BattleArt.ownsSpeciesArt() or BattleArt.setting:get()=='rom' then return nil end
  local battler=mon and mon.mon and mon or {mon=mon}
  local species=BattleArt.speciesFor(battler)
  if BattleArt.setting:get()=='animated' then
    local def=definition(battler,side)
    local frames=def and loadFrames(def,BattleArt.displayMode())
    if frames and #frames>0 then
      local total=0;for i=1,#frames do total=total+math.max(1,tonumber((def.durations or {})[i])or 100)end
      local t=(love.timer.getTime()*1000)%total
      for i,frame in ipairs(frames)do t=t-math.max(1,tonumber((def.durations or {})[i])or 100);if t<0 then return frame,frames end end
      return frames[1],frames
    end
  end
  if BattleArt.setting:get()=='static' then return BattleArt.image(species,side,battler)end
  return nil
end

return AnimatedBattleArt
