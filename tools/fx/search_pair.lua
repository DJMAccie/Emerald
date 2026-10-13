-- The program table constant is off. Find the (programTable, opcodeTable)
-- pair that actually decodes effect programs: the opcode table is 18 records
-- of {handler VRAM pointer, record length}, the program table 395 pointers.
package.path = "./?.lua;./?/init.lua;" .. package.path
local FxRom = require("mods.STADIUM2_IMPORTER.lib.stadium2_battle_fx_rom")
local path = os.getenv("S2ROM")
  or (os.getenv("HOME").."/Library/Application Support/pokemon-love2d-rseqa/mods/STADIUM2_IMPORTER/baseroms/stadium2.z64")
local f = assert(io.open(path,"rb")); local rom = f:read("*a"); f:close()
local slice = rom:sub(0x36F890+1, 0x419480)
local VR, N = FxRom.VRAM_BASE, FxRom.PROGRAM_COUNT
local OPC = FxRom.OPCODE_COUNT

local function u32(off)
  local a,b,c,d = slice:byte(off+1, off+4)
  if not a then return nil end
  return ((a*256+b)*256+c)*256+d
end
local function inOverlay(v) return v and v >= 0x84100000 and v <= 0x8414D000 end

local ptrRuns = {}
local runStart, run = nil, 0
for off = 0, #slice-4, 4 do
  if inOverlay(u32(off)) then
    if run == 0 then runStart = off end
    run = run + 1
  else
    if run >= 40 then ptrRuns[#ptrRuns+1] = runStart end
    run = 0
  end
end
if run >= 40 then ptrRuns[#ptrRuns+1] = runStart end

-- opcode table: 18 x (pointer, small length)
local opRuns = {}
for off = 0, #slice - OPC*8 do
  local good = true
  for i = 0, OPC-1 do
    local handler = u32(off + i*8)
    local length  = u32(off + i*8 + 4)
    if not inOverlay(handler) or not length or length < 1 or length > 64 then
      good = false break
    end
  end
  if good then opRuns[#opRuns+1] = off end
end
print(("program-table candidates=%d  opcode-table candidates=%d"):format(#ptrRuns, #opRuns))

local best = {}
for _, pt in ipairs(ptrRuns) do
  for _, ot in ipairs(opRuns) do
    FxRom.PROGRAM_TABLE = VR + pt
    FxRom.OPCODE_TABLE  = VR + ot
    local ok = 0
    for id = 0, math.min(N, 200) - 1 do
      if FxRom.program(slice, id) then ok = ok + 1 end
    end
    if ok >= 30 then best[#best+1] = { pt=pt, ot=ot, ok=ok } end
  end
end
table.sort(best, function(a,b) return a.ok > b.ok end)
print(("pairs decoding >=30 of the first 200: %d"):format(#best))
for i = 1, math.min(6, #best) do
  local b = best[i]
  print(("  programTable=0x%-7X opcodeTable=0x%-7X ok=%d/200"):format(b.pt,b.ot,b.ok))
end
