-- Where is the FX effect-program table really? Scan the extractor's own slice
-- for runs of plausible VRAM pointers and report the best candidates.
package.path = "./?.lua;./?/init.lua;" .. package.path
local FxRom = require("mods.STADIUM2_IMPORTER.lib.stadium2_battle_fx_rom")
local path = os.getenv("S2ROM")
  or (os.getenv("HOME").."/Library/Application Support/pokemon-love2d-rseqa/mods/STADIUM2_IMPORTER/baseroms/stadium2.z64")
local f = assert(io.open(path,"rb"), "no ROM at "..path)
local rom = f:read("*a"); f:close()
local BASE, END_ = 0x36F890, 0x419480
local slice = rom:sub(BASE+1, END_)
print(("rom=%d slice=%d (0x%X..0x%X) vrBase=0x%X"):format(
  #rom, #slice, BASE, END_, FxRom.VRAM_BASE))
local function u32(off)
  local a,b,c,d = slice:byte(off+1, off+4)
  if not a then return nil end
  return ((a*256+b)*256+c)*256+d
end
-- A program pointer must land inside the overlay window the decoder accepts.
local function plausible(v)
  return v and v >= 0x84100000 and v <= 0x8414D000
end
local runs = {}
local runStart, run = nil, 0
for off = 0, #slice-4, 4 do
  if plausible(u32(off)) then
    if run == 0 then runStart = off end
    run = run + 1
  else
    if run >= 20 then runs[#runs+1] = { off = runStart, n = run } end
    run = 0
  end
end
if run >= 20 then runs[#runs+1] = { off = runStart, n = run } end
table.sort(runs, function(a,b) return a.n > b.n end)
print(("candidate tables (>=20 pointers): %d"):format(#runs))
for i = 1, math.min(8, #runs) do
  local r = runs[i]
  local vram = FxRom.VRAM_BASE + r.off
  print(("  [%d] sliceOff=0x%-6X n=%-5d implied VRAM=0x%08X%s"):format(
    i, r.off, r.n, vram,
    (r.off == FxRom.PROGRAM_TABLE - FxRom.VRAM_BASE) and "   <-- decoder's PROGRAM_TABLE" or ""))
end
print(("decoder expects PROGRAM_TABLE at slice 0x%X"):format(FxRom.PROGRAM_TABLE - FxRom.VRAM_BASE))
