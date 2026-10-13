-- Can the FX address constants be re-derived for the Europe revision?
-- Ask the most specific question: is there a place where 395 pointers each
-- start a record whose opcode is defined by SOME single 18-entry dictionary
-- found in the same ROM?
package.path = "./?.lua;./?/init.lua;" .. package.path
local FxRom = require("mods.STADIUM2_IMPORTER.lib.stadium2_battle_fx_rom")
local path = os.getenv("S2ROM")
  or (os.getenv("HOME").."/Library/Application Support/pokemon-love2d-rseqa/mods/STADIUM2_IMPORTER/baseroms/stadium2.z64")
local f = assert(io.open(path,"rb")); local rom = f:read("*a"); f:close()
print(("rom=%d md5rev=%s"):format(#rom, "EU/NP3P"))

local function u32(o)
  local a,b,c,d = rom:byte(o+1,o+4)
  if not a then return nil end
  return ((a*256+b)*256+c)*256+d
end
-- Control: does the US fragment-79 base hold a plausible overlay on this ROM?
local US_BASE = 0x36F890
print("\ncontrol — US constants applied to this ROM:")
print(("  file 0x%X .. 0x%X"):format(US_BASE, US_BASE + 0x4B486))
local bytes = {}
for i = 0, 7 do bytes[#bytes+1] = ("%02X"):format(rom:byte(US_BASE+i+1) or 0) end
print("  first 8 bytes: " .. table.concat(bytes, " "))

-- Look for the EU overlay: a place where a long run of pointers lands inside
-- a window that also starts with defined-looking code.
local candidates = {}
for base = 0x100000, #rom - 0x500000, 0x10 do
  -- a program table's entries point forward by tens of KB, consistently
  local hits, span = 0, { lo = math.huge, hi = 0 }
  for id = 0, 394 do
    local ptr = u32(base + 0x82154 + id*4)
    if ptr and ptr > base and ptr < base + 0x500000 then
      hits = hits + 1
      if ptr < span.lo then span.lo = ptr end
      if ptr > span.hi then span.hi = ptr end
    end
  end
  if hits >= 380 then
    candidates[#candidates+1] = { base = base, hits = hits,
                                  lo = span.lo, hi = span.hi }
  end
end
table.sort(candidates, function(a,b) return a.hits > b.hits end)
print(("\nEU candidates (>=380/395 pointers land in a 5MB window): %d"):format(#candidates))
for i = 1, math.min(8, #candidates) do
  local c = candidates[i]
  print(("  [%d] overlayBase=0x%-8X hits=%d  pointers 0x%X..0x%X")
    :format(i, c.base, c.hits, c.lo, c.hi))
end
