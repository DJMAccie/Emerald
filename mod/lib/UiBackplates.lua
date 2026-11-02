-- ARENA FILL and SPRITE LIGHT

local V = ...

local ModSetting = V.require("ModSetting")

local UiBackplates = {}

UiBackplates.spriteLight = ModSetting.new("spriteLight", "SPRITE LIGHT",
  { "SHADED", "UNLIT" }, { "SHADED", "UNLIT" })

function UiBackplates.spritesUnlit()
  if UiBackplates.arenaWhite() then return true end
  return UiBackplates.spriteLight:get() == "UNLIT"
end

UiBackplates.arenaFill = ModSetting.new("arenaFill", "ARENA FILL",
  { "OFF", "WHITE" }, { "OFF", "WHITE" })

function UiBackplates.arenaWhite()
  return UiBackplates.arenaFill:get() == "WHITE"
end

return UiBackplates
