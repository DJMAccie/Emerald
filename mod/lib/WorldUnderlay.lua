-- One cheap, curved floor beneath the loaded voxel neighborhood

local V = ...

local Voxel3D = V.require("Voxel3D")
local Mat4 = V.require("Mat4")
local ModSetting = V.require("ModSetting")

local WorldUnderlay = {}

local STEP = 32
local RANGE = 32768
local HEIGHT = -20

WorldUnderlay.setting = ModSetting.new(
  "worldFill", "WORLD FILL",
  { "cyan", "black", "off", "nature" },
  { "CYAN", "BLACK", "OFF/KFP", "NATURE" })

local COLORS = {
  cyan  = {   0 / 255,  71 / 255, 109 / 255, 1 }, -- #00476D
  black = {  24 / 255,  24 / 255,  24 / 255, 1 }, -- #181818
  cave  = {  18 / 255,  12 / 255,  12 / 255, 1 }, -- deep earth below shafts
}

local DEFAULT_FILL = "cyan"

local cachedMesh = nil
local textures = {}

function WorldUnderlay.selected()
  return WorldUnderlay.setting:get() or DEFAULT_FILL
end

function WorldUnderlay.enabled()
  return WorldUnderlay.selected() ~= "off"
end


local function axis()
  local positive, p, step, band = { 0 }, 0, STEP, 512
  while p < RANGE do
    p = math.min(RANGE, p + step)
    positive[#positive + 1] = p
    if p >= band then
      step = math.min(step * 2, 2048)
      band = band * 2
    end
  end
  local out = {}
  for i = #positive, 2, -1 do out[#out + 1] = -positive[i] end
  for i = 1, #positive do out[#out + 1] = positive[i] end
  return out
end

local function meshFor()
  if cachedMesh then return cachedMesh end
  local verts, indices = {}, {}
  local points = axis()
  local columns, rows = #points - 1, #points - 1
  for z = 1, #points do
    for x = 1, #points do
      verts[#verts + 1] = { points[x], HEIGHT, points[z], 0.5, 0.5, 1 }
    end
  end
  local stride = columns + 1
  for z = 0, rows - 1 do
    for x = 0, columns - 1 do
      local a = z * stride + x + 1
      indices[#indices + 1] = a
      indices[#indices + 1] = a + 1
      indices[#indices + 1] = a + stride + 1
      indices[#indices + 1] = a
      indices[#indices + 1] = a + stride + 1
      indices[#indices + 1] = a + stride
    end
  end
  cachedMesh = Voxel3D.newMesh(verts, indices)
  return cachedMesh
end

local function colorKey(color)
  return ("%.6f,%.6f,%.6f,%.6f"):format(
    color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 1)
end

local function textureFor(color)
  local key = colorKey(color)
  if textures[key] then return textures[key] end
  if not (love and love.image and love.image.newImageData
          and love.graphics and love.graphics.newImage) then return nil end
  local ok, texture = pcall(function()
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, unpack(color))
    local image = love.graphics.newImage(data)
    image:setFilter("nearest", "nearest")
    return image
  end)
  if ok then textures[key] = texture end
  return ok and texture or nil
end

function WorldUnderlay.draw(state, cx, cy, resolvedColor)
  if not state or not WorldUnderlay.enabled() then return false end
  local material = WorldUnderlay.selected()
  if material == "nature" then material = "cyan" end
  local color = resolvedColor or COLORS[material] or COLORS[DEFAULT_FILL]
  local mesh, texture = meshFor(), textureFor(color)
  if not (mesh and texture) then return false end
  Voxel3D.lighting(false)
  Voxel3D.seams(false)
  Voxel3D.glass(false)
  Voxel3D.draw(mesh, texture, Mat4.translate(cx or 0, 0, cy or 0))
  Voxel3D.glass(true)
  Voxel3D.seams(true)
  Voxel3D.lighting(true)
  return true
end

WorldUnderlay.COLORS = COLORS
WorldUnderlay.HEIGHT = HEIGHT
WorldUnderlay.STEP = STEP
WorldUnderlay.RANGE = RANGE

return WorldUnderlay
