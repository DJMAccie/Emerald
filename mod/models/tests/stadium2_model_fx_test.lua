package.path = "./?.lua;./?/init.lua;" .. package.path

local Fragment = require("mods.emerald_3d_voxel_mod.models.lib.fragment")
local Fx = require("mods.emerald_3d_voxel_mod.models.lib.fx")

local checks = 0
local function ok(value, message)
  checks = checks + 1
  if not value then error("FAIL " .. message, 0) end
end

local bytes = {}
for i = 1, 0x300 do bytes[i] = 0 end

local function put8(offset, value)
  bytes[offset + 1] = value % 0x100
end

local function put32(offset, value)
  put8(offset, math.floor(value / 0x1000000))
  put8(offset + 1, math.floor(value / 0x10000))
  put8(offset + 2, math.floor(value / 0x100))
  put8(offset + 3, value)
end

local BASE = 0x8FF00000
put32(0x240, 0x27BDFFE0)
put32(0x244, 0xAFBF001C)
put32(0x248, 0x03E00008)
put32(0x24C, 0x27BD0020)

local chars = {}
for i = 1, #bytes do chars[i] = string.char(bytes[i]) end
local data = table.concat(chars)

local deduped = Fragment.dedupeFx({
  { bone = 2, callback = 0x81000068, handler = 0x81000068, arg = 0x120, commandOffset = 0x200 },
  { bone = 2, callback = 0x81000068, handler = 0x81000068, arg = 0x120, commandOffset = 0x220 },
  { bone = 2, callback = 0x81000068, handler = 0x81000068, arg = 0x120, commandOffset = 0x200 },
})
ok(#deduped == 2, "distinct physical handler commands survive dedupe")
ok(deduped[1].commandOffset == 0x200 and deduped[2].commandOffset == 0x220, "handler command offsets preserved")

local localProbe = Fx.probe(data, BASE + 0x240, BASE, 0x100)
ok(localProbe.origin == "fragment", "fragment callback classified")
ok(localProbe.offset == 0x240, "fragment callback offset")
ok(localProbe.reason == "jr_ra", "fragment callback return detected")
ok(localProbe.length == 0x10, "fragment callback probe length")
ok(type(localProbe.fingerprint) == "string" and #localProbe.fingerprint > 0, "fragment callback fingerprint")
ok(localProbe.words == "27BDFFE0 AFBF001C 03E00008 27BD0020", "fragment callback words")

local runtimeProbe = Fx.probe(data, 0x80123456, BASE, 0x100)
ok(runtimeProbe.origin == "runtime", "runtime callback classified")
ok(runtimeProbe.offset == nil, "runtime callback has no fragment offset")

print(("%d checks passed (Stadium 2 model FX)"):format(checks))
