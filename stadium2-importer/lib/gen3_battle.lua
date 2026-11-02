-- Gen 3 (FireRed/LeafGreen/Emerald) battle implementation: intentionally
-- inert. The native game3 battle engine owns the screen; the importer's job on
-- a Gen 3 cart is to extract and serve Stadium 2 models through
-- mod.exports.models, which Battle Art places in its staged voxel battles.
local Gen3 = {}
local modRef
function Gen3.bind(mod) modRef = mod; return Gen3 end
function Gen3.configureGame()
  -- Stadium 2 carries models for #1-251; every Gen 3 cart can meet them.
  local ok, Importer = pcall(require, "mods.STADIUM2_IMPORTER.lib.importer")
  if ok and Importer and Importer.configure then Importer.configure({ count = 251 }) end
  return nil
end
function Gen3.install() return nil end
function Gen3.ensure() return nil end
function Gen3.update() return nil end
function Gen3.finish() return nil end
function Gen3.enabled() return false end
function Gen3.ready() return false end
function Gen3.status() return { generation = 3, active = false, reason = "native game3 battles; models served to Battle Art" } end
function Gen3.currentScene() return nil end
function Gen3.uninstall() return nil end
function Gen3.resetForTests() return nil end
return Gen3
