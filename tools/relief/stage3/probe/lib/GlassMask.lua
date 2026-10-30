-- Voxel world mode: the glass in the windows, found rather than listed.
--
-- Buildings and doors in the overworld art carry small panes -- six texels
-- wide, framed in black, with a diagonal shine drawn in. This module finds
-- them by SHAPE in the tileset image itself: a border row of six black
-- texels, four or five rows of black-flanked non-black glass under it, and
-- a closing border row. No tile ids are hardcoded, so a total conversion
-- that draws its own windows in the same idiom gets glass for free, and art
-- with no windows gets an empty mask and costs nothing.
--
-- The scan slides at PIXEL granularity because the art does: the building
-- window sits a row down inside its tile, and the door's pane straddles a
-- 2x2 tile block entirely -- a per-tile matcher finds neither.
--
-- What the scan yields is a MASK TEXTURE the same size as the tileset
-- atlas: opaque white on glass texels, transparent everywhere else. Terrain
-- meshes sample the atlas by normalized coordinates (ChunkMesher.uvRect),
-- so the scene shader can sample this mask with the SAME coordinates and
-- know, per fragment, whether it is drawing glass -- on any wall, at any
-- angle, in free-roam or a staged battle, with no geometry work anywhere.
-- The recoloured atlases (display modes, RED++) keep the tileset's layout,
-- so the alignment holds under every palette.
--
-- What the shader does with the answer (Voxel3D): by day a thin glint
-- sweeps across the panes -- a pseudo reflection, view-anchored, preserving
-- the art under it -- and after dark the panes are LIT: the texel's own
-- shine pattern, warmed and brightened, exempt from the sun, the shadow
-- map and the hour's tint, as a window with a lamp behind it is.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local Assets = require("src.render.Assets")

local GlassMask = {}

-- pane geometry the scan accepts: six glass texels across, and this many
-- rows of them between the two border rows
GlassMask.GLASS_W = 6
GlassMask.SHINE = true         -- a pane's drawn shine joins the pane (detect)
GlassMask.ROWS = { 4, 5 }        -- door pane, building pane

-- Whether a channel triple is the border black. The raw tileset art is the
-- four DMG greys, so black is genuinely zero; the threshold forgives a
-- rescaled asset without accepting the dark grey rung (85/255 = 0.33).
local function isBlack(r, g, b)
  return r < 0.12 and g < 0.12 and b < 0.12
end

GlassMask._isBlack = isBlack     -- named for the suite

-- Find every pane in an image, through a pure reader so the geometry is
-- testable headless: `getPixel(x, y)` returns r, g, b in 0..1 for 0-based
-- coordinates. Returns { {x=, y=, w=, h=}, ... } rects of GLASS texels
-- (the border is the detector's evidence, not part of the answer).
function GlassMask.scan(getPixel, w, h)
  local function black(x, y)
    return isBlack(getPixel(x, y))
  end
  local function borderRow(x, y)
    for c = 1, 6 do
      if not black(x + c, y) then return false end
    end
    return true
  end
  local function glassRow(x, y)
    if not (black(x, y) and black(x + 7, y)) then return false end
    for c = 1, 6 do
      if black(x + c, y) then return false end
    end
    return true
  end
  local want = {}
  for _, n in ipairs(GlassMask.ROWS) do want[n] = true end

  local rects = {}
  for y = 0, h - 1 do
    for x = 0, w - 8 do
      if borderRow(x, y) then
        local n = 0
        while y + 1 + n < h and glassRow(x, y + 1 + n) do
          n = n + 1
        end
        if want[n] and y + 1 + n < h and borderRow(x, y + 1 + n) then
          rects[#rects + 1] = { x = x + 1, y = y + 1,
                                w = GlassMask.GLASS_W, h = n }
        end
      end
    end
  end
  return rects
end

-- ------- the runtime cache, one entry per tileset image

local cache = {}       -- image path -> { rects, texture (or false) }

-- the mask texture for some rects, the size of the atlas they were found in
local function maskTexture(rects, w, h)
  if #rects == 0 or not (love.image and love.image.newImageData
     and love.graphics and love.graphics.newImage) then
    return false
  end
  local texture = false
  local built = pcall(function()
    local mask = love.image.newImageData(w, h)
    for _, r in ipairs(rects) do
      for yy = r.y, r.y + r.h - 1 do
        for xx = r.x, r.x + r.w - 1 do
          mask:setPixel(xx, yy, 1, 1, 1, 1)
        end
      end
    end
    texture = love.graphics.newImage(mask)
    texture:setFilter("nearest", "nearest")
  end)
  if not built then texture = false end
  return texture
end

local function entry(tileset)
  local path = tileset and tileset.image
  if not path then return nil end
  local hit = cache[path]
  if hit then return hit end
  local ok, data = pcall(Assets.imageData, path)
  if not (ok and data) then
    -- unreadable art is a verdict for the session, not a retry loop
    cache[path] = { rects = {}, texture = false }
    return cache[path]
  end
  local w, h = data:getDimensions()
  local rects = GlassMask.scan(function(x, y)
    return data:getPixel(x, y)
  end, w, h)
  cache[path] = { rects = rects, texture = maskTexture(rects, w, h) }
  return cache[path]
end

-- ------- Emerald: the facade detector
--
-- Emerald's panes do not match the scan above (their frames are dark slate,
-- not black, so the scan finds nothing in Emerald's art). This detector works
-- from WHERE the art is used instead. Only the front walls and doors of a
-- building can hold glass, and only their pixels are looked at:
--   - an atlas: the tile slots of the facade mids the builder recorded
--     (GlassMask.facade / GlassMask.door, from Gen3Scene's build);
--   - a composed building image (BuildingModels): the cells that are wall
--     or door (GlassMask.isFacadeCell);
--   - a civic image (Gen3Civic.material): its front wall and door rows.
-- Inside those pixels a pixel is glass by colour; the glass is grouped into
-- components and kept by shape and by the darker frame around it. Every
-- image gets its own mask, the size of that image, cached per image object.

local facadeSets = setmetatable({}, { __mode = "k" })  -- tileset -> { mids, n }
local MB = require("src.core.game3.mb")

-- a front wall tile of an outdoor building (called per cell by the builder)
function GlassMask.facade(ts, mid)
  if not (ts and mid) then return end
  local f = facadeSets[ts]
  if not f then f = { mids = {}, n = 0 }; facadeSets[ts] = f end
  if not f.mids[mid] then f.mids[mid] = true; f.n = f.n + 1 end
end

-- a cell whose metatile behaviour is a door (MB_*DOOR)
function GlassMask.door(ts, mid, behavior)
  if type(behavior) ~= "number" then return end
  local name = MB.nameOf(behavior)
  if name and name:find("DOOR") then GlassMask.facade(ts, mid) end
end

-- a building cell that may hold glass: a wall tile or a door
function GlassMask.isFacadeCell(c)
  if c.shape and c.shape.kind == "wall" then return true end
  if type(c.behavior) == "number" then
    local name = MB.nameOf(c.behavior)
    if name and name:find("DOOR") then return true end
  end
  return false
end

local function lumOf(r, g, b)
  return 0.299 * r + 0.587 * g + 0.114 * b
end

-- mark a rectangle [x0,x1) x [y0,y1) of a w x h image as facade pixels
local function markRect(inF, w, h, x0, y0, x1, y1)
  for y = math.max(0, y0), math.min(h, y1) - 1 do
    for x = math.max(0, x0), math.min(w, x1) - 1 do inF[y * w + x + 1] = true end
  end
end

-- The glass in one image (rule v2). `px0(x, y)` returns r, g, b in 0..255 for
-- 0-based coordinates; `inF` is the search region (flat index y * w + x + 1).
--   GLASS: b - r >= 40, b >= g, luminance 55..235, 4-connected inside the region.
--   KEPT: area 6..520, bounding box at most 40 wide and 34 tall, and not a band
--         along the TOP row of the region (over more than half its width).
--   GROWN: once, the directly 4-adjacent region pixels with b - r >= 20 and
--          b >= g - 4 (pale highlights inside a pane).
-- Returns the kept components ({ pixels, x0, y0, x1, y1 }) and the counts.
local function detectOnce(w, h, px0, inF, shine)
  local rgb = {}
  local function px(idx)
    local c = rgb[idx]
    if c then return c[1], c[2], c[3] end
    local r, g, b = px0((idx - 1) % w, math.floor((idx - 1) / w))
    c = { r, g, b }
    rgb[idx] = c
    return r, g, b
  end
  local function nbrs(idx)
    local x, y = (idx - 1) % w, math.floor((idx - 1) / w)
    local out = {}
    if x > 0 then out[#out + 1] = idx - 1 end
    if x < w - 1 then out[#out + 1] = idx + 1 end
    if y > 0 then out[#out + 1] = idx - w end
    if y < h - 1 then out[#out + 1] = idx + w end
    return out
  end
  local function isGlass(idx)
    local r, g, b = px(idx)
    local l = lumOf(r, g, b)
    -- clear blue glass, or a dark navy pane; a pale bluish WALL (b-r 40..47,
    -- bright) is neither
    return b >= g and l >= 55 and l <= 240
      and (b - r >= 48 or (b - r >= 36 and l <= 115))
  end
  -- the shine drawn across a pane (near-white, faintly blue): never a pane by itself, but part of
  -- the pane it crosses -- left out, it cut an arched window into pieces too small to count
  local function isShine(idx)
    local r, g, b = px(idx)
    return b - r >= 12 and b - r <= 34 and b >= g and lumOf(r, g, b) >= 195
  end
  local function isLoose(idx)
    local r, g, b = px(idx)
    return b - r >= 20 and b >= g - 4
  end

  -- the top and bottom rows of the search region
  local top, bottom = h, -1
  for idx in pairs(inF) do
    local y = math.floor((idx - 1) / w)
    if y < top then top = y end
    if y > bottom then bottom = y end
  end
  local span = bottom - top + 1

  local stats = { comps = 0, kept = 0, rejArea = 0, rejBox = 0, rejTop = 0, grown = 0 }
  local keptComps, seen = {}, {}
  -- in reading order, so a pane always grows from its top-left pixel: the
  -- seed decides which shade the component follows, and pairs() order would
  -- make the mask differ from run to run
  local order = {}
  for idx in pairs(inF) do order[#order + 1] = idx end
  table.sort(order)
  for _, idx in ipairs(order) do
    if not seen[idx] and isGlass(idx) then
      seen[idx] = true
      -- one pane is one shade: a component only spreads to glass within 36
      -- (summed channels) of its seed, so a glass door does not merge with
      -- the bluish wall or the roof band around it
      local sr, sg, sb = px(idx)
      local comp, queue, head = {}, { idx }, 1
      while head <= #queue do
        local p = queue[head]; head = head + 1
        comp[#comp + 1] = p
        for _, q in ipairs(nbrs(p)) do
          if inF[q] and not seen[q] and isGlass(q) then
            local r, g, b = px(q)
            if math.abs(r - sr) + math.abs(g - sg) + math.abs(b - sb) <= 36 then
              seen[q] = true; queue[#queue + 1] = q
            end
          elseif shine and inF[q] and not seen[q] and isShine(q) then
            seen[q] = true; queue[#queue + 1] = q
          end
        end
      end
      stats.comps = stats.comps + 1
      local area = #comp
      local x0, x1, y0, y1 = w, -1, h, -1
      local topXs, nTop = {}, 0
      for _, p in ipairs(comp) do
        local x, y = (p - 1) % w, math.floor((p - 1) / w)
        if x < x0 then x0 = x end
        if x > x1 then x1 = x end
        if y < y0 then y0 = y end
        if y > y1 then y1 = y end
        if y == top and not topXs[x] then topXs[x] = true; nTop = nTop + 1 end
      end
      local bw, bh = x1 - x0 + 1, y1 - y0 + 1
      if area < 10 or area > 520 then
        stats.rejArea = stats.rejArea + 1
      elseif y1 >= bottom - 5 and (bw < 5 or bh < 4) then
        -- a thin piece low on the wall: the pilaster squares, not a pane
        stats.rejBox = stats.rejBox + 1
      elseif bw > 40 or bh > 34 or bw < 3 or bh < 3
          or bh > 2.5 * bw or bw > 4 * bh
          -- a pane fills its box; a thin outline does not
          or (area < 0.45 * bw * bh and bw > 3 and bh > 3) then
        stats.rejBox = stats.rejBox + 1
      elseif (y0 == top and nTop * 2 > bw)
          -- a wide strip in the top fifth of the wall is roof band or emblem
          or (y0 - top < 0.2 * span and bw >= 2 * bh) then
        stats.rejTop = stats.rejTop + 1
      else
        stats.kept = stats.kept + 1
        local all, have = {}, {}
        for _, p in ipairs(comp) do all[#all + 1] = p; have[p] = true end
        for _, p in ipairs(comp) do
          for _, q in ipairs(nbrs(p)) do
            if false and inF[q] and not have[q] and isLoose(q) then
              have[q] = true; all[#all + 1] = q; stats.grown = stats.grown + 1
            end
          end
        end
        keptComps[#keptComps + 1] = { pixels = all, x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
      end
    end
  end
  return keptComps, stats
end
-- Panes found with their shine joined on, plus every pane found the plain way that those do not
-- cover: joining the shine only ever adds windows (it merged two of the lab's panes into one shape
-- that no longer passed, which lost them).
local function detect(w, h, px0, inF)
  local plain, stats = detectOnce(w, h, px0, inF, false)
  if not GlassMask.SHINE then return plain, stats end
  local joined = detectOnce(w, h, px0, inF, true)
  local covered = {}
  for _, c in ipairs(joined) do for _, p in ipairs(c.pixels) do covered[p] = true end end
  for _, c in ipairs(plain) do
    if not covered[c.pixels[1]] then joined[#joined + 1] = c end
  end
  stats.kept = #joined
  return joined, stats
end

-- an image-sized mask texture with the given pixels opaque white
local function pixelTexture(list, w, h)
  if #list == 0 or not (love.image and love.image.newImageData
     and love.graphics and love.graphics.newImage) then
    return false
  end
  local texture = false
  local built = pcall(function()
    local mask = love.image.newImageData(w, h)
    for _, p in ipairs(list) do
      mask:setPixel((p - 1) % w, math.floor((p - 1) / w), 1, 1, 1, 1)
    end
    texture = love.graphics.newImage(mask)
    texture:setFilter("nearest", "nearest")
  end)
  if not built then texture = false end
  return texture
end

-- GlassMask.log = true prints one line per building (and per atlas or civic)
-- as its mask is built (debug switch, off by default)
GlassMask.log = false

-- ImageData / Image key -> texture or false, for everything baked here
local imageCache = setmetatable({}, { __mode = "k" })

-- The hand-made overrides for buildings (data/gen3_glass_overrides.lua): a
-- table keyed by building id, fields off / drop / add. Empty means none.
local function overridesFor(id)
  local ok, t = pcall(function() return V.data("gen3_glass_overrides") end)
  if not (ok and type(t) == "table") then return nil end
  return t[id]
end

-- Bake one image's mask (or nothing): cached per key, logged when asked.
-- `ov` is an override entry (or nil); `tag` names the image in the log; `pic`
-- is the picture's ImageData when it is still held (nil otherwise).
local function bake(key, w, h, px0, inF, tag, ov, pic)
  local hit = imageCache[key]
  if hit ~= nil then return hit or nil end
  local comps, stats = detect(w, h, px0, inF)
  local list = {}
  for _, c in ipairs(comps) do
    local drop = false
    if ov and ov.drop then
      for _, r in ipairs(ov.drop) do
        if c.x1 >= r[1] and c.x0 <= r[1] + r[3] - 1 and c.y1 >= r[2] and c.y0 <= r[2] + r[4] - 1 then
          drop = true; break
        end
      end
    end
    if not drop then for _, p in ipairs(c.pixels) do list[#list + 1] = p end end
  end
  if ov and ov.add then
    for _, r in ipairs(ov.add) do
      for y = math.max(0, r[2]), math.min(h, r[2] + r[4]) - 1 do
        for x = math.max(0, r[1]), math.min(w, r[1] + r[3]) - 1 do
          list[#list + 1] = y * w + x + 1
        end
      end
    end
  end
  local texture = pixelTexture(list, w, h)
  imageCache[key] = texture
  -- debug hook (GlassMask.dump, nil by default): the picture, the searched pixels and the mask
  if GlassMask.dump then
    GlassMask.dump({ tag = tag, pic = pic, w = w, h = h, px0 = px0, search = inF, mask = list, boxes = comps })
  end
  if GlassMask.log then
    print(string.format("[GlassMask] %s %dx%d glass comps %d kept %d rej area %d box %d top %d grown %d",
      tag, w, h, stats.comps, stats.kept, stats.rejArea, stats.rejBox, stats.rejTop, stats.grown))
  end
  return texture or nil
end

-- A composed building image: its wall and door cells (`cells`, the scene's
-- cell map). `m` is BuildingModels.mesh's result: image and imageData.
function GlassMask.building(m, cells, bld)
  local data = m and m.imageData
  if not (data and m.image) then return nil end
  local id = tostring(bld.name or bld.kind or bld.model or "?")
  local ov = overridesFor(id)
  if ov and ov.off then return nil end
  local w, h = data:getDimensions()
  local inF = {}
  for dy = 0, bld.depth - 1 do
    -- a building on the map's top edge: its top row is roof (no cell above
    -- it to tell the roof from the wall), not facade
    local top = dy == 0 and bld.cy == 0
    for dx = 0, bld.width - 1 do
      local c = cells[(bld.cx + dx) .. ':' .. (bld.cy + dy)]
      if c and not top and GlassMask.isFacadeCell(c) then
        markRect(inF, w, h, dx * 16, dy * 16, dx * 16 + 16, dy * 16 + 16)
      end
    end
  end
  local function px0(x, y)
    local r, g, b = data:getPixel(x, y)
    return math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)
  end
  return bake(m.image, w, h, px0, inF,
    string.format("%s cell %d,%d", id, bld.cx, bld.cy), ov, data)
end

-- A civic's composed image (Gen3Civic.material): the front wall rows and the
-- door, read the way Gen3Civic reads its tile rows. The side copy (right of
-- the front) is not searched.
function GlassMask.civic(g, image)
  if not image then return nil end
  local hit = imageCache[image]
  if hit ~= nil then return hit or nil end
  local p = V.require("Gen3Civic").profile(g)
  local w, h = p.w * 2 + 4, p.h
  local inF = {}
  markRect(inF, w, h, 0, p.wallTop, p.w, p.wallBottom)
  markRect(inF, w, h, p.doorLeft, p.doorTop, p.doorRight, p.doorBottom)
  local ts = g.ts
  local function px0(x, y)
    local row = g.rows[math.floor(y / 16) + 1]
    local mid = row and row[math.floor(x / 16) + 1]
    local slot = mid and ts.midToSlot[mid]
    if not slot then return 0, 0, 0 end
    local px, py = slot % ts.cols * 16 + x % 16, math.floor(slot / ts.cols) * 16 + y % 16
    local r, gg, b, a = ts.imageData:getPixel(px, py)
    if ts.overImageData then
      local rr, bb, cc, aa = ts.overImageData:getPixel(px, py)
      r, gg, b = rr * aa + r * (1 - aa), bb * aa + gg * (1 - aa), cc * aa + b * (1 - aa)
    end
    return math.floor(r * 255 + 0.5), math.floor(gg * 255 + 0.5), math.floor(b * 255 + 0.5)
  end
  return bake(image, w, h, px0, inF,
    string.format("civic %s cell %d,%d", tostring(g.kind or "?"), g.cx or 0, g.cy or 0), nil, nil)
end

-- ------- atlases: the tiles of the recorded facade mids

-- ImageData -> { n = facade count it was built for, texture = texture|false }
local paneCache = setmetatable({}, { __mode = "k" })

-- The glass mask for one of a tileset's own atlases (ts.image or
-- ts.overImage), or nil: nil for any other image, for a tileset with no
-- facade tiles yet, and for an atlas with no glass in its facades.
function GlassMask.panes(ts, image)
  local data
  if image ~= nil and image == ts.image then data = ts.imageData
  elseif image ~= nil and image == ts.overImage then data = ts.overImageData end
  local f = data and facadeSets[ts]
  if not (f and f.n > 0) then return nil end
  local hit = paneCache[data]
  if hit and hit.n == f.n then return hit.texture or nil end
  -- a facade tile registered since the last bake (f.n grew): bake() would hand
  -- back its cached image for this ImageData, so drop that one and detect again
  if hit then imageCache[data] = nil end
  local w, h = data:getDimensions()
  local inF = {}
  for mid in pairs(f.mids) do
    local slot = ts.midToSlot[mid]
    if slot then
      local x0, y0 = (slot % ts.cols) * 16, math.floor(slot / ts.cols) * 16
      markRect(inF, w, h, x0, y0, x0 + 16, y0 + 16)
    end
  end
  local function px0(x, y)
    local r, g, b = data:getPixel(x, y)
    return math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)
  end
  local texture = bake(data, w, h, px0, inF, "atlas " .. (image == ts.image and "under" or "over"), nil, data)
  paneCache[data] = { n = f.n, texture = texture or false }
  return texture or nil
end

-- The panes found in a tileset's art, as glass rects in atlas pixels.
function GlassMask.rects(tileset)
  local e = entry(tileset)
  return e and e.rects or {}
end

-- The mask texture for a tileset, or nil when it has no panes (or the art
-- is unreadable, or there is no GPU) -- callers bind the blank instead.
function GlassMask.texture(tileset)
  local e = entry(tileset)
  return (e and e.texture) or nil
end

-- A 1x1 transparent stand-in, for the frames (and drivers) with no mask:
-- the scene shader always declares the sampler, and an unbound sampler is
-- a driver-dependent crash rather than a fallback.
local blank = nil

function GlassMask.blank()
  if blank == nil then
    local ok, img = pcall(function()
      local data = love.image.newImageData(1, 1)
      data:setPixel(0, 0, 0, 0, 0, 0)
      return love.graphics.newImage(data)
    end)
    blank = (ok and img) or false
  end
  return blank or nil
end

-- Drop the GPU objects (window resize, hot reload). The rects survive --
-- they are a fact about the art -- but textures are rebuilt on demand.
function GlassMask.invalidate()
  for _, e in pairs(cache) do
    if e.texture and e.texture.release then pcall(e.texture.release, e.texture) end
    e.texture = false
  end
  for _, e in pairs(paneCache) do
    if e.texture and e.texture.release then pcall(e.texture.release, e.texture) end
  end
  for _, t in pairs(imageCache) do
    if t and t.release then pcall(t.release, t) end
  end
  cache = {}
  paneCache = setmetatable({}, { __mode = "k" })
  imageCache = setmetatable({}, { __mode = "k" })
  blank = nil
end

return GlassMask
