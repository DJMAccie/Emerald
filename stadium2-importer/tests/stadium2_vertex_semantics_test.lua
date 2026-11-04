package.path = "./?.lua;./?/init.lua;" .. package.path

local VertexSemantics = require("mods.STADIUM2_IMPORTER.lib.vertex_semantics")

local failures = 0
local function ok(value, name)
  if value then print("PASS " .. name)
  else failures = failures + 1; print("FAIL " .. name) end
end

-- Stadium normals have an encoded magnitude near 119/127, not 1 exactly.
local normals = {
  119 / 127, 0, 0,
  0, -119 / 127, 0,
  0, 0, 119 / 127,
  84 / 127, 84 / 127, 0,
}
local semantics, measurement = VertexSemantics.classify(normals)
ok(semantics == "normal" and measurement.normalRatio == 1,
  "Stadium signed normal payload is detected without G_LIGHTING")

local colors = {
  1 / 127, 1 / 127, 1 / 127,
  55 / 127, 55 / 127, 55 / 127,
}
ok(VertexSemantics.classify(colors) == "color",
  "zero and mid-grey RGB payloads are not mistaken for normals")

local mixed = {
  119 / 127, 0, 0,
  0, 119 / 127, 0,
  0, 0, 0,
}
ok(VertexSemantics.classify(mixed) == "normal",
  "normal-majority mixed draw remains lit")

if failures > 0 then os.exit(1) end
