-- The engine's tile-animation clock
local TileRenderer = require("src.render.TileRenderer")

local clockUpvalue = nil -- nil = not looked for yet, false = absent

local function findClockUpvalue()
  if not (debug and debug.getupvalue) then return false end
  if type(TileRenderer.tick) ~= "function" then return false end
  for i = 1, 32 do
    local ok, name, value = pcall(debug.getupvalue, TileRenderer.tick, i)
    if not (ok and name) then break end
    if name == "animFrame" and type(value) == "number" then return i end
  end
  return false
end

local function animFrame()
  if TileRenderer.animFrame then
    local ok, f = pcall(TileRenderer.animFrame)
    if ok and type(f) == "number" then return f end
  end
  if clockUpvalue == nil then clockUpvalue = findClockUpvalue() end
  if clockUpvalue then
    local ok, _, value = pcall(debug.getupvalue, TileRenderer.tick, clockUpvalue)
    if ok and type(value) == "number" then return value end
  end
  if love.timer and love.timer.getTime then
    return math.floor(love.timer.getTime() * 60)
  end
  return 0
end

return { animFrame = animFrame }
