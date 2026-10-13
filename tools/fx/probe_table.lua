-- Try each candidate program-table location: the right one decodes programs
-- cleanly. Usage: S2ROM=... luajit tools/fx/probe_table.lua [sliceOff ...]
package.path = "./?.lua;./?/init.lua;" .. package.path
local FxRom = require("mods.STADIUM2_IMPORTER.lib.stadium2_battle_fx_rom")
local path = os.getenv("S2ROM")
  or (os.getenv("HOME").."/Library/Application Support/pokemon-love2d-rseqa/mods/STADIUM2_IMPORTER/baseroms/stadium2.z64")
local f = assert(io.open(path,"rb")); local rom = f:read("*a"); f:close()
local slice = rom:sub(0x36F890+1, 0x419480)

local candidates = {}
for _, a in ipairs(arg or {}) do candidates[#candidates+1] = tonumber(a) end
if #candidates == 0 then
  candidates = { 0x82154, 0x89370, 0x8B550, 0x840D0, 0x844C8, 0x86230 }
end

local function try(off)
  FxRom.PROGRAM_TABLE = FxRom.VRAM_BASE + off
  local ok, n, firstErr = 0, 0, nil
  for id = 0, FxRom.PROGRAM_COUNT - 1 do
    local p, err = FxRom.program(slice, id)
    if p then ok = ok + 1 else n = n + 1; firstErr = firstErr or err end
  end
  return ok, n, firstErr
end

for _, off in ipairs(candidates) do
  local ok, bad, err = try(off)
  print(("sliceOff=0x%-7X programs decoded %d/%d  bad=%d  firstErr=%s"):format(
    off, ok, FxRom.PROGRAM_COUNT, bad, tostring(err)))
end
