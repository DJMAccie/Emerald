-- Landmarks: the object events whose sprite is a thing, not a person.
--
-- A person is a card and reads correctly as one. A truck is not: drawn as a
-- card it is a wall of pixels leaning against whatever it stands near, and
-- the oblique drawing's roof band reads as a slab glued to its side. Those
-- gids get a closed voxel model built from their own artwork instead, by
-- SpriteVoxel. Everything else keeps the card path untouched.
--
-- Recipes are written in sprite pixels, read straight off the drawing. See
-- SpriteVoxel for the projection that makes that possible: a point's screen
-- row in a Gen 3 object drawing is its height above the ground PLUS its
-- depth away from the viewer, so the drawing's lower band is the south wall
-- and its upper band is the top, both 1:1.
local V=...
local SpriteVoxel=V.require('SpriteVoxel')
local M={log=false}
local built={}

-- gid 94: the moving van (48x48, inanimate), drawn cab-west and box-east.
--   columns 0..16   the cab          17..47   the cargo box
--   rows   28..41   cab wall         24..41   box wall
--   rows   12..27   cab roof         8..23    box roof
--   rows   42..47   wheels          39..41   undercarriage band
-- The rects below are exactly those bands, so each wall and each roof is
-- painted by the same pixels the card would have shown, now on the plane
-- they were drawn for.
local TRUCK={
 width=48,
 boxes={
  -- Read straight off the drawing with the oblique rule (screen row =
  -- depth - height; ground row 47 is the front edge). Every face takes
  -- exactly as many drawing pixels as it is wide/tall/deep: nothing is
  -- stretched. The cab's white roof is rows 12..26 over its windscreen wall
  -- (rows 27..41); the box's ribbed roof is rows 8..23 over its emblem wall
  -- (rows 24..41). Both come out 15-16 deep, as the art implies. The north
  -- side repeats the south (the van is symmetric); the ends take each row's
  -- own edge pixel.
  {name='nose',x0=0,x1=3,y0=6,y1=17,d0=0,d1=16,
   -- (the van's front, as its drawing shows it at the cab's west edge: white panel over the grey
   -- bumper, across the whole width; the windscreen is the dark band of the cab face above it)
   paint={south={x=0,y=31,w=3,h=11},north={x=0,y=31,w=3,h=11},top={x=1,y=24,w=1,h=1},
    west={x=1,y=31,w=1,h=11},east={x=2,y=31,w=1,h=11},bottom={x=0,y=41,w=3,h=1}}},
  {name='cab_edge',x0=3,x1=5,y0=6,y1=21,d0=0,d1=16,
   paint={south={x=3,y=27,w=2,h=15},north={x=3,y=27,w=2,h=15},top={x=3,y=14,w=2,h=13},
    west={x=5,y=30,w=1,h=1},east={x=4,y=27,w=1,h=15},bottom={x=3,y=41,w=2,h=1}}},
  {name='cab',x0=5,x1=16,y0=6,y1=21,d0=0,d1=16,
   paint={south={x=5,y=27,w=11,h=15},north={x=5,y=27,w=11,h=15},top={x=5,y=12,w=11,h=15},
    west={x=5,y=30,w=1,h=1},east={x=15,y=27,w=1,h=15},bottom={x=5,y=41,w=11,h=1}}},
  {name='body',x0=16,x1=48,y0=6,y1=24,d0=0,d1=16,
   paint={south={x=16,y=24,w=32,h=18},north={x=16,y=24,w=32,h=18},
    top={x=16,y=8,w=32,h=16},
    east={x=46,y=24,w=1,h=18},west={x=17,y=24,w=1,h=18},
    bottom={x=16,y=41,w=32,h=1}}},
  -- Chassis between the wheels, inboard of them, as the drawing's grey band
  -- under the body shows.
  {name='chassis',x0=0,x1=48,y0=4,y1=6,d0=4,d1=12,flat={x=20,y=44,w=1,h=1},
   paint={south={x=20,y=44,w=1,h=1}}},
  -- Two axles, each a wheel a side. Front wheels sit under the cab, rear
  -- wheels under the box, and both are the drawing's own wheel (rows 42..47).
  {name='wheel_fl',x0=6,x1=16,y0=0,y1=6,d0=0,d1=4,
   paint={south={x=6,y=42,w=10,h=6},north={x=9,y=42,w=1,h=1},top={x=9,y=42,w=1,h=1},
    bottom={x=9,y=42,w=1,h=1},east={x=9,y=42,w=1,h=1},west={x=9,y=42,w=1,h=1}}},
  {name='wheel_fr',x0=6,x1=16,y0=0,y1=6,d0=12,d1=16,
   paint={north={x=6,y=42,w=10,h=6},south={x=9,y=42,w=1,h=1},top={x=9,y=42,w=1,h=1},
    bottom={x=9,y=42,w=1,h=1},east={x=9,y=42,w=1,h=1},west={x=9,y=42,w=1,h=1}}},
  {name='wheel_rl',x0=32,x1=41,y0=0,y1=6,d0=0,d1=4,
   paint={south={x=32,y=42,w=9,h=6},north={x=35,y=43,w=1,h=1},top={x=35,y=43,w=1,h=1},
    bottom={x=35,y=43,w=1,h=1},east={x=35,y=43,w=1,h=1},west={x=35,y=43,w=1,h=1}}},
  {name='wheel_rr',x0=32,x1=41,y0=0,y1=6,d0=12,d1=16,
   paint={north={x=32,y=42,w=9,h=6},south={x=35,y=43,w=1,h=1},top={x=35,y=43,w=1,h=1},
    bottom={x=35,y=43,w=1,h=1},east={x=35,y=43,w=1,h=1},west={x=35,y=43,w=1,h=1}}},
 },
}

-- gid 59: Poké Ball item (16x16, inanimate). A 10x8x8 voxel sphere sitting on
-- the ground, with red dome, dark belt and white base.
local ITEM_BALL={
 width=16,
 boxes={
  {name='core',x0=4,x1=12,y0=1,y1=8,d0=1,d1=8,
   paint={south={x=3,y=5,w=10,h=10},north={x=3,y=5,w=10,h=10},
    top={x=4,y=5,w=8,h=4},bottom={x=4,y=11,w=8,h=4},
    east={x=3,y=5,w=10,h=10},west={x=3,y=5,w=10,h=10}}},
  {name='waist',x0=3,x1=13,y0=2,y1=7,d0=2,d1=7,
   paint={south={x=3,y=5,w=10,h=10},north={x=3,y=5,w=10,h=10},
    top={x=4,y=5,w=8,h=3},bottom={x=4,y=11,w=8,h=3},
    east={x=3,y=5,w=10,h=10},west={x=3,y=5,w=10,h=10}}},
  {name='top_cap',x0=5,x1=11,y0=8,y1=9,d0=2,d1=7,
   paint={top={x=5,y=5,w=6,h=2},south={x=5,y=5,w=6,h=1},north={x=5,y=5,w=6,h=1},
    east={x=5,y=5,w=1,h=2},west={x=10,y=5,w=1,h=2}}},
  {name='bot_cap',x0=5,x1=11,y0=0,y1=1,d0=2,d1=7,
   paint={bottom={x=5,y=13,w=6,h=2},south={x=5,y=13,w=6,h=1},north={x=5,y=13,w=6,h=1},
    east={x=5,y=13,w=1,h=2},west={x=10,y=13,w=1,h=2}}},
  {name='front_cap',x0=5,x1=11,y0=3,y1=6,d0=0,d1=1,
   paint={south={x=5,y=8,w=6,h=4},top={x=5,y=5,w=6,h=2},bottom={x=5,y=12,w=6,h=2},
    east={x=4,y=8,w=1,h=4},west={x=11,y=8,w=1,h=4}}},
  {name='back_cap',x0=5,x1=11,y0=3,y1=6,d0=8,d1=9,
   paint={north={x=5,y=8,w=6,h=4},top={x=5,y=5,w=6,h=2},bottom={x=5,y=12,w=6,h=2},
    east={x=4,y=8,w=1,h=4},west={x=11,y=8,w=1,h=4}}},
 },
}

-- gid 82: Cuttable tree (16x16, inanimate). A round leafy shrub-tree with a
-- visible wood trunk and dome canopy.
local CUTTABLE_TREE={
 width=16,
 boxes={
  -- Wood trunk (4x4x4)
  {name='trunk',x0=6,x1=10,y0=0,y1=4,d0=6,d1=10,
   paint={south={x=6,y=12,w=4,h=3},north={x=6,y=12,w=4,h=3},
    east={x=6,y=12,w=4,h=3},west={x=6,y=12,w=4,h=3},
    bottom={x=6,y=13,w=4,h=2}}},
  -- Main foliage core (10x10x10)
  {name='crown_core',x0=3,x1=13,y0=4,y1=14,d0=3,d1=13,
   paint={south={x=1,y=1,w=14,h=11},north={x=1,y=1,w=14,h=11},
    top={x=3,y=1,w=10,h=6},bottom={x=3,y=8,w=10,h=4},
    east={x=1,y=1,w=14,h=11},west={x=1,y=1,w=14,h=11}}},
  -- Crown broad equator (14x6x8)
  {name='crown_wide',x0=1,x1=15,y0=6,y1=12,d0=4,d1=12,
   paint={south={x=1,y=1,w=14,h=11},north={x=1,y=1,w=14,h=11},
    top={x=1,y=1,w=14,h=5},bottom={x=1,y=7,w=14,h=4},
    east={x=1,y=1,w=14,h=11},west={x=1,y=1,w=14,h=11}}},
  -- Crown deep equator (8x6x12)
  {name='crown_deep',x0=4,x1=12,y0=6,y1=12,d0=2,d1=14,
   paint={south={x=1,y=1,w=14,h=11},north={x=1,y=1,w=14,h=11},
    top={x=3,y=1,w=10,h=6},bottom={x=3,y=8,w=10,h=4},
    east={x=1,y=1,w=14,h=11},west={x=1,y=1,w=14,h=11}}},
  -- Crown top crest (6x1x6)
  {name='crown_top',x0=5,x1=11,y0=14,y1=15,d0=5,d1=11,
   paint={top={x=4,y=1,w=8,h=3},south={x=4,y=1,w=8,h=1},north={x=4,y=1,w=8,h=1},
    east={x=4,y=1,w=1,h=1},west={x=11,y=1,w=1,h=1}}},
 },
}

-- gid 86: Breakable rock (Rock Smash, 16x16, inanimate). A jagged cracked
-- boulder sitting on the ground.
local BREAKABLE_ROCK={
 width=16,
 boxes={
  -- Broad lower base (12x6x12)
  {name='base',x0=2,x1=14,y0=0,y1=6,d0=2,d1=14,
   paint={south={x=1,y=2,w=14,h=14},north={x=1,y=2,w=14,h=14},
    top={x=4,y=2,w=8,h=6},bottom={x=4,y=12,w=8,h=3},
    east={x=1,y=2,w=14,h=14},west={x=1,y=2,w=14,h=14}}},
  -- Upper block (8x5x8)
  {name='upper',x0=4,x1=12,y0=6,y1=11,d0=4,d1=12,
   paint={south={x=1,y=2,w=14,h=14},north={x=1,y=2,w=14,h=14},
    top={x=4,y=2,w=8,h=6},bottom={x=4,y=12,w=8,h=3},
    east={x=1,y=2,w=14,h=14},west={x=1,y=2,w=14,h=14}}},
  -- Top crest (4x2x5)
  {name='crest',x0=6,x1=10,y0=11,y1=13,d0=5,d1=10,
   paint={south={x=6,y=2,w=4,h=3},north={x=6,y=2,w=4,h=3},
    top={x=6,y=2,w=4,h=3},east={x=6,y=2,w=1,h=2},west={x=9,y=2,w=1,h=2}}},
  -- Side flanks (14x3x8)
  {name='flanks',x0=1,x1=15,y0=2,y1=5,d0=4,d1=12,
   paint={south={x=1,y=2,w=14,h=14},north={x=1,y=2,w=14,h=14},
    top={x=3,y=5,w=10,h=4},bottom={x=3,y=12,w=10,h=3},
    east={x=1,y=2,w=14,h=14},west={x=1,y=2,w=14,h=14}}},
 },
}

-- gid 87: Pushable boulder (Strength, 16x16, inanimate). A massive solid
-- round boulder.
local PUSHABLE_BOULDER={
 width=16,
 boxes={
  -- Core mass (12x10x12)
  {name='core',x0=2,x1=14,y0=2,y1=12,d0=2,d1=14,
   paint={south={x=0,y=0,w=16,h=16},north={x=0,y=0,w=16,h=16},
    top={x=2,y=0,w=12,h=8},bottom={x=2,y=10,w=12,h=6},
    east={x=0,y=0,w=16,h=16},west={x=0,y=0,w=16,h=16}}},
  -- Broad equator (16x6x10)
  {name='wide',x0=0,x1=16,y0=4,y1=10,d0=3,d1=13,
   paint={south={x=0,y=0,w=16,h=16},north={x=0,y=0,w=16,h=16},
    top={x=2,y=0,w=12,h=8},bottom={x=2,y=10,w=12,h=6},
    east={x=0,y=0,w=16,h=16},west={x=0,y=0,w=16,h=16}}},
  -- Deep equator (10x6x14)
  {name='deep',x0=3,x1=13,y0=4,y1=10,d0=1,d1=15,
   paint={south={x=0,y=0,w=16,h=16},north={x=0,y=0,w=16,h=16},
    top={x=2,y=0,w=12,h=8},bottom={x=2,y=10,w=12,h=6},
    east={x=0,y=0,w=16,h=16},west={x=0,y=0,w=16,h=16}}},
  -- Top dome cap (8x2x8)
  {name='top_dome',x0=4,x1=12,y0=12,y1=14,d0=4,d1=12,
   paint={top={x=3,y=0,w=10,h=5},south={x=3,y=0,w=10,h=2},north={x=3,y=0,w=10,h=2},
    east={x=3,y=0,w=2,h=2},west={x=11,y=0,w=2,h=2}}},
  -- Base (10x2x10)
  {name='base',x0=3,x1=13,y0=0,y1=2,d0=3,d1=13,
   paint={bottom={x=3,y=12,w=10,h=4},south={x=3,y=12,w=10,h=2},north={x=3,y=12,w=10,h=2},
    east={x=3,y=12,w=2,h=2},west={x=11,y=12,w=2,h=2}}},
 },
}

-- gid 97: Birch's bag (16x16, inanimate). A field bag on the grass with a
-- strap loop.
local BIRCHS_BAG={
 width=16,
 boxes={
  -- Main pouch (11x10x8)
  {name='pouch',x0=3,x1=14,y0=0,y1=10,d0=3,d1=11,
   paint={south={x=2,y=1,w=13,h=14},north={x=2,y=1,w=13,h=14},
    top={x=3,y=1,w=10,h=6},bottom={x=4,y=12,w=8,h=3},
    east={x=2,y=1,w=13,h=14},west={x=2,y=1,w=13,h=14}}},
  -- Handle strap (8x4x3)
  {name='strap',x0=4,x1=12,y0=10,y1=14,d0=5,d1=8,
   paint={south={x=3,y=1,w=9,h=5},north={x=3,y=1,w=9,h=5},
    top={x=3,y=1,w=9,h=3},east={x=3,y=1,w=2,h=4},west={x=10,y=1,w=2,h=4}}},
 },
}

local RECIPES={
 [94]=TRUCK,
 -- [59] (item ball) is a body of revolution from its own sprite now (Gen3RockSprites), not a stack of boxes
 [82]=CUTTABLE_TREE,
 [86]=BREAKABLE_ROCK,
 [87]=PUSHABLE_BOULDER,
 [97]=BIRCHS_BAG,
}

function M.recipe(gid)
 local n=tonumber(gid)
 return n and RECIPES[n] or nil
end

-- The model for this gid, built once from the sprite the card path would
-- have drawn. Returns nil for every gid without a recipe, and for a build
-- that produced nothing -- the caller then keeps the card.
function M.mesh(gid,spr)
 local n=tonumber(gid)
 if not n then return nil end
 local hit=built[n]
 if hit then return hit.mesh end
 local recipe=RECIPES[n]
 if not recipe then return nil end
 local mesh,stats=SpriteVoxel.build(spr,recipe)
 built[n]={mesh=mesh or false}
 if M.log then
  print(('[LANDMARK] gid=%d %s'):format(n,mesh
   and ('quads=%d boundaryFaces=%d boxes=%d'):format(stats.quads or 0,stats.faces or 0,stats.boxes or 0)
   or 'no model -- card path kept'))
 end
 return mesh
end

-- A modelled solid occupies every cell its model covers, not only the
-- object's own cell (the van's cab and box stand on the cells either side):
-- while the 3D field is on, those cells block like the object itself. The
-- original value is restored as soon as the object is gone or 3D is off.
-- gid -> list of {dx,dy} cells beside the object's own cell
-- gid -> how much larger than its drawing the model stands (the van was barely taller than the player)
M.SCALE={[94]=1.4}
M.SOLID_CELLS={[94]={{-1,0},{1,0}}}
local held={}        -- [index] = original collision value
local heldGrid
function M.syncCollision(on)
 local okC,Collision=pcall(require,'src.core.game3.collision')
 local okO,Objects=pcall(require,'src.core.game3.objects')
 if not (okC and okO) then return end
 local grid,w=Collision._grid,Collision._widthCells
 if grid~=heldGrid then held={};heldGrid=grid end   -- a rebind rebuilt it
 if not (grid and w) then return end
 local want={}
 if on then
  for _,lid in ipairs(Objects._order or {})do
   local eo=Objects._byId and Objects._byId[lid]
   local cells=eo and eo.visible and not eo.hidden and M.SOLID_CELLS[tonumber(eo.graphicsId)]
   if cells then
    for _,d in ipairs(cells)do
     local x,y=(eo.cellX or 0)+d[1],(eo.cellY or 0)+d[2]
     if x>=0 and y>=0 and x<w then want[y*w+x+1]=true end
    end
   end
  end
 end
 for i,orig in pairs(held)do if not want[i] then grid[i]=orig;held[i]=nil end end
 for i in pairs(want)do
  if held[i]==nil and grid[i]==0 then held[i]=grid[i];grid[i]=0x07 end   -- 0x07 = solid
 end
end

function M.release()
 for _,m in pairs(built)do if m.mesh then m.mesh:release() end end
 built={}
end

return M
