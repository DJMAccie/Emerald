-- Find the effect-program table by its CONTENT: a run where every entry is a
-- pointer into fragment 79 that starts a record with a defined opcode.
package.path = "./?.lua;./?/init.lua;" .. package.path
local FxRom = require("mods.STADIUM2_IMPORTER.lib.stadium2_battle_fx_rom")
local path = os.getenv("S2ROM")
  or (os.getenv("HOME").."/Library/Application Support/pokemon-love2d-rseqa/mods/STADIUM2_IMPORTER/baseroms/stadium2.z64")
local f = assert(io.open(path,"rb")); local rom = f:read("*a"); f:close()
local VR, N, BASE = FxRom.VRAM_BASE, FxRom.PROGRAM_COUNT, FxRom.ROM_BASE
local OPC_ADDR = 0x8416A598
FxRom.OPCODE_TABLE = OPC_ADDR
local defs = FxRom.opcodes(rom)
local defined = {}
for i = 0, 17 do
  local row = defs[i] or defs[i+1]
  defined[i] = row and row.length
end

local function u32(o)
  local a,b,c,d = rom:byte(o+1,o+4)
  if not a then return nil end
  return ((a*256+b)*256+c)*256+d
end
local function toFile(a) return BASE + a - VR end
local function firstOpDefined(addr)
  if not addr or addr < VR or addr >= OPC_ADDR then return false end
  local off = toFile(addr)
  if off < 0 or off + 1 > #rom then return false end
  return defined[rom:byte(off+1)] ~= nil
end

-- score each 4-byte position by how many entries start a defined record
local scored = {}
for pt = 0, #rom - 4*N, 4 do
  local hits = 0
  for id = 0, N-1 do
    if firstOpDefined(u32(pt + id*4)) then hits = hits + 1 end
  end
  if hits >= 250 then scored[#scored+1] = { pt = pt, hits = hits } end
end
table.sort(scored, function(a,b) return a.hits > b.hits end)
print(("positions where >=250 of %d entries start a defined record: %d"):format(N, #scored))
for i = 1, math.min(10, #scored) do
  local s = scored[i]
  print(("  [%d] tableFile=0x%-8X tableVRAM=0x%08X hits=%d/%d")
    :format(i, s.pt, VR + (s.pt - BASE), s.hits, N))
end
