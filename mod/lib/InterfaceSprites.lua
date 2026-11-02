-- Interface sprites

local V = ...

local ModSetting = V.require("ModSetting")

local InterfaceSprites = {}

InterfaceSprites.setting = ModSetting.new("interfaceSprites",
  "INTERFACE SPRITES",
  { "off", "battle_art", "modded" },
  { "OFF", "BATTLE ART", "MODDED" }, 1)

InterfaceSprites.scalingSetting = ModSetting.new("interfaceScaling",
  "INTERFACE SCALING", { "fit", "full" }, { "FIT", "FULL" }, 1)


return InterfaceSprites
