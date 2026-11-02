-- Voxel world mode

local V = ...

local ModSetting = V.require("ModSetting")

local AntiAlias = {}
local Upscale=V.require('SpatialUpscale')

AntiAlias.KEY = "aa"
AntiAlias.LABEL = "AA"

AntiAlias.setting = ModSetting.new(AntiAlias.KEY, AntiAlias.LABEL,
                                   { 0, 2, 4 }, { "OFF", "2X", "4X" })

local live = 1

function AntiAlias.samples()
  return tonumber(AntiAlias.setting:get()) or 0
end

local function wanted()
  local n = AntiAlias.samples()
  if n <= 1 then return 1 end
  return math.sqrt(n)
end

local function textureLimit()
  if not (love.graphics and love.graphics.getSystemLimits) then return nil end
  local ok, limits = pcall(love.graphics.getSystemLimits)
  return (ok and limits and limits.texturesize) or nil
end

function AntiAlias.expand(w, h)
  local up=Upscale.factor()
  if up>1 then
    local ew,eh=math.max(1,math.floor(w/up+.5)),math.max(1,math.floor(h/up+.5))
    live=ew/math.max(1,w);return ew,eh
  end
  local s = wanted()
  local max = textureLimit()
  if max and max > 0 then
    s = math.min(s, max / math.max(1, w), max / math.max(1, h))
  end
  if not (s > 1.01) then
    live = 1
    return w, h
  end
  local ew, eh = math.floor(w * s + 0.5), math.floor(h * s + 0.5)
  live = ew / math.max(1, w)
  return ew, eh
end

function AntiAlias.factor()
  return live
end

local targets = {}

local function targetFor(slot, w, h)
  local t = targets[slot]
  if not (t and t.w == w and t.h == h) then
    local ok, c = pcall(love.graphics.newCanvas, w, h)
    if not (ok and c) then return nil end
    pcall(c.setFilter, c, "nearest", "nearest")
    if t and t.canvas and t.canvas.release then pcall(t.canvas.release, t.canvas) end
    t = { canvas = c, w = w, h = h }
    targets[slot] = t
  end
  return t.canvas
end

local SHADER = [[
  uniform vec2 tap;        // half a SOURCE texel, in uv
  vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec4 a = Texel(tex, tc + vec2(-tap.x, -tap.y));
    vec4 b = Texel(tex, tc + vec2( tap.x, -tap.y));
    vec4 c = Texel(tex, tc + vec2(-tap.x,  tap.y));
    vec4 d = Texel(tex, tc + vec2( tap.x,  tap.y));
    float al = (a.a + b.a + c.a + d.a) * 0.25;
    if (al <= 0.0) return vec4(0.0);
    vec3 sum = a.rgb * a.a + b.rgb * b.a + c.rgb * c.a + d.rgb * d.a;
    return vec4(sum * 0.25 / al, al) * color;
  }
]]

local shader = nil -- nil = untried, false = unavailable

local function getShader()
  if shader == nil then
    local ok, sh = pcall(love.graphics.newShader, SHADER)
    shader = (ok and sh) or false
  end
  return shader or nil
end

function AntiAlias.resolve(canvas, w, h, slot)
  if not canvas then return canvas end
  local ok, cw, ch = pcall(canvas.getDimensions, canvas)
  if not ok or (cw == w and ch == h) then return canvas end
  if cw<w or ch<h then return Upscale.resolve(canvas,w,h,slot)end
  local target = targetFor(slot or "world", w, h)
  if not target then return canvas end

  local sh = getShader()
  local prevBlend, prevAlpha = love.graphics.getBlendMode()
  pcall(canvas.setFilter, canvas, "linear", "linear")
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setBlendMode("replace", "premultiplied")
  if sh then
    love.graphics.setShader(sh)
    pcall(sh.send, sh, "tap", { 0.5 / cw, 0.5 / ch })
  end
  local drew = pcall(function()
    love.graphics.setCanvas(target)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.draw(canvas, 0, 0, 0, w / cw, h / ch)
  end)
  love.graphics.setCanvas()
  love.graphics.setShader()
  love.graphics.setBlendMode(prevBlend or "alpha", prevAlpha)
  pcall(canvas.setFilter, canvas, "nearest", "nearest")
  return drew and target or canvas
end

function AntiAlias.invalidate()
  Upscale.invalidate()
  for slot, t in pairs(targets) do
    if t.canvas and t.canvas.release then pcall(t.canvas.release, t.canvas) end
    targets[slot] = nil
  end
end

return AntiAlias
