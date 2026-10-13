-- With the opcode dictionary corrected (OPCODE_TABLE is 0x380 low), find the
-- program table: 395 pointers whose targets all walk cleanly to a terminator.
package.path = "./?.lua;./?/init.lua;" .. package.path
local FxRom = require("mods.STADIUM2_IMPORTER.lib.stadium2_battle_fx_rom")
local path = os.getenv("S2ROM")
  or (os.getenv("HOME").."/Library/Application Support/pokemon-love2d-rseqa/mods/STADIUM2_IMPORTER/baseroms/stadium2.z64")
local f = assert(io.open(path,"rb")); local rom = f:read("*a"); f:close()
local VR, N = FxRom.VRAM_BASE, FxRom.PROGRAM_COUNT
local BASE = FxRom.ROM_BASE
-- the audit's pinned record lengths, and the address they were found at
local OPC_ADDR = 0x8416A598
FxRom.OPCODE_TABLE = OPC_ADDR

local defs = FxRom.opcodes(rom)
local defined = {}
for i = 0, FxRom.OPCODE_COUNT-1 do
  defined[i] = defs[i+1] and defs[i+1].length
end
local function addrs() return BASE end
local function toFile(addr) return BASE + addr - VR end
local function u32atFile(off)
  local a,b,c,d = rom:byte(off+1, off+4)
  if not a then return nil end
  return ((a*256+b)*256+c)*256+d
end
-- walk from a VRAM address through the FULL rom
local function walk(addr)
  local cursor = toFile(addr)
  local records = 0
  local seen = {}
  while records < 64 do
    if not cursor or cursor < 0 or cursor + 1 > #rom then return nil end
    local op = rom:byte(cursor + 1)
    local len = defined[op]
    if not len then return nil, op end
    records = records + 1
    if op == 0 then return records, nil, true end
    if seen[cursor] then return nil end
    seen[cursor] = true
    cursor = cursor + len
  end
  return nil, "no terminator"
end

local best = {}
for pt = 0, #rom - 4*N, 4 do
  local programs, term, recsTotal, firstOp = 0, 0, 0, nil
  for id = 0, N-1 do
    local ptr = u32atFile(pt + id*4)
    if ptr and ptr >= VR and ptr < OPC_ADDR then
      if id == 0 then firstOp = rom:byte(toFile(ptr)+1) end
      local recs, _, done = walk(ptr)
      if recs then programs = programs + 1; recsTotal = recsTotal + recs
        if done then term = term + 1 end end
    end
  end
  if programs >= 300 then
    best[#best+1] = { pt=pt, programs=programs, term=term, avg=recsTotal/programs }
  end
end
table.sort(best, function(a,b) return a.programs > b.programs end)
print(("positions with >=300/%d entries walking cleanly: %d"):format(N, #best))
for i = 1, math.min(6, #best) do
  local b = best[i]
  print(("  ptFile=0x%-7X ptVRAM=0x%08X programs=%d terminated=%d avgRecs=%.1f")
    :format(b.pt, VR + (b.pt - BASE), b.programs, b.term, b.avg))
end
