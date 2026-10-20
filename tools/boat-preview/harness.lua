-- Run the mod's M.boat with a stub mesh builder and print the geometry (no game needed).
--   luajit tools/boat-preview/harness.lua <mod root> /tmp/pixels.lua > /tmp/boat_mesh.txt
-- A sprite is made from the pixel rows gen_pixels.py dumps; the frame is 32x32 by default.
local modRoot = assert(arg[1], "usage: harness.lua <mod root> <pixels.lua>")
local pixelFile = assert(arg[2], "usage: harness.lua <mod root> <pixels.lua>")
local R = {newMesh = function(v, i) return {verts = v, idx = i} end}
local V = {require = function() return R end}
local M = assert(loadfile(modRoot .. "/lib/Gen3RockSprites.lua"))(V)
local rows = dofile(pixelFile)
local W, H = 32, #rows
local cache = {}
local imageData = {}
function imageData:getPixel(x, y)
  if x < 0 or y < 0 or x >= W or y >= H then return 0, 0, 0, 0 end
  local r = cache[y]
  if not r then
    local s = rows[y + 1]
    r = {}
    for i = 0, W - 1 do
      local hex = s:sub(i * 8 + 1, i * 8 + 8)
      r[i] = {tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
              tonumber(hex:sub(5, 6), 16) / 255, tonumber(hex:sub(7, 8), 16) / 255}
    end
    cache[y] = r
  end
  local c = r[x]
  return c[1], c[2], c[3], c[4]
end
local spr = {
  image = {getDimensions = function() return W, H end},
  imageData = imageData,
  quads = {[0] = {getViewport = function() return 0, 0, W, 32 end}},
}
local m = M.boat(spr)
if not m then print("NO MESH") os.exit(1) end
print(string.format("verts %d tris %d", #m.verts, math.floor(#m.idx / 3)))
for _, v in ipairs(m.verts) do
  print(string.format("V %.4f %.4f %.4f %.6f %.6f %.3f", v[1], v[2], v[3], v[4], v[5], v[6]))
end
for _, k in ipairs(m.idx) do print("I " .. k) end
