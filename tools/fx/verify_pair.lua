-- Validate a candidate table pair properly: how many of ALL 395 programs
-- decode, what opcodes they actually use, and do the decoded records look
-- like effect data (bounded lengths, in-overlay data pointers).
package.path = "./?.lua;./?/init.lua;" .. package.path
local FxRom = require("mods.STADIUM2_IMPORTER.lib.stadium2_battle_fx_rom")
local path = os.getenv("S2ROM")
  or (os.getenv("HOME").."/Library/Application Support/pokemon-love2d-rseqa/mods/STADIUM2_IMPORTER/baseroms/stadium2.z64")
local f = assert(io.open(path,"rb")); local rom = f:read("*a"); f:close()
local slice = rom:sub(0x36F890+1, 0x419480)
local VR = FxRom.VRAM_BASE
FxRom.PROGRAM_TABLE = VR + tonumber(os.getenv("PT") or "0x844C8")
FxRom.OPCODE_TABLE  = VR + tonumber(os.getenv("OT") or "0x6A598")
print(("programTable=0x%X opcodeTable=0x%X"):format(
  FxRom.PROGRAM_TABLE-VR, FxRom.OPCODE_TABLE-VR))
local defs = FxRom.opcodes(slice)
local lens, handlers = {}, {}
for i = 1, #defs do
  lens[#lens+1] = tostring(defs[i].length)
  handlers[#handlers+1] = ("0x%08X/%d"):format(defs[i].handler, defs[i].length)
end
print("opcodes: "..table.concat(handlers, "  "))
local ok, used, totalRecs = 0, {}, 0
local firstBad
for id = 0, FxRom.PROGRAM_COUNT-1 do
  local p, err = FxRom.program(slice, id)
  if p then
    ok = ok + 1
    totalRecs = totalRecs + #p.records
    for _, r in ipairs(p.records) do used[r.opcode] = (used[r.opcode] or 0) + 1 end
  elseif not firstBad then
    firstBad = ("id=%d %s"):format(id, tostring(err))
  end
end
print(("programs decoded %d/%d   records=%d   firstBad=%s"):format(
  ok, FxRom.PROGRAM_COUNT, totalRecs, tostring(firstBad)))
local ops = {}
for k, v in pairs(used) do ops[#ops+1] = { k=k, v=v } end
table.sort(ops, function(a,b) return a.v > b.v end)
local line = {}
for i = 1, math.min(12, #ops) do line[#line+1] = ("op%d:%d"):format(ops[i].k, ops[i].v) end
print("opcode mix: "..table.concat(line, " "))
