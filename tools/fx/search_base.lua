-- If the slice is right but the VRAM origin is wrong, one scalar fixes it.
-- Try origins and keep the ones that decode a real number of programs.
package.path = "./?.lua;./?/init.lua;" .. package.path
local FxRom = require("mods.STADIUM2_IMPORTER.lib.stadium2_battle_fx_rom")
local path = os.getenv("S2ROM")
  or (os.getenv("HOME").."/Library/Application Support/pokemon-love2d-rseqa/mods/STADIUM2_IMPORTER/baseroms/stadium2.z64")
local f = assert(io.open(path,"rb")); local rom = f:read("*a"); f:close()
local slice = rom:sub(0x36F890+1, 0x419480)
local PT, OT = 0x84182154, 0x8416A218
local VR = FxRom.VRAM_BASE
local best = {}
-- a wrong origin must still leave both tables inside the slice
local function tryOrigin(delta)
  FxRom.PROGRAM_TABLE = PT + delta
  FxRom.OPCODE_TABLE  = OT + delta
  local ptOff = FxRom.PROGRAM_TABLE - VR
  local otOff = FxRom.OPCODE_TABLE - VR
  if ptOff < 0 or ptOff + 4*FxRom.PROGRAM_COUNT > #slice then return nil end
  if otOff < 0 or otOff + 8*FxRom.OPCODE_COUNT > #slice then return nil end
  local ok = 0
  for id = 0, FxRom.PROGRAM_COUNT-1 do
    if FxRom.program(slice, id) then ok = ok + 1 end
  end
  return ok
end
for delta = -0x40000, 0x40000, 4 do
  local ok = tryOrigin(delta)
  if ok and ok >= 100 then best[#best+1] = { d = delta, ok = ok } end
end
table.sort(best, function(a,b) return a.ok > b.ok end)
print(("origins decoding >=100 programs: %d"):format(#best))
for i = 1, math.min(8, #best) do
  print(("  delta=%+#x  programs=%d/395"):format(best[i].d, best[i].ok))
end
