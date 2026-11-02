-- The three battle-UI backplate options added for the 1.66 update

local V = ...

local ModSetting = V.require("ModSetting")

local UiBackplates = {}

UiBackplates.spriteLight = ModSetting.new("spriteLight", "SPRITE LIGHT",
  { "SHADED", "UNLIT" }, { "SHADED", "UNLIT" })

function UiBackplates.spritesUnlit()
  if UiBackplates.arenaWhite() or UiBackplates.arenaArt() then return true end
  return UiBackplates.spriteLight:get() == "UNLIT"
end

UiBackplates.battleUi = ModSetting.new("battleUi", "BATTLE ART UI",
  { "BOTH", "TEXTBOX", "HUD", "HIDE" },
  { "BOTH", "TEXTBOX", "HUD", "HIDE" })

function UiBackplates.uiHidden(surface)
  local mode = UiBackplates.battleUi:get()
  if surface == "hud" then return mode == "TEXTBOX" or mode == "HIDE" end
  if surface == "text" then return mode == "HUD" or mode == "HIDE" end
  if surface == "panels" then return mode == "HUD" or mode == "HIDE" end
  return false
end

UiBackplates.hudColor = ModSetting.new("hudColor", "HUD COLOR",
  { "COLOR", "INVERTED" }, { "COLOR", "INVERTED" })

function UiBackplates.hudUsesColor()
  return UiBackplates.arenaWhite()
         or UiBackplates.hudColor:get() == "COLOR"
end


UiBackplates.arenaFill = ModSetting.new("arenaFill", "ARENA FILL",
  { "OFF", "WHITE", "GEN6", "PNG", "BLUE" },
  { "OFF", "WHITE", "GEN6", "PNG", "BLUE" })

UiBackplates.stadiumCircle = ModSetting.new("stadiumCircle", "STADIUM CIRCLE",
  { "ON", "OFF", "HALF" }, { "ON", "OFF", "HALF" })


local offsetValues, offsetLabels = {}, {}
for px = 0, 400, 20 do
  offsetValues[#offsetValues + 1] = px
  offsetLabels[#offsetLabels + 1] = px .. " PX"
end
UiBackplates.backdropOffset = ModSetting.new(
  "backdropOffset", "BG Y-OFFSET", offsetValues, offsetLabels, 6)

function UiBackplates.backdropOffsetPixels()
  return tonumber(UiBackplates.backdropOffset:get()) or 100
end

function UiBackplates.arenaWhite()
  return UiBackplates.arenaFill:get() == "WHITE"
end




function UiBackplates.arenaArt()
  local value = UiBackplates.arenaFill:get()
  return value ~= "OFF" and value ~= "WHITE" and value ~= "BLUE"
end

UiBackplates.bossBg = ModSetting.new("bossBg", "BOSS BG",
  { "ON", "OFF" }, { "ON", "OFF" })

function UiBackplates.bossEnabled()
  return UiBackplates.bossBg:get() == "ON"
end


UiBackplates.textboxFill = ModSetting.new("textboxFill", "TEXTBOX FILL",
  { "WHITE", "HALF", "BLACK", "OFF" },
  { "WHITE", "HALF", "BLACK", "OFF" }, 4)

function UiBackplates.textboxMode()
  if UiBackplates.arenaWhite() then return "WHITE" end
  return UiBackplates.textboxFill:get()
end

function UiBackplates.textboxFillStyle()
  local mode = UiBackplates.textboxMode()
  if mode == "WHITE" then return { 1, 1, 1, 1 } end
  if mode == "HALF" then return { 0, 0, 0, 0.30 } end
  if mode == "BLACK" then return { 0, 0, 0, 1 } end
  return nil
end

function UiBackplates.textboxUsesWhiteInk()
  return UiBackplates.textboxMode() ~= "WHITE"
end

return UiBackplates
