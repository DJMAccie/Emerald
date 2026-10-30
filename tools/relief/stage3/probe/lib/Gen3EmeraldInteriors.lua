-- Emerald interior profiles, keyed by the pret tileset the importer named the
-- pair after (building__brendans_mays_house -> 'brendans_mays_house').
-- Same shape as Gen3InteriorProfiles: floor = the floor drawing under the
-- wall run, walls = metatile ids that stand up as roomWall where the cell is
-- blocked, props = { mid, kind, height } furniture reliefs (Gen3Furniture
-- turns each into a one-cell recipe that extrudes the tile's own silhouette).
--
-- Ids were read off labelled renders of the imported rooms (tools/mapsheet.py):
-- Brendan's/May's house 1F, Birch's lab, Oldale's Center 1F and Mart.
-- Hoenn rooms draw the north wall as two rows; cabinets on the second row
-- are still part of the wall drawing, so they are listed as walls and their
-- lower halves on the third row are reliefs. Doormats, rugs, stairs and
-- warp tiles are deliberately not props.
local M={}
local function profile(key,floor,walls,props,primary)
 local p={floor=floor,walls={},props=props or {},primary=primary}
 for _,id in ipairs(walls)do p.walls[id]=true end
 M[key]=p
end
local function reliefs(list,h,kind)
 local out={}
 for _,id in ipairs(list)do out[#out+1]={id,kind or 'relief',h} end
 return out
end
local function join(...)
 local out={}
 for _,t in ipairs({...})do for _,v in ipairs(t)do out[#out+1]=v end end
 return out
end

-- Brendan's / May's house (floor 0x201).
profile('brendans_mays_house',0x201,
 -- 0x20F/0x21F are the void beyond the stair alcove and 0x20D/0x24D the stair
 -- top: neither is wall art, and both draw black when stood up.
 {0x26E,0x21E,0x230,0x231,0x232,0x233,0x234,0x226,0x208,0x209,0x210,0x215,0x216,
  -- 2F back wall: picture, clock, GameCube shelf and the stair alcove's sides
  0x25A,0x25B,0x255,0x265,0x002,0x28F,0x213,
  0x212,0x22F,0x257,0x258,0x259},  -- May's mirrored 2F
 join(
  reliefs({0x238,0x239,0x23A,0x23B,0x23C},22),        -- fridge, sink and counters below the wall
  reliefs({0x002},20),                                -- PC
  reliefs({0x240,0x241},8,'bin'),                     -- bed
  -- the dining table and chairs are pixel-voxel furniture (Gen3PixelFurniture)
  reliefs({0x242},10)))                               -- TV stand

-- Professor Birch's lab (floor 0x202).
profile('lab',0x202,
 {0x210,0x211,0x208,0x212,0x213,0x209,0x218,0x219,0x23C,0x21A,0x21B,0x20A,0x20B,0x20C,0x20D,0x20E},
 join(
  reliefs({0x220,0x221,0x228,0x224,0x225,0x22C,0x22D,0x234,0x235,0x236,0x237,0x23D,0x23E},24), -- bookshelves and cabinets
  reliefs({0x214,0x215,0x216,0x21C,0x21D,0x21E},24),  -- Pokemon machine
  reliefs({0x230,0x238,0x240,0x248,0x231,0x242,0x243,0x24B,0x23A,0x23B,0x22E,0x232,0x29A,0x292},16), -- desks, crates, terminals
  reliefs({0x226,0x239,0x241,0x249,0x247,0x23F},8),   -- chairs and low pieces
  reliefs({0x244,0x24F,0x24E},22)))                   -- plants

-- the Weather Institute (same tileset): its white wall 0x25F over 0x267 --
-- the north wall and the divider across the room at rows 8-9 -- is wall
do local p=M.lab;p.walls[0x25F]=true;p.walls[0x267]=true end

-- Pokemon Center 1F (floor 0x202).
profile('pokemon_center',0x202,
 {0x208,0x209,0x269,0x26A,0x20B,0x24A,0x24B,0x20C,0x20D,0x20E,0x20F,
  0x210,0x211,0x271,0x272,0x248,0x222,0x223,0x252,0x253,0x249,0x004,0x215,0x216,0x217,
  -- 2F (Union Room / trade / battle corner): the orange wall run 0x213, the
  -- window over the doorway 0x25C, the three white doors 0x23F/0x247 and
  -- their bottoms 0x2A6/0x24F (none of these appear on 1F)
  0x213,0x25C,0x23F,0x247,0x2A6,0x24F},
 join(
  -- The seating area (0x230-0x243, 0x26C-0x26F) is walkable floor art, so it
  -- stays flat; 0x288/0x228 are dark side trims that draw black stood up.
  reliefs({0x250,0x22A,0x22B,0x25B,0x251,0x258,0x221,0x205,0x259},14,'bin'), -- front desk
  -- 0x237 is the black south-east corner of the room, not furniture
  -- stools and the glass table are pixel-voxel furniture (Gen3PixelFurniture)
  reliefs({0x225,0x23C},10),                                                 -- plants
  -- The staircase in the west wall is a 2x3 block climbing WEST in 8px
  -- columns (16/11/5/0), not six flat floor tiles. Pins and step heights
  -- from Gen2Recomped-DramaticShapes (MIT, DramaticShape / UNDERdecodedHD).
  {{0x280,'flight',16,11},{0x288,'flight',16,11},{0x290,'flight',16,11},
   {0x281,'flight',5,0},{0x289,'flight',5,0},{0x291,'flight',5,0}}))

-- Poke Mart (floor 0x201).
profile('shop',0x201,
 {0x210,0x222,0x212,0x213,0x223,0x224,0x215,0x218,0x244,0x22A,0x21B,0x228,0x229,0x21D},
 join(
  reliefs({0x232,0x23A,0x241,0x242,0x320,0x22B,0x22C,0x233,0x234,0x23B,0x23C,0x22D},20), -- counter and shelves
  reliefs({0x230,0x231,0x221},10)))                                          -- shelf tops

-- Rooms drawn with the GENERAL primary (indoor maps whose pair is
-- general__<secondary>); tagged so they apply only there.
-- Mauville Bike Shop (floor 0x23F): two-row north wall, bikes on stands down
-- both sides, the service counter and the partition by the back desk.
profile('bike_shop',0x23F,
 {0x201,0x202,0x203,0x204,0x205,0x228,0x229,0x22A,0x22B,0x22C,0x22D,
  0x209,0x20A,0x20B,0x20C,0x20D,0x230,0x231,0x232,0x233,0x234,0x235,
  -- New Mauville Inside shares this tileset (the Bike Shop never draws these):
  -- its corridor walls -- cream caps, khaki faces, white pillars, the wall
  -- ends and the panels set in them. Machines, crates and the generator are
  -- furniture.
  0x21F,0x227,0x25C,0x25D,0x260,0x261,0x268,0x26A,0x26E,0x270,0x272,0x277,0x278,0x27A,
  0x280,0x282,0x288,0x289,0x28A,0x28B,0x28C,0x290,0x291,0x293,0x294,0x295,0x296,0x298,
  0x299,0x29A,0x29F,0x2A0,0x2A5,0x2A6,0x2A7,0x2A8,0x2B1,0x2B4,0x2B6,0x2B7,0x2BE,0x2BF,
  0x2C6,0x2C7,0x2CE,0x2CF,
  -- the black void between its corridors: solid dark mass, not a pit
  0x208},
 join(
  reliefs({0x211,0x212,0x219,0x21A,0x221,0x222,0x206,0x207,0x20E,0x20F,
   0x253,0x254,0x245,0x246,0x24D,0x24E,0x255,0x256},14),            -- bikes on stands
  reliefs({0x213,0x21B,0x21C,0x21D,0x21E},14,'bin'),                -- counter
  reliefs({0x248,0x249,0x24B,0x24C},20)),                           -- partition
 'general')
-- Mossdeep Space Center 1F (floor 0x2F0): monitor wall, desks and stools.
-- Other facility rooms (auto table below) share the tileset: walls merged.
profile('facility',0x2F0,
 {0x218,0x219,0x2F8,0x2B3,0x2B4,0x2B5,0x2BA,0x2B8,0x2B9,0x300,0x2BB,0x2BC,0x2BD,
  0x349,0x34A,0x34B,0x388,0x389,0x38A,0x38B,0x38C,0x38E,0x38F,0x390,0x391,0x392,0x394,0x395,0x397,
  0x39C,0x3BB,0x3BC,0x3BD,0x3C0,0x3C1,0x3C2,0x3C3,0x3C4,0x3C5,0x3F6,0x3FE},
 join(
  reliefs({0x368,0x369,0x370,0x371},14,'bin'),                      -- plotting desks
  reliefs({0x36B,0x36C},18),                                        -- terminals
  reliefs({0x361},9),                                               -- stools
  reliefs({0x2E5,0x3A0,0x3A1},18)),
 'general')

-- The Abandoned Ship's rooms and corridors (general__inside_ship, floor
-- 0x238): wood panelling, white wall tops, black cabin edges, portholes,
-- signs and the flooded hold's purple walls are wall; the black void between
-- cabins is a black mass; beds, tables, life rings, toilets, crates and the
-- engine room's machinery stand as furniture.
profile('inside_ship',0x238,
 {0x201,0x208,0x209,0x210,0x211,0x221,0x222,0x223,0x224,0x225,0x226,0x227,0x229,0x22A,0x22B,0x22C,0x22D,0x22E,0x22F,
  0x230,0x231,0x232,0x233,0x236,0x237,0x23E,0x23F,0x240,0x241,0x242,0x243,0x244,0x245,0x246,0x247,0x248,0x249,
  0x24A,0x24B,0x24C,0x24D,0x24E,0x24F,0x263,0x269,0x26A,0x26B,0x26C,0x26D,0x273,0x274,0x275,0x276,0x27B,0x295,0x296,
  0x297,0x29D,0x29E,0x29F,0x2A7,0x2A8,0x2A9,0x2B0,0x2B1,0x2B8,0x2B9,0x2C0,0x2C1,0x2CC,0x2CD,0x2CE,0x2D4,0x2D5,
  0x2D6,0x2D7,0x2D8,0x2D9,0x2DA,0x2F8},
 join(
  reliefs({0x250,0x251,0x254,0x255,0x258,0x259,0x25C,0x25D,0x25E,0x25F,0x256,0x257,0x20F,0x217,0x270,0x278},10),  -- beds
  reliefs({0x271,0x272,0x279,0x27A,0x299,0x29A},12),                          -- tables, benches
  reliefs({0x2A0,0x2A1,0x2A2},10),                                            -- chairs
  reliefs({0x235,0x262,0x268,0x277,0x27F},12),                                -- toilets, bins
  reliefs({0x20B,0x20C,0x20E,0x214,0x216},20),                                -- engine machinery
  reliefs({0x2E0,0x2E3,0x2E5,0x2E8,0x2E9,0x2EA,0x2EB,0x2EC,0x2ED,0x2F0,0x2F1,0x2F2,0x2F3,0x2F4,0x2F5,0x2F6},16)), -- crates
 'general')
M.inside_ship.wallGround={[0x201]=0x201}

-- Facility tileset extras: the black map padding 0x201 (Mt. Pyre's
-- irregular floors, Devon 1F, Aqua Hideout) is a black mass, not a pit; Mt.
-- Pyre's grey stone wall run (0x2E4/0x2EC/0x2EF/0x2F7, the ledge ends
-- 0x31F/0x327) stands as wall.
do
 local p=M.facility
 for _,id in ipairs({0x201,0x2E4,0x2EC,0x2EF,0x2F7,0x31F,0x327})do p.walls[id]=true end
 p.wallGround=p.wallGround or {};p.wallGround[0x201]=0x201
end

-- Route 117 Day Care: as generated, but the wooden fence along the south
-- edge (0x240/0x241) is a low fence in its own art, not a full wall.
profile('pokemon_day_care',0x201,
 {0x004,0x208,0x209,0x20A,0x20C,0x20D,0x20F,0x210,0x211,0x213,0x215,0x217,0x21C,0x220,
  0x221,0x223,0x224,0x22E,0x235,0x236,0x237,0x23D,0x23F},
 join(
  reliefs({0x240,0x241},10),                                        -- fence
  {{0x21B,'bin',12}},
  reliefs({0x225,0x229,0x22A,0x231,0x232,0x234,0x243},18)))

-- Generated rooms (tools/gen_emerald_tables.py): the north wall is the blocked
-- art on the top two rows, other blocked cells are reliefs, counters bins.
-- Hand profiles above take precedence.
do
 local ok,auto=pcall(function()return V and V.require and V.require('Gen3EmeraldAuto') end)
 if not (ok and auto) then ok,auto=pcall(dofile,(os.getenv('DS_MOD_PATH') or '.')..'/lib/Gen3EmeraldAuto.lua') end
 for key,gen in pairs(ok and auto and auto.interiors or {})do
  if not M[key] then profile(key,gen.floor,gen.walls or {},gen.props or {}) end
 end
end
-- Battle Frontier rooms drawn with the General primary (the Reception Gate):
-- the same secondary art, so the generated profile's walls apply there too
-- (its north wall 0x3BB/0x3C3 and the doorway frame 0x254/0x256; the doorway
-- 0x255 between them stands in the wall)
if M.battle_frontier then
 M.battle_frontier.primary='general'
 M.battle_frontier.wallsAny=M.battle_frontier.wallsAny or {}
 M.battle_frontier.walls[0x255]=true;M.battle_frontier.wallsAny[0x255]=true
end
-- Battle Tent lobby (Slateport, Verdanturf, Fallarbor): the orange drapes
-- down both sides are the tent's walls (they stood as stacked fins); the
-- purple fabric edge on the west (0x292-0x294) is floor, and the bottom
-- corners (0x001, 0x228, 0x230, 0x295: black in the building primary) are
-- not dark drums.
do
 local p=M.battle_tent
 if p then
  for _,id in ipairs({0x20A,0x212,0x21A,0x222,0x20F,0x217,0x21F,0x227})do p.walls[id]=true end
  local drop={[0x20A]=true,[0x212]=true,[0x21A]=true,[0x222]=true,[0x20F]=true,[0x217]=true,[0x21F]=true,[0x227]=true,
   [0x292]=true,[0x293]=true,[0x294]=true,[0x001]=true,[0x228]=true,[0x230]=true,[0x295]=true,
   [0x208]=true}   -- 0x208: the floor's shadow under each drape, not a fin
  for id in pairs({[0x292]=true,[0x293]=true,[0x294]=true})do p.walls[id]=nil end
  -- the tent's floor rounds off at the bottom corners (black there in the
  -- original): in 3D the checkered floor continues, in its own parity
  p.fills={[0x001]=0x210,[0x228]=0x211,[0x295]=0x211,[0x230]=0x211}
  local kept={}
  for _,pr in ipairs(p.props)do if not drop[pr[1]] then kept[#kept+1]=pr end end
  p.props=kept
 end
end
-- Furniture-audit architecture (stand-ins that are walls): Battle Dome door
-- frames, Battle Factory pillars, Trainer Hill's counter run, wall console and
-- roof fronts, the Champion's glass walls and ice slopes; the Battle Arena's
-- plank platform is flat floor raised by Gen3Elevation.DAIS.
do
 local function walls(key,ids,flat)
  local p=M[key];if not p then return end
  local fix={}
  for _,id in ipairs(ids)do fix[id]=true;if not flat then p.walls[id]=true else p.walls[id]=nil end end
  local kept={}
  for _,pr in ipairs(p.props)do if not fix[pr[1]] then kept[#kept+1]=pr end end
  p.props=kept
 end
 walls('battle_dome',{0x255,0x256,0x257,0x25D,0x25F,0x31F,0x317,0x2F0,0x300})
 walls('battle_factory',{0x353,0x210,0x208,0x24B,0x214})
 walls('trainer_hill',{0x315,0x352,0x319,0x318,0x348,0x349,0x30B,0x30C,0x303,0x304,0x30F,0x317,0x32D,0x213,0x214,0x215,
  0x381,0x384,0x36F,0x363,0x386})
 walls('elite_four',{0x2F0,0x2F7,0x2F8,0x2FF,0x300,0x307,0x308,0x309,0x30A,0x30B,0x30C,0x30D,0x30E,0x30F,0x311,0x314,0x316,0x318,0x31C,
  0x320,0x321,0x322,0x323,0x324})
 walls('battle_arena',{0x201,0x21F,0x223,0x224,0x225,0x226,0x215,0x216},true)
 -- the audit's last stand-ins (furniture session, 2026-10-07)
 walls('dewford_gym',{0x228,0x231,0x220,0x22A,0x230})
 walls('battle_palace',{0x213,0x214,0x215,0x210,0x212})
 -- the Battle Palace battle room (General primary, same secondary): its north
 -- wall drawing (red/gold pillars 0x23F/0x247/0x24F, the panels between,
 -- the exit door 0x248-0x252) stands as wall; two of its columns are not
 -- marked blocked, so these stand whatever their collision
 if M.battle_palace then
  local p=M.battle_palace;p.primary='general'
  p.wallsAny=p.wallsAny or {}
  for _,id in ipairs({0x23F,0x247,0x24F,0x24B,0x24C,0x24D,0x24E,0x255,0x256,0x248,0x249,0x24A,0x250,0x251,0x252})do
   p.walls[id]=true;p.wallsAny[id]=true end
 end
 walls('mauville_gym',{0x217,0x21D,0x234,0x235})
 -- Rustboro Gym: the north wall's two lower corner pieces
 walls('rustboro_gym',{0x215,0x217})
 -- the barrier cells are floor with a lightning card on them (Gen3PixelFurniture)
 if M.mauville_gym then M.mauville_gym.walls[0x228]=nil;M.mauville_gym.walls[0x229]=nil end
 walls('mauville_game_corner',{0x219,0x21B})
 walls('lilycove_museum',{0x288,0x28A})
 walls('cable_club',{0x2DD,0x2DE})
 walls('mossdeep_gym',{0x228,0x229})
 walls('lavaridge_gym',{0x230})
 walls('sootopolis_gym',{0x216})
 walls('trick_house_puzzle',{0x228})
end
-- Battle Pyramid floors: the sand maze-wall pieces (0x26B, 0x270, 0x271,
-- 0x2CA, 0x2CB) and the stone wall pieces (0x219, 0x21C, 0x21D, 0x231) were
-- voted props (free-standing slabs and drums); they are the maze's walls.
do
 local p=M.battle_pyramid
 if p then
  local fix={[0x26B]=true,[0x270]=true,[0x271]=true,[0x2CA]=true,[0x2CB]=true,[0x219]=true,[0x21C]=true,[0x21D]=true,[0x231]=true}
  for id in pairs(fix)do p.walls[id]=true end
  local kept={}
  for _,pr in ipairs(p.props)do if not fix[pr[1]] then kept[#kept+1]=pr end end
  p.props=kept
 end
end
-- Ever Grande halls: the walkway's orange rails, the landing's front ledge and
-- the dark drop were voted relief props (rows of tall red barrels); they are
-- flat and take the walkway's heights (Gen3Elevation.DAIS).
do
 local p=M.elite_four
 if p then
  local drop={[0x2D8]=true,[0x2DB]=true,[0x2DC]=true,[0x2E0]=true,[0x2E3]=true,[0x2E4]=true,[0x2E7]=true}
  -- the four rooms' side stands (Sidney, Phoebe, Glacia, Drake): a tall bank
  -- drawn as a light top over its striped front, built as wall with that art
  local stands={0x216,0x21E,0x226,0x23A,0x22E,0x217,0x21F,0x227,0x22F,0x23E,0x21D,0x225,0x23F,0x22D,0x215,
   0x245,0x246,0x247,0x241,0x24D,0x24E,0x24F,0x340,0x255,0x256,0x257,0x341,0x25D,0x25E,0x342,0x265,0x266,0x267,0x343,
   0x29E,0x276,0x277,0x275,0x27D,0x27E,0x27F,0x285,0x286,0x287,0x28D,0x271,0x28E,0x28F,
   0x2CE,0x2A6,0x2A7,0x2A5,0x2AD,0x2AE,0x2AF,0x2B5,0x2B6,0x2B7,0x2BD,0x2A1,0x2BE,0x2BF}
  for _,id in ipairs(stands)do drop[id]=true;p.walls[id]=true end
  local kept={}
  for _,pr in ipairs(p.props)do if not drop[pr[1]] then kept[#kept+1]=pr end end
  p.props=kept
 end
end
-- Lilycove Museum 1F: the partitions' end caps 0x20C/0x214 were voted props
-- (cream seats on brown posts); they are the partition's end: wall.
-- Mart tileset rooms (the Route 121 Safari Zone entrance is an L-shaped room
-- in it): blocked black padding 0x001 outside the room is dark wall mass, not
-- a pit in the floor.
do
 local p=M.lilycove_museum
 if p then
  local fix={[0x20C]=true,[0x214]=true}
  for id in pairs(fix)do p.walls[id]=true end
  local kept={}
  for _,pr in ipairs(p.props)do if not fix[pr[1]] then kept[#kept+1]=pr end end
  p.props=kept
 end
 -- the house tileset's partition end shadows 0x30A/0x30C (Fan Club, Dewford
 -- Hall) are the wall's shadow on the floor, not navy drums (a partition
 -- recipe that includes them still claims them)
 if M.generic_building then
  local kept={}
  for _,pr in ipairs(M.generic_building.props)do if pr[1]~=0x30A and pr[1]~=0x30C then kept[#kept+1]=pr end end
  M.generic_building.props=kept
 end
 if M.shop then M.shop.walls[0x001]=true;M.shop.wallGround=M.shop.wallGround or {};M.shop.wallGround[0x001]=0x001 end
end
-- Fortree treehouses: the front corners 0x3CC/0x3CD are black in the art
-- (the trunk's inside rounding off), a hole in the 3D floor: the plank floor
-- runs on (only these rooms use them)
do
 local p=M.generic_building
 if p then p.fills=p.fills or {};p.fills[0x3CC]=0x3D9;p.fills[0x3CD]=0x3D9 end
end
-- Lavaridge Gym: the partitions' end pieces were voted props -- 0x20B (the
-- striped end face under a 0x20C column) stood as a plain grey slab, 0x215
-- over 0x21F (a column's end on its lava-rock base) as a navy vase. They are
-- the partition's own end: wall.
do
 local p=M.lavaridge_gym
 if p then
  local fix={[0x20B]=true,[0x215]=true,[0x21F]=true}
  for id in pairs(fix)do p.walls[id]=true end
  local kept={}
  for _,pr in ipairs(p.props)do if not fix[pr[1]] then kept[#kept+1]=pr end end
  p.props=kept
 end
end
-- Trick House puzzle rooms: four pieces of the maze wall were voted props
-- (round 'relief' drums): 0x222/0x22C are the cream tops of north-south walls,
-- 0x22A the wood end face under 0x22B, 0x230 a wood face like 0x223. They are
-- wall, as 0x221/0x223-0x225/0x22B already are (furniture session's report).
do
 local p=M.trick_house_puzzle
 if p then
  local fix={[0x222]=true,[0x22A]=true,[0x22C]=true,[0x230]=true,
   -- (furniture session's audit) white posts and tops, wall ends, switch
   -- doors, door frames, doorway holes and puzzle 3's left wall
   [0x21E]=true,[0x226]=true,[0x22D]=true,[0x213]=true,[0x215]=true,[0x23A]=true,[0x242]=true,[0x24D]=true,
   [0x22E]=true,[0x22F]=true,[0x236]=true,[0x237]=true,[0x269]=true,[0x27E]=true}
  for id in pairs(fix)do p.walls[id]=true end
  local kept={}
  for _,pr in ipairs(p.props)do if not fix[pr[1]] then kept[#kept+1]=pr end end
  p.props=kept
 end
end
return M
