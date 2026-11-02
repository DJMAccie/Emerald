-- Voxel world mode

local V = ...
local TiltShift = {}

TiltShift.level = 0
TiltShift.LABELS = { "OFF", "1", "2", "3" }

TiltShift.FOCUS_Y = 0.5
TiltShift.focusY = TiltShift.FOCUS_Y
TiltShift.PRESETS = {
  [1] = { spacing = 0.0016, band = 0.25, range = 0.25, saturation = 1.06 },
  [2] = { spacing = 0.0028, band = 0.25, range = 0.25, saturation = 1.10 },
  [3] = { spacing = 0.0042, band = 0.25, range = 0.25, saturation = 1.14 },
}

local SHADER = [[
  uniform vec2 dir;        // one texel step along the axis being blurred
  uniform float focusY;
  uniform float band;
  uniform float range;
  uniform float spacing;   // gap between taps at full blur, in texels
  uniform float boost;     // 0 = plain blur pass, 1 = final pass (color pop)
  uniform float saturation;
  vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    float d = abs(tc.y - focusY) - band;
    float s = clamp(d / range, 0.0, 1.0);
    s = s * s;             // ease in, so the band edge has no visible seam
    // 9 taps a small step apart: dense enough that even the strongest
    // preset blurs smoothly instead of ghosting into streaks
    vec2 o = dir * (s * spacing);
    vec4 sum = Texel(tex, tc) * 0.2270270270;
    sum += (Texel(tex, tc + o) + Texel(tex, tc - o)) * 0.1945945946;
    sum += (Texel(tex, tc + 2.0 * o) + Texel(tex, tc - 2.0 * o)) * 0.1216216216;
    sum += (Texel(tex, tc + 3.0 * o) + Texel(tex, tc - 3.0 * o)) * 0.0540540541;
    sum += (Texel(tex, tc + 4.0 * o) + Texel(tex, tc - 4.0 * o)) * 0.0162162162;
    if (boost > 0.5) {
      float luma = dot(sum.rgb, vec3(0.299, 0.587, 0.114));
      sum.rgb = mix(vec3(luma), sum.rgb, saturation);
    }
    return sum * color;
  }
]]

local shader = nil -- nil = untried, false = unavailable
local ping, pong, cw, ch = nil, nil, 0, 0

local function getShader()
  if shader == nil then
    local ok, sh = pcall(function() return love.graphics.newShader(SHADER) end)
    shader = (ok and sh) or false
  end
  return shader or nil
end

local function getCanvases(w, h)
  if not ping or cw ~= w or ch ~= h then
    local PixelCanvas = V.require("PixelCanvas")
    local ok, a = PixelCanvas.new(w, h)
    if not ok then return nil end
    local okB, b = PixelCanvas.new(w, h)
    if not okB then return nil end
    a:setFilter("linear", "linear")
    b:setFilter("linear", "linear")
    ping, pong, cw, ch = a, b, w, h
  end
  return ping, pong
end

function TiltShift.setFocus(y)
  y = tonumber(y) or TiltShift.FOCUS_Y
  TiltShift.focusY = math.max(0.2, math.min(0.8, y))
end

function TiltShift.setLevel(level)
  level = math.floor(tonumber(level) or 0)
  if level < 0 then level = 0 end
  if level > 3 then level = 3 end
  TiltShift.level = level
end

function TiltShift.apply(canvas)
  local preset = TiltShift.PRESETS[TiltShift.level]
  if not (preset and canvas) then return canvas end
  local sh = getShader()
  if not sh then return canvas end
  local w, h = canvas:getDimensions()
  local a, b = getCanvases(w, h)
  if not a then return canvas end

  local spacing = math.max(0.75, math.min(3, h * preset.spacing))
  local prevBlend, prevAlpha = love.graphics.getBlendMode()

  canvas:setFilter("linear", "linear")
  love.graphics.setShader(sh)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setBlendMode("replace", "premultiplied")
  pcall(sh.send, sh, "focusY", TiltShift.focusY)
  pcall(sh.send, sh, "band", preset.band)
  pcall(sh.send, sh, "range", preset.range)
  pcall(sh.send, sh, "spacing", spacing)
  pcall(sh.send, sh, "saturation", preset.saturation)

  local ok = pcall(function()
    love.graphics.setCanvas(a)
    pcall(sh.send, sh, "dir", { 1 / w, 0 })
    pcall(sh.send, sh, "boost", 0)
    love.graphics.draw(canvas)
    love.graphics.setCanvas(b)
    pcall(sh.send, sh, "dir", { 0, 1 / h })
    pcall(sh.send, sh, "boost", 1)
    love.graphics.draw(a)
  end)

  love.graphics.setCanvas()
  love.graphics.setShader()
  love.graphics.setBlendMode(prevBlend or "alpha", prevAlpha)
  canvas:setFilter("nearest", "nearest")
  return ok and b or canvas
end

function TiltShift.invalidate()
  ping, pong, cw, ch = nil, nil, 0, 0
end

return TiltShift
