-- Voxel world mode

local V = ...

local Mat4 = V.require("Mat4")
local Voxel = V.require("VoxelState")
local Shadows = V.require("Shadows")

local ShadowMap = {}

-- Sun shear: shadows fall northwest (KX and KZ both negative).
ShadowMap.KX = -0.85 -- west drift per pixel of height
ShadowMap.KZ = -0.55 -- north drift per pixel of height

ShadowMap.SIZES = { 1024, 1536, 2048 }
ShadowMap.TARGET = 0.45
ShadowMap.res = 1024 -- the rung in use; read by the main pass's filter

ShadowMap.HEIGHT = 160

ShadowMap.BIAS = 0.5

ShadowMap.SLOPE = 3.1

ShadowMap.slack = ShadowMap.BIAS

local SHADER = [[
  varying float vDepth;
  varying vec2 roomPosition;
#ifdef VERTEX
]] .. V.require("CanopyBillboard").shader .. [[
  uniform vec3 canopyEye;
  uniform mat4 lightVP;
  uniform mat4 model;
  vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vertex_position=placedVertex(vertex_position);
    vec4 world = faceCanopy(model,vertex_position,canopyEye);
    roomPosition=world.xz;
    vec4 c = lightVP * world;
    // the projection is orthographic (w is 1) and fit() maps clip z onto
    // [0,1] directly (see Z01 there), so clip z IS the stored depth,
    // linear in world units along the sun line -- under every clip-range
    // convention a backend can bring
    vDepth = c.z;
    return c;
  }
#endif
#ifdef PIXEL
  uniform float roomCut;
  uniform vec4 roomBounds;
  uniform float sprite;   // 1 while the CAST is being drawn; see ShadowMap.sprites
  vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    if (roomCut>0.5 && (roomPosition.x<roomBounds.x+0.03 || roomPosition.y<roomBounds.y+0.03
      || roomPosition.x>roomBounds.z-0.03 || roomPosition.y>roomBounds.w-0.03)) discard;
    // the same alpha discard the main pass uses: a sprite card casts its
    // silhouette, not its 16x16 bounding box
    if (Texel(tex, tc).a < 0.5) discard;
    // pack into two channels: the high byte in red, the low in green.
    // Blue says WHAT cast this, which costs a channel that was zero anyway
    // and lets a surface decline one kind of caster -- water does, for the
    // people (see Water's sunLit).
    float d = clamp(vDepth, 0.0, 1.0) * 255.0;
    return vec4(floor(d) / 255.0, fract(d), sprite, 1.0);
  }
#endif
]]

ShadowMap._source = function() return SHADER end -- named for the suite

local shader = nil -- nil = untried, false = unavailable
local canvas = nil -- nil = untried, false = unavailable
local canvasRes = 0 -- the edge `canvas` was made at
local canvasAllocations = 0
local blank = nil -- 1x1 stand-in so the sampler is never unbound
local drawing = false
local ready = false
local lastSig = nil
local prevBlend, prevAlphaMode = nil, nil

local IDENTITY = Mat4.identity()

local function toUnit(vSign)
  return { 0.5, 0, 0, 0.5,
           0, 0.5 * vSign, 0, 0.5,
           0, 0, 1, 0,
           0, 0, 0, 1 }
end

-- Mat4.ortho emits GL z in [-1,1]; LOVE 12's sun pass keeps only [0,1], so remap.
local Z01 = { 1, 0, 0, 0,
              0, 1, 0, 0,
              0, 0, 0.5, 0.5,
              0, 0, 0, 1 }

local vSign = nil

ShadowMap.clipVP = IDENTITY
ShadowMap.uvVP = IDENTITY
ShadowMap.bias = 0

local function getShader()
  if shader == nil then
    local ok, sh = pcall(love.graphics.newShader, SHADER)
    shader = (ok and sh) or false
  end
  return shader or nil
end

local function getCanvas(res)
  if canvas == false then return nil end
  if canvas and canvasRes == res then return canvas end
  local ok, c = V.require("PixelCanvas").new(res, res)
  if not (ok and c) then
    canvas = false
    return nil
  end
  c:setFilter("nearest", "nearest")
  pcall(c.setWrap, c, "clamp", "clamp")
  if canvas and canvas.release then pcall(canvas.release, canvas) end
  canvas, canvasRes = c, res
  canvasAllocations = canvasAllocations + 1
  ready = false
  return canvas
end

local function getBlank()
  if blank == nil then
    local ok, img = pcall(function()
      local data = love.image.newImageData(1, 1)
      data:setPixel(0, 0, 1, 1, 1, 1)
      return love.graphics.newImage(data)
    end)
    blank = (ok and img) or false
  end
  return blank or nil
end

local function probeVSign()
  local done, sign = pcall(function()
    local sh = getShader()
    local tex = getBlank()
    if not (sh and tex) then return 1 end
    local c = love.graphics.newCanvas(4, 4, { dpiscale = 1 })
    local mesh = love.graphics.newMesh(
      { { -1, 0, 0, 0 }, { 1, 0, 1, 0 }, { 1, 1, 1, 1 }, { -1, 1, 0, 1 } },
      "fan", "static")
    mesh:setTexture(tex)
    love.graphics.setCanvas(c)
    love.graphics.clear(1, 1, 0, 1)
    love.graphics.setShader(sh)
    love.graphics.setColor(1, 1, 1, 1)
    pcall(sh.send, sh, "lightVP", "row",
          Mat4.mul(Z01, Mat4.scale(1, -1, 1)))
    pcall(sh.send, sh, "model", "row", IDENTITY)
    pcall(sh.send, sh, "sprite", 0)
    pcall(sh.send, sh, "roomCut", 0)
    love.graphics.draw(mesh)
    love.graphics.setShader()
    love.graphics.setCanvas()
    local data = c:newImageData()
    local w, h = data:getDimensions()
    local topR = data:getPixel(1, 0)
    local botR = data:getPixel(1, h - 1)
    if topR < 0.9 and botR > 0.9 then return 1 end
    if botR < 0.9 and topR > 0.9 then return -1 end
    return 1
  end)
  return (done and sign) or 1
end

-- Never nil: an unbound sampler crashes some drivers.
function ShadowMap.texture()
  if ready and canvas then return canvas end
  return getBlank()
end

function ShadowMap.active()
  if Shadows.off() then return false end
  return ready and canvas ~= nil and canvas ~= false
end

function ShadowMap.discard()
  ready, lastSig = false, nil
end

local function sunDir()
  local x, y, z = ShadowMap.KX, -1, ShadowMap.KZ
  local l = math.sqrt(x * x + y * y + z * z)
  return { x / l, y / l, z / l }
end

ShadowMap.sunDir = sunDir

ShadowMap.FAR_CAP = 2.5 -- multiples of the view height

local function groundReach(vh)
  local a = Voxel.angle or 0
  local cap = ShadowMap.FAR_CAP * vh
  local half = math.atan(1 / (2 * Voxel.FOCAL))
  local below = (math.pi / 2 - a) - half -- top ray, below horizontal
  if below <= 0.02 then return cap end
  local dist = Voxel.FOCAL * vh
  local horizon = dist * math.cos(a) / math.tan(below)
  return math.max(vh / 2, math.min(cap, horizon - dist * math.sin(a)))
end

local function fit(cx, cy, vw, vh)
  local f = sunDir()
  local view = Mat4.lookAt({ 0, 0, 0 }, f, { 0, 0, -1 })

  local reach = ShadowMap.HEIGHT
                * math.max(math.abs(ShadowMap.KX), math.abs(ShadowMap.KZ)) + 24
  local north = groundReach(vh)
  local spread = north * 0.5
  local xs = { cx - vw / 2 - spread, cx + vw / 2 + spread + reach }
  local ys = { -32, ShadowMap.HEIGHT } -- -32 covers recessed water
  local zs = { cy - north, cy + vh / 2 + reach }

  local l, r, b, t, zn, zf
  for _, x in ipairs(xs) do
    for _, y in ipairs(ys) do
      for _, z in ipairs(zs) do
        local px = view[1] * x + view[2] * y + view[3] * z + view[4]
        local py = view[5] * x + view[6] * y + view[7] * z + view[8]
        local pz = view[9] * x + view[10] * y + view[11] * z + view[12]
        l = l and math.min(l, px) or px
        r = r and math.max(r, px) or px
        b = b and math.min(b, py) or py
        t = t and math.max(t, py) or py
        zn = zn and math.min(zn, pz) or pz
        zf = zf and math.max(zf, pz) or pz
      end
    end
  end

  local w, h = r - l, t - b

  local res = ShadowMap.SIZES[#ShadowMap.SIZES]
  for _, size in ipairs(ShadowMap.SIZES) do
    if math.max(w, h) / size <= ShadowMap.TARGET then
      res = size
      break
    end
  end
  ShadowMap.res = res

  local tx, ty = w / res, h / res
  l = math.floor(l / tx) * tx
  b = math.floor(b / ty) * ty
  r, t = l + w, b + h

  local near, far = -zf - 64, -zn + 64
  local proj = Mat4.ortho(l, r, b, t, near, far)
  proj = Mat4.mul(Mat4.scale(1, -1, 1), proj)
  proj = Mat4.mul(Z01, proj)

  ShadowMap.clipVP = Mat4.mul(proj, view)
  ShadowMap.uvVP = Mat4.mul(toUnit(vSign or 1), ShadowMap.clipVP)
  ShadowMap.extent = { r - l, t - b, far - near }
  ShadowMap.slack = ShadowMap.BIAS
                    + ShadowMap.SLOPE * math.max(w, h) / res
  ShadowMap.bias = ShadowMap.slack / math.max(1, far - near)
end

ShadowMap.SNUG = 0.9

function ShadowMap.snug(model)
  local f = sunDir()
  local s = -ShadowMap.slack * ShadowMap.SNUG
  return Mat4.mul(Mat4.translate(f[1] * s, f[2] * s, f[3] * s),
                  model or IDENTITY)
end

-- Returns false when it could not start: then do not draw into it or call finish.
function ShadowMap.begin(cx, cy, vw, vh)
  if Shadows.off() then
    ShadowMap.discard()
    return false
  end
  local sh = getShader()
  if not sh then return false end
  if vSign == nil then
    vSign = probeVSign()
    ShadowMap.vSign = vSign
  end
  fit(cx, cy, vw, vh)
  local c = getCanvas(ShadowMap.res)
  if not c then return false end
  local ok = pcall(love.graphics.setCanvas, { c, depth = true })
  if not ok then
    pcall(love.graphics.setCanvas)
    return false
  end
  prevBlend, prevAlphaMode = love.graphics.getBlendMode()
  love.graphics.clear(1, 1, 0, 1, true, true)
  love.graphics.setDepthMode("lequal", true)
  love.graphics.setMeshCullMode("none")
  love.graphics.setBlendMode("replace", "premultiplied")
  love.graphics.setShader(sh)
  love.graphics.setColor(1, 1, 1, 1)
  pcall(sh.send, sh, "lightVP", "row", ShadowMap.clipVP)
  pcall(sh.send, sh, "sprite", 0)
  pcall(sh.send, sh, "roomCut", 0)
  local scene=V.require('Voxel3D')
  pcall(sh.send,sh,'canopyEye',scene.eye or {0,0,1})
  pcall(sh.send,sh,'canopyFacing',scene.canopyFacing and 1 or 0)
  drawing = true
  ready = false
  return true
end

function ShadowMap.roomClip(bounds)
  if not drawing then return end
  local sh=getShader()
  if sh then
    pcall(sh.send,sh,"roomCut",bounds and 1 or 0)
    if bounds then pcall(sh.send,sh,"roomBounds",bounds)end
  end
end

function ShadowMap.sprites(on)
  if not drawing then return end
  local sh = getShader()
  if sh then pcall(sh.send, sh, "sprite", on and 1 or 0) end
end

function ShadowMap.draw(mesh, texture, model)
  if not (drawing and mesh) then return end
  local Instances=V.require('ModelInstances')
  local batch=mesh;mesh=Instances.mesh(mesh)
  local sh = getShader()
  if texture then mesh:setTexture(texture) end
  pcall(sh.send, sh, "model", "row", model or IDENTITY)
  Instances.draw(batch,sh)
end

function ShadowMap.finish(sig)
  if not drawing then return end
  drawing = false
  love.graphics.setShader()
  love.graphics.setDepthMode()
  love.graphics.setCanvas()
  love.graphics.setBlendMode(prevBlend or "alpha", prevAlphaMode)
  love.graphics.setColor(1, 1, 1, 1)
  lastSig = sig
  ready = true
end

function ShadowMap.invalidate()
  canvas, canvasRes, blank = nil, 0, nil
  drawing, ready, lastSig = false, false, nil
end

return ShadowMap
