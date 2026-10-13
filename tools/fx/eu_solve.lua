-- Derive the Europe revision's FX layout.
--
-- Method: the opcode table is a strong fingerprint -- 18 records of
-- {VRAM handler pointer, record length} whose lengths are pinned by the
-- importer's own audit. Find it anywhere in the ROM, derive the overlay base
-- from where it sits, then search for the program table with a CORRECT
-- dictionary (the earlier search used the US-broken one).
package.path = "./?.lua;./?/init.lua;" .. package.path
local FxRom = require("mods.STADIUM2_IMPORTER.lib.stadium2_battle_fx_rom")
local path = os.getenv("S2ROM")
  or (os.getenv("HOME").."/Library/Application Support/pokemon-love2d-rseqa/mods/STADIUM2_IMPORTER/baseroms/stadium2.z64")
local f = assert(io.open(path,"rb")); local rom = f:read("*a"); f:close()
local LENGTHS = {4,4,4,4,8,8,8,8,8,4,4,4,16,8,8,8,4,4}   -- upstream's pinned table
local OPC_COUNT = 18
local US_OPC_FILE = 0x3D9E28      -- where the USA opcode table sits in the file
local US_PT_OFF   = 0x82154       -- program table, as an offset from the base

local function u32(o)
  local a,b,c,d = rom:byte(o+1,o+4)
  if not a then return nil end
  return ((a*256+b)*256+c)*256+d
end

-- 1. the opcode table, by its length signature plus sane handlers
local opcHits = {}
for off = 0, #rom - OPC_COUNT*8, 4 do
  local ok = true
  for i = 0, OPC_COUNT-1 do
    if (u32(off + i*8 + 4) or -1) ~= LENGTHS[i+1] then ok = false break end
  end
  if ok then
    -- handlers must be plausible code addresses in one contiguous cluster
    local lo, hi = math.huge, 0
    for i = 0, OPC_COUNT-1 do
      local h = u32(off + i*8)
      if not h or h < 0x80000000 or h > 0x81800000 then ok = false break end
      if h < lo then lo = h end
      if h > hi then hi = h end
    end
    if ok and (hi - lo) < 0x40000 then
      opcHits[#opcHits+1] = { off = off, lo = lo, hi = hi }
    end
  end
end
print(("opcode-table candidates by signature: %d"):format(#opcHits))
for i = 1, math.min(6, #opcHits) do
  local h = opcHits[i]
  print(("  [%d] file=0x%-8X handlers 0x%08X..0x%08X"):format(i, h.off, h.lo, h.hi))
end

-- 2. for each, derive the overlay base and hunt the program table
local defs = {}
for _, cand in ipairs(opcHits) do
  local base = cand.off - (US_OPC_FILE - FxRom.ROM_BASE)   -- keep the US relative layout
  local okDict = pcall(function()
    FxRom.OPCODE_TABLE = FxRom.VRAM_BASE + (cand.off - base)
    local d = FxRom.opcodes(rom)
    for i = 0, OPC_COUNT-1 do
      local row = d[i] or d[i+1]
      if not (row and row.length) then error("incomplete") end
    end
    defs = d
  end)
  print(("\nbase=0x%X  dictionary ok=%s"):format(base, tostring(okDict)))
  if not okDict then goto continue end
  do
    local defined = {}
    for i = 0, OPC_COUNT-1 do
      local row = defs[i] or defs[i+1]
      defined[i] = row and row.length
    end
    -- hunt: entry targets must start a defined record
    local best, bestHits = nil, 0
    for pt = base + US_PT_OFF - 0x4000, base + US_PT_OFF + 0x4000, 4 do
      local hits = 0
      for id = 0, 394 do
        local p = u32(pt + id*4)
        if p and p >= base and p < base + 0x600000 then
          local op = rom:byte(p + 1)
          if op and defined[op] then hits = hits + 1 end
        end
      end
      if hits > bestHits then bestHits, best = hits, pt end
    end
    print(("  best program table near the US offset: file=0x%X hits=%d/395")
      :format(best or 0, bestHits))
  end
  ::continue::
end
