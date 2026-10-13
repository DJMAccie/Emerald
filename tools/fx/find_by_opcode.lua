-- The decisive test: a real program's first record must use a DEFINED opcode.
-- That needs no theory about the table's address, only the opcode dictionary
-- (which is uniquely locatable) and the requirement that entry 0 works.
package.path = "./?.lua;./?/init.lua;" .. package.path
local FxRom = require("mods.STADIUM2_IMPORTER.lib.stadium2_battle_fx_rom")
local path = os.getenv("S2ROM")
  or (os.getenv("HOME").."/Library/Application Support/pokemon-love2d-rseqa/mods/STADIUM2_IMPORTER/baseroms/stadium2.z64")
local f = assert(io.open(path,"rb")); local rom = f:read("*a"); f:close()
local slice = rom:sub(0x36F890+1, 0x419480)
local VR, N, OPC = FxRom.VRAM_BASE, FxRom.PROGRAM_COUNT, FxRom.OPCODE_COUNT
local OT = 0x6A598
FxRom.OPCODE_TABLE = VR + OT

local function u32(off)
  local a,b,c,d = slice:byte(off+1, off+4)
  if not a then return nil end
  return ((a*256+b)*256+c)*256+d
end
local defs = FxRom.opcodes(slice)
local defined = {}
for i = 0, OPC-1 do
  if defs[i+1] then defined[i] = defs[i+1].length end
end
local line = {}
for i = 0, OPC-1 do line[#line+1] = ("op%d/%d"):format(i, defined[i] or -1) end
print("opcode dictionary: " .. table.concat(line, " "))

-- Walk the bytecode from a start offset using the dictionary.
local function walk(startOff)
  local cursor, records, seen = startOff, 0, {}
  while records < 64 do
    if cursor < 0 or cursor + 1 > #slice then return nil end
    local op = slice:byte(cursor + 1)
    local len = defined[op]
    if not len then return nil, op, cursor end
    records = records + 1
    if op == 0 then return records, nil, nil, true end
    if seen[cursor] then return nil end
    seen[cursor] = true
    cursor = cursor + len
  end
  return nil
end

-- Score every 4-byte position: how many of the 395 entries walk cleanly?
local best = {}
for pt = 0, #slice - 4*N, 4 do
  local programs, terminated, totalRecs = 0, 0, 0
  for id = 0, N-1 do
    local ptr = u32(pt + id*4)
    if ptr and ptr >= 0 and ptr + 4 <= #slice then
      local recs, _, _, done = walk(ptr)
      if recs then programs = programs + 1; totalRecs = totalRecs + recs
        if done then terminated = terminated + 1 end end
    end
  end
  if programs >= 150 then
    best[#best+1] = { pt=pt, programs=programs, terminated=terminated,
                      avg=totalRecs/math.max(1,programs) }
  end
end
table.sort(best, function(a,b) return a.programs > b.programs end)
print(("positions where >=150 of %d entries walk cleanly: %d"):format(N, #best))
for i = 1, math.min(8, #best) do
  local b = best[i]
  print(("  [%d] ptOff=0x%-6X programs=%d terminated=%d avgRecords=%.1f")
    :format(i, b.pt, b.programs, b.terminated, b.avg))
end
