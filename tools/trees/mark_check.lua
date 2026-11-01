-- P1c gate: run the rewrite's Trees.mark over a map's real window cells (installed cell dump, tile ids only) and score
-- the roots it places against the installed look's instance list (draw_probe_driver output). No engine, no GPU.
--   cd ~/Documents/emerald3d-audit && luajit ~/Documents/Emerald/tools/trees/mark_check.lua MAP SECONDARY CELLS GOLD CLASSES [list|nolist] [W H]
--   CLASSES = "G:5900-6600,A:9500-10300,H:11000-11800" (class letter : vertex-count range of that drawing in GOLD)
-- Scores the map's own cells and its north ring (what the L4 camera sees; the rest of the gold frame is culled).
local MAP, SEC, CELLS, GOLD, CLASSES, LIST, WARG, HARG = ...
assert(CLASSES, "usage: MAP SECONDARY CELLS GOLD CLASSES [list]")
local floor = math.floor
_G.love = { image = { newImageData = function() error("no images in mark_check") end }, graphics = {} }
local V
V = setmetatable({}, { __index = function(t, k)
  if k == "require" then
    return function(name)
      local m = t[name]
      if m == nil then m = assert(loadfile("lib/" .. name .. ".lua"))(V); t[name] = m end
      return m
    end
  end
end })
local Shapes = V.require("Gen3EmeraldShapes")
local Trees = V.require("Trees")
local B = V.require("BorderFill")

-- classes
local ranges = {}
for cls, lo, hi in CLASSES:gmatch("(%a):(%d+)%-(%d+)") do ranges[#ranges + 1] = { cls, tonumber(lo), tonumber(hi) } end
local function classOfVc(vc)
  for _, r in ipairs(ranges) do if vc >= r[2] and vc <= r[3] then return r[1] end end
end

-- cells
local mids, kinds, minx, maxx, minz, maxz = {}, {}, 1e9, -1e9, 1e9, -1e9
for line in io.lines(CELLS) do
  local x, z, mid, kind = line:match("^%S+%s+(%-?%d+)%s+(%-?%d+)%s+(%x+)%s+(%S+)")
  if x then
    x, z = tonumber(x), tonumber(z)
    mids[x .. ":" .. z] = tonumber(mid, 16); kinds[x .. ":" .. z] = kind
    minx, maxx, minz, maxz = math.min(minx, x), math.max(maxx, x), math.min(minz, z), math.max(maxz, z)
  end
end
-- the dump is the player's window, not the map: pass the map's width and height (the window may end inside the map)
local W, H = tonumber(WARG) or (maxx - 7), tonumber(HARG) or (maxz - 7)
local BLOCKED = 7
local field = { width = W, height = H, cells = {} }
local cells, index = {}, {}
for z = 0, H - 1 do
  for x = 0, W - 1 do
    local k = x .. ":" .. z
    local mid = mids[k]
    if mid then
      local shape = Shapes.of("general", SEC, mid, nil, kinds[k] == "tree" and BLOCKED or 0)
      field.cells[k] = { mid = mid, height = 0, cls = "PLATEAU", shape = shape }
      local c = { x = x, y = z, top = 0, inside = true, mid = mid, shape = shape }
      cells[#cells + 1] = c; index[k] = c
    end
  end
end
local src = { width = W, height = H, layout = {}, pair = "general__" .. SEC, mapId = MAP }
for z = minz, maxz do
  for x = minx, maxx do
    if not (x >= 0 and x < W and z >= 0 and z < H) then
      local b = B.resolve(src, field, x, z)
      if b then
        local c = { x = x, y = z, top = b.top or 0, border = true, mid = b.mid, shape = b.shape }
        cells[#cells + 1] = c; index[x .. ":" .. z] = c
      end
    end
  end
end
local roots = Trees.mark(cells, function(x, y) return index[x .. ":" .. y] end, MAP)

local function classOfShape(s)
  if not s then return "?" end
  if s.art == Shapes.treeArt or s.familyFill or s.canopyFill then return "H" end
  if s.narrowFill or (s.art and s.art[1] and (s.art[1][1] == 0x00E or s.art[1][1] == 0x00F)) then return "N" end
  if s.ftree == "green" then return "G" end
  if s.ftree == "ash" then return "A" end
  return "?"
end
-- Scored: the map's own cells inside the dump's window (the ring is BorderFill's business, not a tree class; the
-- gold frame reaches past the dump). RING=1 in the environment adds the north ring.
local ring = os.getenv("RING") == "1"
local function scored(x, z)
  local cx, cz = floor(x / 16), floor(z / 16)
  return cx >= 0 and cx < W and cx <= maxx and cz <= maxz and cz < H and (cz >= 0 or (ring and cz >= minz))
end
local gold, ngold = {}, 0
local gx0, gx1, gz0, gz1 = 1e9, -1e9, 1e9, -1e9
local raw = {}
for line in io.lines(GOLD) do
  local vc, x, y, z = line:match("^I (%d+) %d+ {(%-?[%d.]+),(%-?[%d.]+),(%-?[%d.]+)}")
  if vc then
    local cls = classOfVc(tonumber(vc))
    x, z = tonumber(x), tonumber(z)
    if cls and x == floor(x) and z == floor(z) then
      raw[#raw + 1] = { x, z, cls }
      gx0, gx1, gz0, gz1 = math.min(gx0, x), math.max(gx1, x), math.min(gz0, z), math.max(gz1, z)
    end
  end
end
-- the instance list is ONE frame: cells past its extent are culled, so score only inside it (one cell in)
local function inFrame(x, z) return x > gx0 + 16 and x < gx1 - 16 and z > gz0 + 16 and z < gz1 - 16 end
for _, r in ipairs(raw) do
  if scored(r[1], r[2]) and inFrame(r[1], r[2]) then gold[r[1] .. "," .. r[2]] = r[3]; ngold = ngold + 1 end
end
local pred, npred = {}, 0
for _, r in ipairs(roots) do
  if scored(r.x, r.z) and inFrame(r.x, r.z) then pred[r.x .. "," .. r.z] = classOfShape(r.shape); npred = npred + 1 end
end
local hit, wrongClass, fp, miss = 0, 0, {}, {}
for k, cls in pairs(pred) do
  local g = gold[k]
  if g == cls then hit = hit + 1 elseif g then wrongClass = wrongClass + 1; fp[#fp + 1] = k .. " ours " .. cls .. " gold " .. g
  else fp[#fp + 1] = k .. " ours " .. cls .. " gold -" end
end
for k, g in pairs(gold) do if not pred[k] then miss[#miss + 1] = k .. " gold " .. g end end
table.sort(fp); table.sort(miss)
print(string.format("%s (%s): map %dx%d, scored window x 0..%d z %d..%d", MAP, SEC, W, H, W - 1, minz, H - 1))
print(string.format("gold roots %d, ours %d, exact hits %d (%.1f%%), class-only misses %d, extra %d, missing %d",
  ngold, npred, hit, 100 * hit / math.max(1, ngold), wrongClass, #fp - wrongClass, #miss))
if LIST == "list" then
  for _, l in ipairs(fp) do print("extra  " .. l) end
  for _, l in ipairs(miss) do print("miss   " .. l) end
end
