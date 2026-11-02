-- The three battle-UI backplate options added for the 1.66 update

local V = ...

local ModSetting = V.require("ModSetting")

local UiBackplates = {}

UiBackplates.spriteLight = ModSetting.new("spriteLight", "SPRITE LIGHT",
  { "SHADED", "UNLIT" }, { "SHADED", "UNLIT" })

function UiBackplates.spritesUnlit()
  if UiBackplates.arenaWhite() then return true end
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
  { "OFF", "WHITE" }, { "OFF", "WHITE" })

function UiBackplates.arenaWhite()
  return UiBackplates.arenaFill:get() == "WHITE"
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
