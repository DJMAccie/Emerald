-- The sky, generated rather than shipped

local V = ...

local DayNight = V.require("DayNight")
local CommunityVisuals = V.require("CommunityVisuals")
local PaletteFX = require("src.render.PaletteFX")

local Sky = {}

Sky.MAX_BANDS = 8

Sky.DITHER = false
Sky.DITHER_START = 1.0
Sky.DITHER_CELL_SCALE = 1.0
Sky.DITHER_BLEND = 0.0

Sky.SPAN = 0.30

Sky.ELEV_SPAN = math.rad(62)

local cache = { bands = nil, key = {}, ramp = nil }

function Sky.bands()
  local pal = DayNight.palette()
  local shades = PaletteFX.effectiveColors(pal) or pal
  local nightWeight = 0
  if CommunityVisuals.customSky() then
    local mix = DayNight.mix(DayNight.time())
    nightWeight = math.min(1, (mix.night or 0) + (mix.violet or 0) * 0.65)
  end
  local adjusted = {}
  local nightScale = { 0.45, 0.52, 0.66 }
  for i, c in ipairs(shades) do
    adjusted[i] = {}
    for ch = 1, 3 do
      local scale = 1 - nightWeight + nightWeight * nightScale[ch]
      adjusted[i][ch] = math.floor(c[ch] * scale / 8 + 0.5) * 8
    end
  end
  shades = adjusted
  local n = math.min(#shades, #pal, Sky.MAX_BANDS)
  local key, k = cache.key, 0
  local same = cache.bands ~= nil and #cache.bands == n
  for i = 1, n do
    local c = shades[i]
    for ch = 1, 3 do
      k = k + 1
      if key[k] ~= c[ch] then same = false end
      key[k] = c[ch]
    end
  end
  if same then return cache.bands end

  if cache.ramp and cache.ramp.release then pcall(cache.ramp.release, cache.ramp) end
  cache.ramp, cache.rampFor = nil, nil

  local bands = {}
  for i = 1, n do
    local c = shades[n - i + 1]
    bands[i] = { c[1] / 255, c[2] / 255, c[3] / 255 }
  end
  cache.bands = bands
  return bands
end

function Sky.dress(sky)
  local bands = Sky.bands()
  local haze = bands and bands[#bands]
  if not (sky and haze) then return sky end
  sky[1], sky[2], sky[3] = haze[1], haze[2], haze[3]
  sky.bands = bands
  return sky
end

function Sky.region(h, horizonY)
  if not (h and h > 0) then return nil end
  local edge = horizonY
  if not (edge and edge > 0) then edge = h * Sky.SPAN end
  edge = math.min(edge, h)
  if edge < 1 then return nil end
  return edge
end

local SHADER_SRC = [[
uniform Image ramp;     // the bands, one texel each, top of the sky first
uniform float count;    // how many texels wide that ramp is
uniform float edge;     // the sky's bottom, in canvas pixels
uniform float top;      // where the deepest band begins, in canvas pixels --
                        // 0 glues the gradient to the frame (the flat
                        // screen); an anchored caller passes the row its
                        // fixed elevation span starts on, often negative
uniform float cell;     // the diorama's pixel size, in canvas pixels
uniform float start;    // where the checker begins inside a band
uniform float ditherBlend; // strength of the adjacent-band checker colour
uniform float axisX;    // the "toward the ground" direction on the canvas:
uniform float axisY;    // (0,1) for a level camera; a rolled VR eye tips
                        // it, and edge/top are distances along it
uniform vec3 rayBase;   // the eye's ray fan (VRRig eyeCamera.skyRay): a
uniform vec3 rayDu;     // canvas point at fractions (u, v) looks along
uniform vec3 rayDv;     // base + u*du + v*dv, world axes -- so each pixel
                        // knows its TRUE elevation and the gradient is a
                        // real skybox, untouched by any head motion
uniform float raySpan;  // radians of elevation the gradient covers
uniform vec2 invSize;   // 1/w, 1/h: canvas pixels to fractions
uniform float useRay;   // 0 = the flat screen's frame-linear gradient
uniform float cellAng;  // one checker cell in RADIANS (ray path): the
                        // dither's own grid, laid on azimuth/elevation so
                        // the pattern is glued to the SKY -- a screen-cell
                        // parity flips under every head motion and the
                        // whole gradient shimmers
uniform float alpha;
uniform float glowAmt;  // twilight warmth around the low sun; 0 = none
uniform vec2 glowPos;   // the sun disc, in canvas pixels (flat path)
uniform float glowInvR; // 1 / the glow's reach in pixels (flat path)
uniform vec3 glowDir;   // the sun's world direction (ray path)
uniform vec2 weatherAtmosphere;
uniform float glowInvA; // 1 / the glow's reach in radians (ray path)
uniform vec3 glowColor;

// Band `i`, read from its own texel centre. The index is clamped rather than
// trusted: `pos` below can land exactly on `count` when the arithmetic is
// carried at mediump -- which is the fragment default on GLSL ES -- and a
// sample past the last band must be the last band, not whatever is off the
// end of the image.
vec3 bandAt(float i) {
  return Texel(ramp, vec2((clamp(i, 0.0, count - 1.0) + 0.5) / count, 0.5)).rgb;
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
  float tn;
  float glowD = 2.0;                                  // past the reach
  if (useRay > 0.5) {
    // Clean world-anchored sky: use the pixel's true ray elevation directly.
    // No angular cell snapping, checker parity, or block quantisation.
    vec3 dir = normalize(rayBase + rayDu * (sc.x * invSize.x)
                                  + rayDv * (sc.y * invSize.y));
    float elev = atan(dir.y, length(dir.xz));
    if (elev < 0.0) { discard; }                      // below the horizon
    tn = 1.0 - clamp(elev / max(raySpan, 0.001), 0.0, 1.0);
    if (glowAmt > 0.0) {
      glowD = acos(clamp(dot(dir, glowDir), -1.0, 1.0)) * glowInvA;
    }
  } else {
    // Clean flat-screen path: sample the true pixel row instead of snapping
    // to the diorama pixel grid. This removes the rectangles visible through
    // clouds from the separate weather mod.
    float row = sc.x * axisX + sc.y * axisY;
    if (row > edge) { discard; }                      // below the horizon
    tn = clamp((row - top) / max(edge - top, 1.0), 0.0, 1.0);
    if (glowAmt > 0.0) {
      glowD = length(sc - glowPos) * glowInvR;
    }
  }

  // Smoothly interpolate across the existing day/night palette. The palette
  // itself is unchanged; only the visible stepping/checker pattern is removed.
  float pos = tn * max(count - 1.0, 0.0);
  float base = min(floor(pos), count - 1.0);
  float fracBand = fract(pos);
  vec3 c = bandAt(base);
  if (base < count - 1.0) {
    c = mix(c, bandAt(base + 1.0), fracBand);
  }

  // Keep the existing twilight color, but make the atmospheric glow smooth too.
  if (glowAmt > 0.0) {
    float g = glowAmt * pow(clamp(1.0 - glowD, 0.0, 1.0), 2.0);
    c = mix(c, glowColor, clamp(g, 0.0, 1.0) * 0.65);
  }
  c = clamp(c * (1.0-weatherAtmosphere.x) + vec3(0.70,0.80,1.0)*weatherAtmosphere.y, 0.0, 1.0);
  return vec4(c, alpha);
}
]]

local function rampFor(bands)
  if cache.ramp and cache.rampFor == bands then return cache.ramp end
  if not (love.image and love.image.newImageData
          and love.graphics and love.graphics.newImage) then return nil end
  local n = #bands
  if n < 1 then return nil end
  local ok, data = pcall(love.image.newImageData, n, 1)
  if not (ok and data) then return nil end
  for i = 1, n do
    local c = bands[i]
    pcall(data.setPixel, data, i - 1, 0, c[1], c[2], c[3], 1)
  end
  local built, img = pcall(love.graphics.newImage, data)
  if not (built and img) then return nil end
  pcall(img.setFilter, img, "nearest", "nearest")
  pcall(img.setWrap, img, "clamp", "clamp")
  cache.ramp, cache.rampFor = img, bands
  return img
end

Sky._rampFor = rampFor -- named for the suite

function Sky.ramp()
  local bands = Sky.bands()
  if not (bands and bands[1]) then return nil end
  local img = rampFor(bands)
  if not img then return nil end
  return img, #bands, bands
end

Sky.GLOW_REACH = 0.64

local shader = nil -- nil = untried, false = unavailable

Sky._source = function() return SHADER_SRC end -- named for the suite

local function getShader()
  if shader == nil then
    shader = false
    if love.graphics and love.graphics.newShader then
      local ok, sh = pcall(love.graphics.newShader, SHADER_SRC)
      if ok and sh then
        shader = sh
      else
        local msg = ("sky shader did not compile: %s -- the bands draw flat, "
                     .. "with no dither between them"):format(tostring(sh))
        if V and V.log then V.log:warn("%s", msg)
        elseif V and V.dlog then V.dlog(msg)
        elseif V and V.mod and V.mod.log then V.mod.log:warn("%s", msg) end
      end
    end
  end
  return shader or nil
end

Sky._getShader = getShader -- named for the suite

local function paintFlat(w, h, bands, edge, alpha, cell, top)
  local g = love.graphics
  local n = #bands
  if n < 1 then return end
  local y0 = top or 0
  local y1 = math.min(h, math.ceil(edge))
  local span = math.max(1, edge - y0)
  local steps = math.max(128, math.min(720, math.floor(span)))
  local prev = 0
  for j = 0, steps - 1 do
    local a0 = j / steps
    local a1 = (j + 1) / steps
    local ya = math.max(0, math.floor(y0 + a0 * span + 0.5))
    local yb = math.min(y1, math.floor(y0 + a1 * span + 0.5))
    ya = math.max(prev, ya)
    if yb > ya then
      local pos = a0 * math.max(n - 1, 0)
      local bi = math.min(n, math.floor(pos) + 1)
      local bj = math.min(n, bi + 1)
      local f = pos - math.floor(pos)
      local c0, c1 = bands[bi], bands[bj]
      local r = c0[1] + (c1[1] - c0[1]) * f
      local gg = c0[2] + (c1[2] - c0[2]) * f
      local b = c0[3] + (c1[3] - c0[3]) * f
      g.setColor(r, gg, b, alpha)
      g.rectangle("fill", 0, ya, w, yb - ya)
      prev = yb
    end
  end
end

Sky.DISC_FRAC = 0.030 -- disc radius, as a fraction of the frame height
Sky.DISC_MIN = 3 -- but never fewer cells than this across a radius

Sky.MOON_CRATERS = { { -0.4, -0.2 }, { 0.2, 0.45 }, { 0.5, -0.4 },
                     { -0.15, 0.7 }, { 0.05, 0.05 } }

Sky.CRATER_FRAC = 0.2

local MOON_CRATERS = Sky.MOON_CRATERS

function Sky.discShades(moon)
  local src = moon and DayNight.MOON_COLORS or DayNight.SUN_COLORS
  return PaletteFX.effectiveColors(src) or src
end

local function looming(body)
  return (body.glowAmt or 0) > 0.25 and not body.moon
end

function Sky.discRadius(h, cell, body)
  cell = math.max(1, cell or 1)
  local r = math.max(Sky.DISC_MIN,
                     math.floor(h * Sky.DISC_FRAC / cell + 0.5))
  if body and looming(body) then r = r + math.max(1, math.floor(r * 0.4)) end
  return r * cell, r
end

local function discCells(r, moon, shades, twilight, plot)
  local core = shades[1]
  local main = shades[twilight and 3 or 2]
  local craterR = math.max(1, math.floor(r / 5))
  for dy = -r, r do
    for dx = -r, r do
      local d = math.sqrt(dx * dx + dy * dy)
      if d <= r + 0.1 then
        local c = d <= r * 0.5 and core or main
        local keep = d <= r - 0.9 or (dx + dy) % 2 == 0
        if moon then
          for _, cr in ipairs(MOON_CRATERS) do
            local cdx = dx - math.floor(cr[1] * r + 0.5)
            local cdy = dy - math.floor(cr[2] * r + 0.5)
            if cdx * cdx + cdy * cdy <= craterR * craterR then
              c = shades[3]
            end
          end
        end
        if keep then plot(dx, dy, c) end
      end
    end
  end
end

local function paintDisc(body, edge, cell, w, h)
  local g = love.graphics
  if not (body and body.y and g.setScissor) then return end
  local shades = Sky.discShades(body.moon)
  local twilight = looming(body)
  local _, r = Sky.discRadius(h, cell, body)
  local bx = math.floor(body.x / cell) * cell + cell / 2
  local by = math.floor(body.y / cell) * cell + cell / 2
  if by - r * cell > edge then return end -- wholly below the horizon point
  local sx, sy, sw, sh = g.getScissor()
  g.setScissor(0, 0, math.ceil(w), math.floor(edge))
  discCells(r, body.moon, shades, twilight, function(dx, dy, c)
    g.setColor(c[1] / 255, c[2] / 255, c[3] / 255, 1)
    g.rectangle("fill", bx + dx * cell - cell / 2,
                by + dy * cell - cell / 2, cell, cell)
  end)
  if sx then g.setScissor(sx, sy, sw, sh) else g.setScissor() end
  g.setColor(1, 1, 1, 1)
end

local deferredBody, fallbackDiscShader
local function celestialTarget() local c=love.graphics.getCanvas();while type(c)=='table' do c=c[1] or c.canvas end;return c end
Sky.nativeCelestialReplaced = false
function Sky.resetDeferredBody()
  deferredBody=nil;Sky.nativeCelestialReplaced=false;Sky.allowDeferredBody=false
end
local function deferBody(body,edge,cell,w,h)
  if not body or not Sky.allowDeferredBody or not(V.companion and V.companion.canReplaceCelestials and V.companion:canReplaceCelestials())then return false end
  if not fallbackDiscShader then
    local ok,sh=pcall(love.graphics.newShader,[[
#ifdef VERTEX
vec4 position(mat4 m,vec4 v){vec4 c=m*v;c.z=c.w*0.99999;return c;}
#endif
#ifdef PIXEL
vec4 effect(vec4 c,Image t,vec2 uv,vec2 px){return c*Texel(t,uv);}
#endif
]])
    if not ok then return false end;fallbackDiscShader=sh
  end
  local b={};for k,v in pairs(body)do b[k]=v end
  deferredBody={body=b,edge=edge,cell=cell,w=w,h=h,canvas=celestialTarget()};return true
end

local discBake = { key = nil, img = nil }

Sky.DISC_BAKE_R = 9 -- bake radius, in cells
Sky.DISC_BAKE_PX = 8 -- texture pixels per cell

function Sky.paint(w, h, sky, horizonY, cell, body, top, axis, ray)
  local bands = sky and sky.bands
  if not (bands and bands[1]) then return false end
  if not (w and h and w > 0 and h > 0) then return false end
  local g = love.graphics
  if not (g and g.rectangle) then return false end
  local edge
  if ray then
    edge = h
  elseif axis then
    edge = horizonY
  else
    edge = Sky.region(h, horizonY)
  end
  if not edge then return false end
  local alpha = sky[4] or 1
  cell = math.max(1, math.floor((cell or 1) + 0.5))
  local skyCell = cell

  local prevShader = g.getShader and g.getShader() or nil
  local cmp, write
  if g.getDepthMode then cmp, write = g.getDepthMode() end
  if g.setDepthMode then g.setDepthMode("always", false) end
  local blend, blendAlpha
  if g.getBlendMode then blend, blendAlpha = g.getBlendMode() end
  if g.setBlendMode then g.setBlendMode("alpha") end

  local glowAmt = body and not body.moon and (body.glowAmt or 0) or 0
  if ray and glowAmt > 0 and not (body and body.dx) then glowAmt = 0 end
  local function rayDirAt(u, v)
    local b, du, dv = ray.base, ray.du, ray.dv
    local x = b[1] + du[1] * u + dv[1] * v
    local y = b[2] + du[2] * u + dv[2] * v
    local z = b[3] + du[3] * u + dv[3] * v
    local l = math.sqrt(x * x + y * y + z * z)
    if l < 1e-9 then return 0, 0, -1 end
    return x / l, y / l, z / l
  end
  local function rayAngle(u0, v0, u1, v1)
    local ax, ay, az = rayDirAt(u0, v0)
    local bx, by, bz = rayDirAt(u1, v1)
    local d = ax * bx + ay * by + az * bz
    return math.acos(math.max(-1, math.min(1, d)))
  end
  local weather = V.companion and V.companion.atmosphereSnapshot and V.companion:atmosphereSnapshot() or {}
  local sh = getShader()
  local function send(name,...)
    if weather.sky and sh.hasUniform and not sh:hasUniform(name)then return end
    return sh:send(name,...)
  end
  local ramp = sh and rampFor(bands)
  if not ramp then sh = nil end -- no ramp, no gradient: paint it flat
  if sh then
    local sent = pcall(function()
      send("ramp", ramp)
      send("count", #bands)
      send("edge", edge)
      send("top", math.min(top or 0, edge - 1))
      send("axisX", axis and axis[1] or 0)
      send("axisY", axis and axis[2] or 1)
      send("useRay", ray and 1 or 0)
      if ray then
        send("rayBase", ray.base)
        send("rayDu", ray.du)
        send("rayDv", ray.dv)
        send("raySpan", Sky.ELEV_SPAN)
        send("invSize", { 1 / w, 1 / h })
        send("cellAng",
                math.max(1e-4, rayAngle(0.5, 0, 0.5, 1) * skyCell / h))
      end
      send("cell", skyCell)
      send("start", Sky.DITHER and Sky.DITHER_START or 2)
      send("ditherBlend", Sky.DITHER_BLEND)
      send("alpha", alpha)
      send("weatherAtmosphere", {weather.sky and weather.sky.dim or 0, weather.sky and weather.sky.flash or 0})
      send("glowAmt", glowAmt)
      if glowAmt > 0 then
        local gc = body.glowColor or { 248, 224, 168 }
        if ray then
          local dx, dy, dz = body.dx, body.dy, body.dz
          local l = math.sqrt(dx * dx + dy * dy + dz * dz)
          send("glowDir", { dx / l, dy / l, dz / l })
          send("glowInvA", 1 / math.max(
            1e-3, rayAngle(0, 0.5, 1, 0.5) * Sky.GLOW_REACH))
        else
          send("glowPos", { body.x, body.y })
          send("glowInvR", 1 / math.max(1, w * Sky.GLOW_REACH))
        end
        send("glowColor", { gc[1] / 255, gc[2] / 255, gc[3] / 255 })
      end
    end)
    if sent then
      g.setShader(sh)
      g.setColor(1, 1, 1, 1)
      local rectH = (axis or ray) and h or math.min(h, math.ceil(edge))
      g.rectangle("fill", 0, 0, w, rectH)
      g.setShader()
    else
      sh = nil
    end
  end
  if not sh then
    if weather.sky then
      local adjusted={}
      for i,c in ipairs(bands)do
        adjusted[i]={}
        for k,f in ipairs({.70,.80,1})do adjusted[i][k]=math.max(0,math.min(1,c[k]*(1-(weather.sky.dim or 0))+f*(weather.sky.flash or 0)))end
      end
      bands=adjusted
    end
    paintFlat(w, h, bands, (axis or ray) and math.min(h, edge) or edge,
              alpha, cell, math.min(top or 0, edge - 1))
  end
  if not (axis or ray) then
    if not deferBody(body, math.min(h, edge), cell, w, h) then paintDisc(body, math.min(h, edge), cell, w, h) end
  end
  g.setColor(1, 1, 1, 1)

  if g.setBlendMode and blend then g.setBlendMode(blend, blendAlpha) end
  if g.setDepthMode then g.setDepthMode(cmp or "always", write or false) end
  if prevShader and g.setShader then g.setShader(prevShader) end
  return true
end

function Sky.invalidate()
  Sky.resetDeferredBody()
  if fallbackDiscShader then fallbackDiscShader:release();fallbackDiscShader=nil end
  shader = nil
  if cache.ramp and cache.ramp.release then pcall(cache.ramp.release, cache.ramp) end
  cache.ramp, cache.rampFor = nil, nil
  if discBake.img and discBake.img.release then
    pcall(discBake.img.release, discBake.img)
  end
  discBake.key, discBake.img = nil, nil
end

return Sky
