-- Terrain rock as real rock (Opus; user: "real rocks would 'rock' in this
-- game", "atm it just feels like it's stretched").
--
-- The old builder unprojected the drawing one pixel column at a time: each
-- face column was one art column stood up (diagonal folds became vertical
-- stripes), sides and backs repeated an edge pixel (streaks), and every face
-- was a flat plane. This one builds rock per map cell instead:
--
--  * Height. Each rock cell is a block. A column of the drawing climbs
--    south to north: a FACE tile (dark, the drawn front of a tier) stands one
--    course (16 px) above whatever is south of it; a LID tile (light, the top
--    of a tier) is level with the rock south of it. So a cliff band is one
--    course, stacked face rows are stacked courses, and a massif drawn as
--    tiers (Route 122's Mt. Pyre) rises tier by tier. A rock is never lower
--    than the walkable ground touching it, so terraces never float.
--  * Texture. Every face shows rock art 1:1, tiled in 16-px courses along the
--    face: the top course of a south face is the cell's own drawing (so the
--    original view still reads), every other face takes the mass's own face
--    tile. Nothing is ever stretched or smeared.
--  * Relief. Each course is cut into 4x4 patches set out 0..2 px by their own
--    brightness (light knuckles stand out, dark cracks sit back), with their
--    sides closed, so a face is lumpy stone that catches side light.
--  * Tops take the cell's own drawing where it is a lid, the nearest lid of
--    the column (or the mass's commonest lid) where it is a face.
local V=...
local M={enabled=true}

M.COURSE=16      -- one drawn tile of face
M.PATCH=4        -- relief patch size (pixels)
M.CLEAN_TOPS=true -- tops of partly-ground patches take a clean rock patch's picture (cleanPatch)
M.RELIEF=2       -- deepest relief (pixels)
M.DARK=.42       -- a pixel darker than this (luminance) is face shadow
M.FACE_SHARE=.5  -- a tile this much dark pixel is a face tile
M.MAXH=96        -- tallest rock above its foot
M.MAXH_MAP={EM_SKY_PILLAR_OUTSIDE=48,EM_LAVARIDGE_TOWN=48}   -- per map: its ridges stand low (the 2D draws one or two courses)
M.RUNFACE={EM_ROUTE115=true,EM_MT_CHIMNEY=true,EM_ROUTE112=true}
M.NOCARVE={EM_ROUTE115=true,EM_SOOTOPOLIS_CITY=true}   -- Sootopolis: its paths are drawn in the rock's own colours (the east shore was carved away to sky)
M.LIP=4
M.SEA_ISLANDS=true
M.SEA_ISLAND_MIN=6
M.BOULDER={[0x150]=true,[0x151]=true,[0x158]=true,[0x159]=true,[0x15A]=true,[0x15B]=true}
M.FOLIAGE=.12
M.SEA_BLUE=.3
M.SEA_MAXH=32   -- an island stands at most two courses out of the sea
-- SMOOTH (default off): a mass's top rises per 4x4 patch, not per cell. Each patch
-- takes the bilinear height of the cell centres round it, capped at SMOOTH_LIP over
-- the edge it stands next to plus SMOOTH_SLOPE per px in from that edge, so a rim
-- rounds over instead of stepping. Vertices are shared, so the top is continuous.
M.SMOOTH=true
M.SOFT=true      -- SMOOTH's height model: flat cell tops rounded at the shoulders (see smoothPrep)
M.SOFT_ROUND=3   -- deepest the rounding goes under a top
-- per map: a deeper shoulder for a BANK -- a rock mass one course high, the shore ridge between a
-- beach and the grass above it. Those are drawn as a rounded bevel; at 3 px the top read as a flat
-- pillow on a vertical wall (Route 104, user: "it should look like the original map, all brown and
-- have a natural slope"), so a bank's top curves over into its face instead. A taller mass on the
-- same map (a sea stack, a reef wall, a two-course terrace) keeps SOFT_ROUND: rounding those over
-- was the "bouncy castle".
M.BANK_ROUND={EM_ROUTE104=9,EM_ROUTE105=9,EM_ROUTE106=9,EM_ROUTE107=9,EM_ROUTE108=9,EM_ROUTE109=9}
-- (Mt. Pyre's EXTERIOR keeps the drawn graveyard terraces as blocks -- soft
-- rock looked messy on those walls, user's call. The SUMMIT's outer mountain is
-- soft like the rest of the world: user chose it from the two renders in
-- docs/shots/mtpyre-rock-block-vs-soft-2026-10-16.png)
M.SMOOTH_SKIP={EM_MT_PYRE_EXTERIOR=true}
M.SKIRT={EM_MOSSDEEP_CITY=true}   -- maps whose smooth rock walls run down to the cell's own floor
M.SMOOTH_LIP=6
M.SMOOTH_SLOPE=1.6
-- per map: the tile every wall shows (Mt. Chimney's commonest clean face is
-- a diagonal flank edge, which stood as palisade stripes on every wall)
M.FACE_TILE={EM_MT_CHIMNEY=0x274,EM_ROUTE112=0x274,EM_EVER_GRANDE_CITY=0x0A9}
-- Meteor Falls: its ridged wall front (the commonest face tile with no
-- floor colour in it was a yellow stalagmite: every wall stood yellow-striped)
for _,id in ipairs({'EM_METEOR_FALLS_1F_1R','EM_METEOR_FALLS_1F_2R','EM_METEOR_FALLS_B1F_1R','EM_METEOR_FALLS_B1F_2R','EM_METEOR_FALLS_STEVENS_CAVE'})do
 M.FACE_TILE[id]=0x231 end
-- the General primary's diagonal flank and edge tiles: a mass whose commonest
-- clean face is one of these walls itself in the stacked-boulder front 0x0A9
-- instead (stood up, a flank is vertical palisade stripes)
M.FLANK={[0x068]=true,[0x072]=true,[0x073]=true,[0x075]=true,[0x078]=true,[0x07B]=true,
 [0x08A]=true,[0x090]=true,[0x09B]=true,[0x0A2]=true}
M.FRONT=0x0A9
-- per map: rock round the highest walkable ground rises away from it in
-- steps (STEP px per cell) instead of standing as one sheer slab at its edge
M.RIM={EM_MT_CHIMNEY=true}
M.STEP=12
-- per map: rock k cells south of walkable ground stands at most NORTHSLOPE*k
-- above it, so from the player camera (level 4: 40 degrees over the horizon,
-- a rise of .84 per unit back) its top never covers that ground (Ever
-- Grande's Victory Road massif hid the League path and the player)
-- (every map since 2026-10-07; checked at the player camera on 12 mountain maps)
M.NORTHCAP=setmetatable({},{__index=function()return true end})
M.NORTHSLOPE=12
local SHADE={south=.84,north=.62,east=.74,west=.7}

local function key(x,y)return x..':'..y end
-- walkable: outdoors the cartridge's collision is 0; in caves walkable floor
-- carries other codes (43 cave floor, 41 water) and only 7 is blocked
local function walk(n)
 if M.CAVES and M.CAVES[M.mapId or ''] then return n.collision~=nil and n.collision~=7 and n.collision~=255 end
 return (n.collision or 0)==0
end
local function lum(r,g,b)return .299*r+.587*g+.114*b end

-- Rolled out map by map, each checked at the player, low and orbit cameras;
-- other maps keep the old builder until checked (Mt. Chimney's lava rim and
-- a Mossdeep wall need their own handling first).
M.OUTCROP=false   -- ragged edge notches on tall rock tops (read as crenellations)
M.LONE_BOULDER=true   -- see handles()
M.MAPS={EM_MT_PYRE_EXTERIOR=true,EM_MT_PYRE_SUMMIT=true,EM_ROUTE122=true,EM_JAGGED_PASS=true,
 EM_ROUTE111=true,EM_ROUTE114=true,EM_LILYCOVE_CITY=true,EM_RUSTBORO_CITY=true,EM_SOOTOPOLIS_CITY=true,
 EM_DEWFORD_TOWN=true,EM_SLATEPORT_CITY=true,EM_FALLARBOR_TOWN=true,EM_LAVARIDGE_TOWN=true,EM_MOSSDEEP_CITY=true,
 EM_ROUTE116=true,EM_ROUTE118=true,EM_ROUTE120=true,EM_ROUTE121=true,
 EM_EVER_GRANDE_CITY=true,EM_ROUTE112=true,EM_ROUTE115=true,EM_MT_CHIMNEY=true,
 EM_MAUVILLE_CITY=true,EM_VERDANTURF_TOWN=true,EM_PACIFIDLOG_TOWN=true,EM_ROUTE103=true,EM_ROUTE104=true,
 EM_ROUTE106=true,EM_ROUTE110=true,EM_ROUTE113=true,EM_ROUTE119=true,EM_ROUTE123=true,EM_FORTREE_CITY=true,
 EM_ROUTE101=true,EM_ROUTE102=true,EM_ROUTE105=true,EM_ROUTE107=true,EM_ROUTE108=true,EM_ROUTE109=true,EM_ROUTE117=true,
 EM_ROUTE124=true,EM_ROUTE125=true,EM_ROUTE126=true,EM_ROUTE127=true,EM_ROUTE128=true,EM_ROUTE129=true,EM_ROUTE130=true,
 EM_ROUTE131=true,EM_ROUTE132=true,EM_ROUTE133=true,EM_ROUTE134=true,EM_OLDALE_TOWN=true,EM_LITTLEROOT_TOWN=true,EM_PETALBURG_CITY=true,
 EM_SAFARI_ZONE_NORTH=true,EM_SAFARI_ZONE_NORTHWEST=true,EM_SAFARI_ZONE_SOUTH=true,EM_SAFARI_ZONE_SOUTHWEST=true,EM_SAFARI_ZONE_NORTHEAST=true,EM_SAFARI_ZONE_SOUTHEAST=true,
 -- islands that were still old stretched domes (2026-10-17): their rock now reads 1:1 in courses
 EM_SKY_PILLAR_OUTSIDE=true,EM_SOUTHERN_ISLAND_EXTERIOR=true}
-- not the Battle Frontier (East/West): its low pond and garden walls stack into tall spikes and
-- pillars under the face-climbing rule; they keep the dome builder until they get their own rule
-- not yet: Route 115 (sand ridges), Mt. Chimney (lava rim)
-- Caves (user: "ok now do the caves"): their walls are the same drawn rock --
-- face rows under lighter tops -- and are built the same way instead of the
-- old column builder, which stood each art column up as a stripe.
-- Every cave map (Gen3Scene adds each as it is built), except CAVE_SKIP. A
-- cave wall stands at most CAVE_MAXH over the nearest floor: the solid rock
-- between passages is drawn as dark fill, which read as face row on face row
-- and climbed into towers.
M.CAVES={}
M.OWN_FACE={}
M.CAVE_SKIP={}
M.CAVE_MAXH=32
M.CAVE_RISE=8     -- cave rock rises this much per cell further from the passages
M.CAVE_EXTRA=24   -- at most this much
M.CAVE_SOFT=false -- soft rock in caves too
function M.cave(def)
 local id=def and def.id
 if not id or M.CAVE_SKIP[id] or id:find('ABANDONED_SHIP') or id:find('NEW_MAUVILLE') then return end
 -- (secret bases, map type 9, are rooms hollowed in rock, a shrub or a tree: the same)
 if tonumber(def.mapType)==9 then M.OWN_FACE[id]=true end
 if tonumber(def.mapType)==4 or tonumber(def.mapType)==9 or (tonumber(def.mapType)==5 and id:find('^EM_UNDERWATER')) then M.CAVES[id]=true end
end
local tile
-- a piece of the General diagonal shore bluff (0x080-0x084, 0x088-0x08C): a rock edge along a shore,
-- never a stone of its own, however few cells it has (Route 115's bluff ends stood as lone pillars)
-- (only where checked: on Route 111, 119 and Lilycove the same tiles are drawn as round boulders and stay domes)
M.BLUFF_MAPS={EM_ROUTE115=true}
local function bluff(mass)
 if not (M.BLUFF_MAPS[mass.mapId or ''] and mass.members and #mass.members>0) then return false end
 for _,m in ipairs(mass.members)do
  local i=m.mid
  if not (i and ((i>=0x080 and i<=0x084) or (i>=0x088 and i<=0x08C)) and m.cy) then return false end
 end
 return true
end
function M.handles(mass,cells)
 if not (M.enabled and mass and not mass.object and not mass.bank) then return false end
 if not (M.MAPS[mass.mapId or ''] or M.CAVES[mass.mapId or '']) then return false end
 -- (the sand hills of Routes 114 and 115 are one rolling surface: Gen3Hills)
 -- (the counted relief of the General mountain, Route 111 / 114: Gen3Relief)
 if V.require('Gen3Relief').claims(mass,cells) then return true end
 if V.require('Gen3Hills').claims(mass,cells) then return true end
 -- a lone boulder on land (a rock mass of one or two cells, Route 118's beach rocks) is a round stone
 -- (Gen3Mass body), not a course-built block with its drawing on the front
 -- (and a free-standing 2x2 rock -- Route 111's desert spires, which stood as drums with every pixel
 -- column smeared down their sides -- unless it closes a terrace: walkable floors round it on two levels)
 if M.LONE_BOULDER and not mass.seaBoulders and not bluff(mass) and not M.CAVES[mass.mapId or ''] and #mass.members<=4 then
  local x0,y0,x1,y1=1e9,1e9,-1e9,-1e9
  for _,m in ipairs(mass.members)do x0,y0,x1,y1=math.min(x0,m.cx),math.min(y0,m.cy),math.max(x1,m.cx),math.max(y1,m.cy) end
  local free=#mass.members<=2
  if not free and cells then
   local inside={};for _,m in ipairs(mass.members)do inside[m]=true end
   local lo,hi
   for _,m in ipairs(mass.members)do for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    local n=cells[key(m.cx+d[1],m.cy+d[2])]
    if n and not inside[n] and walk(n) then local f=n.floorHigh or n.base or 0;lo=math.min(lo or f,f);hi=math.max(hi or f,f) end
   end end
   free=lo~=nil and hi-lo<16
  end
  if free and x1-x0<=1 and y1-y0<=1 then mass.boulder=true;return false end
 end
 -- an island in the sea (more than a 2x2 boulder) is rock built by course,
 -- standing on the water (as a dome it stretched into barrels and planks)
 if mass.seaBoulders then
  if not (M.SEA_ISLANDS and #mass.members>=M.SEA_ISLAND_MIN) then return false end
  -- (a chain of the 2x2 sea boulders is boulders, not an island: Route 110)
  local chain=true
  for _,m in ipairs(mass.members)do if not M.BOULDER[m.mid] then chain=false;break end end
  if chain then return false end
  -- (boulders drawn in deep water, a blue ring round each, stay boulders)
  local blue,n=0,0
  for _,m in ipairs(mass.members)do local t=tile(m.ts,m.mid);if t then blue=blue+(t.blue or 0);n=n+1 end end
  if n==0 or blue/n>M.SEA_BLUE then return false end
  mass.rockSmallWet=false
  return true
 end
 -- small rocks standing in water (pillars by a dock) keep the old builder,
 -- which cuts the sea out of their tiles
 if cells and mass.rockSmallWet==nil then
  local wet=false
  if #mass.members<=12 then
   for _,m in ipairs(mass.members)do for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    local n=cells[key(m.cx+d[1],m.cy+d[2])]
    if n and n.shape and n.shape.kind=='water' then wet=true end
   end end
   -- (a bank with land on its other side is not a rock standing in water:
   -- Route 120's lake bank and Sootopolis's shore stood as a thin floating
   -- slab over a strip of sand-coloured ground)
   if wet then
    local inside={};for _,m in ipairs(mass.members)do inside[m]=true end
    for _,m in ipairs(mass.members)do for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local n=cells[key(m.cx+d[1],m.cy+d[2])]
     if n and not inside[n] and n.shape and n.shape.kind~='water' and not n.boundary then wet=false end
    end end
   end
  end
  mass.rockSmallWet=wet
 end
 if mass.rockSmallWet then return false end
 -- scattered small rocks (Route 115's sand boulders) keep the old builder:
 -- stacked as courses they stood as pillars
 -- (Meteor Falls only: Desert Ruins, Island Cave and the Ancient Tomb draw round boulders on these tiles, which stay domes)
 -- (a lone cave-wall cell is a piece of the cave's wall, built like the rest: as a dome it was a dark pillar)
 local caveWall=(mass.mapId or ''):find('^EM_METEOR_FALLS') and M.CAVES[mass.mapId or ''] and mass.members[1] and mass.members[1].shape and mass.members[1].shape.kind=='caveWall'
 if #mass.members<=4 and not bluff(mass) and not caveWall then
  -- (but a small piece closing the end of a raised terrace -- Lilycove's
  -- east ledge -- is that terrace's rock, built like the rest of it)
  local foot,top
  local inside={};for _,m in ipairs(mass.members)do inside[m]=true end
  for _,m in ipairs(mass.members)do for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
   local n=cells and cells[key(m.cx+d[1],m.cy+d[2])]
   if n and not inside[n] and walk(n) then local f=n.floorHigh or n.base or 0
    foot=math.min(foot or f,f);top=math.max(top or f,f) end
  end end
  if not (foot and top-foot>=16) then return false end
  mass.terraceEnd=top
 end

 local c=mass.members and mass.members[1]
 if c and c.shape and c.shape.kind=='caveWall' then return M.CAVES[mass.mapId or ''] and true or false end
 return c and c.shape and c.shape.kind=='cliff' and not c.shape.seaRock and not c.shape.sea and true or false
end

-- per tileset, per tile: luminance grid and dark share
function tile(ts,mid)
 ts.rockTiles=ts.rockTiles or {}
 local t=ts.rockTiles[mid]
 if t~=nil then return t or nil end
 local slot=ts.midToSlot[mid]
 if not slot or not ts.imageData then ts.rockTiles[mid]=false;return nil end
 local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
 local L,dark={},0
 for y=0,15 do for x=0,15 do
  local r,g,b=ts.imageData:getPixel(ox+x,oy+y)
  if ts.overImageData then local rr,gg,bb,aa=ts.overImageData:getPixel(ox+x,oy+y)
   if aa>0 then r,g,b=rr*aa+r*(1-aa),gg*aa+g*(1-aa),bb*aa+b*(1-aa) end end
  local l=lum(r,g,b);L[y*16+x]=l
  if l<M.DARK then dark=dark+1 end
 end end
 local rs,gs=0,0
 for y=0,15 do for x=0,15 do local r,g=ts.imageData:getPixel(ox+x,oy+y);rs=rs+r;gs=gs+g end end
 local bl,gr=0,0
 for y=0,15 do for x=0,15 do
  local r,g,b=ts.imageData:getPixel(ox+x,oy+y)
  if b>r+.15 and b>g then bl=bl+1 end
  -- (foliage: also what hangs over the tile in the over-player layer)
  if ts.overImageData then local rr,gg,bb,aa=ts.overImageData:getPixel(ox+x,oy+y)
   if aa>.5 then r,g,b=rr,gg,bb end end
  if g>r*1.1 and g>b*1.05 then gr=gr+1 end
 end end
 -- a rock tile with forest hanging over it (Route 112's mountain top under
 -- the canopy) is rock top, never a face, and never the wall's or lid's art
 local foliage=gr/256>M.FOLIAGE
 -- an all-black tile (the outside of a room drawn in its map: Mirage Tower's
 -- corners) is no rock art: never a face, never the wall's or lid's art
 local void=true
 for k=0,255 do if L[k]>.04 then void=false;break end end
 if void then foliage=true end
 t={L=L,void=void,face=dark/256>=M.FACE_SHARE and not foliage,lava=rs/256>.7 and gs/256<.32,blue=bl/256,foliage=foliage}
 ts.rockTiles[mid]=t
 return t
end
local function isFace(c)local t=tile(c.ts,c.mid);return t and t.face and not t.lava end

local function floorOf(n)
 if not n then return nil end
 return n.floorHigh or n.base or 0
end
-- the lowest floor a rock's side must close down to beside a stair flight cell: a one-cell flight climbs
-- from its lower neighbour's floor, so its treads stand below its own base at its foot (Mt. Pyre Summit's
-- north stair left a tread-sized hole between its second step and the rock beside it)
local function sideFloor(n,cells)
 local f=floorOf(n)
 if not (f and n.floor and n.floor.step and n.shape and n.shape.kind=='flat') then return f end
 for _,d in ipairs({{0,1},{0,-1},{1,0},{-1,0}})do
  local m=cells[key(n.cx+d[1],n.cy+d[2])]
  if m and m.base and walk(m) and not (m.shape and (m.shape.kind=='cliff' or m.shape.kind=='rock')) then f=math.min(f,m.base) end
 end
 return f
end

-- heights and the mass's own face/lid tiles, once per mass
local function prepare(mass,cells)
 if mass.rock then return mass.rock end
 local R={H={},faceMid=nil,lidMid=nil}
 mass.rock=R
 local inMass={}
 for _,c in ipairs(mass.members)do inMass[c]=true end
 local faces,lids={}, {}
 for _,c in ipairs(mass.members)do
  local t=tile(c.ts,c.mid)
  -- (a roof or wall drawn into the rock row -- the Lilycove Center's roof in
  -- its ledge -- is no lid: it capped every ledge in orange)
  local bld=c.column or c.bldModel or c.civic or c.gym
  if t and not bld and not t.foliage then if t.face then faces[c.mid]=(faces[c.mid] or 0)+1 else lids[c.mid]=(lids[c.mid] or 0)+1 end end
 end
 local function pick(t)local b,n;for m,v in pairs(t)do if not n or v>n or (v==n and m<b) then b,n=m,v end end;return b end
 R.faceMid=pick(faces) or mass.members[1].mid
 R.faceCount=faces[R.faceMid] or 0
 R.lidMid=pick(lids) or R.faceMid
 -- the foot: lowest floor touching the mass
 local foot
 for _,c in ipairs(mass.members)do
  for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
   local n=cells[key(c.cx+d[1],c.cy+d[2])]
   if n and not inMass[n] then local f=floorOf(n);foot=foot and math.min(foot,f) or f end
  end
 end
 foot=foot or 0;R.foot=foot
 -- climb each column south to north
 local H=R.H
 for x=mass.x0,mass.x1 do
  for y=mass.y1,mass.y0,-1 do
   local c=cells[key(x,y)]
   if c and inMass[c] then
    local s=cells[key(x,y+1)]
    local southTop
    if s and inMass[s] then southTop=H[s] else southTop=floorOf(s) or foot end
    local h
    local lt=tile(c.ts,c.mid)
    if lt and lt.lava then h=southTop   -- lava lies flat in its crater, level with the lava south of it
    elseif isFace(c) and (not M.RUNFACE[mass.mapId or ''] or (function()
      -- (on RUNFACE maps a face climbs only as part of a tier front: a run
      -- of face cells east-west; a lone face cell is a diagonal flank)
      local e,w=cells[key(x+1,y)],cells[key(x-1,y)]
      return (e and inMass[e] and isFace(e)) or (w and inMass[w] and isFace(w)) end)()) then h=southTop+M.COURSE
    elseif s and inMass[s] then h=southTop
    -- (a blocked floor-coloured cell of a cave, unreachable floor: level with
    -- what lies south of it; it rises only where a drawn face says so)
    elseif c.shape.fromBlocked then h=southTop
    else h=southTop+M.COURSE end
    -- (RUNFACE maps) a light rock cell with no face cell beside it is a low
    -- terrace lip drawn with a small shaded arc (Mt. Chimney's crater slopes),
    -- not a one-tile block: it stands M.LIP over the ground south of it
    if M.RUNFACE[mass.mapId or ''] and not isFace(c) then
     local nearFace=false
     for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
      local n=cells[key(x+d[1],y+d[2])]
      if n and inMass[n] and isFace(n) then nearFace=true end
     end
     if not nearFace then h=math.min(h,(floorOf(s) or southTop)+M.LIP) end
    end
    -- a strip one cell wide (no rock east or west) is a ridge seen edge-on,
    -- not a tower: one course over the ground beside it
    local e,w=cells[key(x+1,y)],cells[key(x-1,y)]
    if not (e and inMass[e]) and not (w and inMass[w]) then
     local side=math.max(floorOf(e) or foot,floorOf(w) or foot)
     h=math.min(h,side+M.COURSE)
    end
    H[c]=math.min(h,foot+(mass.seaBoulders and M.SEA_MAXH or (M.MAXH_MAP[mass.mapId or '']or M.MAXH)))
   end
  end
 end
 -- (RUNFACE maps: the mountain's tops are walkable terraces the cartridge
 -- rates; rock bounding a terrace rises exactly to it, not tiers above)
 if M.RUNFACE[mass.mapId or ''] then
  for _,c in ipairs(mass.members)do
   local top
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1},{1,1},{-1,1},{1,-1},{-1,-1}})do
    local n=cells[key(c.cx+d[1],c.cy+d[2])]
    if n and not inMass[n] and walk(n) then local f=floorOf(n);top=top and math.max(top,f) or f end
   end
   if top and top>foot then H[c]=top
   elseif top then H[c]=math.min(H[c],top+M.COURSE) end
  end
 end
 -- (RIM maps) rock round the highest walkable ground: flush at its edge,
 -- then up STEP per cell away from it, with a ragged crest, never above
 -- what the climb gave it
 if M.RIM[mass.mapId or ''] then
  local top
  for _,c in ipairs(mass.members)do
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    local n=cells[key(c.cx+d[1],c.cy+d[2])]
    if n and not inMass[n] and walk(n) then local f=floorOf(n);top=top and math.max(top,f) or f end
   end
  end
  if top then
   local dist,q={},{}
   for _,c in ipairs(mass.members)do
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local n=cells[key(c.cx+d[1],c.cy+d[2])]
     if n and not inMass[n] and walk(n) and floorOf(n)==top and not dist[c] then dist[c]=1;q[#q+1]=c end
    end
   end
   local k=1
   while k<=#q do
    local c=q[k];k=k+1
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local n=cells[key(c.cx+d[1],c.cy+d[2])]
     if n and inMass[n] and not dist[n] then dist[n]=dist[c]+1;q[#q+1]=n end
    end
   end
   for c,d in pairs(dist)do
    local t=R.H[c] or H[c]
    if not (tile(c.ts,c.mid) or {}).lava and t>=top then
     local jag=d>1 and ((c.cx*7+c.cy*13)%3)*4 or 0
     H[c]=math.min(t,top+(d-1)*M.STEP+jag)
    end
   end
  end
 end
 if M.CAVES[mass.mapId or ''] then
  local near,q={},{}
  for _,c in ipairs(mass.members)do
   local f
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    local n=cells[key(c.cx+d[1],c.cy+d[2])]
    if n and not inMass[n] and walk(n) then local v=floorOf(n);f=f and math.max(f,v) or v end
   end
   if f then near[c]=f;q[#q+1]=c end
  end
  local k=1
  while k<=#q do
   local c=q[k];k=k+1
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    local n=cells[key(c.cx+d[1],c.cy+d[2])]
    if n and inMass[n] and near[n]==nil then near[n]=near[c];q[#q+1]=n end
   end
  end
  -- (thick rock between passages rises further from them: CAVE_RISE per cell beyond the rim, so a cave's
  -- solid rock is a massif with its walls round it, not one flat sheet a tile up -- Rusturf Tunnel)
  local depth={}
  do local q2,h2={},1
   for _,c in ipairs(mass.members)do
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local n=cells[key(c.cx+d[1],c.cy+d[2])]
     if n and not inMass[n] and walk(n) then depth[c]=0;q2[#q2+1]=c;break end
    end
   end
   while q2[h2]do local c=q2[h2];h2=h2+1
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local n=cells[key(c.cx+d[1],c.cy+d[2])]
     if n and inMass[n] and depth[n]==nil then depth[n]=depth[c]+1;q2[#q2+1]=n end
    end
   end
  end
  for _,c in ipairs(mass.members)do
   -- (and never below it: between floors on different levels the rock
   -- follows the floor it stands beside -- a wall a tile tall over the
   -- nearest floor, an unreachable piece of floor level with it)
   if near[c] and H[c] then
    local extra=(M.CAVE_RISE>0 and depth[c] and not (c.shape and c.shape.fromBlocked and not isFace(c))) and math.min(M.CAVE_RISE*math.max(0,depth[c]-1),M.CAVE_EXTRA) or 0
    H[c]=math.min(H[c]+extra,near[c]+M.CAVE_MAXH+extra)
    local low=near[c]+((c.shape and c.shape.fromBlocked) and 0 or M.COURSE)
    if H[c]<low then H[c]=low end
   end
  end
 end
 if M.NORTHCAP[mass.mapId or ''] then
  for _,c in ipairs(mass.members)do
   for k=1,8 do
    local n=cells[key(c.cx,c.cy-k)]
    if not n then break end
    -- (caves: furniture standing against a room's south wall -- Magma
    -- Hideout's containers -- shows its whole front as drawn: the rock right
    -- south of it tops out at its floor, then rises as from ground. Checked
    -- before the mass test: a furniture tile the tables also list as rock
    -- is a member of the mass)
    if n.prop and M.CAVES[mass.mapId or ''] then H[c]=math.min(H[c],(n.prop.groundHeight or floorOf(n))+M.NORTHSLOPE*(k-1));break end
    if not inMass[n] then
     -- (a fence or garden wall between them is looked past)
     if walk(n) then H[c]=math.min(H[c],floorOf(n)+M.NORTHSLOPE*k);break end
     if n.bldModel or n.civic or n.mass then break end
    end
   end
  end
 end
 -- never below the walkable ground touching it
 for _,c in ipairs(mass.members)do
  for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
   local n=cells[key(c.cx+d[1],c.cy+d[2])]
   if n and not inMass[n] and walk(n) then
    local f=floorOf(n);if f>H[c] then H[c]=f end
   end
  end
 end
 -- a flank tile (the side edge of a terrace) beside that terrace's walkable
 -- top stands level with it, not a course above (a brown lump on the grass
 -- at the corner of Lilycove's east ledge)
 for _,c in ipairs(mass.members)do if M.FLANK[c.mid] then
  local top
  for _,d in ipairs({{1,0},{-1,0}})do
   local n=cells[key(c.cx+d[1],c.cy+d[2])]
   if n and not inMass[n] and walk(n) then top=math.max(top or 0,floorOf(n)) end
  end
  -- (only beside a terrace standing above the rock's foot: a corner tile where the diagonal edge jogs, with the
  -- beach on its open side, stands a course like the walls it joins -- flush, it was a notch in the edge)
  if top and top>(R.foot or 0) and H[c]>top and H[c]-top<=M.COURSE then H[c]=top end
 end end
 -- never below the cell's own solved floor height: a rock cell takes the
 -- height of the terrace nearest it, and the ground showing round its rock is
 -- drawn there -- lower rock left that ground as a slab over it (the green
 -- cube on Route 116's ledge, green blocks on Route 112) or a hole beside it
 if not mass.seaBoulders then
  for _,c in ipairs(mass.members)do
   if H[c] and (c.base or 0)>H[c] and not (tile(c.ts,c.mid) or {}).lava then H[c]=c.base end
  end
 end
 if mass.terraceEnd then for _,c in ipairs(mass.members)do H[c]=mass.terraceEnd end end
 R.inMass=inMass
 return R
end

local function sub(uv,x0,y0,x1,y1)
 local l,t,r,b=uv[1][1],uv[1][2],uv[3][1],uv[3][2]
 local u0,u1=l+(r-l)*x0/16,l+(r-l)*x1/16
 local v0,v1=t+(b-t)*y0/16,t+(b-t)*y1/16
 return {{u0,v0},{u1,v0},{u1,v1},{u0,v1}}
end

-- Silhouette: which 4x4 patches of a cell are rock. A patch whose pixels are
-- mostly the ground tile's colours (the grass round a drawn rock's corner) is
-- not rock: the rock takes the drawing's own outline, not the cell's square.
local function groundSet(mass,cells)
 if mass.rockGround~=nil then return mass.rockGround end
 local Mass=V.require('Gen3Mass')
 local c=mass.members[1]
 local set={}
 -- the ground tile, and any water touching the mass (a rock drawn standing
 -- in the sea has the sea round it in its tiles)
 local mids={}
 local g=Mass.ground(mass,cells);if g then mids[g]=true end
 for _,m in ipairs(mass.members)do
  for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
   local n=cells[key(m.cx+d[1],m.cy+d[2])]
   if n and n.ts==c.ts and n.shape and n.shape.kind=='water' then mids[n.mid]=true end
  end
 end
 for mid in pairs(mids)do
  local slot=c.ts.midToSlot[mid]
  if slot then
   local ox,oy=slot%c.ts.cols*16,math.floor(slot/c.ts.cols)*16
   for y=0,15 do for x=0,15 do
    local r,gg,b=c.ts.imageData:getPixel(ox+x,oy+y)
    -- from water tiles only their blue (shore tiles carry sand and rock too)
    if mid==g or b>r+.12 then
     set[math.floor(r*255+.5)*65536+math.floor(gg*255+.5)*256+math.floor(b*255+.5)]=true
    end
   end end
  end
 end
 mass.rockGround=set
 return set
end
-- ground pixels in a tile (grass strips along a drawn rock's edge)
local function groundCount(mass,cells,ts,mid)
 mass.rockGC=mass.rockGC or {}
 local n=mass.rockGC[mid];if n then return n end
 local set=groundSet(mass,cells)
 local slot=ts.midToSlot[mid];n=0
 if slot then
  local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
  for y=0,15 do for x=0,15 do
   local r,gg,b=ts.imageData:getPixel(ox+x,oy+y)
   if set[math.floor(r*255+.5)*65536+math.floor(gg*255+.5)*256+math.floor(b*255+.5)] then n=n+1 end
  end end
 end
 mass.rockGC[mid]=n
 return n
end
local function occupancy(mass,cells,c)
 mass.rockOcc=mass.rockOcc or {}
 local o=mass.rockOcc[c]
 if o then return o end
 -- (a mountain whose lit tops share the ground's colours, Route 115's sand,
 -- keeps its whole cells: carving would leave only the shaded strips)
 -- (a cave's ledge tops are drawn in its floor's own colours: the same)
 if M.NOCARVE[mass.mapId or ''] or M.CAVES[mass.mapId or ''] then o={};for k=0,15 do o[k]=true end;mass.rockOcc[c]=o;return o end
 local set=groundSet(mass,cells)
 local ts=c.ts;local slot=ts.midToSlot[c.mid]
 o={}
 local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
 local S=M.PATCH
 for j=0,16/S-1 do for i=0,16/S-1 do
  local g=0
  for yy=0,S-1 do for xx=0,S-1 do
   local r,gg,b=ts.imageData:getPixel(ox+i*S+xx,oy+j*S+yy)
   if set[math.floor(r*255+.5)*65536+math.floor(gg*255+.5)*256+math.floor(b*255+.5)] then g=g+1 end
  end end
  o[j*(16/S)+i]=g<(S*S)/2
 end end
 mass.rockOcc[c]=o
 return o
end

-- (a 4 px patch partly drawn as ground -- the sand or grass strip along a cliff tile's edge -- is still
-- rock when most of it is rock; painted 1:1 its ground pixels lay as yellow and green stripes along the
-- rock's tops. Such a patch takes the picture of the nearest patch of the same tile with no ground in it)
local function cleanPatch(mass,cells,ts,mid)
 mass.cleanPatch=mass.cleanPatch or {}
 local key=tostring(ts)..':'..mid
 local t=mass.cleanPatch[key]
 if t then return t end
 t={}
 local set=groundSet(mass,cells)
 local slot=ts.midToSlot[mid]
 local N=16/M.PATCH
 if not (slot and ts.imageData) then mass.cleanPatch[key]=t;return t end
 local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
 local dirty={}
 for j=0,N-1 do for i=0,N-1 do
  local g=0
  for yy=0,M.PATCH-1 do for xx=0,M.PATCH-1 do
   local r,gg,b=ts.imageData:getPixel(ox+i*M.PATCH+xx,oy+j*M.PATCH+yy)
   if set[math.floor(r*255+.5)*65536+math.floor(gg*255+.5)*256+math.floor(b*255+.5)] then g=g+1 end
  end end
  dirty[j*N+i]=g>0
 end end
 for j=0,N-1 do for i=0,N-1 do
  if dirty[j*N+i] then
   local best,bd
   for jj=0,N-1 do for ii=0,N-1 do
    if not dirty[jj*N+ii] then local d=(ii-i)^2+(jj-j)^2;if not bd or d<bd then best,bd={ii,jj},d end end
   end end
   if best then t[j*N+i]=best end
  end
 end end
 mass.cleanPatch[key]=t
 return t
end

-- One face segment with relief: u from ua to ub along the face (art columns
-- ua..ub of `info`'s tile), heights top..bottom, courses of 16 counted from
-- the rock's top H (so stacked courses line up). P(u,h,o) places a point.
local function segment(emit,P,uv,info,ua,ub,top,bottom,H,shade)
 local S,REL=M.PATCH,M.RELIEF
 local lo,hi=1,0
 for k=0,255 do local l=info.L[k];if l<lo then lo=l end;if l>hi then hi=l end end
 local function off(u,row)
  if u<ua or u>=ub then return 0 end
  local s=0
  for yy=0,S-1 do for xx=0,S-1 do s=s+info.L[((math.floor(row/S)*S+yy)%16)*16+(math.floor(u/S)*S+xx)%16] end end
  s=s/(S*S)
  return hi>lo and math.floor(REL*(s-lo)/(hi-lo)+.5) or 0
 end
 local h=top
 while h>bottom+.01 do
  local d=H-h                       -- depth below the rock's top
  local row=d%16
  local step=math.min(S-(row%S),h-bottom)
  local y1,y0=h,h-step
  local r0=row;local r1=row+step
  for u=ua,ub-S,S do
   local o=off(u,r0)
   local t=sub(uv,u%16,r0,u%16+S,r1)
   emit({P(u,y1,o),P(u+S,y1,o),P(u+S,y0,o),P(u,y0,o)},t,shade)
   if o>0 then
    local c={t[1],t[1],t[1],t[1]}
    local oL,oR=off(u-S,r0),off(u+S,r0)
    local oU=(d<.01) and 0 or off(u,(r0-S)%16)
    local oD=(y0<=bottom+.01) and 0 or off(u,(r0+S)%16)
    if oL<o then emit({P(u,y1,oL),P(u,y1,o),P(u,y0,o),P(u,y0,oL)},c,shade*.88) end
    if oR<o then emit({P(u+S,y1,o),P(u+S,y1,oR),P(u+S,y0,oR),P(u+S,y0,o)},c,shade*.88) end
    if oU<o then emit({P(u,y1,oU),P(u+S,y1,oU),P(u+S,y1,o),P(u,y1,o)},c,1) end
    if oD<o then emit({P(u,y0,o),P(u+S,y0,o),P(u+S,y0,oD),P(u,y0,oD)},c,shade*.7) end
   end
  end
  h=y0
 end
end

-- SMOOTH: the patch heights and shared vertex heights of a whole mass, once per mass
local function smoothPrep(mass,cells,R)
 if R.SP then return R.SP end
 local S,N=M.PATCH,16/M.PATCH
 local SP={HP={},VH={}}
 R.SP=SP
 local function cellAt(cx,cy)return cells[key(cx,cy)] end
 local function inside(gx,gy)
  local cx,cy=math.floor(gx/N),math.floor(gy/N)
  local n=cellAt(cx,cy)
  return (n and R.inMass[n] and occupancy(mass,cells,n)[(gy-cy*N)*N+(gx-cx*N)]) or false
 end
 -- a cell's height for the bilinear: rock its own top, outside ground its floor
 local function Hc(cx,cy)
  local n=cellAt(cx,cy)
  if n and R.inMass[n] then return R.H[n] end
  if n then return floorOf(n) end
  return R.foot
 end
 -- distance (in patches) from each patch to the nearest walkable or water edge
 local dist,flo,q,all={},{},{},{}
 for _,c in ipairs(mass.members)do for j=0,N-1 do for i=0,N-1 do
  local gx,gy=c.cx*N+i,c.cy*N+j
  if inside(gx,gy) then
   local k=gx..':'..gy
   all[#all+1]={gx,gy,k}
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    local n=cellAt(math.floor((gx+d[1])/N),math.floor((gy+d[2])/N))
    if n and not R.inMass[n] and (walk(n) or (n.shape and n.shape.kind=='water')) and not dist[k] then
     dist[k]=0;flo[k]=floorOf(n);q[#q+1]={gx,gy,k}
    end
   end
  end
 end end end
 local qi=1
 while qi<=#q do
  local p=q[qi];qi=qi+1
  for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
   local gx,gy=p[1]+d[1],p[2]+d[2];local nk=gx..':'..gy
   if dist[nk]==nil and inside(gx,gy) then dist[nk]=dist[p[3]]+1;flo[nk]=flo[p[3]];q[#q+1]={gx,gy,nk} end
  end
 end
 -- a tall drawn cliff (face tiles stacked two courses on its south side, Route 114's
 -- wall, Mt. Chimney): its south wall stands at the cell's own top, not rounded
 R.tallS={}
 for _,c in ipairs(mass.members)do
  local s,nn=cellAt(c.cx,c.cy+1),cellAt(c.cx,c.cy-1)
  if isFace(c) and not (s and R.inMass[s]) and nn and R.inMass[nn] and isFace(nn) then R.tallS[c]=true end
 end
 -- patch height. SOFT (default): the cell's own solved height, a flat top, rounded at its shoulders by a
 -- 3x3 mean over the patches round it (outside the rock: the ground's floor) -- soft rock that keeps its
 -- tiers. Otherwise: bilinear of the four nearest cell centres (thin walls stood as tent ridges), capped
 -- by the lip and the slope.
 local function stepAt(gx,gy)
  local cx,cy=math.floor(gx/N),math.floor(gy/N)
  local n=cellAt(cx,cy)
  if n and R.inMass[n] then
   if occupancy(mass,cells,n)[(gy-cy*N)*N+(gx-cx*N)] then return R.H[n] end
   return floorOf(n)
  end
  if n then return floorOf(n) end
  return R.foot
 end
 -- a bank (one course high) rounds over its whole height on the maps that ask for it; a taller mass
 -- keeps SOFT_ROUND, so a sea stack or a reef wall beside a beach stays crisp
 local round=M.SOFT_ROUND
 local deep=M.BANK_ROUND[mass.mapId or '']
 if deep then
  local hi=0
  for _,m in ipairs(mass.members)do local h=R.H[m];if h and h>hi then hi=h end end
  if hi-(R.foot or 0)<=M.COURSE then round=deep end
 end
 local acc,cnt={},{}
 for _,p in ipairs(all)do
  local gx,gy,k=p[1],p[2],p[3]
  local h
  if M.SOFT then
   local sum=0
   for dy=-1,1 do for dx=-1,1 do sum=sum+stepAt(gx+dx,gy+dy) end end
   -- (rounded at most SOFT_ROUND under the top: a thin wall stays a wall with a soft rim, not a knife ridge)
   -- (and never above its own top: a lower rock cell beside a taller one stayed its height -- raised by
   -- the mean, the two ran together into a ramp)
   local own=stepAt(gx,gy)
   h=math.min(own,math.max(sum/9,own-round))
  else
  local px,py=gx*M.PATCH+M.PATCH/2,gy*M.PATCH+M.PATCH/2
  local fx,fy=(px-8)/16,(py-8)/16
  local x0,y0=math.floor(fx),math.floor(fy);local tx,ty=fx-x0,fy-y0
  local t=(1-tx)*(1-ty)*Hc(x0,y0)+tx*(1-ty)*Hc(x0+1,y0)+(1-tx)*ty*Hc(x0,y0+1)+tx*ty*Hc(x0+1,y0+1)
  h=t
  if dist[k] then
   local base=flo[k];local dd=(dist[k]+.5)*M.PATCH
   h=base+math.min(math.max(t-base,0),M.SMOOTH_LIP+M.SMOOTH_SLOPE*dd)
  end
  end
  local cx,cy=math.floor(gx/N),math.floor(gy/N);local n=cellAt(cx,cy);local s=cellAt(cx,cy+1)
  if n and R.tallS[n] and gy-cy*N==N-1 and not (s and R.inMass[s]) then h=R.H[n] end
  SP.HP[k]=h
  for _,v in ipairs({{gx,gy},{gx+1,gy},{gx+1,gy+1},{gx,gy+1}})do
   local vk=v[1]..':'..v[2];acc[vk]=(acc[vk] or 0)+h;cnt[vk]=(cnt[vk] or 0)+1
  end
 end
 for vk,v in pairs(acc)do SP.VH[vk]=v/cnt[vk] end
 return SP
end

-- the rock standing in this cell (absolute heights), patch by patch
-- Does this rock cell build nothing above its own floor? (a flank tile flush with the beach beside
-- it: H at the foot.) Gen3Terrain asks, so a rock it builds beside such a cell slopes down to it
-- instead of treating it as solid and leaving its own side open (Route 124's sea stack stood over a
-- hole, the first-person survey's magenta probe).
function M.flat(c,cells)
 if c and c.rockFlat~=nil then return c.rockFlat end   -- (asked for every corner of every fallback rock)
 local mass=c and c.mass
 local r=false
 if mass and cells and not mass.hill and M.handles(mass,cells) then
  local R=prepare(mass,cells)
  local H=R.inMass[c] and R.H[c]
  r=H~=nil and H<=math.max(R.foot or 0,c.base or 0)+2
 end
 if c then c.rockFlat=r end
 return r
end
function M.append(mass,cells,emit,uvFor,cell)
 if mass.relief then return V.require('Gen3Relief').append(mass,cells,emit,uvFor,cell) end
 if mass.hill then return V.require('Gen3Hills').append(mass,cells,emit,uvFor,cell) end
 local R=prepare(mass,cells)
 local c=cell
 if not c or not R.inMass[c] then return true end
 local H=R.H[c];if not H then return true end
 local S=M.PATCH;local N=16/S
 local x,z=c.cx*16,c.cy*16
 local own=uvFor(c.ts,c.mid)
 local ownInfo=tile(c.ts,c.mid)
 local face=ownInfo and ownInfo.face
 local lidMid=R.lidMid
 if not face then lidMid=c.mid else
  for k=1,4 do local n=cells[key(c.cx,c.cy-k)]
   if not (n and R.inMass[n]) then break end
   if not isFace(n) then lidMid=n.mid;break end
  end
 end
 -- (secret bases: its own tile on top too -- a poster was the commonest light tile and capped every wall)
 if M.OWN_FACE[mass.mapId or ''] then lidMid=c.mid end
 local lu=uvFor(c.ts,lidMid) or own
 -- a face whose top is flush with the walkable ground behind it (a cliff
 -- under a lawn): its top is that ground, not a strip of rock lid
 if face or M.FLANK[c.mid] or mass.terraceEnd then
  for _,d in ipairs({{0,-1},{-1,0},{1,0}})do
   local n=cells[key(c.cx+d[1],c.cy+d[2])]
   if n and not R.inMass[n] and walk(n) and math.abs(floorOf(n)-H)<=2 and n.shape and n.shape.kind=='flat' then
    lu=uvFor(n.ts,n.shape.groundMid or n.mid) or lu;break
   end
  end
 end
 -- clean face art: the mass's commonest face tile with no grass in it (a
 -- tile with a grass strip along its edge would print it on every face)
 if R.cleanFace==nil then
  local best,bn
  for _,m in ipairs(mass.members)do
   if isFace(m) and not (tile(m.ts,m.mid) or {}).foliage and groundCount(mass,cells,m.ts,m.mid)==0 then
    R.faceVotes=R.faceVotes or {}
    R.faceVotes[m.mid]=(R.faceVotes[m.mid] or 0)+1
    if not bn or R.faceVotes[m.mid]>bn then best,bn=m.mid,R.faceVotes[m.mid] end
   end
  end
  -- (a clean tile that is rare in the mass is something else standing in
  -- the rock -- a stalagmite, a grating: the mass's commonest face then)
  if best and R.faceMid and R.faceVotes and (R.faceVotes[best] or 0)<.25*(R.faceCount or 0) then best=nil end
  R.cleanFace=M.FACE_TILE[mass.mapId or ''] or best or R.faceMid
  if M.FLANK[R.cleanFace] and mass.members[1].ts.midToSlot[M.FRONT] then R.cleanFace=M.FRONT end
 end
 local fu=uvFor(c.ts,R.cleanFace) or own
 local finfo=tile(c.ts,R.cleanFace) or ownInfo
 -- (secret bases: every wall cell shows its own tile on its faces -- a poster
 -- hung on the north wall is that cell's tile, and as the mass's face art it
 -- papered the whole wall)
 if M.OWN_FACE[mass.mapId or ''] then fu,finfo=own,ownInfo or finfo end
 local ownClean=face and groundCount(mass,cells,c.ts,c.mid)==0
 local occ=occupancy(mass,cells,c)
 -- the ground under this cell (for its own carved-away patches)
 local low=R.foot
 for _,d in ipairs({{0,1},{1,0},{-1,0},{0,-1}})do
  local n=cells[key(c.cx+d[1],c.cy+d[2])]
  if n and not R.inMass[n] then low=floorOf(n);break end
 end
 -- (the scene lays this cell's ground at its own floor: a carved patch is that ground, not the beach
 -- below the terrace -- faces hung down to the beach under the grass and showed as lines through it)
 if c.base and c.base>low then low=c.base end
 -- (cell, patch) of a patch offset from this cell
 local function locate(cx,cy,i,j)
  if i<0 then cx=cx-1;i=i+N elseif i>=N then cx=cx+1;i=i-N end
  if j<0 then cy=cy-1;j=j+N elseif j>=N then cy=cy+1;j=j-N end
  return cells[key(cx,cy)],i,j
 end
 -- body height at a patch, before outcrop shaping
 local function baseAt(cx,cy,i,j)
  local n,ii,jj=locate(cx,cy,i,j)
  if n and R.inMass[n] then
   if occupancy(mass,cells,n)[jj*N+ii] then return R.H[n] end
   return low
  end
  return floorOf(n) or R.foot
 end
 -- outcrop shaping: a patch on an exposed edge of a tall rock breaks down
 -- 1..3 px, a corner (two exposed sides) 4..7 px: a ragged skyline and worn
 -- corners instead of a ruler edge (deterministic per patch)
 local function topAt(cx,cy,i,j)
  local n,ii,jj=locate(cx,cy,i,j)
  if not (n and R.inMass[n] and occupancy(mass,cells,n)[jj*N+ii]) then return baseAt(cx,cy,i,j) end
  local h=R.H[n]
  if h-R.foot<M.COURSE or not M.OUTCROP then return h end
  local ex=0
  for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
   if baseAt(n.cx,n.cy,ii+d[1],jj+d[2])<h-2 then ex=ex+1 end
  end
  if ex==0 then return h end
  local hash=(n.cx*73+n.cy*151+ii*37+jj*11)%7
  if ex>=2 then return h-4-(hash%4) end
  return h-1-(hash%3)
 end
 local function heightAt(i,j)return topAt(c.cx,c.cy,i,j)end
  -- (soft rock outdoors; caves, and maps whose rock is a drawn flank -- Route 112, Mt. Chimney -- keep blocks)
  if M.SMOOTH and (M.CAVE_SOFT or not M.CAVES[mass.mapId or '']) and not M.RUNFACE[mass.mapId or ''] and not M.SMOOTH_SKIP[mass.mapId or ''] and not M.OWN_FACE[mass.mapId or ''] then
   -- SMOOTH texturing: a surface whose every patch edge rises at most its 4 px run (45 degrees
   -- or less) is a TOP and takes the lid art 1:1 from x and z. A steeper one is a FACE and takes
   -- the face art in courses of world y (16 px, row 0 at each course's top), 1:1 along the face.
   -- Face pieces are cut at each course line, so no uv is interpolated across a course and
   -- nothing is sheared by its slope.
   local SP=smoothPrep(mass,cells,R)
   local function isIn(gx,gy)
    local cx,cy=math.floor(gx/N),math.floor(gy/N);local n=cells[key(cx,cy)]
    return (n and R.inMass[n] and occupancy(mass,cells,n)[(gy-cy*N)*N+(gx-cx*N)]) or false
   end
   local function groundOut(gx,gy)
    local cx,cy=math.floor(gx/N),math.floor(gy/N);local n=cells[key(cx,cy)]
    if n and R.inMass[n] then return low end
    if n then return floorOf(n) end
    return R.foot
   end
   -- uv of tile pixel (px,py) inside a uv rect (the same rect layout as sub)
   local function tuv(uv,px,py)
    local l,t,r,b=uv[1][1],uv[1][2],uv[3][1],uv[3][2]
    return {l+(r-l)*px/16,t+(b-t)*py/16}
   end
   -- art row of height y in the course that starts at base (row 0 at the course top)
   local function rowAt(base,y)return math.min(16,math.max(0,base+16-y))end
   -- one face piece inside one course: corner k is P[k] at tile column cols[k], height ys[k]
   -- (a face cell shows its own drawn face, not the mass's one face tile: on Route 112 that tile was a
   -- banded flank and every slope stood striped)
   local faceArt=(face and ownClean and ownInfo and not ownInfo.foliage and M.SOFT and not M.FACE_TILE[mass.mapId or '']) and own or fu
   local function facePiece(P,cols,ys,base,shade)
    local uv={}
    for k=1,4 do uv[k]=tuv(faceArt,cols[k],rowAt(base,ys[k])) end
    emit(P,uv,shade)
   end
   for j=0,N-1 do for i=0,N-1 do
    if occ[j*N+i] then
     local gx,gy=c.cx*N+i,c.cy*N+j
     local x0,z0=gx*S,gy*S
     local h00,h10,h11,h01=SP.VH[gx..':'..gy],SP.VH[(gx+1)..':'..gy],SP.VH[(gx+1)..':'..(gy+1)],SP.VH[gx..':'..(gy+1)]
     local dmax=math.max(math.abs(h10-h00),math.abs(h11-h01),math.abs(h01-h00),math.abs(h11-h10))
     if dmax<=S then
      -- a 4 px patch of the top that is partly drawn as ground -- the sand or grass strip along a
      -- cliff tile's edge -- takes the picture of the nearest patch of the same tile with none in it.
      -- Laid 1:1 those ground pixels drew a bright sand line along the top of a whole ridge (Route
      -- 104's shore: user, "all brown"). The block builder below has done this since CLEAN_TOPS; the
      -- smooth path drew the raw patch.
      local ci,cj=i,j
      if M.CLEAN_TOPS then
       local cp=cleanPatch(mass,cells,c.ts,lidMid)
       if cp and cp[j*N+i] then ci,cj=cp[j*N+i][1],cp[j*N+i][2] end
      end
      emit({{x0,h00,z0},{x0+S,h10,z0},{x0+S,h11,z0+S},{x0,h01,z0+S}},sub(lu,ci*S,cj*S,ci*S+S,cj*S+S),1)
     else
      -- a steep patch is a face: strips 1 px deep in z, each cut at the course lines
      -- of its own midline, so every piece's art runs level with the world courses
      local function hh(s,t)local a=h00+(h10-h00)*s/S;local b=h01+(h11-h01)*s/S;return a+(b-a)*t/S end
      local gxs=(h10-h00+h11-h01)/(2*S);local gzs=(h01-h00+h11-h10)/(2*S)
      local sh=math.abs(gxs)>=math.abs(gzs) and (gxs>0 and SHADE.west or SHADE.east) or (gzs>0 and SHADE.north or SHADE.south)
      for k=0,S-1 do
       local hm0,hm1=(hh(0,k)+hh(0,k+1))/2,(hh(S,k)+hh(S,k+1))/2
       local cuts={0,S}
       local lo,hi=math.min(hm0,hm1),math.max(hm0,hm1)
       for m=math.floor(lo/16)*16+16,hi,16 do
        if (hm0-m)*(hm1-m)<0 then cuts[#cuts+1]=S*(m-hm0)/(hm1-hm0) end
       end
       table.sort(cuts)
       for q=1,#cuts-1 do
        local sa,sb=cuts[q],cuts[q+1]
        if sb-sa>.01 then
         local base=math.floor((hm0+(hm1-hm0)*(sa+sb)/2/S)/16)*16
         local ys={hh(sa,k),hh(sb,k),hh(sb,k+1),hh(sa,k+1)}
         local cols={i*S+sa,i*S+sb,i*S+sb,i*S+sa}
         facePiece({{x0+sa,ys[1],z0+k},{x0+sb,ys[2],z0+k},{x0+sb,ys[3],z0+k+1},{x0+sa,ys[4],z0+k+1}},cols,ys,base,sh)
        end
       end
      end
     end
     -- each side that stands over lower ground is closed course by course down to that ground
     local edges={
      {-1,0,function(u,y)return {x0,y,z0+u}end,{h00,h01},j*S,SHADE.west,gx-1,gy},
      {1,0,function(u,y)return {x0+S,y,z0+u}end,{h10,h11},j*S,SHADE.east,gx+1,gy},
      {0,-1,function(u,y)return {x0+u,y,z0}end,{h00,h10},i*S,SHADE.north,gx,gy-1},
      {0,1,function(u,y)return {x0+u,y,z0+S}end,{h01,h11},i*S,SHADE.south,gx,gy+1}}
     for _,e in ipairs(edges)do
      local nx,ny=e[7],e[8]
      if not isIn(nx,ny) then
       local F=groundOut(nx,ny)
       local fn=cells[key(math.floor(nx/N),math.floor(ny/N))]
       if fn and not R.inMass[fn] then F=math.min(F,sideFloor(fn,cells)) end
       -- (a rock over a sunken cell stands on that cell's own ground: Mossdeep's bluff hung 13 px above its 48 floor)
       if M.SKIRT[mass.mapId or ''] and c.base and c.base<F then F=c.base end
       local ta,tb=e[4][1],e[4][2]
       local function tu(u)return ta+(tb-ta)*u/S end
       local top=math.max(ta,tb)
       -- the wall cut at the ground and at each course line of world y
       local cut={F}
       for m=math.floor(F/16)*16+16,top,16 do cut[#cut+1]=m end
       cut[#cut+1]=top
       for q=1,#cut-1 do
        local yb,yt=cut[q],cut[q+1]
        if yt>yb+.01 then
         local a0,a1=math.max(yb,math.min(yt,tu(0))),math.max(yb,math.min(yt,tu(S)))
         if math.max(a0,a1)>yb+.01 then
          local base=math.floor((yb+.01)/16)*16
          local P={e[3](0,yb),e[3](S,yb),e[3](S,a1),e[3](0,a0)}
          facePiece(P,{e[5],e[5]+S,e[5]+S,e[5]},{yb,yb,a1,a0},base,e[6])
         end
        end
       end
      end
     end
    end
   end end
   return true
  end
 for j=0,N-1 do for i=0,N-1 do
  if occ[j*N+i] then
   local px,pz=x+i*S,z+j*S
   local T=topAt(c.cx,c.cy,i,j)
   -- the top patch is drawn from the lid art at this patch's place
   local ci,cj=i,j
   if M.CLEAN_TOPS then
    local cp=cleanPatch(mass,cells,c.ts,lidMid)[j*N+i]
    if cp then ci,cj=cp[1],cp[2] end
   end
   emit({{px,T,pz},{px+S,T,pz},{px+S,T,pz+S},{px,T,pz+S}},sub(lu,ci*S,cj*S,ci*S+S,cj*S+S),1)
   local sides={
    {0,1,'south',function(u,h,o)return {x+u,h,pz+S+o}end,i*S},
    {0,-1,'north',function(u,h,o)return {x+16-u,h,pz-o}end,16-(i+1)*S},
    {1,0,'east',function(u,h,o)return {px+S+o,h,z+16-u}end,16-(j+1)*S},
    {-1,0,'west',function(u,h,o)return {px-o,h,z+u}end,j*S}}
   for _,s in ipairs(sides)do
    local nh=heightAt(i+s[1],j+s[2])
    -- (a face onto ground outside the mass runs down to the cell's own ground
    -- too: a rock over a sunken cell stood on the floor beside it, open below)
    local nIn=locate(c.cx,c.cy,i+s[1],j+s[2])
    if c.base and not (nIn and R.inMass[nIn]) then nh=math.min(nh,c.base) end
    if nIn and not R.inMass[nIn] then nh=math.min(nh,sideFloor(nIn,cells)) end
    if nh<T then
     -- the south face shows the cell's own drawing in its top course
     local useOwn=(s[3]=='south' and ownClean)
     segment(emit,s[4],useOwn and own or fu,useOwn and ownInfo or finfo,s[5],s[5]+S,T,nh,H,SHADE[s[3]])
    end
   end
  end
 end end
 return true
end

-- AUDIT (M.audit, debug, default off): a rock object whose lowest emitted point
-- is more than a pixel above the ground under it is printed as floating. Gen3Mass
-- calls checkFloat once per mass: run(c,emit) emits cell c's share (c=nil for an
-- object, which has no cells). Ground under a cell is its own floor (c.base; sea 0).
M.audit=false
M.auditN=0
function M.checkFloat(mass,cells,path,run,groundOf)
 if not M.audit or mass.audited then return end
 mass.audited=true
 M.auditN=M.auditN+1
 local lowAll,at=math.huge,nil
 for _,c in ipairs(cells and mass.members or {false})do
  local lo=math.huge
  run(c or nil,function(v)for _,q in ipairs(v)do if q[2]<lo then lo=q[2] end end end)
  if lo<lowAll then lowAll,at=lo,c end
 end
 if lowAll==math.huge then return end
 -- ground under a cell: its own floor; a cell in or at the water stands on the surface (water is drawn at
 -- y=.05 for every water cell, Gen3Scene), level 0
 local function under(c)
  local g=c.base or 0
  if g<=0 then
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    local n=cells and cells[key(c.cx+d[1],c.cy+d[2])]
    if n and n.mass~=mass and n.shape and n.shape.kind=='water' then return 0 end
   end
  end
  return g
 end
 local ground=math.huge
 if groundOf then ground=groundOf() elseif at then ground=under(at) else
  for _,c in ipairs(mass.members or {})do ground=math.min(ground,under(c)) end
 end
 if ground==math.huge then ground=0 end
 if lowAll>ground+1 then
  local kind=(mass.object and 'object' or 'mass')..(mass.seaBoulders and ' sea' or '')..(mass.bank and ' bank' or '')
  print(('[RK1 float] %s %s cells=%d bottom=%.1f ground=%.1f lowest=%s path=%s'):format(tostring(M.mapId),kind,
   #(mass.members or {}),lowAll,ground,at and (at.cx..','..at.cy) or '-',path))
 end
end

-- F040/G2: what a tile's drawing is (face, lid, foliage) for the builders that lay a cell's own or a
-- neighbour's art on rock: Gen3Relief takes no wall art from a foliage-drawn cell (green stripes up the face)
M.tileArt=tile
return M
