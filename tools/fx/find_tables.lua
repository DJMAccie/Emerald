-- Find the effect-program table by VALIDATION rather than by looking like
-- pointers: a true table's entries must each decode into a distinct program
-- with real records, not into the same lone terminator.
package.path = "./?.lua;./?/init.lua;" .. package.path
local FxRom = require("mods.STADIUM2_IMPORTER.lib.stadium2_battle_fx_rom")
local path = os.getenv("S2ROM")
  or (os.getenv("HOME").."/Library/Application Support/pokemon-love2d-rseqa/mods/STADIUM2_IMPORTER/baseroms/stadium2.z64")
local f = assert(io.open(path,"rb")); local rom = f:read("*a"); f:close()
local slice = rom:sub(0x36F890+1, 0x419480)
local VR, N, OPC = FxRom.VRAM_BASE, FxRom.PROGRAM_COUNT, FxRom.OPCODE_COUNT

local function u32(off)
  local a,b,c,d = slice:byte(off+1, off+4)
  if not a then return nil end
  return ((a*256+b)*256+c)*256+d
end
local function inSlice(off) return off and off >= 0 and off + 4 <= #slice end

-- 1. the opcode table first: it is the smaller, more distinctive structure.
local opCands = {}
for off = 0, #slice - OPC*8 do
  local good = true
  for i = 0, OPC-1 do
    local h = u32(off + i*8)
    local len = u32(off + i*8 + 4)
    if not (h and h >= VR and len and len >= 1 and len <= 64) then good = false break end
  end
  if good then opCands[#opCands+1] = off end
end
print("opcode-table candidates: " .. #opCands)

-- 2. program tables: for each, decode and score by REAL programs.
local function score(ptOff, otOff)
  FxRom.PROGRAM_TABLE = VR + ptOff
  FxRom.OPCODE_TABLE  = VR + otOff
  local defs = FxRom.opcodes(slice)
  local programs, records, longest, op0only, seen = 0, 0, 0, 0, {}
  for id = 0, N-1 do
    local p = FxRom.program(slice, id)
    if p then
      programs = programs + 1
      records = records + #p.records
      if #p.records > longest then longest = #p.records end
      if #p.records <= 1 then op0only = op0only + 1 end
      seen[p.address] = true
    end
  end
  local distinct = 0
  for _ in pairs(seen) do distinct = distinct + 1 end
  -- A real table: many programs, mostly multi-record, mostly distinct.
  local score = programs + distinct * 2 + longest * 3 - op0only * 4
  return score, programs, records, longest, op0only, distinct
end

local best = {}
for pt = 0, #slice - 4*N, 4 do
  -- cheap pre-filter: entry 0 must at least be in the slice
  local p0 = u32(pt)
  if p0 and inSlice(p0) then
    for _, ot in ipairs(opCands) do
      local score, programs, records, longest, op0only, distinct = score(pt, ot)
      if score > 0 and programs >= 100 then
        best[#best+1] = { pt=pt, ot=ot, score=score, programs=programs,
                          records=records, longest=longest, op0only=op0only,
                          distinct=distinct }
      end
    end
  end
end
table.sort(best, function(a,b) return a.score > b.score end)
print(("scored %d (table, opcode) pairs"):format(#best))
for i = 1, math.min(6, #best) do
  local b = best[i]
  print(("  [%d] progTable=0x%-6X opcodeTable=0x%-6X programs=%d distinct=%d records=%d longest=%d op0only=%d"
    ):format(i, b.pt, b.ot, b.programs, b.distinct, b.records, b.longest, b.op0only))
end
