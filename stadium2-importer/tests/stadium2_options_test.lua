package.path = "./?.lua;./?/init.lua;" .. package.path

local checks = 0
local function ok(value, message)
  checks = checks + 1
  if not value then error("FAIL " .. message, 0) end
end

package.loaded["mods.STADIUM2_IMPORTER.lib.importer"] = nil
local Importer = require("mods.STADIUM2_IMPORTER.lib.importer")
local models, battle, shader, rapidashCut, betaBattleFx = true, true, "stadium", true, false
Importer.bind({ options={ get=function(_, key)
  if key == "stadium2_models" then return models end
  if key == "stadium2_battle" then return battle end
  if key == "stadium2_shader" then return shader end
  if key == "stadium2_rapidash_cut_fx" then return rapidashCut end
  if key == "stadium2_beta_battle_fx" then return betaBattleFx end
end } })
ok(Importer.modelsEnabled(), "Stadium 2 models default ON")
ok(Importer.battleEnabled(), "3D battle scene default ON")
ok(Importer.shaderStyle() == "stadium", "Stadium lighting is the default model shader")
rapidashCut=false
ok(not Importer.rapidashCutEffectEnabled(), "cut Rapidash particles follow the OFF option")
rapidashCut=true
ok(Importer.rapidashCutEffectEnabled(), "cut Rapidash particles default ON")
ok(not Importer.betaBattleFxEnabled(), "move FX default OFF")
betaBattleFx=true
ok(Importer.betaBattleFxEnabled(), "beta move FX setting reaches the importer")
shader = "cel"
ok(Importer.shaderStyle() == "cel", "cel-shaded model option reaches the renderer configuration")
shader = "invalid"
ok(Importer.shaderStyle() == "stadium", "unknown shader settings use Stadium lighting")
shader = "stadium"
models = false
ok(not Importer.modelsEnabled(), "models OFF disables renderers")
local rig, err = Importer.newRenderer(25, "normal")
ok(rig == nil and err == "Stadium 2 models disabled", "renderer creation is blocked while models are OFF")
models = true
battle = false
ok(Importer.modelsEnabled() and not Importer.battleEnabled(), "models stay ON when the 3D battle scene is OFF")

local function read(path) local f = assert(io.open(path, "rb")); local s = f:read("*a"); f:close(); return s end
local main = read("mods/STADIUM2_IMPORTER/main.lua")
local manifest = read("mods/STADIUM2_IMPORTER/manifest.json")
for _, key in ipairs({"stadium2_models", "stadium2_battle", "stadium2_shader", "stadium2_rapidash_cut_fx", "stadium2_beta_battle_fx"}) do
  ok(main:find('key="' .. key .. '"', 1, true) ~= nil, "main defines option " .. key)
end
ok(main:find('local MOD_BUILD = "' .. manifest:match('"version": "([^"]+)"') .. '"', 1, true) ~= nil,
  "main.lua's module-cache build stamp matches the manifest version")
ok(manifest:find('"dependencies": []', 1, true) ~= nil, "no required mods")

print(("%d checks passed (Stadium 2 options)"):format(checks))
