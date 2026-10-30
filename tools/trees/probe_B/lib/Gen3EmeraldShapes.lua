-- Emerald metatile recipes for the Gen 3 scene (lib/Gen3Scene.lua).
--
-- Gen3TileShape.lua carries FireRed/LeafGreen numbers and stands down on any
-- other Gen 3 cart; this module answers instead. Two sources, in this order:
--
--  1. The cart's own metatile BEHAVIOR (src/core/game3/mb.lua canonical ids:
--     a name FireRed also has keeps FireRed's number, an Emerald-only name
--     sits at 0x100 + its raw value). Ledges, rails, grass, water and
--     mountain caps are the same thing on every Hoenn map, so they never
--     need a per-tileset table.
--  2. Reviewed metatile ids, scoped by the pret tileset the importer named
--     the pair after (general__petalburg -> primary 'general', secondary
--     'petalburg'). Roofs, walls, trees and cliff art are drawings, so they
--     are listed by id; collision then vetoes extrusion the way it does for
--     FireRed (a walkable copy of a cliff cap stays at floor level).
--
-- Ids were read off labelled renders of the imported maps (Littleroot,
-- Route 101, Oldale: tools/mapsheet.py), not guessed from the atlas alone.
-- Hoenn conventions that differ from Kanto:
--  * A tree is two cells wide and THREE tall: a walkable grass row carrying
--    the canopy's overhang (0x1CE/0x1CF, tall grass 0x1C6/0x1C7), the canopy
--    (0x1D4-0x1D7) and the trunk (0x1DC/0x1DD; 0x1E4-0x1E7 where the next
--    tree's overhang merges in). The trunk's left cell owns the model.
--  * The top row of a roof is walkable: the player walks BEHIND buildings.
--    It is still part of the facade, so the roof covers them in 3D.
--
-- These are presentation recipes, never movement rules. Unlisted art stays
-- flat; never infer a wall from a blocked floor alone.
local V=...
local M={}

local B={
 TALL_GRASS=0x02,LONG_GRASS=0x103,SHORT_GRASS=0x107,ASHGRASS=0x124,
 JUMP_EAST=0x38,JUMP_WEST=0x39,JUMP_NORTH=0x3A,JUMP_SOUTH=0x3B,
 JUMP_SOUTHEAST=0x13E,JUMP_SOUTHWEST=0x13F,
 MOUNTAIN_TOP=0x0C,CAVE=0x08,LADDER=0x61,WARP_DOOR=0x69,CAVE_DOOR=0x60,
 HORIZONTAL_RAIL=0x1D6,VERTICAL_RAIL=0x1D5,
 ISOLATED_HORIZONTAL_RAIL=0x1D4,ISOLATED_VERTICAL_RAIL=0x1D3,
 INTERIOR_DEEP_WATER=0x111,SOOTOPOLIS_DEEP_WATER=0x114,
 SEAWEED=0x22,SEAWEED_NO_SURFACING=0x12A,WATERFALL=0x13,PUDDLE=0x16,
 BERRY_TREE_SOIL=0x1A0,MUDDY_SLOPE=0x1D0,BUMPY_SLOPE=0x1D1,
}
M.behaviors=B
local BLOCKED=7 -- LayoutNative coll for an impassable cell, as Gen3TileShape reads it

local function set(list)local t={};for _,id in ipairs(list)do t[id]=true end;return t end
local function span(t,from,to)for id=from,to do t[id]=true end;return t end

-- ------- General (primary) --------------------------------------------------
local G={}
G.grass=0x001
G.sand=0x11C

-- Mountain and cliff art: the brown rounded caps, faces and corners. Only a
-- blocked cell extrudes; walkable caps carry MOUNTAIN_TOP and sit on their
-- native elevation layer instead. 0x06E is a ledge corner, not a cliff.
G.cliff={}
span(G.cliff,0x068,0x06D);span(G.cliff,0x070,0x07D)
span(G.cliff,0x080,0x084);span(G.cliff,0x088,0x08C)
span(G.cliff,0x090,0x094);span(G.cliff,0x09B,0x09E)
G.cliff[0x0A0]=true;span(G.cliff,0x0A2,0x0A4);span(G.cliff,0x0A8,0x0AC)
span(G.cliff,0x0B4,0x0B7);G.cliff[0x0BD]=true;G.cliff[0x0BE]=true
span(G.cliff,0x0E0,0x0E2);G.cliff[0x0E4]=true;G.cliff[0x0E7]=true;G.cliff[0x0EE]=true;G.cliff[0x0EF]=true
span(G.cliff,0x160,0x16F);span(G.cliff,0x175,0x17F);G.cliff[0x158]=true;G.cliff[0x15C]=true
-- the other three quarters of the 2x2 boulder in rough water (0x158 is its fourth)
G.cliff[0x150]=true;G.cliff[0x151]=true;G.cliff[0x159]=true
-- Boulders standing in open water (Route 103, the sea routes): a low rock, not
-- a 32-unit retaining cliff.
G.seaRock=set({0x150,0x151,0x158,0x159,0x15C,0x175,0x176,0x177,0x178,0x179,0x17A,0x17B,0x17C,0x17D,0x17E,0x17F})
span(G.cliff,0x182,0x184);G.cliff[0x187]=true
G.cliff[0x1EE]=true;G.cliff[0x1EF]=true;G.cliff[0x1F0]=true;G.cliff[0x1F1]=true
G.cliffCap=0x0DC   -- cap texture for the raised top
G.cliffSide=0x0E1  -- face texture for the vertical drop

-- Ledge ends that carry no jump behavior of their own (the corner where a
-- ledge turns). The jumpable body and ends come from JUMP_* behaviors.
G.ledgeLeft=set({0x06E})
-- 0x06F is 0x06E's mirror: the run's lip rounding down into a side ledge below it (Route 104 30,55,
-- Route 118, Lilycove). Unlisted, it fell to the shrub list and stood as a post above the lip.
G.ledgeRight=set({0x06F})

-- Buildings drawn in the General tileset (every town shares these). Rows are
-- listed as they stand on the map, roof rows over wall rows; Gen3TileShape
-- .column folds each vertical run into a facade.
local roof,wall={},{}
local function building(roofIds,wallIds)
 for _,id in ipairs(roofIds)do roof[id]=true end
 for _,id in ipairs(wallIds)do wall[id]=true end
end
-- Route house: red tiled roof, tan/brown walls, red door 0x021.
building({0x008,0x009,0x00A,0x010,0x011,0x012},
 {0x018,0x019,0x01A,0x020,0x021,0x022,0x00B,0x00C,0x013,0x014})
-- Poke Mart (Oldale): blue roof top 0x028-0x02B over the blue ball-logo slope
-- 0x030-0x033, then the white upper wall and the door/MART board row.
building({0x028,0x029,0x02A,0x02B,0x030,0x031,0x032,0x033},
 {0x038,0x039,0x03A,0x03B,0x040,0x041,0x042,0x043})
-- Pokemon Center (Oldale): red roof top 0x048-0x04B over the ball-logo slope
-- 0x050-0x053, then the white upper wall and the door/P.C board row.
building({0x048,0x049,0x04A,0x04B,0x050,0x051,0x052,0x053},
 {0x058,0x059,0x05A,0x05B,0x060,0x061,0x062,0x063})
-- Gym: grey stone with the GYM board; door 0x1CD.
building({0x130,0x132},
 {0x1C0,0x1C1,0x1C2,0x1C3,0x1C4,0x1C5,0x1C8,0x1C9,0x1CA,0x1CB,0x1CC,0x1CD})
-- Thatched yellow roof over a white lower wall (route-side buildings).
building({0x1AA,0x1AB,0x1AC,0x1B2,0x1B3,0x1B4},{0x1B8,0x1B9,0x1BA,0x1BB,0x1BC})
G.roof,G.wall=roof,wall

-- Trees (see the header). Overhang rows are walkable grass and stay flat: the
-- model's canopy already occupies that space in 3D.
G.treeTop=set({0x1D4,0x1D5,0x1D6,0x1D7})
G.treeRootLeft=set({0x1DC,0x1E4,0x1E6})
G.treeRootRight=set({0x1DD,0x1E5,0x1E7})
G.treeOverhang=set({0x1CE,0x1CF})       -- grass under a canopy edge
G.treeOverhangGrass=set({0x1C6,0x1C7})  -- tall grass under a canopy edge
-- Native tree drawing for the ORIGINAL art mode: canopy row over trunk row.
-- The whole drawing is three rows: the tip painted over the grass row above
-- (0x1CE/0x1CF), the canopy, then the lower foliage and trunk.
G.treeArt={{0x1CE,0x1CF},{0x1D4,0x1D5},{0x1DC,0x1DD}}

-- Dense forest canopy (Route 119, Petalburg Woods edges): one blocked cell per
-- tree crown, so each stands its own smaller tree. The one-cell-wide tree is
-- a canopy over a trunk at 0x00E/0x016 and 0x00F/0x017.
G.canopyTree=set({0x0C6,0x0C7,0x0CE})
G.narrowTreeTop={[0x00E]=0x016,[0x00F]=0x017}
G.narrowTreeRoot={[0x016]=0x00E,[0x017]=0x00F}
G.flowers=set({0x004})
G.shrub=set({0x193})
G.sign=set({0x003,0x01B,0x131})
G.rockInWater=set({0x0CD,0x18C,0x194})
-- Short-grass paths and their edges: reviewed flat ground.
G.surface={}
span(G.surface,0x1D0,0x1D2);span(G.surface,0x1D8,0x1DA);span(G.surface,0x1E0,0x1E2)
span(G.surface,0x100,0x102);span(G.surface,0x108,0x10A);span(G.surface,0x110,0x112)
G.surface[0x001]=true;G.surface[0x11C]=true

-- ------- secondary tilesets -------------------------------------------------
local S={}
local function secondary(name,t)
 t.ground=t.ground or G.grass
 for _,k in ipairs({'roof','wall','treeTop','treeRootLeft','treeRootRight','hedge','shrub','surface'})do t[k]=t[k] or {} end
 S[name]=t
end
-- Petalburg (Littleroot, Oldale, Petalburg, Routes 101-104). Read from the
-- map renders: Littleroot houses 0x208-0x23A, Birch's lab 0x20C-0x249,
-- Oldale house 0x26C-0x28F, and the Center's red roof-top corners 0x282/0x283.
secondary('petalburg',{
 roof=set({
  0x208,0x209,0x20A,0x210,0x211,0x212,0x218,0x219,0x21A,           -- Littleroot house
  0x20C,0x20D,0x20E,0x214,0x215,0x216,0x242,0x243,0x24A,0x24B,     -- Birch's lab (dome 0x242/0x243/0x24A/0x24B)
  0x26C,0x26D,0x26E,0x274,0x275,0x276,                             -- Oldale house
  0x282,0x283,                                                     -- Pokemon Center roof-top right corners
 }),
 wall=set({
  0x220,0x221,0x222,0x223,0x228,0x229,0x22A,0x22B,0x230,0x231,0x232,0x238,0x239,0x23A,0x240,0x248, -- Littleroot house (door 0x248)
  0x21E,0x21F,0x20F,0x22C,0x22D,0x241,0x226,0x227,0x217,0x234,0x235,0x249,                       -- Birch's lab (door 0x249)
  0x27C,0x27D,0x27E,0x27F,0x284,0x286,0x287,0x28F,                                               -- Oldale house (door 0x287)
 }),
 -- Roof profile per drawing: the Littleroot house is two tiers (upper roof,
 -- upper-storey wall band, skirt roof); Birch's lab is a shallow pitched roof
 -- with its ridge band along the back and the dome on the slope.
 roofTypes=(function()
  local t={}
  for _,mid in ipairs({0x208,0x209,0x20A,0x210,0x211,0x212,0x218,0x219,0x21A})do t[mid]='twoTier' end
  for _,mid in ipairs({0x20C,0x20D,0x20E,0x214,0x215,0x216,0x242,0x243,0x24A,0x24B})do t[mid]='lowRidge' end
  return t
 end)(),
 treeRootLeft=set({0x285}),  -- trunk half overlapping a Mart roof corner
 shrub=set({0x202,0x28A,0x28B}),
 hedge=set({0x23C,0x23D,0x23E,0x244,0x245,0x246,0x24C,0x24D,0x254,0x255,0x256,0x264,0x265,0x266}),
 surface=set({0x201,0x206,0x207,0x270,0x271,0x272,0x278,0x279,0x27A,0x288,0x289,0x28C}),
})
-- Building tiles the generator cannot reach from a door (reviewed against
-- the original art, building by building).
-- Sootopolis house: an octagonal cone roof (two rows) over a two-row drum.
-- The cone and the dome are drawn from above, so they lie on a flat lid.
secondary('sootopolis',{roofType='flat',roof=set({0x201,0x202,0x209,0x20A,0x20B,0x218}),wall=set({0x223,0x214,0x224,0x22B,0x21C,0x22C})})
-- Pacifidlog hut: a thatch dome drawn over the water row behind (0x209-0x20B)
-- and the upper door row, above a one-row drum.
secondary('pacifidlog',{roofType='flat',roof=set({0x209,0x20A,0x20B,0x211,0x212,0x213}),wall=set({0x219,0x21A,0x21B})})
-- Rustboro's gym is the General gym with its right edge and porch corners
-- redrawn over the city's paving.
secondary('rustboro',{roof=set({0x2DB}),wall=set({0x2C9,0x2D1})})
-- Lilycove Department Store: the window tile of its centre column.
secondary('lilycove',{wall=set({0x2FB})})
-- Route 113 glass workshop: a walkable window cell and the roof's top-right.
-- 0x223: the grey-green boulder (beside Fallarbor's Battle Tent, on Route 114's river bank): a stone,
-- not a wall -- the generator took it into the tent's door-anchored box, and it stood as a block with
-- the stone painted on its front
secondary('fallarbor',{roof=set({0x2FE}),wall=set({0x2FF}),cliff=set({0x223})})
M.secondary=S
M.treeArt=G.treeArt

-- ------- generated tables ---------------------------------------------------
-- lib/Gen3EmeraldAuto.lua is derived from every imported map by
-- tools/gen_emerald_tables.py (buildings anchored on doors, props by pixel
-- colour, cave walls in cave pairs). Hand entries above win; the generated
-- sets only fill ids the hand tables do not name.
local auto
do
 local ok,mod=pcall(function()return V and V.require and V.require('Gen3EmeraldAuto') end)
 if not (ok and mod) then
  if V and V.mod and V.mod.log and V.mod.log.warn then V.mod.log:warn('Gen3EmeraldAuto via V.require failed: %s',tostring(mod)) else print('[Emerald] Gen3EmeraldAuto via V.require failed: '..tostring(mod)) end
  ok,mod=pcall(dofile,(os.getenv('DS_MOD_PATH') or '.')..'/lib/Gen3EmeraldAuto.lua')
 end
 auto=ok and mod or {outdoor={},general={},interiors={}}
end
local HAND_KINDS={'roof','wall','treeTop','treeRootLeft','treeRootRight','hedge','shrub','surface','rock','cliff','caveWall'}
local function claimed(t,mid)
 for _,k in ipairs(HAND_KINDS)do if t[k] and t[k][mid] then return true end end
 return false
end
-- Generated rock/shrub hulls (benches, signs, bushes, boulders guessed from
-- pixel colour) read as blobs rather than scenery, so they are not taken:
-- unlisted props keep their original drawing flat on the ground. Buildings,
-- cliffs and cave walls are the generated kinds that stand up.
local AUTO_KINDS={'roof','wall','cliff','caveWall'}
for name,gen in pairs(auto.outdoor or {})do
 local t=S[name]
 if not t then secondary(name,{ground=gen.floor});t=S[name];t.auto=true elseif gen.floor and not t.ground then t.ground=gen.floor end
 for _,k in ipairs(AUTO_KINDS)do
  t[k]=t[k] or {}
  for _,mid in ipairs(gen[k] or {})do if not claimed(t,mid) then t[k][mid]=true end end
 end
end
G.rock=G.rock or {}
for _,k in ipairs({'roof','wall','cliff'})do
 for _,mid in ipairs((auto.general or {})[k] or {})do
  if not (G.roof[mid] or G.wall[mid] or G.cliff[mid] or G.treeTop[mid] or G.treeRootLeft[mid] or G.treeRootRight[mid]
   or G.treeOverhang[mid] or G.treeOverhangGrass[mid] or G.flowers[mid] or G.shrub[mid] or G.sign[mid] or G.surface[mid]) then
   G[k][mid]=true
  end
 end
end
M.auto=auto

-- ------- lookup -------------------------------------------------------------
local function isSurfable(behavior)
 local ok,Collision=pcall(require,'src.core.game3.collision')
 if ok and Collision and Collision.isSurfable and Collision.isSurfable(behavior) then return true end
 return behavior==B.INTERIOR_DEEP_WATER or behavior==B.SOOTOPOLIS_DEEP_WATER
  or behavior==B.SEAWEED or behavior==B.SEAWEED_NO_SURFACING or behavior==B.WATERFALL
end

local function jumpSouth(b)return b==B.JUMP_SOUTH or b==B.JUMP_SOUTHEAST or b==B.JUMP_SOUTHWEST end

local function tree(t,mid,ground)
 if t.treeRootLeft[mid] then return {kind='tree',root=true,ground=ground,anchorX=16,anchorZ=12,art=G.treeArt,artTipRows=1} end
 if t.treeRootRight[mid] then return {kind='tree',root=false,ground=ground} end
 if t.treeTop[mid] then return {kind='tree',root=false,ground=ground} end
end

-- Landmark pins by pret secondary name. Metatile lists from
-- Gen2Recomped-DramaticShapes data/gen3_shapes.lua (MIT, DramaticShape /
-- UNDERdecodedHD): Slateport's market stall awnings. (Their Fortree water
-- pins 518/519 are the tiles our tree roots hang from here, so they stay out.)
-- Generated "cliff" sets are colour guesses. They are trusted only where the
-- secondary tileset really draws rock; in a town or facility tileset the same
-- guess catches stall goods, boats and machinery, which must stay flat.
local ROCKY={dewford=true,ever_grande=true,fallarbor=true,fortree=true,lavaridge=true,lilycove=true,pacifidlog=true,sootopolis=true}
local PINS={slateport={}}
local STAKE_FENCE={[0x149]=true,[0x148]=true,[0x13A]=true,[0x138]=true,[0x14A]=true,[0x142]=true,[0x140]=true,[0x139]=true}
for _,mid in ipairs({517,525,526,527,551,565,559,760,761,762})do PINS.slateport[mid]='awning' end
-- 0x243 is the round bush beside the Pokemon Center; the generated table lists it as a wall
-- because it touches the building, which made green boxes of them
PINS.slateport[0x243]='shrub'
PINS.sootopolis={[0x244]='steps',[0x245]='steps'}
-- Lilycove's navy post-and-rail fences (0x250-0x252): the generated table lists them as rock, which stood them
-- up as solid navy slabs; they are a fence line (Gen3Objects cuts the rails against the grass round them).
PINS.lilycove={}
for _,mid in ipairs({0x258,0x25A})do PINS.lilycove[mid]='fenceline' end
-- the dark hollow drawn in the east ledge's north edge: flat as drawn (as an
-- object it stood as a black and yellow wedge)
PINS.lilycove[0x2A2]='flatart'
-- the blue iron fences stand up (Gen3Fence)
for _,mid in ipairs({0x250,0x251,0x252})do PINS.lilycove[mid]='fence' end
-- Route 110's low concrete curbs along the channels (Gen3Fence curbs)
PINS.mauville=PINS.mauville or {}
for _,mid in ipairs({0x04E,0x04D,0x03E,0x045,0x047})do PINS.mauville[mid]='fence' end
-- the grey stake fences (Route 110 under the Cycling Road, Route 117, Mauville)
for _,mid in ipairs({0x149,0x148,0x13A,0x138,0x14A,0x142,0x140,0x139})do PINS.mauville[mid]='fence' end
-- Mauville's pink log stakes (rows and columns of separate posts): each post
-- stands from its own pixels
for _,mid in ipairs({0x291,0x292,0x288,0x28A,0x273,0x282,0x2B2,0x290})do PINS.mauville[mid]='stakes' end
-- Fortree: the treehouse deck's west-end plank tile (blocked, just outside the
-- hut's footprint) is deck floor, not a shrub cut-out of its plank lines (Opus)
PINS.fortree={[0x233]='flat'}
-- Lavaridge hot spring: the boulder rim round the pool is a knee-high rock
-- edge (8 px), not a two-storey building (user: "the walls are wayy too
-- high"); the pool inside is walkable shallow water at the sand's level.
-- Mt. Pyre's exterior: the darker grass path running north up the mountain
-- (blocked, but drawn as ground) stood as a tall green slab; it is flat
PINS.facility={}
for _,mid in ipairs({0x332,0x338,0x339,0x33B,0x33C,0x33D})do PINS.facility[mid]='flat' end
-- Mt. Pyre's summit: the same dark path with its edges (blocked, drawn as ground) stood as a tall
-- rounded green ridge, and the white steps at its head as a huge grey block; flat path, real steps
for _,mid in ipairs({0x32F,0x340,0x33E,0x337,0x33F})do PINS.facility[mid]='flat' end
for _,mid in ipairs({0x330,0x331})do PINS.facility[mid]='steps' end
-- Slateport's moored sailboats (Gen3Boat), wherever the tileset is drawn
PINS.slateport=PINS.slateport or {}
for _,m in ipairs({0x338,0x339,0x33A,0x340,0x341,0x342,0x348,0x349,0x34A,0x346,0x347,0x368,0x34E,0x34F,0x370,0x356,0x357,0x378,0x35E,0x35F,0x380})do PINS.slateport[m]='boat' end
-- Fortree tileset: the fast river you cannot surf (0x206, 0x20F its shade
-- under a bridge) is water, not rock; the white boardwalk's legs standing in
-- it (0x0F5/0x0F8/0x0F9/0x0FA) are drawn on water too
PINS.fortree=PINS.fortree or {}
for _,m in ipairs({0x206,0x20F})do PINS.fortree[m]='river' end
-- Petalburg Woods' exit paths (the shaded strip leading out of the wood, blocked): flat as drawn. As an
-- unnamed blocked group they stood as two striped slabs five courses up, hanging over each entrance.
PINS.rustboro={[0x205]='flatart'}
-- Rustboro's navy iron railings round the lawns: the looped rail drawn from the front (east-west) and
-- the plain line drawn from above (north-south) stand up (Gen3Fence); as unnamed blocked ground they
-- were cut out as leaning bars. Each keeps the ground it is drawn on (plaza, or lawn).
local RUSTBORO_RAIL={[0x2FC]=0x2BB,[0x2A7]=0x2BB,[0x2BE]=0x2BB,[0x2BF]=0x2BB,[0x31A]=0x2BB,[0x2B7]=0x001,
 [0x2DE]=0x001,[0x2DF]=0x001,[0x2EC]=0x2BB,[0x318]=0x318,[0x319]=0x319,
 -- the ends, corners and edge pieces (a piece drawn half on lawn, half on paving keeps its own tile
 -- as its ground: the line drawn on it lies under the rail that stands there; a piece drawn wholly on
 -- lawn or paving takes that, or a second rail lay flat on the ground under the standing one)
 [0x315]=0x2BB,[0x320]=0x2BB,[0x31D]=0x2BB,[0x2C6]=0x2BB,[0x2C7]=0x2BB,[0x2D5]=0x2BB,[0x321]=0x001,[0x33F]=0x001,[0x2D7]=0x001,
 [0x31B]=0x001,[0x32D]=0x32D,[0x2E9]=0x2BB,[0x2E7]=0x001,[0x2E6]=0x001,[0x32C]=0x32C,[0x352]=0x2BB,[0x2DC]=0x2BB,[0x2CD]=0x2BB,
 -- (the rail with the hedge growing over its foot, south lawn: it stood as broken bits)
 [0x337]=0x001,[0x33E]=0x001}
for m in pairs(RUSTBORO_RAIL)do PINS.rustboro[m]='fence' end
-- Rustboro's 17 street lamps (Gen3Lamp): the blocked foot 0x21A stands the lamp up from its drawing, and
-- the head drawn over the player in the cell north of it (0x212, 0x213) is part of that lamp. As unnamed
-- blocked art Gen3Objects cut a 12 px slab out of them, twice as thick as the post is drawn.
PINS.rustboro[0x21A]='lamp'
PINS.rustboro[0x212]='lamptop'
PINS.rustboro[0x213]='lamptop'
PINS.lavaridge={}
-- the cable car pylon's foot (Route 112, Mt. Chimney): plain ground, the
-- pylon stands on it in 3D (Gen3CableCar)
PINS.lavaridge[0x264]='poleFoot'
for _,mid in ipairs({0x299,0x29A,0x29B,0x29D,0x2A1,0x2A5,0x2A9,0x2AD,0x2B1,0x2B2,0x2B3,0x2B4,0x2B5})do PINS.lavaridge[mid]='rim' end
-- Mt. Chimney's and Jagged Pass's pale ash pines: narrow trees one cell wide, crown pieces (0x2C5/0x2C6/0x2CD) stacked
-- over a base with the trunk and shadow (0x2CC). The generated table lists them as cliff/rock, which fused whole
-- forests into walls. They are standing objects (Gen3Objects.ashTrees).
for _,mid in ipairs({0x2C5,0x2C6,0x2C7,0x2CC,0x2CD})do PINS.lavaridge[mid]='ashtree' end
-- the pines' crown tops drawn over bare ground (walkable, over layer): ground
-- in 3D, the pine standing in the cell below carries the crown
PINS.lavaridge[0x2C4]='ashtop'
-- Mt. Chimney's cable car station fence (white posts and rails): stood up by Gen3Fence
for _,mid in ipairs({0x296,0x293,0x287,0x285,0x294,0x28E,0x28F})do PINS.lavaridge[mid]='fence' end
-- Fallarbor, Route 113 and Route 114's round trees (Opus; user: "the trees
-- around falabor town are kinda mangled"): the generated table had their
-- pieces as cliff and shrub. Each tree is 2x2 -- crown top-left/right over
-- the ground (over layer), crown bottom with the trunk at the boundary of its
-- two lower cells -- and the forest packs them a cell apart, so each tile
-- carrying a trunk on its LEFT edge is one tree's lower-right cell: the tree
-- stands there (its centre on that cell's west edge), built by the native
-- tree builder from the lone tree's drawing. Green trees in town and on
-- Route 114, ash-covered ones on Route 113.
PINS.fallarbor={}
local FALLARBOR_TREES={
 green={art={{0x206,0x207},{0x20E,0x20F}},roots={0x20F,0x26B,0x274},parts={0x206,0x207,0x20E,0x26C,0x273,0x214,0x215}},
 ash={art={{0x204,0x205},{0x20C,0x20D}},roots={0x20D,0x26D,0x276},parts={0x204,0x205,0x20C,0x26E,0x275}},
}
for fam,t in pairs(FALLARBOR_TREES)do
 for _,m in ipairs(t.roots)do PINS.fallarbor[m]='ftree:'..fam..':root' end
 for _,m in ipairs(t.parts)do PINS.fallarbor[m]='ftree:'..fam..':part' end
end
-- Ever Grande's two gates up to the League: the roof over the path, the post
-- tops and the posts' feet. Their cells are ground; Gen3LeagueGate builds the
-- gate you walk under from the drawing (the generated table had the roof's
-- corners as cliff and the posts as rock).
PINS.ever_grande={}
for mid=0x248,0x25F do PINS.ever_grande[mid]='leagueGate' end
for _,mid in ipairs({0x260,0x264,0x26C})do PINS.ever_grande[mid]='leagueGate' end

-- The plain floor tile of a secondary tileset (Dewford's sand, a cave's floor), or nil.
function M.floor(secondary)
 local t=S[secondary]
 return t and t.ground or nil
end
-- Returns a shape, or nil to let Gen3TileShape.of finish (steps, ladders,
-- FireRed-scoped interiors, and the flat default).
-- Three tall palms rise out of the canopy: crown 0x250-0x252 (bright frond
-- tips 0x248-0x24A behind it), trunk 0x241 / 0x25C under the crown's middle.
-- In 3D the crown stands one course above the canopy on its trunk (Gen3Scene),
-- and the cells round it are plain canopy (their own art has the crown's
-- fronds or the trunk drawn flat into the canopy).
local FORTREE_CANOPY={[0x22A]=true,[0x243]=true,[0x244]=true,[0x246]=true,[0x247]=true,
 [0x248]=true,[0x249]=true,[0x24A]=true,[0x250]=true,[0x251]=true,[0x252]=true,
 [0x25C]=true,[0x273]=true,[0x241]=true}
local FORTREE_PALM_CROWN={[0x250]=true,[0x251]=true,[0x252]=true}
local FORTREE_PALM_FLAT={[0x248]=true,[0x249]=true,[0x24A]=true,[0x250]=true,[0x251]=true,[0x252]=true,
 [0x25C]=true,[0x273]=true,[0x241]=true}
local stamps,stampsTried
function M.of(primary,secondary,mid,behavior,collision)
 if type(mid)~='number' then return nil end
 -- Outdoor tables are keyed by the pret secondary name, and several names
 -- exist in both families (general__facility / building__facility), so they
 -- only ever apply to the General primary. Interiors are Gen3EmeraldInteriors.
 if primary~='general' then return nil end
 -- the Abandoned Ship's rooms (general primary, but rooms): their profile in
 -- Gen3EmeraldInteriors answers, not the outdoor votes (cabins as roofed
 -- buildings, walls as rocks)
 if secondary=='inside_ship' then return nil end
 local sec=S[secondary]
 local ground=(sec and sec.ground) or G.grass
 local pin=PINS[secondary] and PINS[secondary][mid]
 -- tiles of a tree family that has cut over to the stamp table (Gen3TreeStamps) answer from it, before any older path
 if stampsTried==nil then
  local ok,m=pcall(function()return V and V.require and V.require('Gen3TreeStamps')end)
  stampsTried=true;stamps=ok and m or nil
 end
 if stamps then
  local stamp=stamps.of(secondary,mid,collision,behavior,ground,behavior and isSurfable(behavior))
  if stamp then return stamp end
 end
 -- the grey stake fence is drawn with the shared (primary) tiles: it stands on every outdoor map, not
 -- only where a secondary names it (Route 104's lay flat as checkered cards)
 local stake=not pin and STAKE_FENCE[mid]
 if stake then pin='fence' end
 -- Fortree's canopy-edge tiles (the foliage round each treehouse platform and
 -- along the forest's rim, drawn with the canopy texture) are part of the
 -- raised canopy mass, not shrub cut-outs (Opus, Fortree pass)
 -- (0x241, the palm trunk seen through a gap, is walkable but unreachable)
 if secondary=='fortree' and FORTREE_CANOPY[mid] and (collision==BLOCKED or mid==0x241) then
  return {kind='tree',root=true,canopy=true,fortree=true,ground=ground,anchorX=8,anchorZ=8,art={{mid}},
   topMid=FORTREE_PALM_FLAT[mid] and 0x0C7 or nil,palmCrown=FORTREE_PALM_CROWN[mid] or nil}
 end
 -- Route 110's Seaside Cycling Road (the only map drawing these ids): the deck
 -- is a flat floor the elevation raises to 48; every structure tile round it
 -- is sea (still a water cell, for surfing under the road) or grass, and
 -- Gen3CyclingRoad builds the slab, its fascia faces and the legs (Opus)
 if secondary=='mauville' then
  local ok,R=pcall(function()return V and V.require and V.require('Gen3CyclingRoad')end)
  if ok and type(R)=='table' then
   if R.DECK[mid] then return {kind='flat',reviewedSurface=true,cyclingRoad='deck'} end
   if R.SEA[mid] then return {kind='water',reviewedSurface=true,behavior=behavior,cyclingRoad='sea'} end
   if R.LAND[mid] then return {kind='flat',reviewedSurface=true,cyclingRoad='land',ground=G.grass} end
   if R.TREE[mid] then return {kind='tree',root=true,canopy=true,ground=ground,anchorX=8,anchorZ=8,art={{mid}},topMid=0x0C7,roadTree=true} end
  end
 end
 if pin=='fenceline' then return {kind='flat',ground=ground,fenceLine=true} end
 -- (Opus: built as turned solid pines by Gen3AshPine, not Gen3Objects groves)
 if pin=='ashtree' then return {kind='flat',ground=0x271,ashPine=true,reviewedSurface=true} end
 if type(pin)=='string' and pin:sub(1,6)=='ftree:' then
  local fam,role=pin:match('ftree:(%a+):(%a+)')
  local t=FALLARBOR_TREES[fam]
  if role=='root' then
   return {kind='tree',root=true,ground=0x279,planeOwn=true,anchorX=0,anchorZ=10,art=t.art,artTipRows=1,reviewedSurface=true}
  end
  return {kind='tree',root=false,ground=0x279,planeOwn=true,reviewedSurface=true}
 end
 if pin=='fence' then
  local g=({lavaridge=0x271,lilycove=0x001,mauville=0x001})[secondary] or ground
  if secondary=='rustboro' then g=RUSTBORO_RAIL[mid] or g end
  if stake then g=0x001 end
  return {kind='fence',ground=g,reviewedSurface=true}
 end
 if pin=='river' then return {kind='water',reviewedSurface=true,river=true} end
 if pin=='stakes' then
  if collision~=BLOCKED then return nil end
  return {kind='posts',h=9,ground=0x001,reviewedSurface=true}
 end
 if pin=='flatart' then return {kind='flat',reviewedSurface=true} end
 if pin=='boat' then return {kind='boat',reviewedSurface=true} end
 if pin=='ashtop' then return {kind='flat',groundMid=0x271,ashTop=true,reviewedSurface=true} end
 -- a street lamp's foot stands on the lawn; its head cell is lawn too (the lamp is built by Gen3Lamp)
 if pin=='lamp' then return {kind='flat',ground=0x2BB,lamp=true,reviewedSurface=true} end
 if pin=='lamptop' then return {kind='flat',lampTop=true,reviewedSurface=true} end
 if pin=='leagueGate' then return {kind='flat',reviewedSurface=true,leagueGate=true} end
 if pin=='poleFoot' then return {kind='flat',reviewedSurface=true,groundMid=0x271} end
 if pin=='rim' then return {kind='rock',ground={0x2A8,0x2A3,0x2BC,0x274,0x272,0x001},height=8} end
 if pin=='awning' then return {kind='awning',ground=ground,height=18} end
 if pin=='shrub' then return {kind='shrub',ground=ground,height=10} end
 -- Sootopolis's two drawn stair tiles: real steps (Gen3Stairs builds 4 per cell from the stair art, rising
 -- north from floor.low to floor.high, which Gen3StairTerraces sets). Asked for by the terrace work.
 if pin=='steps' then return {kind='steps',height=6} end
 if pin=='flat' then return {kind='flat',reviewedSurface=true} end
 local mountain=false
 -- 1. behaviors: identical on every Hoenn tileset pair
 if behavior then
  -- Route 111's mudslide is a flight climbing north, not flat ground and not
  -- a hole in the cliff (pin from Gen2Recomped-DramaticShapes, MIT). The
  -- height solver reads the same behaviour as a step (Gen3Elevation).
  if behavior==B.MUDDY_SLOPE then return {kind='steps',height=6} end
  if isSurfable(behavior) then return {kind='water',reviewedSurface=true,behavior=behavior} end
  if jumpSouth(behavior) then
   return {kind='ledge',ground=ground,left=behavior==B.JUMP_SOUTHWEST or nil,right=behavior==B.JUMP_SOUTHEAST or nil}
  end
  -- a side ledge (jump east/west) is a kerb along its dirt band (Gen3Outdoor sideLedge, flat as drawn
  -- when its tile has no such band); a north jump stays flat
  if behavior==B.JUMP_EAST or behavior==B.JUMP_WEST then return {kind='ledge',side=true,ground=ground} end
  if behavior==B.JUMP_NORTH then
   -- the ledge renderer is south-facing only; keep the art flat rather than wrong
   return {kind='flat',reviewedSurface=true}
  end
  -- The RAIL behaviours mark Emerald's white boardwalks and bridges (Route 119,
  -- the Safari Zone). They are not fences: the old fence recipe stood stakes
  -- made from unrelated art. The tile's own drawing is the deck.
  if behavior==B.HORIZONTAL_RAIL or behavior==B.ISOLATED_HORIZONTAL_RAIL
   or behavior==B.VERTICAL_RAIL or behavior==B.ISOLATED_VERTICAL_RAIL then
   return {kind='flat',reviewedSurface=true}
  end
  if behavior==B.TALL_GRASS or behavior==B.LONG_GRASS or behavior==B.ASHGRASS then
   -- ash-covered grass is ash all through (its tile is the ground and the tuft): not green blades on green
   return {kind='grass',ground=ground,height=behavior==B.LONG_GRASS and 8 or 4,ownGround=behavior==B.ASHGRASS or nil}
  end
  -- MOUNTAIN_TOP marks the whole mountain: walkable tops stay ground (their
  -- elevation layer lifts them), a BLOCKED one is the rock mass itself. It
  -- falls through to the reviewed ids (General cliff art keeps its cap and
  -- face textures) and otherwise rises as a cliff of its own drawing.
  if behavior==B.MOUNTAIN_TOP and collision==BLOCKED then
   mountain=true
  elseif behavior==B.MOUNTAIN_TOP or behavior==B.BERRY_TREE_SOIL or behavior==B.MUDDY_SLOPE
   or behavior==B.BUMPY_SLOPE or behavior==B.PUDDLE or behavior==B.SHORT_GRASS then
   return {kind='flat',reviewedSurface=true}
  end
 end
 -- 2. reviewed ids
 if primary=='general' then
  if G.cliff[mid] then
   if collision==BLOCKED then
    -- a boulder in the sea: only its rock pixels stand up (Gen3Objects cuts it
    -- against the water around it), the water in its tile stays water
    if G.seaRock[mid] then return {kind='flat',seaRock=true,ground=ground} end
    return {kind='cliff',height=32,ground=ground,cap=G.cliffCap,side=G.cliffSide}
   end
   return {kind='flat',reviewedSurface=true}
  end
  if G.ledgeLeft[mid] then return {kind='ledge',ground=ground,left=true} end
  if G.ledgeRight[mid] then return {kind='ledge',ground=ground,right=true} end
  if G.roof[mid] then return {kind='roof',ground=ground,roofType='front'} end
  if G.wall[mid] then return {kind='wall',ground=ground} end
  local t=tree(G,mid,ground);if t then return t end
  if G.canopyTree[mid] then
   -- a dense forest canopy is a seamless texture, not single trees: it stands
   -- as a raised canopy mass (Gen3Scene tree branch, shape.canopy)
   if collision==BLOCKED then return {kind='tree',root=true,canopy=true,ground=ground,anchorX=8,anchorZ=8,treeScale=0.6,art={{mid}}} end
   return {kind='flat',reviewedSurface=true}
  end
  if G.narrowTreeRoot[mid] then return {kind='tree',root=true,ground=ground,anchorX=8,anchorZ=12,treeScale=0.7,art={{G.narrowTreeRoot[mid]},{mid}}} end
  if G.narrowTreeTop[mid] then return {kind='tree',root=false,ground=ground} end
  -- the tree's top is drawn over this grass; the 3D tree is there now, so the
  -- ground shows plain grass instead of a flat picture of the treetop
  if G.treeOverhang[mid] then return {kind='flat',reviewedSurface=true,groundMid=G.grass} end
  if G.treeOverhangGrass[mid] then return {kind='grass',ground=ground,groundMid=G.grass,height=4} end
  -- the flowers and the shrub are drawn on their own grass, whatever the town's floor is
  if G.flowers[mid] then return {kind='flowers',ground=G.grass,height=6} end
  if G.shrub[mid] then return {kind='shrub',ground=G.grass,height=10} end
  if G.sign[mid] then return {kind='sign',height=12,ground=ground} end
  if G.rockInWater[mid] or G.surface[mid] then return {kind='flat',reviewedSurface=true} end
  if G.rock[mid] then
   if collision==BLOCKED then return {kind='rock',ground=ground,height=8} end
   return {kind='flat',reviewedSurface=true}
  end
 end
 if sec then
  if sec.roof[mid] then return {kind='roof',ground=sec.ground,roofType=(sec.roofTypes and sec.roofTypes[mid]) or sec.roofType or 'front'} end
  if sec.wall[mid] then return {kind='wall',ground=sec.ground} end
  local t=tree(sec,mid,ground);if t then return t end
  if sec.hedge[mid] then return {kind='shrub',ground=ground,height=8,hedge=true} end
  if sec.shrub[mid] then
   if collision==BLOCKED then return {kind='shrub',ground=ground,height=10} end
   return {kind='flat',reviewedSurface=true}
  end
  if sec.surface[mid] then return {kind='flat',reviewedSurface=true} end
  -- generated leftovers: only a blocked cell stands up; the same drawing on a
  -- walkable cell (a copy used as floor) stays flat
  if sec.cliff and sec.cliff[mid] and ROCKY[secondary] then
   if collision==BLOCKED then return {kind='cliff',height=32,ground=ground,cap=mid,side=mid} end
   return {kind='flat',reviewedSurface=true}
  end
  if sec.caveWall and sec.caveWall[mid] then
   if collision==BLOCKED then return {kind='caveWall',height=28,ground=ground,cap=mid,side=mid} end
   return {kind='flat',reviewedSurface=true}
  end
  if sec.rock and sec.rock[mid] then
   if collision==BLOCKED then return {kind='rock',ground=ground,height=8} end
   return {kind='flat',reviewedSurface=true}
  end
 end
 if mountain then return {kind='cliff',height=32,ground=ground,cap=mid,side=mid,mountain=true} end
 return nil
end

return M
