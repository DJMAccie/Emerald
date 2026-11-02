-- Voxel world mode

local V = ...


local DayNight = {}

DayNight.CYCLE = 1200 -- seconds around the whole dial
DayNight.DAY_LEN = 600 -- the sun's half; the moon has the rest
DayNight.BLEND = 75 -- seconds of palette blend either side of a twilight

-- the sun's position in the cycle at noon
DayNight.T = { day = 300 }

local NOON_KX, NOON_KZ = -0.85, -0.55
local TH_NOON = math.deg(math.atan2(-NOON_KZ, -NOON_KX))
local EL_NOON = math.deg(math.atan(1 / math.sqrt(NOON_KX * NOON_KX
                                                 + NOON_KZ * NOON_KZ)))

local TH_RISE, TH_SET = -70, 250 -- north of east / north of west
local TH_MRISE, TH_MMID, TH_MSET = -20, -90, -160
local EL_MOON = 40

DayNight.K_MAX = 2.0 -- shear clamp: a shadow at most twice its height
DayNight.ALPHA_SUN = 0.40 -- the existing midday shadow weight
DayNight.ALPHA_MOON = 0.26 -- moonlight is a softer press
DayNight.FADE_DEG = 12

DayNight.ELEV_SQUASH = 0.14

local function arc(a, b, c, s)
  if s < 0.5 then return a + (b - a) * 2 * s end
  return b + (c - b) * (2 * s - 1)
end

function DayNight.bodyAt(t)
  t = t % DayNight.CYCLE
  if t <= DayNight.DAY_LEN then
    local s = t / DayNight.DAY_LEN
    return arc(TH_RISE, TH_NOON, TH_SET, s),
           EL_NOON * math.sin(math.pi * s), false
  end
  local s = (t - DayNight.DAY_LEN) / (DayNight.CYCLE - DayNight.DAY_LEN)
  return arc(TH_MRISE, TH_MMID, TH_MSET, s),
         EL_MOON * math.sin(math.pi * s), true
end

function DayNight.shearAt(t)
  local th, el, moon = DayNight.bodyAt(t)
  if el < 0.5 then el = 0.5 end
  local k = math.min(DayNight.K_MAX, 1 / math.tan(math.rad(el)))
  return -math.cos(math.rad(th)) * k, -math.sin(math.rad(th)) * k, moon
end

function DayNight.strengthAt(t)
  local _, el = DayNight.bodyAt(t)
  local s = el / DayNight.FADE_DEG
  if s < 0 then return 0 end
  return s < 1 and s or 1
end

DayNight.PALETTES = {
  day = { { 184, 216, 248 }, { 144, 192, 248 }, { 104, 160, 240 },
          { 72, 128, 224 }, { 48, 96, 200 }, { 40, 72, 168 } },
  golden = { { 248, 216, 144 }, { 232, 184, 136 }, { 176, 152, 168 },
             { 120, 128, 192 }, { 80, 104, 184 }, { 56, 80, 152 } },
  dawn = { { 248, 216, 152 }, { 248, 176, 136 }, { 232, 136, 144 },
           { 176, 104, 168 }, { 112, 80, 168 }, { 64, 64, 136 } },
  dusk = { { 248, 200, 112 }, { 248, 152, 96 }, { 232, 104, 96 },
           { 184, 80, 136 }, { 120, 64, 152 }, { 56, 48, 120 } },
  violet = { { 200, 136, 160 }, { 152, 104, 160 }, { 112, 80, 152 },
             { 72, 56, 128 }, { 40, 40, 96 }, { 16, 24, 64 } },
  night = { { 88, 104, 160 }, { 64, 80, 136 }, { 48, 56, 112 },
            { 32, 40, 88 }, { 16, 24, 64 }, { 8, 8, 40 } },
}

-- what the world's own colours are multiplied by, per phase (0..255)
DayNight.TINTS = {
  day = { 255, 255, 255 },
  golden = { 255, 232, 208 },
  dawn = { 255, 216, 192 },
  dusk = { 255, 192, 168 },
  violet = { 184, 160, 200 },
  night = { 72, 84, 124 },
}

DayNight.GLOWS = { dawn = { 248, 232, 176 }, dusk = { 248, 224, 168 } }
DayNight.SUN_COLORS = { { 248, 240, 200 }, { 248, 208, 96 },
                        { 248, 144, 80 }, { 216, 96, 64 } }
DayNight.MOON_COLORS = { { 240, 244, 248 }, { 224, 232, 240 },
                         { 168, 184, 208 }, { 120, 136, 168 } }

local DIAL
local function dial()
  if DIAL then return DIAL end
  local B, D, C = DayNight.BLEND, DayNight.DAY_LEN, DayNight.CYCLE
  DIAL = {
    { 0, "dawn" }, { B, "day" },
    { D - 2 * B, "day" }, { D - B, "golden" }, { D, "dusk" },
    { D + B / 2, "violet" }, { D + B, "night" },
    { C - B, "night" }, { C - B / 2, "violet" }, { C, "dawn" },
  }
  return DIAL
end

function DayNight.mix(t)
  t = t % DayNight.CYCLE
  local d = dial()
  for i = 1, #d - 1 do
    local a, b = d[i], d[i + 1]
    if t >= a[1] and t < b[1] then
      if a[2] == b[2] then return { [a[2]] = 1 } end
      local u = (t - a[1]) / (b[1] - a[1])
      return { [a[2]] = 1 - u, [b[2]] = u }
    end
  end
  return { dawn = 1 }
end

local function q8(v)
  v = math.floor(v / 8 + 0.5) * 8
  if v < 0 then return 0 end
  return v > 248 and 248 or v
end

local function blend3(key, mix, fallback)
  local r, g, b = 0, 0, 0
  for name, w in pairs(mix) do
    local c = key[name] or fallback
    r = r + c[1] * w
    g = g + c[2] * w
    b = b + c[3] * w
  end
  return { q8(r), q8(g), q8(b) }
end

local palCache = { key = nil, pal = nil }

function DayNight.palette(t)
  t = t or DayNight.time()
  local key = math.floor(t % DayNight.CYCLE)
  if palCache.key == key then return palCache.pal end
  local mix = DayNight.mix(t)
  local pal = {}
  for i = 1, #DayNight.PALETTES.day do
    local r, g, b = 0, 0, 0
    for name, w in pairs(mix) do
      local c = DayNight.PALETTES[name][i]
      r = r + c[1] * w
      g = g + c[2] * w
      b = b + c[3] * w
    end
    pal[i] = { q8(r), q8(g), q8(b) }
  end
  palCache.key, palCache.pal = key, pal
  return pal
end

local tintCache = { key = nil, tint = nil }
local NEUTRAL = { 1, 1, 1 }

function DayNight.tint(outdoor, t)
  if not outdoor then return NEUTRAL end
  t = t or DayNight.time()
  local key = math.floor(t % DayNight.CYCLE)
  if tintCache.key ~= key then
    local mix = DayNight.mix(t)
    local r, g, b = 0, 0, 0
    for name, w in pairs(mix) do
      local c = DayNight.TINTS[name] or DayNight.TINTS.day
      r = r + c[1] * w
      g = g + c[2] * w
      b = b + c[3] * w
    end
    tintCache.key = key
    tintCache.tint = { r / 255, g / 255, b / 255 }
  end
  return tintCache.tint
end

function DayNight.glow(t)
  t = t or DayNight.time()
  local _, _, moon = DayNight.bodyAt(t)
  if moon then return 0, nil end
  local mix = DayNight.mix(t)
  local amt = (mix.dawn or 0) + (mix.dusk or 0)
  if amt <= 0 then return 0, nil end
  return amt, blend3(DayNight.GLOWS, mix, DayNight.GLOWS.dusk)
end

function DayNight.hours()
  local d = os.date("*t")
  return d.hour + d.min / 60 + d.sec / 3600
end

function DayNight.syncTime()
  return ((DayNight.hours() - 6) * (DayNight.CYCLE / 24)) % DayNight.CYCLE
end

function DayNight.time()
  return DayNight.syncTime()
end

DayNight.STEP = 2

function DayNight.rigTime()
  local t = DayNight.time()
  return math.floor(t / DayNight.STEP) * DayNight.STEP
end

function DayNight.applyRig(outdoor)
  local ShadowMap = V.require("ShadowMap")
  local Voxel3D = V.require("Voxel3D")
  local t = outdoor and DayNight.rigTime() or DayNight.T.day
  local kx, kz, moon = DayNight.shearAt(t)
  ShadowMap.KX, ShadowMap.KZ = kx, kz
  Voxel3D.SHADOW_KX, Voxel3D.SHADOW_KZ = kx, kz
  local base = moon and DayNight.ALPHA_MOON or DayNight.ALPHA_SUN
  Voxel3D.SHADOW_ALPHA = base * DayNight.strengthAt(t)
  return t
end


function DayNight.body(t)
  t = t or DayNight.time()
  local th, el, moon = DayNight.bodyAt(t)
  if el < -2 then return nil end
  local e = math.rad(el * DayNight.ELEV_SQUASH)
  local b = math.rad(th)
  return {
    dx = math.cos(b) * math.cos(e),
    dy = math.sin(e),
    dz = math.sin(b) * math.cos(e),
    moon = moon,
  }
end

DayNight.CANOPY = { VIRIDIAN_FOREST = true, ILEX_FOREST = true }


local LAMPS = { night = 1, violet = 1, dusk = 0.9, dawn = 0.25 }

function DayNight.windowLight(t)
  local mix = DayNight.mix(t or DayNight.time())
  local lit = 0
  for name, w in pairs(mix) do
    lit = lit + (LAMPS[name] or 0) * w
  end
  return lit
end

return DayNight
