-- Pixel-voxel furniture recipes, second author. PCs and TVs are tube sets
-- (the user, 2026-10-06): their parts reach back (field 7) to about 4/5 of
-- their width, a near cube, not a flat panel. Each entry is the argument
-- list of add() in Gen3PixelFurniture.lua:
--   {name, secondary, rows, parts, groundMids, shadowPoints, height}
local R={}
local BACK_YES={'crate','box','load','bucket','bin','seat','chair','stool','sofa','bench','cushion','cot','bed',
 'stand','pedestal','planter','plant','pot','potbush','basket','statue','bust','grave','table','tablet','stump','log','trunk',
 'pillar','post','pole','cube','capsule','cooler','pylon','backrest','bush','beacon','benche','wide'}
local BACK_NO={'cabinet','counter','desk','pc','tv','shelf','machine','console','kiosk','fridge','sink','board',
 'display','screen','monitor','register','rack','wardrobe','drawer','server','engine','generator','vending','slot',
 'roulette','gate','partition','fence','rail','railflag','flag','umbrella','kitchen','stove','laptop','appliance','case','showcase'}
local function add(...)
 local a={...}
 -- potted plants: no extra height (repeating leaf rows reads as stripes)
 if a[1]:find('plant') and not a[1]:find('planter') then
  a[9]=a[9] or {};a[9].lift=0
  -- Seat the leaves on the pot. A drawing row r lands on screen row
  -- depth - height, so the crown can sit anywhere along that line; put its
  -- footprint centred over the pot: half the leaf rows on its top, half on
  -- its face (a round bush, not a sheet), lifted (base) so it sits there. A trunk from the pot's rim up to the crown shows the
  -- pot's own soil and rim rows on its face, so head-on nothing changes.
  local pot,leaves
  for _,pt in ipairs(a[4])do if pt[11] then leaves=pt else pot=pt end end
  if pot and leaves then
   local L0,L1=leaves[6],leaves[3]+leaves[4]
   local n=math.floor((L1-L0+1)/2)              -- half the rows deep, half tall
   local c=(pot[6]+pot[3])/2+pot[4]             -- the pot's middle (depth)
   -- The crown's front edge over the pot's middle: a crown centred over the
   -- pot had to be lifted ~13 px to keep the drawing in place and read as a
   -- lollipop on a stick from low down; this way it rests on the pot on a
   -- short stem, overhanging the back rim (still inside the pot's cell)
   local F=math.floor(c+.5)
   if a[9].crownCentre then F=math.floor(c+n/2+.5) end
   leaves[3]=L0+n-1;leaves[4]=L1-leaves[3];leaves[11]=math.max(pot[4]+1,F-1-L1)
   local cx=math.floor((pot[1]+pot[2])/2)
   a[4][#a[4]+1]={cx-2,cx+2,L1,leaves[11]-pot[4],true,L1-3,nil,'disc',nil,nil,pot[4]}
  end
 end
 -- Backs (the user, 2026-10-11): a piece that looks the same turned round
 -- (a crate, a seat, a stool, a planter, a statue) repeats its face on its
 -- back plane (part field 14) instead of one flat colour. TVs, PCs, counters,
 -- cabinets, shelves and machines keep a plain back. opts.back forces it
 -- either way. Only plain solid parts take the field.
 local back=a[9] and a[9].back
 if back==nil then
  local yes,no=false,false
  for tok in a[1]:gsub('^em_gate_','em_'):gmatch('[^_]+')do   -- em_gate_*: the Reception Gate's pieces, not gates
   tok=tok:gsub('%d+$',''):gsub('s$','')
   for _,w in ipairs(BACK_NO)do if tok:sub(-#w)==w then no=true end end
   for _,w in ipairs(BACK_YES)do if tok:sub(-#w)==w then yes=true end end
  end
  back=yes and not no
 end
 if back then for _,pt in ipairs(a[4])do
  if pt[5]==true and (not pt[8] or pt[8]==true) and pt[14]==nil then   -- plain and round=true parts (not disc/card/ball)
   pt[14]=true
  end
 end end
 R[#R+1]=a
 -- the facility tileset is used under both families (general__facility for
 -- Devon, building__facility elsewhere): register a 'general' twin too
 if a[2]=='facility' then
  local b={};for i=1,9 do b[i]=a[i] end
  b[1]=a[1]..'_g';local o={};for k,v in pairs(a[9] or {})do o[k]=v end;o.primary='general';b[9]=o
  R[#R+1]=b
 end
end

-- Rustboro Pokemon School: student desks (three art variants) with the chair
-- tucked under the front, the desk whose chair is pulled out askew, and the teacher's desk. Floor 0x201.
for _,m in ipairs({{0x20C,0x214},{0x20D,0x215}})do
 add('em_school_desk_'..string.format('%X',m[1]),'pokemon_school',{{m[1]},{m[2]}},
  {{0,16,9,7,true},{3,13,19,4,false,13}},{0x201},{{0,17},{2,18}},7)
end
-- 0x20E/0x216: the chair stands askew, so it is three column strips whose
-- feet reach the floor on rows 20, 23 and 21.
add('em_school_desk_20E','pokemon_school',{{0x20E},{0x216}},
 {{0,16,9,7,true},{2,6,16,4,false,13},{6,9,19,4,false,13},{9,14,17,4,false,12}},{0x201},{{0,17},{2,21}},7)
-- the blackboard on the north wall (4 cells from 0x228, rows 0..17) over its
-- slatted wooden cabinet (0x230..0x233: top rows 18..19, a 12-row face)
add('em_school_blackboard','pokemon_school',{{0x228,0x229,0x22A,0x22B},{0x230,0x231,0x232,0x233}},
 {{0,64,19,12,true,18,nil,nil,true},{0,64,-1,18,true,0,16,nil,true,nil,12}},{0x201,0x221},nil,12,nil,{lift=0})
add('em_school_teacher_desk','pokemon_school',{{0x21C,0x21D},{0x224,0x225}},
 {{0,32,22,8,true}},{0x201,0x221},{{2,8}},8)

-- Gym entrance statues (one drawing, eight palettes): a pedestal whose top
-- (rows 0-15, the badge dish) lies flat and whose front stands 16 tall.
-- Floor corners and the drop shadow are sampled per gym.
for _,g in ipairs({
 {'rustboro',0x21E,0x226,{0x201,0x237},{{0,0},{0,30},{0,31}}},
 {'dewford',0x21F,0x227,{0x213,0x20C}},
 {'mauville',0x216,0x21E,{0x24F,0x204}},
 {'lavaridge',0x215,0x21F,{0x210,0x208},{{0,0},{1,0},{1,1},{2,0}}},
 {'petalburg',0x240,0x248,{0x205,0x22C}},
 {'fortree',0x227,0x22F,{0x201,0x206}},
 {'mossdeep',0x204,0x20C,{0x224,0x209}},
 {'sootopolis',0x217,0x21F,{0x257,0x23F},{{0,0},{0,31}}},
})do
 add('em_gym_statue_'..g[1],g[1]..'_gym',{{g[2]},{g[3]}},{{0,16,15,16,true}},g[4],g[5],16)
end

-- Fortree Gym: Winona's rounded platform (5x2 cells). Its front face shortens
-- toward the rounded ends, so the ends are column strips of falling height;
-- the middle runs one row lower (the step). Winona stands on its top (dais).
add('em_fortree_platform','fortree_gym',{{0x21B,0x21C,0x21D,0x21E,0x21F},{0x240,0x241,0x242,0x243,0x244}},
 {{1,3,23,4,true},{3,5,23,5,true},{5,7,23,6,true},{7,16,23,7,true},{16,63,23,8,true},
  {63,73,23,7,true},{73,75,23,6,true},{75,77,23,5,true},{77,79,23,4,true}},{0x202},{{0,7}},8,nil,{dais=true})

-- Fortree Gym maze: columns of round tree stumps, one per cell, h=10. Most
-- stumps' tops are drawn on rows 11..20 counted from the cell above (rows
-- -5..4 here) with the face on rows 5..14, so a stump stands wholly in its own
-- cell; the next stump's top hides the lower face rows exactly as in the art.
-- 0x20B heads a column: its own top is rows 2..12 and its face runs to row 25.
-- The border bushes (0x218) are the same stumps with tops on rows 3..12.
-- 0x219 and 0x210 only carry the face of the stump above (empty recipes, so
-- they're not built as walls). The last stump of a column (0x211) samples its
-- drop shadow. 'disc': turned, a true cylinder.
local stumpGround={0x202,0x201}
for _,mid in ipairs({0x220,0x21A,0x22C})do
 add('em_fortree_stump_'..string.format('%X',mid),'fortree_gym',{{mid}},{{0,16,4,10,true,-5,nil,'disc'}},stumpGround,nil,10)
end
add('em_fortree_stump_211','fortree_gym',{{0x211}},{{0,16,4,10,true,-5,nil,'disc'}},stumpGround,{{0,11}},10)
add('em_fortree_stump_20B','fortree_gym',{{0x20B}},{{0,16,12,13,true,2,nil,'disc'}},stumpGround,nil,13)
add('em_fortree_bush_218','fortree_gym',{{0x218}},{{0,16,12,13,true,3,nil,'disc'}},stumpGround,nil,13)
for _,mid in ipairs({0x219,0x210})do
 add('em_fortree_stump_face_'..string.format('%X',mid),'fortree_gym',{{mid}},{},stumpGround,nil,0)
end

-- Fortree Gym gate arms: twin segmented logs running north from a pivot
-- stump, at the stump's top height (10) so they join it. 0x23A caps a column,
-- 0x233 continues it, 0x229/0x23B end on the stump below (whose top starts on
-- row 10, so the logs stop at row 9). 0x238 is a short loose pair of logs
-- lying on the floor: 3 rows of its own face show under its top.
local function logs(front,h)
 return {{0,7,front,h,true,0,nil,true},{9,16,front,h,true,0,nil,true}}
end
for _,mid in ipairs({0x23A,0x233})do
 add('em_fortree_gate_'..string.format('%X',mid),'fortree_gym',{{mid}},logs(15,10),{0x202,0x201},nil,10)
end
for _,mid in ipairs({0x229,0x23B})do
 add('em_fortree_gate_'..string.format('%X',mid),'fortree_gym',{{mid}},logs(9,10),{0x202,0x201},nil,10)
end
add('em_fortree_logs_238','fortree_gym',{{0x238}},logs(12,3),{0x202,0x201},nil,3)

-- Pokemon Center 1F (34 Centers). The PC against the back wall: a cabinet
-- whose cap is rows 8..11 (rows 0..7 are wall), face to row 39; its feet are
-- floor shadow (capped under the 32-px wall top). The low bookshelf beside the plant: white top rows 0..8,
-- shelves on its face down to row 23.
-- (Opus, user: "the pc is wonky, make it look real") Read as a real wall
-- terminal: a base cabinet (face rows 32..39, 8 tall) whose top is the
-- keyboard (rows 25..31, lying flat 7 deep, typed on), and the monitor
-- housing (face rows 12..24 with the screen, white cap rows 8..11) standing
-- on the cabinet behind the keyboard, a deep tube set (backZ 14: ~10 deep for
-- its 12-px screen, user: CRTs are near cubes), against the wall, whose own art
-- stays on the wall plane above it. Was one 4-px slab with the keyboard and
-- screen painted on its front.
add('em_center_pc','pokemon_center',{{0x20C},{0x004},{0x224}},
 {{1,15,15,24,true,8,28,nil,true,nil,nil,{8,13}}},{0x202},{{1,42}},24,32,{lift=0})
-- Center 2F laptop (0x004 over 0x2B6, on the floor beside the counter): an open laptop. Its keyboard (art rows 9..15)
-- lies flat on a 5-tall base whose grey front is rows 16..20; the screen (rows 0..8) stands on the base's back edge as
-- a thin panel.
add('em_center_laptop','pokemon_center',{{0x004},{0x2B6}},
 {{0,16,15,5,true,9},{0,16,-1,9,true,0,nil,'card',nil,nil,5}},{0x202},nil,14)
add('em_center_bookshelf','pokemon_center',{{0x271,0x272},{0x279,0x27A}},{{0,32,8,15,true}},{0x202},{{2,25}},15)

-- The front desk (6x2 from 0x250): its top is drawn in the floor's own cream,
-- so its parts keep every pixel (part field 9). Two side wings run back to
-- the wall (top rows -7..12), the front counter's top is rows 13..20 and its
-- face 11 tall. Behind it: the healing machine, a low deep console (its
-- ball cups and conveyor are its top, rows -14..6, an 8-row front) and the
-- medical box, standing on the floor (no lift: it would stretch the front
-- notches and hide the machine base). The Poke Ball on each curved end
-- stands up off the counter top as a round ball (base 11). Nurse Joy's cell (0x207) stays floor.
add('em_center_desk','pokemon_center',{{0x250,0x22A,0x22B,0x207,0x25B,0x251},{0x258,0x221,0x221,0x205,0x221,0x259}},
 {{1,16,20,11,true,-7,nil,nil,true},{80,95,20,11,true,-7,nil,nil,true},{1,95,20,11,true,13,nil,nil,true},
  {17,47,6,8,true,-14,nil,nil,true},{65,79,-4,16,true,-7},
  {3,14,20,0,true,8,nil,'ball',true,nil,11},{82,93,20,0,true,8,nil,'ball',true,nil,11}},{0x202},nil,11,nil,{lift=0})

-- The potted plant in the back corner (wall cell 0x211 over 0x219): a round
-- pot (top rows 11..16, face 6) with the leaves as a round bush standing on
-- the pot's rim (base 6; top rows 0..2, face rows 3..13). Wall colours round
-- the leaves are sampled out.
add('em_center_plant','pokemon_center',{{0x211},{0x219}},
 {{3,13,16,6,true,11,nil,'disc'},{0,16,2,11,true,0,nil,'disc',nil,nil,6}},{0x202},{{0,0},{0,8},{0,15},{0,16}},6)

-- Center 2F potted plants (0x25E over 0x266): round pot (top rows 19..24,
-- face 6) and the leaves (rows 3..18, drawn sitting on the soil) as a round
-- bush resting on the pot.
add('em_center_plant_2f','pokemon_center',{{0x25E},{0x266}},
 {{3,13,24,6,true,19,nil,'disc'},{0,16,7,11,true,3,nil,'disc',nil,nil,6}},{0x202},{{1,26}},6)

-- the same plant drawn against the east wall (League lobby: 0x20A over
-- 0x212); the wall's edge strip and the pot's shadow are sampled out
add('em_center_plant_wall_e','pokemon_center',{{0x20A},{0x212}},
 {{3,13,24,6,true,19,nil,'disc'},{0,13,7,11,true,3,nil,'disc',nil,nil,6}},{0x202,0x240},{{15,0},{1,26}},6)

-- Center 2F long reception counter, one recipe per counter cell (y=3): its
-- cream top is drawn from row 12 of the cell above (rows -4..8 here), the
-- face rows 9..15; keep, since the top is floor-coloured. Extra height repeats
-- a plain face row. The terminals (0x25D) and Cable Club machines keep their
-- own handling. UNVERIFIED.
for _,mid in ipairs({0x2D6,0x2E0,0x2D7,0x2D5})do
 add('em_center_2f_counter_'..string.format('%X',mid),'pokemon_center',{{mid}},
  {{0,16,8,7,true,-4,nil,nil,true,12}},{0x202},nil,7)
end

-- the counter gate under each back-room door (0x25D, between the counter
-- runs): the same counter height so the desk runs through (it was left a
-- gap); its grey screen panel the top, sides in the gate's grey.
add('em_center_2f_gate','pokemon_center',{{0x25D}},{{0,16,8,7,true,-4,nil,nil,true,12,nil,{6,6}}},{0x202},nil,7)

-- Center 2F link machines (0x2DB over 0x2E3, 0x2DA over 0x2E2): the keypad
-- box (top rows 8..11, keypad face to row 22) standing on its grey stand
-- (top rows 23..24, 6-row face; base 6). The white cable from the ceiling
-- stays painted on the wall.
for _,m in ipairs({{0x2DB,0x2E3},{0x2DA,0x2E2}})do
 add('em_center_link_'..string.format('%X',m[1]),'pokemon_center',{{m[1]},{m[2]}},
  {{2,14,24,6,true,23},{1,15,11,11,true,8,nil,nil,nil,nil,6}},{0x202},{{0,31}},6,nil,{lift=0})
end

-- 0x23C on its own (Center 2F, beside a link machine) is only floor shadow.
add('em_center_flat_23C','pokemon_center',{{0x23C}},{{0,16,15,0}},{0x202},nil,0)

-- The three dark oval marks on the floor beside the PC are floor details: a
-- zero-height part keeps them painted flat (they were being stood up as boxes).
add('em_center_floor_marks','pokemon_center',{{0x23C},{0x225}},{{0,16,22,0}},{0x202},nil,0)

-- Poke Mart (23 Marts). The goods shelves against the back wall: rows 0..14
-- are wall, the top rows 15..17, the stocked face down to row 39; below that
-- is only the shelf's shadow on the floor. The extra height repeats the base
-- row (38), never the goods.
for _,b in ipairs({0x230,0x221})do
 add('em_mart_wall_shelf_'..string.format('%X',b),'shop',{{0x223,0x224},{0x228,0x229},{b,0x231}},
  {{0,32,17,22,true,15,nil,nil,nil,38}},{0x201},nil,22)
end

-- The Mart's L-shaped glass counter. Its tops are drawn in the floor's own
-- colours where the glass shows through, so parts keep every pixel. The arm
-- along x=2 (four cells from the back wall): register and glass top rows
-- 8..54, face 8 tall; the arm along y=4 (two cells): top rows -3..6. Extra
-- height repeats a plain teal face row.
add('em_mart_counter_arm','shop',{{0x22A},{0x232},{0x23A},{0x242}},{{0,16,54,8,true,8,nil,nil,true,58,nil,{1,9}}},{0x201},nil,8)
add('em_mart_counter_front','shop',{{0x320,0x241}},{{0,32,6,8,true,-3,nil,nil,true,10,nil,{1,2}}},{0x201},nil,8)
-- The tiered display racks (one column of a rack per recipe, 1x3): three
-- shelves stepping down toward the front, at heights 36, 26 and 16 read off
-- where each shelf's face meets the next shelf's top. No lift, so the tiers
-- keep meeting exactly as drawn. (0x2AA/0x2AB tops: the Lilycove Department
-- Store's racks, same shape.)
for _,c in ipairs({{0x22B,0x233,0x23B},{0x22C,0x234,0x23C},{0x2AA,0x233,0x2B2},{0x2AB,0x234,0x2B3}})do
 add('em_mart_rack_'..string.format('%X',c[1]),'shop',{{c[1]},{c[2]},{c[3]}},
  {{0,16,3,36,true,0,nil,nil,nil,nil,nil,{2,15}},{0,16,17,26,true,14,nil,nil,nil,nil,nil,{2,15}},{0,16,31,16,true,28,nil,nil,nil,nil,nil,{2,15}}},{0x201},nil,16,nil,{lift=0})
end

-- Mart potted plant (0x225 over 0x22D): round pot (top rows 17..23, face 7),
-- leaves as a round bush on its rim (base 7). The octagon floor's own
-- colours round it are sampled out. UNVERIFIED.
add('em_mart_plant','shop',{{0x225},{0x22D}},
 {{2,14,23,7,true,17,nil,'disc'},{0,16,4,12,true,0,nil,'disc',nil,nil,7}},{0x201},{{0,0},{2,0},{0,3}},7)

-- Shared house tileset (generic_building, 73 houses). UNVERIFIED.
-- Potted plants: free-standing (0x222 over 0x22A) and against the back wall
-- (0x290 over 0x298, wall and baseboard colours sampled out). Round pot (top
-- rows 18..24, face 7) with the leaves as a round bush on its rim (base 7).
add('em_generic_plant','generic_building',{{0x222},{0x22A}},
 {{2,14,24,7,true,18,nil,'disc'},{0,16,4,13,true,1,nil,'disc',nil,nil,7}},{0x223},nil,7)
add('em_generic_plant_wall','generic_building',{{0x290},{0x298}},
 {{2,14,24,7,true,18,nil,'disc'},{0,16,4,13,true,1,nil,'disc',nil,nil,7}},{0x223},{{0,0},{0,20}},7)
add('em_generic_plant_291','generic_building',{{0x291},{0x299}},
 {{2,14,24,7,true,18,nil,'disc'},{0,16,4,13,true,1,nil,'disc',nil,nil,7}},{0x223},nil,7)
-- The TV against the back wall (1x3, rows 0..12 are wall): the set (top rows
-- 13..15, screen face to row 29) stands on its stand (top rows 30..31, legs
-- down to row 39, base of the set = 8).
add('em_generic_tv','generic_building',{{0x230},{0x21E},{0x238}},
 {{0,16,31,8,true,30},{0,16,15,14,true,13,17,nil,nil,nil,8}},{0x224,0x223},{{0,8}},8)
-- Sink and stove counter (2x2 from 0x26C): top rows 5..16 (basin, hob), the
-- drawers on its 7-row face; the extra height repeats the plinth row.
add('em_generic_sink_stove','generic_building',{{0x26C,0x26D},{0x274,0x275}},
 {{0,32,16,7,true,5,nil,nil,nil,22}},{0x224,0x223},nil,7)

-- Mauville Gym: the barrier posts. Each post stands on its blocked cell and is
-- drawn up into the cell above: the insulator cap's top is rows -9..-4, its
-- face (cap, neck, foot) runs down to row 14. Round ('disc'); the extra height
-- repeats a neck row. The lightning beams between posts stay flat. UNVERIFIED.
-- 0x240's foot has the north-south bolt drawn across it (its cyan sampled
-- out by a shadow point, so the post isn't striped; the bolt stands in
-- em_mauvgym_bolt_248).
for _,mid in ipairs({0x246,0x247,0x24E,0x240,0x218,0x243})do
 add('em_mauville_post_'..string.format('%X',mid),'mauville_gym',{{mid}},
  {{0,16,-4,18,true,-9,nil,'disc',nil,2}},{0x20A,0x209},mid==0x240 and {{7,0}} or nil,18)
end
-- Roxanne's platform (5x2 from 0x208): the white slab with its gold plate
-- and the spiral rocks at its corners, top rows 0..23, an 8-row front; a
-- dais, so Roxanne stands on it.
add('em_rustboro_platform','rustboro_gym',{{0x208,0x209,0x20A,0x20B,0x20C},{0x210,0x211,0x212,0x213,0x214}},
 {{0,80,23,8,true,0,nil,nil,true}},{0x201,0x202,0x203,0x204},nil,8,nil,{dais=true,lift=0})
-- Wattson's stage (4x2 from 0x224): top rows 1..23, a 7-row front with the
-- steps in the middle; a dais, so Wattson stands on it. UNVERIFIED.
add('em_mauville_stage','mauville_gym',{{0x224,0x225,0x226,0x227},{0x22C,0x22D,0x22E,0x22F}},
 {{1,63,23,7,true,0}},{0x20A},nil,7,nil,{dais=true})

-- Petalburg Gym: Norman's platform (5x2 from 0x233). Its cream top is the
-- floor's colour (keep). Top rows 1..23, a 7-row front; in the middle two
-- steps come down to the floor (tops rows 24..25 and 28..29). A dais, so
-- Norman stands on it. UNVERIFIED.
add('em_petalburg_platform','petalburg_gym',{{0x233,0x234,0x235,0x236,0x237},{0x23B,0x23C,0x23D,0x23E,0x23F}},
 {{1,80,23,7,true,1,nil,nil,true},{16,65,25,6,true,24,nil,nil,true},{16,65,29,2,true,28,nil,nil,true}},
 {0x201},nil,7,nil,{dais=true})

-- Mossdeep Gym: Tate and Liza's stage (4x2 from 0x218): top rows 0..23
-- (the pink mat), a 6-row front, and a step down the middle (top rows
-- 26..27, 4 tall). A dais. UNVERIFIED.
add('em_mossdeep_stage','mossdeep_gym',{{0x218,0x219,0x21A,0x21B},{0x220,0x221,0x222,0x223}},
 {{0,64,23,6,true,0},{16,48,27,4,true,26}},{0x20A},nil,6,nil,{dais=true})

-- Sootopolis Gym: Juan's platform (5x2 from 0x231): cream border drawn in the
-- floor's colour (keep), top rows 1..25, a 6-row front. A dais. UNVERIFIED.
add('em_sootopolis_platform','sootopolis_gym',{{0x231,0x22A,0x22B,0x22C,0x236},{0x204,0x232,0x233,0x234,0x205}},
 {{1,79,25,6,true,1,nil,nil,true}},{0x23E},nil,6,nil,{dais=true})
-- The wall fountains (2x3 from 0x268): the falling water on a block against
-- the wall (rim rows 8..10, face to row 31), the basin in front (water
-- surface rows 32..42, a 3-row rim). UNVERIFIED.
add('em_sootopolis_fountain','sootopolis_gym',{{0x268,0x269},{0x270,0x271},{0x278,0x279}},
 {{2,30,10,21,true,8,nil,nil,true},{3,29,42,3,true,32,nil,nil,true}},{0x23E},nil,3)

-- Dewford Gym: Brawly's ring (4x2 from 0x232 over four 0x210): the mat is
-- the top (rows 0..24), a 7-row front; the two back corner posts stand on the
-- mat (base 7, top rows 0..1, 6 tall). A dais. UNVERIFIED.
add('em_dewford_ring','dewford_gym',{{0x232,0x233,0x234,0x235},{0x210,0x210,0x210,0x210}},
 {{1,63,24,7,true,0},{1,6,1,6,true,0,nil,nil,nil,nil,7},{58,63,1,6,true,0,nil,nil,nil,nil,7}},
 {0x201,0x210},nil,7,nil,{dais=true})
-- The two green speakers beside it (1x2 from 0x22E): grille top rows 0..7,
-- a 24-row face of stacked cabinets; extra height repeats a cabinet stripe.
add('em_dewford_speaker','dewford_gym',{{0x22E},{0x236}},{{0,16,7,24,true,0,nil,nil,nil,27}},{0x201,0x210},nil,24)

-- Lavaridge Gym: Flannery's platform (5x2 from 0x218): top rows 2..23, the
-- rounded ends 6 tall, the middle 8 (it reaches one row lower). A dais.
-- UNVERIFIED.
add('em_lavaridge_platform','lavaridge_gym',{{0x218,0x219,0x21A,0x21B,0x21C},{0x220,0x221,0x222,0x223,0x224}},
 {{1,16,23,6,true,2},{64,79,23,6,true,2},{16,64,23,8,true,2}},{0x208,0x209},{{0,31}},8,nil,{dais=true})

-- Battle Tent lobby (Slateport, Verdanturf, Fallarbor share it): two low
-- yellow counters, faces only along their fronts (5-6 rows), the curved
-- corners as column strips whose front edge steps with the curve. Over the
-- left counter's front hangs a blue cloth (cols 24..55): the counter runs on
-- at its height with the cloth its face, the cloth pooling in a low 2-row
-- skirt on the floor in front.
local tentFloor={0x210,0x211,0x209,0x208}
add('em_tent_counter_left','battle_tent',
 {{0x268,0x269,0x209,0x208},{0x270,0x209,0x210,0x211},{0x278,0x279,0x27A,0x27B},{0x280,0x281,0x282,0x283},{0x288,0x289,0x28A,0x28B}},
 {{1,6,50,6,true,0},{6,12,53,6,true,0},{12,24,56,6,true,0},{15,32,15,6,true,9},{24,56,56,6,true,0},{24,56,69,2,true,63,nil,nil,true},{56,64,56,6,true,44}},
 tentFloor,nil,6)
add('em_tent_counter_right','battle_tent',
 {{0x208,0x209,0x26E,0x26F},{0x211,0x210,0x209,0x277},{0x27C,0x27D,0x27E,0x27F},{0x284,0x285,0x286,0x287}},
 {{0,48,57,5,true,45},{48,54,57,5,true,0},{54,60,53,5,true,0},{60,64,50,5,true,0}},
 tentFloor,nil,5)

-- Lilycove Department Store (shop tileset). The U-shaped glass counter (6x4
-- from 0x2DD): the front case (top rows 12..21 with the goods under glass,
-- a 10-row face) and the two arms back to the wall (glass tops in the floor's
-- colour, so keep; the register on the left arm stays painted on its top).
add('em_store_counter','shop',
 {{0x2DD,0x29B,0x29B,0x29B,0x29B,0x2DD},{0x29E,0x2A3,0x2A3,0x2A3,0x2A3,0x29E},{0x2A4,0x20B,0x208,0x208,0x208,0x29E},{0x2DE,0x206,0x201,0x201,0x201,0x2D1}},
 {{16,80,21,10,true,12},{0,16,53,10,true,12,nil,nil,true},{80,96,53,10,true,12,nil,nil,true}},
 {0x201,0x208,0x206},nil,10)
-- 5F: the glass case on the east (an arm down x14: 0x306 over 0x29E 0x29E
-- over 0x2D1, top rows 12..53, a 9-row face; the case cells drawn on the
-- floor row above their collision, 0x2F7 over 0x2A3: top rows 13..22)
add('em_store_case_arm','shop',{{0x306},{0x29E},{0x29E},{0x2D1}},{{0,16,53,9,true,12,nil,nil,true}},{0x2F2,0x2F4,0x2F7,0x2F3,0x2FA,0x2FD},nil,9,nil,{lift=0})
add('em_store_case','shop',{{0x2F7},{0x2A3}},{{0,16,22,9,true,13,nil,nil,true}},{0x2F2,0x2F4,0x2F3,0x2FA,0x2FD},nil,9,nil,{lift=0})
-- Its potted plants (0x26D over 0x275): round pot (top rows 19..24, face 6),
-- leaves on its rim (base 6); octagon floor colours sampled out. UNVERIFIED.
add('em_store_plant','shop',{{0x26D},{0x275}},
 {{3,13,24,6,true,19,nil,'disc'},{0,16,8,10,true,3,nil,'disc',nil,nil,6}},{0x201},{{0,3},{0,12},{15,12}},6)
-- Department Store 1F: the reception counter (6x3 from 0x29C): a low back
-- counter at the wall (top rows 8..12), the side arms (top rows 8..39) and
-- the front counter (top rows 28..39), 7-row faces; the clerks' floor between
-- stays floor. UNVERIFIED.
add('em_store_reception','shop',
 {{0x29C,0x290,0x290,0x290,0x290,0x29D},{0x2A4,0x2D4,0x298,0x299,0x298,0x2A5},{0x2AC,0x2A1,0x2A0,0x2A1,0x2A0,0x2AD}},
 {{16,80,12,3,true,8},{0,16,39,7,true,8},{80,96,39,7,true,8},{0,96,39,7,true,28}},{0x268,0x270},nil,7)
-- Route 121 Safari Zone entrance: the reception counter (6x2 from 0x2A8):
-- its two arms (tops from the cell above, rows -16..23) and the front
-- counter (top rows 12..23), 8-row faces; the clerks' floor behind stays
-- floor. The east desk: a long counter down x16 (0x2C3 over 0x2D0 x4 over
-- 0x2D1, top rows 8..87) and two short ends beside it (0x2C3/0x2D2 over
-- 0x2D1). The planter boxes of shrubs (0x259/0x25A over 0x261/0x262).
local sfz={0x268,0x270,0x278,0x280,0x271,0x279,0x298,0x299,0x2D4}
add('em_safari_counter','shop',{{0x2A8,0x2D4,0x298,0x299,0x299,0x2A9},{0x2B0,0x2A1,0x2A0,0x2A1,0x2A1,0x2B1}},
 {{0,16,23,8,true,-16,nil,nil,true},{80,96,23,8,true,-16,nil,nil,true},{16,80,23,8,true,12,nil,nil,true}},sfz,nil,8,nil,{lift=0})
add('em_safari_desk_long','shop',{{0x2C3},{0x2D0},{0x2D0},{0x2D0},{0x2D0},{0x2D1}},{{0,16,87,8,true,8,nil,nil,true}},sfz,nil,8,nil,{lift=0})
for _,t in ipairs({0x2C3,0x2D2})do
 add('em_safari_desk_end_'..string.format('%X',t),'shop',{{t},{0x2D1}},{{0,16,23,8,true,8,nil,nil,true}},sfz,nil,8,nil,{lift=0})
end
add('em_safari_chair','shop',{{0x2C8}},{{1,5,11,10,true,0,nil,nil,nil,nil,nil,{2,6}},{4,15,11,4,true,4,nil,nil,nil,nil,nil,{9,7}}},sfz,{{0,0},{15,0},{0,15},{15,15}},4,nil,{lift=0})
add('em_safari_chair_e','shop',{{0x2BA}},{{11,15,11,10,true,0,nil,nil,nil,nil,nil,{12,6}},{1,12,11,4,true,4,nil,nil,nil,nil,nil,{6,7}}},sfz,{{0,0},{15,0},{0,15},{15,15}},4,nil,{lift=0})
add('em_safari_planter','shop',{{0x259,0x25A},{0x261,0x262}},{{0,31,23,8,true,10,nil,nil,true}},sfz,nil,8,nil,{lift=0})
-- Route 121 Safari Zone entrance: potted plants on the orange floor (0x25C
-- over 0x264, and over 0x274 by the south-east desk). Round pot (top rows
-- 19..24, face 6), the leaves (rows 3..18) a round bush on it; the floor
-- round the crown is sampled out.
for _,lo in ipairs({0x264,0x274})do
 add('em_safari_plant_'..string.format('%X',lo),'shop',{{0x25C},{lo}},
  {{3,13,24,6,true,19,nil,'disc'},{0,16,7,11,true,3,nil,'disc',nil,nil,6}},{0x268,0x270,0x280,0x278},
  {{0,0},{15,0},{3,0},{1,1},{13,0},{15,16},{0,31},{15,31}},6)
end
-- Department Store rooftop: the flower planters (2x2 from 0x2C9; top rows
-- 9..22 the flowers, a 7-row face), the purple benches (0x2C1 0x2C2: seat
-- top rows 3..10, 5-row front) and the chair by the east rail (0x2C0,
-- backrest on its right)
local rtf={0x24A,0x24D,0x25B}
-- the two vending machines at the north rail (drawn in 0x26F: top rows
-- 1..9, a 21-row front of cans and the slot; 0x277 is the cell they block)
add('em_roof_vending','shop',{{0x26F},{0x277}},{{1,15,9,21,true,1,nil,nil,true}},{0x24A,0x253,0x281},nil,21,nil,{lift=0})
-- Department Store 1F: the round red-checked stools by the counter (0x26E)
add('em_store_stool','shop',{{0x26E}},{{2,14,9,5,true,0,nil,'disc',true}},{0x268,0x270},{{0,0}},5,nil,{lift=0})
add('em_roof_planter','shop',{{0x2C9,0x2CA},{0x2CB,0x2CC}},{{0,31,22,7,true,9,nil,nil,true}},rtf,{{0,0},{8,0},{12,0},{3,4}},7,nil,{lift=0})
add('em_roof_bench','shop',{{0x2C1,0x2C2}},{{1,31,10,5,true,3,nil,nil,true}},rtf,{{0,0},{12,0}},5,nil,{lift=0})
add('em_roof_chair','shop',{{0x2C0}},{{11,15,11,9,true,1,nil,nil,nil,nil,nil,{12,6}},{1,12,11,4,true,4,nil,nil,nil,nil,nil,{6,7}}},rtf,{{0,0},{4,0}},4,nil,{lift=0})
-- 1F plants on the orange floor (0x26C over 0x274).
add('em_store_plant_1f','shop',{{0x26C},{0x274}},
 {{3,13,24,6,true,19,nil,'disc'},{0,16,8,10,true,3,nil,'disc',nil,nil,6}},{0x268,0x270},{{0,0}},6)
-- The produce tables by the entrance (2x2 from 0x2DF): baskets on the top
-- (rows 9..22), open legs and a low shelf below (hollow, 9 tall). UNVERIFIED.
add('em_store_produce_table','shop',{{0x2DF,0x267},{0x261,0x262}},{{0,31,22,9,false,9}},{0x268,0x270},nil,9)

-- Contest Hall lobby (Lilycove). The green reception counter (8x2 from
-- 0x2D0): side arms back to the wall (top rows 0..20), a thin back strip,
-- the front counter (top rows 12..20, 10-row face) whose two openings stay
-- open below a 3-row apron. UNVERIFIED.
add('em_contest_counter','contest',
 {{0x2D0,0x2D1,0x29E,0x2D7,0x2D7,0x2AE,0x2D1,0x2E0},{0x2D8,0x2D9,0x2A6,0x2DF,0x2DF,0x2B6,0x2D9,0x2E8}},
 {{0,16,20,10,true,0},{112,128,20,10,true,0},{16,112,3,1,true,0},{32,96,20,10,true,12},
  {16,32,20,10,false,12},{96,112,20,10,false,12}},{0x260,0x221},nil,10)
-- The sofas against the side walls (1x2), seen from above: the backrest
-- along the wall (9 tall) and the seat (5 tall). Mirrored on the right.
add('em_contest_sofa_left','contest',{{0x238},{0x240}},{{0,7,28,9,true,0},{6,15,28,5,true,6}},{0x260},nil,5)
add('em_contest_sofa_right','contest',{{0x239},{0x241}},{{9,16,28,9,true,0},{1,10,28,5,true,6}},{0x260},nil,5)
-- The small display tables (0x2DD): top rows 0..11, a 3-row face.
add('em_contest_table','contest',{{0x2DD}},{{0,16,11,3,true,0}},{0x260},{{15,14}},3)

-- Oceanic Museum (Slateport). UNVERIFIED.
-- Glass cube exhibits (0x221 over 0x229): glass top rows 5..22, 9-row face.
add('em_omuseum_cube','oceanic_museum',{{0x221},{0x229}},{{0,16,22,9,true,5}},{0x201,0x202},nil,9)
-- Glass tube exhibits (0x220 over 0x228): a round tube, top rows 0..9, 21 tall.
add('em_omuseum_tube','oceanic_museum',{{0x220},{0x228}},{{0,16,9,21,true,0,nil,'disc'}},{0x201,0x202},nil,21)
-- Display cases against the wall (2x3 from 0x226): glass top rows 0..7,
-- the exhibit behind the glass and the plinth down to row 38. No lift: it
-- already reaches the wall top.
add('em_omuseum_wall_case','oceanic_museum',{{0x226,0x227},{0x22E,0x22F},{0x236,0x237}},
 {{1,23,7,31,true,0}},{0x201,0x202},nil,31,nil,{lift=0})
-- The U-shaped exhibit counters (4x4 from 0x222): the back piece with its
-- exhibits on top (rows 14..24, 7-row face) and the two arms (top rows
-- 14..52, 10-row rounded fronts).
for _,mid in ipairs({{0x248,0x249},{0x249,0x233}})do
 add('em_omuseum_counter_'..string.format('%X',mid[2]),'oceanic_museum',
  {{0x222,0x223,0x223,0x224},{0x255,mid[1],mid[2],0x256},{0x23E,0x244,0x203,0x23E},{0x260,0x243,0x201,0x260}},
  {{16,48,24,7,true,14,nil,nil,nil,nil,nil,{6,20}},{0,16,52,10,true,14,nil,nil,nil,nil,nil,{6,20}},{48,64,52,10,true,14,nil,nil,nil,nil,nil,{6,20}}},{0x201,0x202},nil,10)
end

-- 2F exhibits. The long cream display tables (4x2): top rows 0..24, a 7-row
-- face, the models standing on them -- the two Wailmer-like blobs (0x238 row)
-- and the ship (0x22A row).
local om={0x201,0x202,0x203,0x243,0x24B}
add('em_omuseum_table_blobs','oceanic_museum',{{0x238,0x239,0x240,0x22C},{0x232,0x233,0x233,0x234}},
 {{0,64,24,7,true,0,nil,nil,true},{9,30,7,6,true,0,nil,nil,true,nil,7},{35,46,6,5,true,2,nil,nil,true,nil,7}},om,nil,7,nil,{lift=0})
add('em_omuseum_table_ship','oceanic_museum',{{0x22A,0x230,0x231,0x22C},{0x232,0x233,0x233,0x234}},
 {{0,64,24,7,true,0,nil,nil,true},{17,46,8,6,true,0,nil,nil,true,nil,7}},om,nil,7,nil,{lift=0})
-- The white pillar (0x225 on the wall, 0x22D/0x235 on the floor): a square
-- column (14x14) backed onto the wall, level with the wall top (28): its face
-- is the white shaft over the band and the blue base (art rows 19..46 of
-- the four cells -- the base below is the same blue), the same down its sides.
add('em_omuseum_pillar','oceanic_museum',{{0x22D},{0x235}},
 {{1,15,-14,28,true,-15,0,nil,true,nil,nil,nil,true}},om,nil,28,nil,{lift=0,maxH=28})
-- the consoles (2x2 from 0x253): a low desk (top rows 12..24, 7-row face)
-- with its monitor standing on it
add('em_omuseum_console','oceanic_museum',{{0x253,0x254},{0x25B,0x25C}},
 {{0,24,24,7,true,12,nil,nil,true},{3,15,10,9,true,8,10,nil,true,nil,7}},om,nil,7,nil,{lift=0})
-- the submarine model on its case (2x2 from 0x251)
add('em_omuseum_sub','oceanic_museum',{{0x251,0x252},{0x259,0x25A}},
 {{0,32,21,9,true,11,nil,nil,true},{4,30,14,7,true,9,nil,nil,true,nil,9}},om,nil,9,nil,{lift=0})

-- Devon Corporation 1F (facility tileset). UNVERIFIED.
-- Reception desk (5x2 from 0x386 row): white top rows 14..25, open below on
-- its legs (hollow, 6 tall).
add('em_devon_desk','facility',{{0x386,0x38D,0x38D,0x38D,0x387},{0x38E,0x39C,0x39C,0x39C,0x38F}},
 {{0,80,25,6,false,14}},{0x380,0x381},nil,6)
-- The round planters by the back wall (0x3F6 over 0x3FE): top rows 8..20,
-- a 10-row round face.
-- Devon 3F, the president's office: the navy sofa against the north wall
-- (3x2 from 0x349: backrest top rows 8..11 standing 10, seat and arms top
-- rows 17..24 with a 5-row front), the two navy armchairs facing the long
-- table (three cells each: a tall back, the seat between its arms) and the
-- glass display cases by the west wall (0x2DD over 0x2E5: glass top rows
-- 19..28, a 15-row cabinet face).
local dvo={0x380,0x381}
add('em_devon_sofa','facility',{{0x349,0x34A,0x34B},{0x351,0x352,0x353}},
 {{2,46,11,10,true,8,nil,nil,nil,nil,nil,{10,10}},{0,48,24,5,true,17,nil,nil,nil,nil,nil,{10,22}}},dvo,nil,5,nil,{lift=0})
add('em_devon_armchair_w','facility',{{0x348},{0x350},{0x3A8}},
 {{0,5,28,9,true,8,nil,nil,nil,nil,nil,{1,12}},{4,16,31,6,true,11,nil,nil,nil,nil,nil,{8,13}}},dvo,{{2,1}},6,nil,{lift=0})
add('em_devon_armchair_e','facility',{{0x2FF},{0x307},{0x3A9}},
 {{11,16,28,9,true,8,nil,nil,nil,nil,nil,{13,12}},{0,12,31,6,true,11,nil,nil,nil,nil,nil,{4,13}}},dvo,{{2,1}},6,nil,{lift=0})
-- the same armchair in the Aqua boss's office (0x3F5 over 0x3FD over 0x3FA)
add('em_aqua_armchair_e','facility',{{0x3F5},{0x3FD},{0x3FA}},
 {{11,16,28,9,true,8,nil,nil,nil,nil,nil,{13,12}},{0,12,31,6,true,11,nil,nil,nil,nil,nil,{4,13}}},{0x3E6,0x3E5,0x3ED},nil,6,nil,{lift=0})
-- the pink round stool there (0x336)
for _,mid in ipairs({0x336,0x285})do   -- 0x285: the red one (unused Ruby map)
 add('em_aqua_stool_'..string.format('%X',mid),'facility',{{mid}},{{2,14,9,5,true,1,nil,'disc',true}},{0x228,0x229,0x202},nil,5,nil,{lift=0})
end
add('em_devon_showcase','facility',{{0x2DD},{0x2E5}},{{0,16,28,15,true,19}},dvo,{{2,17}},15,nil,{lift=0})
add('em_devon_planter','facility',{{0x3F6},{0x3FE}},{{0,16,20,10,true,8,nil,'disc'}},{0x380,0x381},nil,10)

-- Battle Frontier (battle_frontier tileset: Tower lobby, lounges, Scott's
-- house, reception gate). UNVERIFIED.
-- Potted plants (0x26E or 0x25F over 0x276 or 0x267): round pot (top rows
-- 19..24, face 6), leaves on its rim (base 6); floor border colours out.
for _,m in ipairs({{0x26E,0x276},{0x25F,0x267}})do
 add('em_frontier_plant_'..string.format('%X',m[1]),'battle_frontier',{{m[1]},{m[2]}},
  {{3,13,24,6,true,19,nil,'disc'},{0,16,8,10,true,1,nil,'disc',nil,nil,6}},{0x200},{{0,0},{15,0}},6)
end
-- Battle Tower lobby booths (1x4 from 0x210 at each partition): the yellow
-- partition running back to the wall (top rows -9..35, 20 tall), the terminal
-- standing on the counter at its front end (top rows 36..42, 12 tall, base 8)
-- and the counter under it (top rows 44..54, 8 tall). The counter cells
-- between booths (0x212, 0x214): top rows -4..6, 8 tall. No lift, so the
-- terminal stays seated on the counter.
add('em_frontier_booth','battle_frontier',{{0x210},{0x210},{0x218},{0x220}},
 {{1,15,35,20,true,-9},{1,15,42,12,true,36,nil,nil,nil,nil,8},{0,16,54,8,true,44}},{0x200,0x203,0x204},nil,8,nil,{lift=0})
for _,mid in ipairs({0x212,0x214})do
 add('em_frontier_counter_'..string.format('%X',mid),'battle_frontier',{{mid}},{{0,16,6,8,true,-4}},{0x200},nil,8,nil,{lift=0})
end

-- Frontier lounges (Lounge1-9, same tileset): the row of potted plants along
-- the back wall (0x3C6/0x3C7 over 0x3D7/0x3CE/0x3CF): round pot (top rows
-- 17..23, face 7), leaves on its rim (base 7). UNVERIFIED.
for _,t in ipairs({0x3C6,0x3C7})do for _,b in ipairs({0x3D7,0x3CE,0x3CF})do
 add('em_lounge_plant_'..string.format('%X_%X',t,b),'battle_frontier',{{t},{b}},
  {{2,14,23,7,true,17,nil,'disc'},{0,16,6,10,true,2,nil,'disc',nil,nil,7}},{0x3C8,0x3C9},{{1,0},{0,2},{15,24},{0,0},{1,4},{8,4},{0,7},{0,10},{0,12}},7)
end end
-- Route 109 / Slateport beach (general__slateport, outdoors): the beach
-- umbrellas (2x3: the canopy, top rows 3..28 with a 3-row rim, up on its
-- pole 24 px; its orange shade on the sand stays ground), the deck chairs
-- (0x2E1 over 0x2E9 over 0x2F1: the reclined back, top rows 9..12 and a
-- 13-row slatted face, on the seat, top rows 26..33 on 3-px legs) and the
-- striped bins (0x2E0 over 0x2E8 over 0x2F0: lid rows 9..13, a 23-row body)
local bch={0x124}
for _,u in ipairs({{0x2E4,0x2E5,0x2EC,0x2ED,0x2F4,0x2F5},{0x2E2,0x2E3,0x2EA,0x2EB,0x2F2,0x2F3},{0x2E6,0x2E7,0x2EE,0x2EF,0x2F6,0x2F7}})do
 add('em_beach_umbrella_'..string.format('%X',u[1]),'slateport',{{u[1],u[2]},{u[3],u[4]},{u[5],u[6]}},
  {{0,32,28,3,true,3,nil,'disc',nil,nil,24},{15,17,31,24,true,32,nil,nil,nil,nil,nil,{15,36}}},bch,{{0,34},{0,40},{3,29}},3,nil,{primary='general',lift=0})
end
add('em_beach_chair','slateport',{{0x2E1},{0x2E9},{0x2F1}},
 {{1,14,33,3,false,26,nil,nil,true,nil,nil,{4,30}},{1,14,12,13,true,9,nil,nil,true,nil,3,{4,14}}},bch,nil,3,nil,{primary='general',lift=0})
-- (it is a striped air mattress lying on the sand, seen from above -- pillow at the head, rows 9..14 --
-- not a bin: it lies flat, 3 px thick, the pillow a little higher)
add('em_beach_bin','slateport',{{0x2E0},{0x2E8},{0x2F0}},{{1,16,14,5,false,9},{1,16,44,3,false,15}},bch,nil,5,nil,{primary='general',lift=0})

-- Slateport market stalls (general__slateport, outdoors): the clay pots and
-- bowls of goods (one cell, round: top rows 0..9, a 5-row belly; their drop
-- shadow on the paving sampled out), the fruit baskets, the potted flowers
-- and the wooden crates (lid over a stacked pair of fronts, or one crate)
local mkf={0x211,0x210,0x212,0x209}
for _,m in ipairs({{0x20C,{{15,10}}},{0x28E,{{15,10}}},{0x21B,{{15,6}}},{0x21C,{{15,6}}},{0x22B,{{15,5}}},{0x223,{{15,5}}},{0x20B,{{15,6}}}})do
 add('em_market_pot_'..string.format('%X',m[1]),'slateport',{{m[1]}},{{0,16,9,5,true,0,nil,'disc',true}},mkf,m[2],5,nil,{primary='general',lift=0})
end
-- the fruit and flower baskets (0x344, 0x213): low round baskets, the goods
-- heaped on top in their own colours
for _,m in ipairs({0x344,0x213})do
 add('em_market_basket_'..string.format('%X',m),'slateport',{{m}},{{1,15,9,4,true,0,nil,'disc',true}},mkf,nil,4,nil,{primary='general',lift=0})
end
for _,c in ipairs({{0x32E,0x336},{0x32F,0x337}})do
 add('em_market_crates_'..string.format('%X',c[1]),'slateport',{{c[1]},{c[2]}},{{0,15,15,16,true,0,nil,nil,true}},mkf,{{15,5}},16,nil,{primary='general',lift=0})
end
for _,m in ipairs({0x33E,0x33F})do
 add('em_market_crate_'..string.format('%X',m),'slateport',{{m}},{{0,15,8,7,true,0,nil,nil,true}},mkf,{{15,5}},7,nil,{primary='general',lift=0})
end

-- Battle Frontier plaza flags (0x39E 0x39F, drawn on the paving north of
-- the white fence): the pole and its gold banner stand as one thin cutout
-- (card, 2 px thick) at the cell's north edge; the pole's foot stays painted
-- on the fence below
for _,sec in ipairs({'battle_frontier_outside_west','battle_frontier_outside_east'})do
 add('em_bf_flag_'..sec:sub(-4),sec,{{0x39E,0x39F}},{{3,22,-1,16,true,0,14,'card'}},{0x05E},nil,16,nil,{primary='general',lift=0})
 -- the flags on the white rails (0x3F6 with 0x3F7 or 0x39F): the banner
 -- flies east from the rail post, a thin cutout like the plaza flags
 for _,b in ipairs({0x3F7,0x39F})do
  add('em_bf_railflag_'..sec:sub(-4)..'_'..string.format('%X',b),sec,{{0x3F6,b}},{{4,22,-1,15,true,0,13,'card'}},{0x05E,0x109},nil,15,nil,{primary='general',lift=0})
 end
end

-- Inside of the moving truck (the whole 5x5 load): the packed boxes and the
-- cabinet, each a lid over its front as drawn -- the box and the cabinet at
-- the back, the pile down the west side and the boxes along the tailgate.
-- Their greys are the floor's, so every part keeps its pixels.
do
 local K=function(x0,x1,front,h,first)return {x0,x1,front,h,true,first,nil,nil,true}end
 add('em_truck_load','inside_of_truck',
  {{0x201,0x202,0x203,0x204},{0x209,0x20A,0x20B,0x20C},{0x211,0x212,0x213,0x214},{0x219,0x21A,0x21B,0x21C},{0x221,0x222,0x223,0x224}},
  {K(0,16,13,9,3),K(16,32,18,4,8),K(32,64,10,12,0),K(0,16,61,9,24),K(16,32,50,5,40),K(32,48,61,9,40),
   K(16,32,66,4,56),K(48,64,66,4,56)},{0x20A},nil,12,nil,{primary='general',lift=0})
end

-- Magma Hideout (general__lavaridge): Team Magma's machines on the cave
-- floor. The white containers and the dish generators are 2x3 boxes seen
-- from above-front: the lid or dish is the top (rows 0..22), the yellow
-- doors or the console the face down to the feet. The big generator is the
-- same build seven cells wide. Each is drawn in several tile variants (by
-- the wall, by the lava), so every combination is listed.
local mgh={0x308,0x310,0x311,0x313,0x3A2,0x271,0x309,0x312}
local MG={primary='general',lift=0}
for _,t in ipairs({{0x36D,0x36E},{0x384,0x385}})do for _,m in ipairs({{0x375,0x376},{0x38C,0x38D}})do for _,b in ipairs({{0x37D,0x37E},{0x3A8,0x3A9}})do
 add(string.format('em_magma_container_%X_%X_%X',t[1],m[1],b[1]),'lavaridge',{t,m,b},{{0,32,22,25,true,0,nil,nil,true,nil,nil,{2,29}}},mgh,nil,25,nil,MG)
end end end
for _,t in ipairs({{0x380,0x381},{0x382,0x383},{0x386,0x387}})do for _,m in ipairs({{0x388,0x389},{0x38A,0x38B},{0x38E,0x38F}})do for _,b in ipairs({{0x390,0x391},{0x396,0x397}})do
 add(string.format('em_magma_dish_%X_%X_%X',t[1],m[1],b[1]),'lavaridge',{t,m,b},{{0,32,22,24,true,0,nil,nil,true,nil,nil,{1,20}}},mgh,nil,24,nil,MG)
end end end
add('em_magma_generator','lavaridge',{{0x368,0x369,0x36A,0x36B,0x36B,0x36B,0x36E},{0x370,0x371,0x372,0x373,0x373,0x373,0x376},{0x378,0x379,0x37A,0x37B,0x37B,0x37B,0x37E}},
 {{0,112,22,25,true,0,nil,nil,true,nil,nil,{6,8}}},mgh,nil,25,nil,MG)
-- the drilling machines (2x2, drawn head-on: the bit or the dome between
-- two crawler tracks): the drawing stands as a cutout 20 px thick, so the
-- gaps round the bit stay open
for _,t in ipairs({{0x358,0x359},{0x392,0x393}})do for _,b in ipairs({{0x360,0x361},{0x39A,0x39B}})do
 add(string.format('em_magma_drill_%X_%X',t[1],b[1]),'lavaridge',{t,b},{{0,32,-1,32,true,0,12,'card'}},mgh,nil,32,nil,MG)
end end
for _,t in ipairs({{0x35A,0x35B},{0x394,0x395},{0x365,0x366}})do for _,b in ipairs({{0x362,0x363},{0x39C,0x39D}})do
 add(string.format('em_magma_domedrill_%X_%X',t[1],b[1]),'lavaridge',{t,b},{{0,32,-1,32,true,0,12,'card'}},mgh,nil,32,nil,MG)
end end

-- Lilycove's east cape: the little white beacon with the yellow lamp (0x240
-- on the shallows over its base 0x2A2 on the cape's edge). A round base
-- (top rows 18..22, a 6-row face), the white bulb on it and the lamp on top
-- as balls; water, shore edge and its shadow on the grass sampled out.
add('em_lilycove_beacon','lilycove',{{0x240},{0x2A2}},
 {{1,15,22,6,true,18,nil,'disc'},{0,16,17,0,true,6,nil,'ball',nil,nil,6},{4,12,5,0,true,0,nil,'ball',nil,nil,18}},
 {0x19E,0x002,0x001},{{0,0},{1,0},{2,2},{0,16},{1,17},{3,17},{0,23},{15,12}},6,nil,{primary='general',lift=0})

-- Reception Gate: the yellow C-shaped desks (2x4 from 0x350, opening
-- west; 0x352 mirrored, opening east): the top and bottom arms (top rows
-- 12..21 and 44..53) and the back arm joining them, 9-row grey faces; the
-- round gold-capped pedestals (0x364 over 0x36C: cap rows 8..13, a 17-row
-- column); the red armchairs (0x2C5 backrest west, 0x2BD east)
local gtf={0x05E}
add('em_gate_desk_w','battle_frontier',{{0x350,0x351},{0x358,0x359},{0x368,0x369},{0x370,0x371}},
 {{0,16,21,9,true,12,nil,nil,true},{16,32,53,9,true,12,nil,nil,true},{0,16,53,9,true,44,nil,nil,true}},gtf,nil,9,nil,{primary='general',lift=0})
add('em_gate_desk_e','battle_frontier',{{0x352,0x353},{0x35A,0x35B},{0x36A,0x36B},{0x372,0x373}},
 {{16,32,21,9,true,12,nil,nil,true},{0,16,53,9,true,12,nil,nil,true},{16,32,53,9,true,44,nil,nil,true}},gtf,nil,9,nil,{primary='general',lift=0})
add('em_gate_pedestal','battle_frontier',{{0x364},{0x36C}},{{2,14,13,17,true,8,nil,'disc',true}},gtf,nil,17,nil,{primary='general',lift=0})
add('em_gate_chair_w','battle_frontier',{{0x2C5}},{{1,5,3,9,true,0,nil,nil,true,nil,nil,{2,6}},{5,14,11,4,true,4,nil,nil,true,nil,nil,{8,7}}},gtf,nil,4,nil,{primary='general',lift=0})
add('em_gate_chair_e','battle_frontier',{{0x2BD}},{{11,15,3,9,true,0,nil,nil,true,nil,nil,{12,6}},{2,11,11,4,true,4,nil,nil,true,nil,nil,{7,7}}},gtf,nil,4,nil,{primary='general',lift=0})
-- Reception Gate palms (crown drawn in the walkable cell 0x354 above the
-- pot 0x35C): round pot (top rows 19..24, face 6), the crown a round bush on
-- it, as the Center 2F plants
add('em_gate_palm_plant','battle_frontier',{{0x354},{0x35C}},
 {{3,13,24,6,true,19,nil,'disc'},{0,16,7,11,true,3,nil,'disc',nil,nil,6}},{0x05E,0x364,0x36C,0x3A8},nil,6,nil,{primary='general'})
-- Armchairs (one cell each): backrest 9 tall on one side, seat 4 tall; their
-- hidden sides the grey upholstery (not the navy outline), no extra height.
for _,mid in ipairs({0x3EF,0x3F7})do       -- backrest on the left
 add('em_lounge_chair_'..string.format('%X',mid),'battle_frontier',{{mid}},
  {{1,5,11,9,true,1,nil,nil,nil,nil,nil,{3,6}},{4,15,11,4,true,4,nil,nil,nil,nil,nil,{8,8}}},{0x3C8,0x3C9},nil,4,nil,{lift=0})
end
for _,mid in ipairs({0x3DF,0x3E7,0x3DA})do -- backrest on the right
 add('em_lounge_chair_'..string.format('%X',mid),'battle_frontier',{{mid}},
  {{11,15,11,9,true,1,nil,nil,nil,nil,nil,{12,6}},{1,12,11,4,true,4,nil,nil,nil,nil,nil,{7,8}}},{0x3C8,0x3C9},nil,4,nil,{lift=0})
end
-- The bench along the left wall (0x3DD top, 0x3E5 middle, 0x3ED front):
-- backrest against the wall (9 tall), seat 3 tall.
add('em_lounge_bench_3DD','battle_frontier',{{0x3DD}},{{1,4,15,9,true,1},{4,15,15,3,true,1}},{0x3C8,0x3C9},nil,3)
add('em_lounge_bench_3E5','battle_frontier',{{0x3E5}},{{1,4,15,9,true,0},{4,15,15,3,true,0}},{0x3C8,0x3C9},nil,3)
add('em_lounge_bench_3ED','battle_frontier',{{0x3ED}},{{1,4,11,9,true,0},{4,15,11,3,true,0}},{0x3C8,0x3C9},nil,3)

-- Pretty Petal flower shop (Route 104). UNVERIFIED.
local petal={0x201,0x203}
-- Flower planter boxes (0x22E over 0x236): flowers on top (rows 0..23), the
-- wooden box face 8 tall.
add('em_petal_planter','pretty_petal_flower_shop',{{0x22E},{0x236}},{{0,16,23,7,true,0}},petal,nil,7)
-- the long planter (three cells deep) and the short one in front of the back
-- flower tables (one cell: flowers rows 0..7, wooden face 8..14)
add('em_petal_planter_long','pretty_petal_flower_shop',{{0x22E},{0x22E},{0x236}},{{0,16,39,7,true,0}},petal,nil,7)
add('em_petal_planter_short','pretty_petal_flower_shop',{{0x236}},{{0,16,7,7,true,0}},petal,nil,7)
-- Plant stands (0x225, 0x22D, 0x235): a low green cart (top rows 6..41, open
-- legs 6 tall) with three potted plants standing on it (base 6; leaves on
-- top, pot on the face, round).
add('em_petal_plant_stand','pretty_petal_flower_shop',{{0x225},{0x22D},{0x235}},
 {{0,16,41,6,false,6},
  {2,14,6,7,true,1,nil,'disc',nil,nil,6},{2,14,18,7,true,13,nil,'disc',nil,nil,6},{2,14,30,7,true,25,nil,'disc',nil,nil,6}},
 petal,nil,6,nil,{lift=0})
-- Flower tables by the back wall (2x2 from 0x233): pots on the top (rows
-- 3..25, wall colour sampled out), open legs (5 tall).
add('em_petal_flower_table','pretty_petal_flower_shop',{{0x233,0x234},{0x23B,0x23C}},{{0,32,25,5,false,3}},petal,{{0,0}},5)
-- Round wooden stools (0x23D): seat top rows 0..6, a 3-row rim, three legs
-- to row 13 (hollow, round).
add('em_petal_stool','pretty_petal_flower_shop',{{0x23D}},{{2,14,6,7,false,0}},petal,nil,7,nil,{lift=0})
-- The shop counter (2x3 from 0x245): the stool at its end (seat rows 0..9 on
-- legs), the low arm (top rows 26..36, 3 tall) and the main counter running
-- back (top rows 0..37, 9 tall).
add('em_petal_counter','pretty_petal_flower_shop',{{0x245,0x237},{0x23E,0x23F},{0x246,0x247}},
 {{2,14,9,4,false,0},{0,16,36,3,true,26,nil,nil,nil,nil,nil,{5,30}},{16,32,37,9,true,0,nil,nil,nil,nil,nil,{20,20}}},petal,nil,9)

-- Pokemon Day Care (Route 117). UNVERIFIED.
add('em_daycare_plant','pokemon_day_care',{{0x21D},{0x225}},
 {{2,14,24,6,true,19,nil,'disc'},{0,16,8,10,true,3,nil,'disc',nil,nil,6}},{0x201},{{1,0}},6)
-- The wooden table (2x2 from 0x229): plank top rows 2..23, open legs (7).
add('em_daycare_table','pokemon_day_care',{{0x229,0x22A},{0x231,0x232}},{{0,32,23,7,false,2}},{0x201,0x204},nil,7)
-- Stools (0x228, 0x230): seat rows 1..9 on legs (5).
for _,mid in ipairs({0x228,0x230})do
 add('em_daycare_stool_'..string.format('%X',mid),'pokemon_day_care',{{mid}},{{2,14,9,5,false,1}},{0x201,0x204},nil,5)
end
-- The reception counter (5x2 from 0x218): top rows 12..24 with its sign, a
-- 6-row front; its right end runs back to the wall (top rows 0..24).
add('em_daycare_counter','pokemon_day_care',{{0x218,0x226,0x219,0x226,0x21B},{0x220,0x22E,0x221,0x22E,0x223}},
 {{0,72,24,6,true,12},{64,78,24,6,true,0}},{0x201,0x206,0x207},nil,6)

-- Lilycove Museum 1F: the stone tablet exhibit (5x3 from 0x242): a low plinth
-- drawn in the floor's colour inside its rim (keep; top rows 0..41, 5 tall)
-- with the tablet standing on it (base 5; top rows 1..17, 6 tall).
-- UNVERIFIED.
add('em_lmuseum_tablet','lilycove_museum',
 {{0x242,0x228,0x229,0x22A,0x244},{0x24A,0x230,0x231,0x232,0x24C},{0x252,0x253,0x253,0x253,0x254}},
 {{0,80,41,5,true,0,nil,nil,true},{16,64,17,6,true,1,nil,nil,nil,nil,5}},{0x202,0x203,0x23F},nil,5)

-- Seashore House (Route 109). UNVERIFIED.
local sea={0x21A,0x225,0x22A,0x224}
-- Wooden tables (one row of cells): plank top rows 0..12 on short legs.
add('em_seashore_table3','seashore_house',{{0x218,0x210,0x219}},{{0,48,12,3,false,0}},sea,nil,3)
add('em_seashore_table_l','seashore_house',{{0x220,0x219}},{{0,32,12,3,false,0}},sea,nil,3)
add('em_seashore_table_r','seashore_house',{{0x218,0x221}},{{0,32,12,3,false,0}},sea,nil,3)
-- Drinks coolers at the back (2x2 from 0x206): top rows 0..6, the glass
-- front with bottles to row 29 (keep: the glass shows the floor's colour).
add('em_seashore_cooler','seashore_house',{{0x206,0x207},{0x20E,0x20F}},{{0,32,6,24,true,0,nil,nil,true}},sea,nil,24)

-- Mauville Game Corner. UNVERIFIED.
local gc={0x202,0x204}
-- The slot machine banks (2x5 from 0x224): the machines' tops run back as
-- the top (rows 0..71), the end panel is the 4-row face.
add('em_gamecorner_slots','mauville_game_corner',{{0x224,0x225},{0x22C,0x22D},{0x22C,0x22D},{0x22C,0x22D},{0x234,0x235}},
 {{0,32,71,4,true,0,nil,nil,nil,74}},gc,{{0,76}},4)
-- Stools by the machines (0x226 facing east, 0x227 facing west): the seat a
-- cushion (top rows 3..10) on its pedestal (open: rows 11..15 the apron and
-- stem), the backrest a 4 px slab along the far side standing on the seat
-- (its top rows 1..2, its 8-row side the face, reaching back over the seat
-- to row 3), its hidden sides the blue of the cushion.
add('em_gamecorner_stool_226','mauville_game_corner',{{0x226}},
 {{5,13,10,5,false,3},{2,6,2,8,true,1,3,nil,nil,nil,5,{3,4}}},gc,nil,5,nil,{lift=0})
add('em_gamecorner_stool_227','mauville_game_corner',{{0x227}},
 {{3,11,10,5,false,3},{10,14,2,8,true,1,3,nil,nil,nil,5,{11,4}}},gc,nil,5,nil,{lift=0})
-- The yellow benches by the east wall (0x21E 0x21F): a long seat (rows
-- 0..12) on legs at both ends.
add('em_gamecorner_bench','mauville_game_corner',{{0x21E,0x21F}},{{1,31,12,3,false,0}},gc,nil,3)
-- Roulette tables (2x3 from 0x222): felt top rows 0..43 on a 3-row skirt.
add('em_gamecorner_roulette','mauville_game_corner',{{0x222,0x223},{0x22A,0x22B},{0x232,0x233}},{{0,32,43,3,false,0}},gc,nil,3)
-- Potted plants by the back wall (0x22F over 0x237).
add('em_gamecorner_plant','mauville_game_corner',{{0x22F},{0x237}},
 {{3,13,24,6,true,19,nil,'disc'},{0,16,8,10,true,1,nil,'disc',nil,nil,6}},gc,{{0,0},{0,9}},6)

-- Weather Institute (lab tileset). UNVERIFIED.
local labFloor={0x252,0x27A}
-- Bookshelves (2x2 from 0x22C): top rows 0..11, shelves on a 20-row face.
add('em_lab_bookshelf','lab',{{0x22C,0x22D},{0x234,0x235}},{{0,32,11,20,true,0,nil,nil,nil,26,nil,{4,2}}},labFloor,nil,20)
-- Work tables (2x3 from 0x260): two chairs behind (backrests, 13 tall) and
-- the table (top rows 20..39, open legs 7).
add('em_lab_table','lab',{{0x260,0x261},{0x253,0x254},{0x28A,0x28B}},
 {{2,14,2,13,true,1,6},{18,30,2,13,true,1,6},{0,32,39,7,false,20}},labFloor,nil,7)
-- the same table with the other pair of chairs behind (0x264/0x265, 2F)
add('em_lab_table_264','lab',{{0x264,0x265},{0x253,0x254},{0x28A,0x28B}},
 {{2,14,2,13,true,1,6},{18,30,2,13,true,1,6},{0,32,39,7,false,20}},labFloor,nil,7)
-- the orange bed in the Weather Institute's rest room (2x2 from 0x26C): the
-- white headboard standing at its head (top rows 0..3) and the mattress on
-- its frame (top rows 10..26, the legs below)
add('em_wi_bed','lab',{{0x26C,0x26D},{0x274,0x275}},
 {{5,27,4,12,true,0,nil,nil,true},{4,28,26,5,false,10,nil,nil,true}},{0x252,0x272},nil,5,nil,{lift=0})
-- Green chairs beside them (0x25E backrest left, 0x256 right).
add('em_lab_chair_25E','lab',{{0x25E}},{{1,5,12,9,true,0,nil,nil,nil,nil,nil,{2,3}},{5,14,12,3,true,5,nil,nil,nil,nil,nil,{8,7}}},labFloor,nil,3)
add('em_lab_chair_256','lab',{{0x256}},{{11,15,12,9,true,0,nil,nil,nil,nil,nil,{12,3}},{2,11,12,3,true,5,nil,nil,nil,nil,nil,{6,7}}},labFloor,nil,3)

-- Battle Dome lobby: the banks of potted plants (tops 0x384/0x386/0x38B/
-- 0x327 over 0x385/0x387/0x38C/0x32F): round pot (top rows 19..24, face 6),
-- leaves on its rim (base 6). UNVERIFIED.
for _,m in ipairs({{0x384,0x385},{0x386,0x387},{0x38B,0x38C},{0x327,0x32F},{0x384,0x387},{0x386,0x385}})do
 add('em_dome_plant_'..string.format('%X_%X',m[1],m[2]),'battle_dome',{{m[1]},{m[2]}},
  {{3,13,24,6,true,19,nil,'disc'},{0,16,7,11,true,3,nil,'disc',nil,nil,6}},{0x340,0x341},nil,6)
end

-- Battle Dome pre-battle room: the potted plants (as the lobby's, on the
-- blue floor; wall colours behind the north pair sampled out), the yellow
-- table (2x3 from 0x35E: top rows 0..42 on legs), the two red armchairs
-- east of it (one column of three cells, backrests east), the armchair by
-- the west machine (0x364) and that machine against the west wall (four
-- cells from 0x353: top rows 10..36, a 19-row face).
local dpf={0x346,0x345,0x34C,0x34D,0x337,0x33F}
for _,m in ipairs({{0x2E8,0x2F0,{{0,0}}},{0x2F8,0x300,{{0,16}}},{0x308,0x31F,{{0,0},{7,0},{0,8},{0,9},{0,16}}},{0x308,0x317,{{0,0},{7,0},{0,8},{0,9},{0,16}}}})do
 add('em_dome_plant_'..string.format('%X_%X',m[1],m[2]),'battle_dome',{{m[1]},{m[2]}},
  {{3,13,24,6,true,19,nil,'disc'},{0,16,7,11,true,3,nil,'disc',nil,nil,6}},dpf,m[3],6)
end
add('em_dome_pre_table','battle_dome',{{0x35E,0x35F},{0x366,0x367},{0x36E,0x36F}},{{8,32,42,5,false,0,nil,nil,true}},dpf,nil,5,nil,{lift=0})
add('em_dome_pre_chairs','battle_dome',{{0x35D},{0x365},{0x36D}},
 {{11,15,10,10,true,0,nil,nil,true,nil,nil,{12,8}},{1,12,16,4,true,5,nil,nil,true,nil,nil,{6,10}},
  {11,15,34,10,true,24,nil,nil,true,nil,nil,{12,32}},{1,12,40,4,true,29,nil,nil,true,nil,nil,{6,34}}},dpf,nil,4,nil,{lift=0})
add('em_dome_pre_chair_w','battle_dome',{{0x364}},
 {{11,15,6,7,true,0,nil,nil,true,nil,nil,{12,4}},{1,12,9,3,true,5,nil,nil,true,nil,nil,{6,7}}},dpf,nil,3,nil,{lift=0})
add('em_dome_pre_machine','battle_dome',{{0x353},{0x35B},{0x363},{0x36B}},{{0,13,36,19,true,10,nil,nil,true}},dpf,nil,19,nil,{lift=0})

-- Battle Factory lobby. UNVERIFIED.
-- Potted plants: the pot's lit side is drawn in the floor's colour, so the
-- pot keeps every pixel (narrowed to its own columns); background colours
-- round the leaves are sampled out.
for _,m in ipairs({{0x23C,0x23A},{0x34F,0x23B},{0x23C,0x23B},{0x33D,0x35F},{0x230,0x231}})do
 add('em_factory_plant_'..string.format('%X_%X',m[1],m[2]),'battle_factory',{{m[1]},{m[2]}},
  {{4,12,24,6,true,19,nil,'disc',true},{0,16,7,11,true,3,nil,'disc',nil,nil,6}},{0x201,0x202},{{0,1},{0,18}},6)
end
-- Round bins (0x205 over 0x20D): rim rows 6..14, body to row 31 (keep: the
-- body is drawn in the floor's colour).
add('em_factory_bin','battle_factory',{{0x205},{0x20D}},{{0,16,14,17,true,6,nil,'disc',true}},{0x201,0x202},nil,17)

-- Battle Pike lobby. UNVERIFIED.
-- Red armchairs facing north (the camera sees their backs): the seat with
-- its arms seen from above (top cell rows 2..14, 6 high), the tall backrest
-- standing at its south edge (16 high, its back the lower cell's art).
for _,m in ipairs({{0x204,0x20C},{0x206,0x20C},{0x214,0x21C},{0x205,0x20D}})do
 add('em_pike_chair_'..string.format('%X_%X',m[1],m[2]),'battle_pike',{{m[1]},{m[2]}},
  {{1,15,14,6,true,2,nil,nil,true,nil,nil,{2,6}},{3,13,15,16,true,15,12,nil,nil,nil,nil,{5,18}}},{0x2C2,0x2D4},nil,6,nil,{lift=0})
end
-- The round pink table at the back (3x2 from 0x2B2): a round top (rows
-- 7..29) on a 3-row edge; the curtain behind it stays curtain.
add('em_pike_table','battle_pike',{{0x2B2,0x2B3,0x2B4},{0x2BA,0x2BB,0x2BC}},{{8,40,29,3,true,7,nil,'disc'}},{0x2C2,0x2D4},nil,3)

-- Brendan's / May's house 1F (brendans_mays_house). The kitchen row against
-- the back wall (5x2 from 0x230): the fridge (top rows 2..8, face 9..30),
-- the sink counter (top rows 9..23 with the basin and hob drawn on it, face
-- 24..30: its door panels and basin are drawn in the wall's and floor's own
-- colours, so keep) and the dish cabinet (top rows 3..8, glass doors 9..30).
-- Extra height repeats a plain row of each, capped under the 40-px wall.
add('em_bm_kitchen','brendans_mays_house',{{0x230,0x231,0x232,0x233,0x234},{0x238,0x239,0x23A,0x23B,0x23C}},
 {{0,16,8,22,true,2,nil,nil,true,27},{16,48,23,7,true,9,nil,nil,true,28},{49,72,8,22,true,3,nil,nil,true,23}},
 {0x205,0x201},nil,7,nil,{maxH=38})
-- The dining chairs (override em_house_chair_*: same rows, and the backrest's
-- hidden sides take its green upholstery, part field 12, not the dark legs).
for _,mid in ipairs({0x219,0x221})do
 add('em_bm_chair_w_'..mid,'brendans_mays_house',{{mid}},
  {{1,5,6,9,true,nil,nil,nil,nil,nil,nil,{2,3}},{5,15,10,5}},{0x220},{{7,15}},5)
end
for _,mid in ipairs({0x21C,0x224})do
 add('em_bm_chair_e_'..mid,'brendans_mays_house',{{mid}},
  {{11,15,6,9,true,nil,nil,nil,nil,nil,nil,{12,3}},{1,11,10,5}},{0x220},{{8,15}},5)
end
-- The movers' white box (2x2 from 0x240): lid rows 1..13, side 14..23.
add('em_bm_moving_box','brendans_mays_house',{{0x240,0x241},{0x248,0x249}},{{0,31,13,10,true,1}},{0x201},nil,10)
-- The TV (0x002 over 0x24A): its top is rows 13..15 of the cell above
-- (0x242, rows -3..3 here), the screen and the blue stand form the face to
-- row 23. 0x242 itself only carries that top: empty recipe, not a block.
add('em_bm_tv','brendans_mays_house',{{0x002},{0x24A}},{{0,16,3,20,true,-3,11}},{0x201},nil,20,nil,{lift=0})
add('em_bm_tv_top','brendans_mays_house',{{0x242}},{},{0x201},nil,0)

-- May's 1F: the same kitchen pieces in a different order (dish cabinet,
-- sink counter, fridge at the right end), so one recipe per piece; the TV
-- and the moving box stand on the rug's border tiles.
add('em_may_dish_cabinet','brendans_mays_house',{{0x243,0x244},{0x24B,0x24C}},{{9,32,8,22,true,3,nil,nil,true,23}},{0x205,0x201},nil,22,nil,{maxH=38})
add('em_may_sink','brendans_mays_house',{{0x231,0x232},{0x239,0x23A}},{{0,32,23,7,true,9,nil,nil,true,28}},{0x205,0x201},nil,7,nil,{maxH=38})
add('em_may_fridge','brendans_mays_house',{{0x230},{0x238}},{{0,16,8,22,true,2,nil,nil,true,27}},{0x205,0x201},nil,22,nil,{maxH=38})
add('em_may_tv','brendans_mays_house',{{0x003},{0x2B3}},{{0,16,3,20,true,-3,11}},{0x201},nil,20,nil,{lift=0})
add('em_may_tv_top','brendans_mays_house',{{0x246}},{},{0x201},nil,0)
add('em_may_moving_box','brendans_mays_house',{{0x240,0x241},{0x2B1,0x2B2}},{{0,31,13,10,true,1}},{0x201},nil,10)

-- May's dining table (2x2 from 0x2B9: top rows 1..25, 5-row apron, gold legs
-- to row 31, hollow) and its four chairs, mirrored from Brendan's (backrest
-- on the outer side, seat 5 tall, backrest sides in the green upholstery).
add('em_may_table','brendans_mays_house',{{0x2B9,0x2BA},{0x2C1,0x2C2}},{{2,30,26,5,false,1}},{0x2A3,0x2AC,0x2A4},nil,5)
add('em_may_chair_w','brendans_mays_house',{{0x2C0}},{{1,5,6,9,true,nil,nil,nil,nil,nil,nil,{2,3}},{5,15,10,5}},{0x2A3,0x2AC,0x2A4},{{0,8}},5)
add('em_may_chair_e','brendans_mays_house',{{0x2C3}},{{11,15,6,9,true,nil,nil,nil,nil,nil,nil,{12,3}},{1,11,10,5}},{0x2A3,0x2AC,0x2A4},{{15,8}},5)

-- Brendan's / May's bedroom (2F): the TV (0x002 over 0x25D; top rows 0..3,
-- screen and stand to row 23) and the GameCube on the floor (0x265 over
-- 0x266: top rows 8..13, face to row 22).
-- The bed (override em_player_bed: same rows; the mattress's sides take its
-- white sheet colour, part field 12, instead of the dark frame).
add('em_bm_bed','brendans_mays_house',{{0x27B,0x27C,0x27D},{0x283,0x284,0x285},{0x28B,0x28C,0x28D}},
 {{13,36,17,12,true,14},{12,36,38,6,false,23,nil,nil,nil,nil,nil,{20,30}}},{0x201},nil,6)
-- May's bed: the same drawing on her own tiles (0x280..0x292).
add('em_may_bed','brendans_mays_house',{{0x280,0x281,0x282},{0x288,0x289,0x28A},{0x290,0x291,0x292}},
 {{13,36,17,12,true,14},{12,36,38,6,false,23,nil,nil,nil,nil,nil,{20,30}}},{0x201},nil,6)
-- Brendan's desk corner (2x3 from the wall cell 0x252, so it outranks the
-- older 1x3 em_player_shelf column that starts there): the desk on its legs (top rows 5..15 with the tissue box drawn
-- on it, 6 tall), the PC unit standing on it (base 6: monitor top rows
-- -7..-1 from the wall cell above, monitor and case face 0..15), and the
-- orange chair in front (seat rows 21..26 on legs, backrest on the west).
add('em_bm_desk','brendans_mays_house',{{0x252,0x254},{0x25A,0x25B},{0x262,0x263}},
 {{1,32,31,6,false,21},{1,16,15,16,true,9,20,nil,nil,nil,6,{3,27}},{5,14,42,5,false,37},{1,5,36,11,true,33}},
 {0x201},nil,6,nil,{lift=0})
-- May's desk (2x2 from 0x258): the desk on its legs (top rows 4..15, 7 tall)
-- with the PC standing on it (base 7: top rows 0..6, face to row 14), and
-- the purple stool in front (seat rows 20..27 on legs).
add('em_may_desk','brendans_mays_house',{{0x258,0x259},{0x260,0x261}},
 {{0,17,15,7,false,4},{17,32,15,7,false,15},{17,31,6,8,true,0,4,nil,nil,nil,7,{20,3}},{17,29,27,4,false,20}},{0x201},nil,7,nil,{lift=0})
add('em_bm_tv_2f','brendans_mays_house',{{0x002},{0x25D}},{{1,15,3,20,true,0,13}},{0x201},nil,20,nil,{lift=0})
add('em_may_gamecube','brendans_mays_house',{{0x257},{0x267}},{{3,13,8,12,true,8}},{0x201},nil,12,nil,{lift=0})
add('em_bm_gamecube','brendans_mays_house',{{0x265},{0x266}},{{3,13,13,9,true,8}},{0x201},nil,9,nil,{lift=0})

-- Professor Birch's lab (lab tileset, floor 0x202). UNVERIFIED until captured.
-- Floor tiles that only carry the grid lines and shading next to furniture:
-- they were stood up as low blocks (the grey blobs), keep them flat. Rows
-- 13..15 stay out: a plant below draws its leaf tip from them.
for _,mid in ipairs({0x23F,0x24F,0x23E,0x23D,0x247,0x226,0x22A})do
 add('em_lab_floor_'..string.format('%X',mid),'lab',{{mid}},{{0,16,12,0}},{0x202},nil,0)
end
-- The two desks against the back wall (desk top rows 4..15, legs 16..22):
-- the PC desk (2x2 from 0x21A) with the computer standing on it (base 7),
-- and the long desk (4x2 from 0x20B) with two upright book stands on it; the
-- open red book lies flat on its top. No lift: the items stay seated.
add('em_lab_pc_desk','lab',{{0x21A,0x21B},{0x222,0x223}},
 {{0,24,15,7,false,12},{24,32,15,7,false,4},{1,24,1,13,true,0,1,nil,nil,nil,7}},{0x202},nil,7,nil,{lift=0})
add('em_lab_book_desk','lab',{{0x20B,0x20C,0x20D,0x20E},{0x222,0x233,0x222,0x233}},
 {{0,20,15,7,false,4},{20,32,15,7,false,12},{32,51,15,7,false,4},{51,61,15,7,false,12},{61,64,15,7,false,4},
  {20,31,4,7,true,3,nil,nil,nil,nil,7},{51,61,2,9,true,1,nil,nil,nil,nil,7}},{0x202},nil,7,nil,{lift=0})
-- The bookshelf in the back-left corner (white top rows 0..2, books down to
-- row 23; its gaps are drawn in the floor's colour, so keep) with the crate
-- below it (top rows 25..34, face 35..46).
add('em_lab_corner_shelf','lab',{{0x218,0x219},{0x220,0x221},{0x228,0x202}},
 {{0,32,2,21,true,0,nil,nil,true},{0,15,34,12,true,25}},{0x202},nil,21,nil,{maxH=30})
-- The two low bookshelves on the left (2x3 each): deep white tops rows 5..26,
-- books on the face to row 46 (keep), a crate standing on each (base 20).
-- Their back and ends take the white top's colour (part field 12).
for _,l in ipairs({{0x224,0x225},{0x236,0x237}})do
 add('em_lab_low_shelf_'..string.format('%X',l[1]),'lab',{{l[1],l[2]},{0x22C,0x22D},{0x234,0x235}},
  {{0,32,26,20,true,5,nil,nil,true,nil,nil,{2,20}},{8,23,8,7,true,2,nil,nil,nil,nil,20}},{0x202},nil,20,nil,{lift=0})
end
-- The crates on the right (2x2 from 0x229): a single crate (top rows 10..24)
-- and a stack of three (top rows 5..10, faces to row 31).
add('em_lab_crates','lab',{{0x229,0x23A},{0x231,0x242}},{{0,15,24,7,true,10},{16,31,10,21,true,5}},{0x202},nil,7,nil,{lift=0})
-- The side desks with a computer (1x3 from 0x230 and 0x23B): desk top rows
-- 16..39 on legs to row 46, the monitor standing at its back (base 7).
for _,c in ipairs({{0x230,0x238,0x240},{0x23B,0x243,0x24B}})do
 add('em_lab_side_desk_'..string.format('%X',c[1]),'lab',{{c[1]},{c[2]},{c[3]}},
  {{0,16,39,7,false,16},{1,16,4,11,true,1,4,nil,nil,nil,7}},{0x202},nil,7,nil,{lift=0})
end
-- Green lab chairs: seat on legs (hollow) with the backrest standing on it.
-- 0x241: backrest on the east; 0x249: on the west; 0x239: at the back.
add('em_lab_chair_241','lab',{{0x241}},{{1,12,10,5,false,4},{11,15,0,8,true,0,nil,nil,nil,nil,5}},{0x202},nil,5,nil,{lift=0})
add('em_lab_chair_249','lab',{{0x249}},{{4,15,10,5,false,4},{1,5,0,8,true,0,nil,nil,nil,nil,5}},{0x202},nil,5,nil,{lift=0})
add('em_lab_chair_239','lab',{{0x239}},{{2,14,12,3,false,7},{2,14,0,6,true,0,nil,nil,nil,nil,3}},{0x202},nil,3,nil,{lift=0})
-- Potted plants (0x244, 0x22E): the crown's tip is drawn in the cell above;
-- leaves rows -3..5, the pot (rim, soil, red base) rows 6..14.
for _,mid in ipairs({0x244,0x22E})do
 add('em_lab_plant_'..string.format('%X',mid),'lab',{{mid}},
  {{3,13,10,4,true,6,nil,'disc'},{0,16,1,4,true,-3,nil,'disc',nil,nil,4}},{0x202},nil,4)
end
-- Book stacks on the floor (0x29A, 0x248, 0x232): top rows 0..7, 8 tall.
for _,mid in ipairs({0x29A,0x248,0x232})do
 add('em_lab_books_'..string.format('%X',mid),'lab',{{mid}},{{1,15,7,8,true,0}},{0x202},nil,8,nil,{lift=0})
end
-- The healing machine (2x2 from 0x214): a round machine, its domed top with
-- the red ball rows 0..13 (the ellipse), body 18 tall; its inner rim is drawn
-- in the floor's colour, so keep. The red dome is its own round part standing
-- on the body (top rows 1..6, its darker front rows 7..13, base 18), so from
-- the side it rises as a dome. Beside it the server cabinet (0x216 over
-- 0x21E): top row 14, a 17-row face.
add('em_lab_machine','lab',{{0x214,0x215},{0x21C,0x21D}},
 {{0,32,13,18,true,0,nil,'disc',true},{8,25,6,7,true,1,nil,'disc',nil,nil,18}},{0x202},nil,18,nil,{lift=0})
add('em_lab_server','lab',{{0x216},{0x21E}},{{1,15,14,17,true,14,nil,nil,nil,nil,nil,{3,20}}},{0x202},nil,17,nil,{lift=0})

-- Shared house tileset, plain-floor dining set (Oldale House 2 and others):
-- the table on its own tiles (2x2 from 0x24A: top rows 1..22, a 4-row
-- apron, legs to row 30, hollow) and the chairs standing on the wood floor
-- (override em_generic_chair_*: same rows, the floor under them is wood
-- 0x223, not the rug, and the backrest sides take its orange upholstery).
add('em_gb_table_plain','generic_building',{{0x24A,0x24B},{0x252,0x253}},{{2,30,22,8,false,1}},{0x223,0x23E},{{7,28}},8,nil,{floorFrom='neighbour'})
add('em_gb_chair_w_22B','generic_building',{{0x22B}},{{2,6,7,8,true,nil,nil,nil,nil,nil,nil,{3,3}},{5,15,10,5}},{0x223,0x23E},nil,5,nil,{floorFrom='neighbour'})
add('em_gb_chair_e_22C','generic_building',{{0x22C}},{{10,15,7,8,true,nil,nil,nil,nil,nil,nil,{12,3}},{1,10,10,5}},{0x223,0x23E},nil,5,nil,{floorFrom='neighbour'})
-- its mirror on the rug's west side (0x2E1: backrest on the west)
add('em_gb_chair_w_2E1','generic_building',{{0x2E1}},{{2,6,7,8,true,nil,nil,nil,nil,nil,nil,{3,3}},{5,15,10,5}},{0x23E,0x223},nil,5,nil,{floorFrom='neighbour'})
add('em_gb_chair_e_2E2','generic_building',{{0x2E2}},{{10,15,7,8,true,nil,nil,nil,nil,nil,nil,{12,3}},{1,10,10,5}},{0x23E,0x223},nil,5,nil,{floorFrom='neighbour'})

-- The striped-cloth table (2x2 from 0x24C; outranks em_generic_wardrobe,
-- which reads these tiles as a solid cabinet): cloth top rows 1..23, a
-- 4-row skirt, open legs to row 30. Floor from the neighbouring cells.
add('em_gb_cloth_table','generic_building',{{0x24C,0x24D},{0x254,0x255}},{{1,31,23,7,false,1}},{0x223,0x23E},nil,7,nil,{floorFrom='neighbour'})
-- The shared-house bed (override em_generic_bed: same rows; the headboard's
-- hidden sides take the frame's grey, not the white highlight, and the
-- mattress sides its lilac sheet).
add('em_gb_bed','generic_building',{{0x25A,0x25B},{0x262,0x263}},
 {{4,28,4,12,true,0,nil,nil,nil,nil,nil,{7,1}},{4,28,24,6,false,11,nil,nil,nil,nil,nil,{12,13}}},{0x223,0x23E},nil,6,nil,{floorFrom='neighbour'})

-- Tatami rooms (Mr. Briney's cottage and the like). The low tea table
-- (override em_generic_tea_table: same rows, every tatami tile counts as
-- floor so no mat pattern hangs under it, no extra height).
add('em_gb_tea_table','generic_building',{{0x24E,0x24F},{0x256,0x257}},{{2,30,23,7}},{0x229,0x221,0x223},{{0,0},{0,31}},7,nil,{lift=0,floorFrom='neighbour'})
-- Clay pots (one per cell, 0x2B3 and 0x2B4): round, mouth rows 1..5, body
-- rows 6..14; the tatami lines round them are floor.
for _,mid in ipairs({0x2B3,0x2B4})do
 add('em_gb_clay_pot_'..string.format('%X',mid),'generic_building',{{mid}},{{1,15,5,9,true,1,nil,'disc'}},{0x229,0x221},{{0,0},{0,15}},9,nil,{lift=0,floorFrom='neighbour'})
end

-- Rustboro houses (generic_building, the yellow-tile set, floor 0x32B/0x32C).
local rf={0x32C,0x32B}
-- The dining table (3x2 from 0x37E): its top is drawn in the floor's own pale
-- yellow, so keep; top rows 1..25, a 2-row apron, legs to row 29 (hollow).
add('em_rust_table','generic_building',{{0x37E,0x37F,0x38E},{0x386,0x387,0x38F}},{{3,45,25,4,false,1,nil,nil,true}},rf,nil,4,nil,{lift=0})
-- Chairs: backrest on the west (0x344) or east (0x345), seat on legs.
add('em_rust_chair_w','generic_building',{{0x344}},{{2,6,7,8,true,0,nil,nil,nil,nil,nil,{3,2}},{6,14,11,4,false,5}},rf,nil,4,nil,{lift=0})
add('em_rust_chair_e','generic_building',{{0x345}},{{10,14,7,8,true,0,nil,nil,nil,nil,nil,{12,2}},{2,10,11,4,false,5}},rf,nil,4,nil,{lift=0})
-- Potted plants in the corners (0x343/0x346 over 0x34E). The bush (rows
-- 1..15) stands on a short trunk drawn in the art (rows 16..18), so a stem
-- shows from low down.
for _,m in ipairs({{0x343,0x34E},{0x346,0x34E},{0x347,0x34F},{0x343,0x34F},{0x346,0x34F}})do
 local t=m[1]
 add('em_rust_plant_'..string.format('%X_%X',m[1],m[2]),'generic_building',{{m[1]},{m[2]}},
  {{3,13,26,6,true,18,nil,'disc'},{0,16,8,8,true,1,nil,'disc',nil,nil,6}},rf,nil,6)
end
-- The white sofa (2x2 from 0x354): cushion top rows 9..23, a 2-row front,
-- short legs to row 30 (keep: its white shares the floor's pale tones).
add('em_rust_sofa','generic_building',{{0x354,0x355},{0x35C,0x35D}},{{1,31,25,5,false,9,nil,nil,true}},rf,nil,5,nil,{lift=0})
-- The small square table on the rug (0x248/0x25E over 0x250/0x251): top
-- rows 1..22, legs to row 31, on the rug or the tiles.
add('em_rust_small_table','generic_building',{{0x248,0x25E},{0x250,0x251}},{{2,30,22,9,false,1}},{0x37C,0x38C,0x32C,0x32B},nil,9,nil,{lift=0,floorFrom='neighbour'})
-- The small white bed in the flats (0x321 over 0x3B6; its left 4 px are
-- drawn in the rug cell beside it, 0x23A over 0x384): headboard rows 2..9, mattress rows 10..22 on a frame.
add('em_rust_cot','generic_building',{{0x23A,0x321,0x32F},{0x384,0x3B6,0x3FD}},{{12,36,9,8,true,2,nil,nil,true},{12,36,22,6,false,10,nil,nil,true}},{0x37C,0x38C,0x32C,0x32B,0x23A},nil,6,nil,{lift=0,floorFrom='neighbour'})
-- The green cabinet (0x349 over 0x351): top rows 1..6, doors to row 22.
add('em_rust_cabinet','generic_building',{{0x349},{0x351}},{{1,15,6,16,true,1,nil,nil,true}},rf,nil,16)

-- Devon Corporation 2F (facility, floor 0x380/0x381): the researchers' desks
-- (2x2 from 0x3A3: desktop rows 11..24, legs to row 31) with a monitor
-- standing on each (base 7), the round stools, the round bins and the white
-- worktable (2x2 from 0x3A5).
local dv={0x380,0x381}
add('em_devon_desk_pc','facility',{{0x3A3,0x3A4},{0x3AB,0x3AC}},
 {{0,32,24,7,false,11},{1,16,10,13,true,8,12,nil,nil,nil,7,{4,20}}},dv,nil,7,nil,{lift=0})
add('em_devon_stool','facility',{{0x3A7}},{{2,14,9,5,true,1,nil,'disc',true}},dv,nil,5,nil,{lift=0})
add('em_devon_bin','facility',{{0x39D}},{{2,14,8,7,true,0,nil,'disc'}},dv,nil,7,nil,{lift=0})
add('em_devon_worktable','facility',{{0x3A5,0x3A6},{0x3AD,0x3AE}},{{0,32,24,6,false,1,nil,nil,true}},dv,nil,6,nil,{lift=0})

-- Devon 3F: the president's conference tables, seen from above (5x5 and 2x5
-- from 0x3B8): white-rimmed top rows 13..61, a 4-row edge and short legs to
-- row 71 (hollow, keep). They were being stood up like walls.
add('em_devon_conf_table','facility',
 {{0x3B8,0x3B9,0x3B9,0x3B9,0x3BA},{0x3C0,0x3C1,0x3C1,0x3C1,0x3C2},{0x3BB,0x3BC,0x3BC,0x3BC,0x3BD},{0x3C3,0x3C4,0x3C4,0x3C4,0x3C5},{0x3BE,0x3C6,0x3C6,0x3C6,0x3BF}},
 {{0,80,61,10,false,13,nil,nil,true,nil,nil,{8,63}}},{0x380,0x381},nil,10,nil,{lift=0})
add('em_devon_side_table','facility',
 {{0x3B8,0x3BA},{0x3C0,0x3C2},{0x3BB,0x3BD},{0x3C3,0x3C5},{0x3BE,0x3BF}},
 {{0,32,61,10,false,13,nil,nil,true,nil,nil,{8,63}}},{0x380,0x381},nil,10,nil,{lift=0})

-- Floor cushions (zabuton) on tatami (0x244 and 0x259): cushion top rows 3..11
-- (the centre's tatami-green is keep), a 3-row padded side.
for _,mid in ipairs({0x244,0x259})do
 add('em_gb_cushion_'..string.format('%X',mid),'generic_building',{{mid}},{{1,15,11,3,true,3,nil,nil,true}},{0x229,0x221},{{0,0},{0,1}},3,nil,{lift=0})
end

-- Dewford: the tea table variant with 0x25F in its top-right cell.
add('em_gb_tea_table_b','generic_building',{{0x24E,0x25F},{0x256,0x257}},{{2,30,23,7}},{0x229,0x221,0x223},{{0,0},{0,31}},7,nil,{lift=0,floorFrom='neighbour'})
-- Dewford Hall (plank floor 0x223/0x239): the oval dining table (3x2 from
-- 0x2E8: top rows 2..22, short legs to row 25), the yellow-cloth table (2x2
-- from 0x27B: top rows 1..22, skirt 23..25, legs to row 30), the white bed
-- in the back room (2x2 from 0x283) and its bedside drawers (0x268/0x270).
local pl={0x223,0x239}
add('em_hall_oval_table','generic_building',{{0x2E8,0x2E9,0x2EA},{0x2F0,0x2F1,0x2F2}},{{3,45,22,3,false,2,nil,nil,true}},pl,nil,3,nil,{lift=0})
add('em_hall_cloth_table','generic_building',{{0x27B,0x27C},{0x252,0x253}},{{3,29,22,8,false,1}},pl,nil,8,nil,{lift=0})
add('em_hall_bed','generic_building',{{0x283,0x284},{0x28B,0x28C}},{{1,31,26,4,false,9,nil,nil,true}},pl,nil,4,nil,{lift=0})
add('em_hall_drawers','generic_building',{{0x268},{0x270}},{{1,15,8,15,true,1}},pl,nil,15,nil,{lift=0})

-- Stern's Shipyard (facility, floors 0x202 tiles / 0x228,0x229 plates).
local sy={0x202,0x229,0x228}
-- desks with a computer (2x2 from 0x241): desktop on legs, monitor on it
add('em_ship_desk_pc','facility',{{0x241,0x242},{0x249,0x24A}},
 {{0,32,26,5,false,11},{1,16,11,12,true,8,12,nil,nil,nil,5,{4,20}}},sy,nil,5,nil,{lift=0})
add('em_ship_stool','facility',{{0x21D}},{{2,14,9,5,true,1,nil,'disc',true}},sy,nil,5,nil,{lift=0})
add('em_ship_worktable','facility',{{0x20C,0x20D},{0x214,0x215}},{{0,32,24,6,false,1,nil,nil,true}},sy,nil,6,nil,{lift=0})
-- steel girders and beam crates lying on the plates, one cell each: a low
-- solid bar (5 tall) whose top is the drawing
-- Steel on the floor. Stacks of I-beams (0x21F head, 0x227 body): two beams
-- side by side seen from above, their ends stacked up the south face -- one
-- layer pair (0x22F: 8 rows), two (0x237: 16) or three (0x22F then 0x237).
-- The sides are the beams' orange.
for n=0,3 do
 for _,e in ipairs({{{0x22F},7,8},{{0x237},-1,16},{{0x22F,0x237},7,24}})do
  local rows={{0x21F}};for i=1,n do rows[#rows+1]={0x227} end
  local endAt=#rows*16
  for _,m in ipairs(e[1])do rows[#rows+1]={m} end
  add('em_ship_beams_'..n..'_'..e[3],'facility',rows,
   {{0,16,endAt+e[2],e[3],true,0,nil,nil,true,nil,nil,{3,20}}},sy,nil,e[3],nil,{lift=0})
 end
end
-- Lattice trusses lying on the floor: two solid chords down the sides and
-- the X bracing between them, open where the art shows floor or the dark
-- inside through it (that brown is not object).
for _,rows in ipairs({{0x23F,0x247,0x24F},{0x335,0x25F,0x25F,0x257},{0x335,0x25F,0x257},{0x335,0x257,0x257},{0x335,0x257}})do
 local r={};for i,m in ipairs(rows)do r[i]={m} end
 local f=#rows*16-1-8
 local nm='em_ship_truss';for _,m in ipairs(rows)do nm=nm..'_'..string.format('%X',m) end
 add(nm,'facility',r,
  {{0,4,f,8,true,0,nil,nil,true,nil,nil,{2,20}},{12,16,f,8,true,0,nil,nil,true,nil,nil,{2,20}},
   {4,12,f,8,false,0}},sy,{{5,5}},8,nil,{lift=0})
end

-- Shipyard architecture (asked by Opus to do it here). The white partition at
-- x=6, seen from above: a long top strip with its 35-row south end face (cells
-- y0..9), and its second run after the doorway (y10..14) reaching the south
-- edge. keep (white is not floor), sideArt repeats the end face along its sides.
add('em_ship_partition_a','facility',{{0x211},{0x20A},{0x20A},{0x209},{0x211},{0x20A},{0x209},{0x210},{0x220},{0x212}},
 {{1,15,116,35,true,0,nil,nil,true,nil,nil,nil,true}},sy,nil,35,nil,{lift=0})
add('em_ship_partition_b','facility',{{0x208},{0x211},{0x20A},{0x20A},{0x20A}},
 {{1,15,47,32,true,9,nil,nil,true,nil,nil,{8,15}}},sy,nil,32,nil,{lift=0})
-- the white beam closing the machine bay (x7..14, y3; its top strip rows
-- 12..20 and a 4-row face) and its tall end post at x15
add('em_ship_beam','facility',{{0x20B,0x20B,0x20B,0x20B,0x20B,0x20B,0x20B,0x20B}},
 {{0,128,20,4,true,12,nil,nil,true,nil,nil,nil,true}},sy,nil,4)
add('em_ship_beam_post','facility',{{0x226},{0x210},{0x220}},
 {{0,16,20,27,true,9,nil,nil,true,nil,nil,nil,true}},sy,nil,27,nil,{lift=0})
-- A tank lying north-south: 2-pixel strips whose heights follow a half
-- circle, each ending on the cap plane (local depth capD), so the top art runs
-- down the curved flank and the cap art fills the round front.
local function lyingTank(parts,x0,x1,first,capD,hmax,base)
 local c,R=(x0+x1)/2,(x1-x0)/2
 for x=x0,x1-1,2 do
  local m=(x+1-c)/R
  local h=math.max(3,math.floor(hmax*math.sqrt(math.max(0,1-m*m))+.5))
  parts[#parts+1]={x,math.min(x+2,x1),capD-h,h,true,first,nil,nil,true,nil,base}
 end
 return parts
end
-- the engine (4x6 from 0x2D0): a low grey platform with its front extension,
-- the big tank lying on it (rounded top, its front cap 24 rows) and the motor
-- in front (12 rows), both standing on the platform (base 5)
add('em_ship_engine','facility',
 {{0x2D0,0x2D1,0x2D2,0x2D3},{0x233,0x234,0x235,0x236},{0x23B,0x23C,0x23D,0x23E},{0x243,0x244,0x245,0x246},{0x24B,0x24C,0x24D,0x24E},{0x229,0x255,0x256,0x229}},
 lyingTank(lyingTank({{0,64,66,5,true,9,nil,nil,true},{16,48,90,5,true,72,nil,nil,true},
  {21,43,76,12,true,72,nil,nil,true,nil,5}},9,55,9,62,20,5),21,43,60,75,7,5),sy,nil,25,nil,{lift=0})
-- the control machine beside it (2x3 from 0x25B): tanks and pipes on top,
-- its control panel the 21-row face
add('em_ship_control','facility',{{0x25B,0x25C},{0x263,0x264},{0x26B,0x26C}},
 {{0,32,17,21,true,0,nil,nil,true}},sy,nil,21,nil,{lift=0})

-- 2F: the same engine, its top row hidden under the railing (the tank top
-- starts at 0x23B), and the control unit without its back row
add('em_ship_engine_2f','facility',
 {{0x23B,0x23C,0x23D,0x23E},{0x243,0x244,0x245,0x246},{0x24B,0x24C,0x24D,0x24E},{0x229,0x255,0x256,0x229}},
 lyingTank(lyingTank({{0,64,34,5,true,0,nil,nil,true},{16,48,58,5,true,40,nil,nil,true},
  {21,43,44,12,true,40,nil,nil,true,nil,5}},9,55,0,30,20,5),21,43,28,43,7,5),sy,nil,25,nil,{lift=0})
add('em_ship_control_2f','facility',{{0x263,0x264},{0x26B,0x26C}},
 {{0,32,1,21,true,0,nil,nil,true}},sy,nil,21,nil,{lift=0})
-- the railing round the display: top rail (rows 0..2) on posts (6 rows, open
-- between them) along the north and south, a low rail strip down each side
for _,mid in ipairs({0x250,0x251,0x252,0x268,0x269,0x297,0x26A})do
 add('em_ship_rail_'..string.format('%X',mid),'facility',{{mid}},{{0,16,2,6,false,0,nil,nil,true}},sy,nil,6,nil,{lift=0})
end
add('em_ship_rail_w','facility',{{0x260}},{{0,8,15,6,true,0,nil,nil,true}},sy,nil,6,nil,{lift=0})
add('em_ship_rail_e','facility',{{0x28D}},{{8,16,15,6,true,0,nil,nil,true}},sy,nil,6,nil,{lift=0})

-- Mauville Bike Shop (general primary, bike_shop secondary). Floor 0x23F
-- (0x214 its shadowed edge). Bikes stand in side view: each is a 4 px thin
-- card (Opus's 'card': the outline keeps its gaps between the spokes),
-- never lifted; the rack posts beside them are thin cards too.
local bk={0x23F,0x214}
local G={primary='general',lift=0}
-- the west wall: the metal parts shelf in the corner (its three shelves the
-- face, backed onto the wall) and the rack of six bikes facing east
do
 local parts={{3,29,-12,18,true,-12,0,nil,true}}
 for k=0,5 do
  local f=8+16*k
  parts[#parts+1]={1,22,f,15,true,f,f+12,'card'}
  parts[#parts+1]={27,29,f+12,8,true,f+12,f+17,'card'}
 end
 add('em_bike_west_rack','bike_shop',{{0x211,0x212},{0x219,0x21A},{0x221,0x222},{0x206,0x207},{0x219,0x222},{0x221,0x222},{0x20E,0x20F}},
  parts,bk,nil,18,nil,G)
end
-- the L-shaped workbench: orange top on a blue frame with short legs (open
-- underneath), the register at its back, and the low step box at its end
add('em_bike_workbench','bike_shop',{{0x213,0x214,0x215,0x216},{0x21B,0x21C,0x21D,0x21E},{0x223,0x224,0x225,0x226}},
 {{0,49,26,12,false,7},{49,63,24,3,true,14},{1,15,-2,8,true,-7,nil,nil,true,nil,12}},bk,nil,12,nil,G)
-- the white partition off the north wall, ending at the display stand
add('em_bike_partition','bike_shop',{{0x238},{0x240}},
 {{0,8,3,24,true,-16,nil,nil,true,nil,nil,{3,10}}},bk,nil,24,nil,{primary='general',lift=0,maxH=28})
-- the goods tables against the north wall: table on legs, a yellow parcel
-- and a red box standing on it
for _,mid in ipairs({0x239,0x23C})do
 add('em_bike_goods_'..string.format('%X',mid),'bike_shop',{{mid,0x23A}},
  {{0,32,-1,7,false,-12},{1,21,-6,4,true,-11,nil,nil,true,nil,7},{21,32,-9,7,true,-13,nil,nil,true,nil,7}},bk,nil,7,nil,G)
end
-- the brown display stands (low platforms), the east one with the Mach Bike
-- in front of it and two Acro Bikes on the rack below, facing west
add('em_bike_stand_w','bike_shop',{{0x248,0x249},{0x250,0x251}},
 {{0,32,18,5,true,-4,nil,nil,true}},bk,nil,5,nil,G)
add('em_bike_east_rack','bike_shop',{{0x243,0x244},{0x24B,0x24C},{0x253,0x254},{0x245,0x246},{0x24D,0x24E},{0x255,0x256}},
 {{0,32,34,5,true,12,nil,nil,true},
  {9,31,32,15,true,32,44,'card'},{9,31,48,15,true,48,60,'card'},{9,31,64,15,true,64,76,'card'},
  {3,5,44,8,true,44,49,'card'},{3,5,60,8,true,60,65,'card'},{3,5,76,8,true,76,81,'card'}},bk,nil,15,nil,G)

-- Trick House entrance: the two bonsai by the side walls (0x319 over 0x327,
-- 0x31A over 0x322). Their leaves are drawn in the tatami's own light green,
-- so the crown keeps every pixel inside its round outline (keep + disc);
-- the pot on its little stand below (top rows 17..24, face 7).
for _,m in ipairs({{0x319,0x327},{0x31A,0x322}})do
 add('em_trick_plant_'..string.format('%X',m[1]),'generic_building',{{m[1]},{m[2]}},
  {{2,14,24,7,true,17,nil,'disc'},{0,16,8,8,true,1,nil,'disc',true,nil,7}},{0x229},nil,7)
end

-- Cycling Road gates (Route 110, shop tileset): the guard's U-shaped counter
-- (6x2 from 0x2A8): two arms and the front bar (top rows -8..23, 8-row face),
-- the thin back strip along the wall, the floor inside the U left open.
add('em_gate_counter','shop',{{0x2A8,0x299,0x298,0x299,0x299,0x2A9},{0x2B0,0x2A1,0x2A0,0x2A1,0x2A1,0x2B1}},
 {{0,16,23,8,true,-8,nil,nil,true,nil,nil,{5,4}},{80,96,23,8,true,-8,nil,nil,true,nil,nil,{5,4}},
  {16,80,23,8,true,12,nil,nil,true,nil,nil,{5,4}},{16,80,-1,8,true,-8,nil,nil,true,nil,nil,{5,4}}},{0x268,0x270},nil,8)

-- Cable Car station, Route 112 (facility tileset, general family). Floor 0x2F0.
-- The two green benches on the west wall (one column 0x303..0x323): each a
-- seat (top rows 13..32, open legs) facing east, its backrest the strip along
-- the wall standing to the same footprint (top rows 8..29, 11 tall).
add('em_cable_benches','facility',{{0x303},{0x30B},{0x313},{0x31B},{0x323}},
 {{4,16,32,6,false,13},{0,4,29,11,true,8,nil,nil,true,nil,nil,{1,15}},
  {4,16,64,6,false,45},{0,4,61,11,true,40,nil,nil,true,nil,nil,{1,47}}},{0x2F0},nil,11,nil,{lift=0})
-- the ticket machine (white box, its panel the face) and the round bin
add('em_cable_machine','facility',{{0x2FA},{0x302},{0x2FB}},
 {{1,16,15,15,true,0,nil,nil,true},{2,14,40,6,true,32,nil,'disc',true}},{0x2F0},nil,15,nil,{lift=0})
-- the timetable board standing at the platform edge: a thin card
add('em_cable_sign','facility',{{0x2F4,0x2F5}},{{0,32,0,15,true,0,12,'card'}},{0x2F0},nil,15,nil,{lift=0})

-- New Mauville inside (bike_shop tileset, general family; Opus did the walls).
local nmG={0x210,0x22F,0x27D,0x27E,0x27F,0x275}
local NG={primary='general',lift=0}
-- the generator (4x4 from 0x2D0): a pale base plate (top rows 8..58, 4-row
-- face) with the big orange dome standing on it (round, top rows 1..35,
-- 18-row face)
add('em_nm_generator','bike_shop',{{0x2D0,0x2D1,0x2D2,0x2D3},{0x2D8,0x2D9,0x2DA,0x2DB},{0x2E0,0x2E1,0x2E2,0x2E3},{0x2E8,0x2E9,0x2EA,0x2EB}},
 {{0,64,58,4,true,8,nil,nil,true},{9,56,35,18,true,1,nil,'disc',true,nil,4}},nmG,nil,22,nil,NG)
-- the equipment rack against the wall (0x2A1 over 0x2A9/0x2AA): the Bike
-- Shop's metal shelf
add('em_nm_rack','bike_shop',{{0x2A9,0x2AA}},{{3,29,-12,18,true,-12,0,nil,true}},nmG,nil,18,nil,{primary='general',lift=0,maxH=24})
-- wall consoles: screen on top, keys and body the face, backed onto the wall
for _,mid in ipairs({0x2DF,0x2EF})do
 add('em_nm_console_'..string.format('%X',mid),'bike_shop',{{mid}},{{1,15,-10,15,true,-15,0,nil,true}},nmG,nil,15,nil,NG)
end
for _,mid in ipairs({0x2DE,0x2EE})do
 add('em_nm_console_'..string.format('%X',mid),'bike_shop',{{mid}},{{1,15,-12,18,true,-16,0,nil,true}},nmG,nil,18,nil,NG)
end
-- the green machine (2x2 from 0x2DC, its tank top in the wall row above):
-- the round green tank at the back, the low unit in front of it, the desk
-- on the right with the printer box on it
add('em_nm_tank_machine','bike_shop',{{0x2DC,0x2DD},{0x2E4,0x2E5}},
 {{8,24,-7,22,true,-15,nil,'disc',true},{0,16,19,11,true,16,nil,nil,true},
  {16,32,14,16,true,10,nil,nil,true},{24,32,-3,12,true,-4,nil,nil,true,nil,16}},nmG,nil,22,nil,NG)
-- the orange bench on its blue frame (open underneath)
add('em_nm_bench','bike_shop',{{0x2A3,0x2A4},{0x2AB,0x2AC}},{{0,32,18,12,false,7}},nmG,nil,12,nil,NG)
-- crates, open and closed, and the fallen one
for _,mid in ipairs({0x2C0,0x2C1,0x2C2,0x2C3,0x258})do
 add('em_nm_crate_'..string.format('%X',mid),'bike_shop',{{mid}},{{0,13,9,5,true,0,nil,nil,true}},nmG,nil,5,nil,NG)
end
-- the drawer cabinet with a box on it, the box with its lid, the desk
add('em_nm_cabinet','bike_shop',{{0x2B0,0x2B1},{0x2B8,0x2B9}},
 {{0,32,10,12,true,4,nil,nil,true},{1,15,4,6,true,0,nil,nil,true,nil,12}},nmG,nil,12,nil,NG)
add('em_nm_box','bike_shop',{{0x2B3},{0x2BB}},{{0,13,16,6,true,8,nil,nil,true}},nmG,nil,6,nil,NG)
-- (anchored on its lower cell alone: the cell above, 0x2B4, is Opus's wall;
-- the cabinet's top is drawn up into it, rows -12..-6)
add('em_nm_desk','bike_shop',{{0x2BC}},{{0,16,-6,12,true,-12,nil,nil,true}},nmG,nil,12,nil,NG)

-- Lavaridge Herb Shop (shop tileset). Floor 0x268/0x270.
local hb={0x268,0x270}
-- the glass display counter (5 cells of 0x2A6 over 0x2A2, top rows 13..15,
-- the glass front with the herb packets behind it the 14-row face) and the
-- register stand at its east end (0x2A5 over 0x2AD)
add('em_herb_counter','shop',{{0x316,0x2A6,0x2A6,0x2A6,0x2A6,0x2A5},{0x2A2,0x2A2,0x2A2,0x2A2,0x2A2,0x2AD}},
 {{0,80,15,14,true,13,nil,nil,true},{80,96,21,10,true,0,nil,nil,true}},hb,nil,14,nil,{maxH=16})
-- the goods shelf along the east wall (0x312, 0x233, 0x314): seen from
-- above, its top runs back rows 0..38, its foot the 9-row face, and the
-- shelves with their goods repeat down its open west side
add('em_herb_side_shelf','shop',{{0x312},{0x233},{0x314}},
 {{1,15,38,9,true,0,nil,nil,true,nil,nil,nil,true}},hb,nil,9,nil,{lift=0})
-- the herb planters (2x2): a box of herbs (top rows 9..22) on short legs
-- and a base board (the 9-row face)
for _,m in ipairs({{0x2DF,0x267},{0x266,0x25A}})do
 add('em_herb_planter_'..string.format('%X',m[1]),'shop',{{m[1],m[2]},{0x261,0x262}},
  {{0,31,22,9,true,9,nil,nil,true}},hb,nil,9)
end

-- Lavaridge hot-spring sand baths (outdoors, 0x298 over 0x2A0): a shallow pit
-- dug in the sand, its rounded rim (rows 7..22) a low 2 px lip, the hollow
-- inside sand-level. Not a block.
add('em_lava_sand_pit','lavaridge',{{0x298},{0x2A0}},{{1,15,20,2,true,7,nil,'disc'}},{0x2A8},nil,2,nil,{primary='general',lift=0})

-- Lavaridge Pokemon Center: the two potted plants under the north window
-- (0x2B8 / 0x2BA, their crowns in the wall row above): round pot (top rows
-- 27..34, 4-row face), the crown seated on it; wall art kept behind.
for _,c in ipairs({{0x2B0,0x2B8,0x2C0},{0x2B2,0x2BA,0x2C2}})do
 add('em_lavapc_plant_'..string.format('%X',c[2]),'pokemon_center',{{c[1]},{c[2]},{c[3]}},
  {{3,13,34,4,true,27,nil,'disc'},{0,16,22,8,true,11,nil,'disc',nil,nil,4}},{0x202},{{0,1},{0,4},{0,5},{0,7},{0,8},{12,7},{11,8},{12,9},{0,0},{2,0},{0,16},{2,16},{0,24}},4,24)
end

-- Lanette's house (Route 114, lab tileset).
-- Yellow drawer cabinets (0x220 over 0x228): lid rows 9..17, 14-row drawer
-- face; the short one (0x24A) lid rows 2..8, 7-row face.
add('em_lan_cabinet','lab',{{0x220},{0x228}},{{0,15,17,14,true,9,nil,nil,true}},{0x202},nil,14,nil,{lift=0,back=true})
add('em_lan_cabinet_low','lab',{{0x24A}},{{0,15,8,7,true,2,nil,nil,true}},{0x202},nil,7,nil,{lift=0,back=true})
-- the blue swivel chairs (0x232): seat on its stem, backrest at the back
add('em_lan_chair','lab',{{0x232}},{{2,14,15,4,false,8},{4,13,4,8,true,0,nil,nil,nil,nil,4}},{0x202},nil,4,nil,{lift=0})
-- the white appliance on legs (0x250 over 0x258)
add('em_lan_appliance','lab',{{0x250},{0x258}},{{0,16,13,17,false,1}},{0x202},nil,17,nil,{lift=0})
-- the low yellow crate across two cells (0x236 0x225)
add('em_lan_crate','lab',{{0x236,0x225}},{{0,32,24,7,true,18,nil,nil,true}},{0x202},nil,7,nil,{lift=0})

-- Fortree treehouses (all five, the Decoration Shop, generic_building): the
-- tree trunk rising through the middle of the room (2x4 from 0x3BE, its
-- rounded foot in 0x3C6/0x3C7). Drawn in the floor's own wood colours, so
-- every pixel counts (keep). A round trunk (disc) as tall as the wall
-- (40): its face is the whole drawn trunk, its footprint the foot.
add('em_fortree_trunk','generic_building',{{0x3BE,0x3BF},{0x3BE,0x3BF},{0x3BE,0x3BF},{0x3C6,0x3C7}},
 {{2,30,23,40,true,0,nil,'disc',true}},{0x3D9},nil,40,nil,{lift=0,maxH=40})

-- Fortree Decoration Shop: the two long yellow display tables (3x2 with the
-- corner wall): top rows 12..24 with a 2-row edge, raised on four short
-- legs drawn in the floor's own colours (keep).
for _,t in ipairs({{{0x3ED,0x3EE,0x3CF},{0x3F5,0x3F6,0x3D7},11,45,12,15,41,44},
                   {{0x3CE,0x3EE,0x3EF},{0x3D6,0x3F6,0x3F7},3,37,4,7,33,36}})do
 add('em_decor_table_'..string.format('%X',t[1][1]),'generic_building',{t[1],t[2]},
  {{t[3],t[4],24,2,true,12,nil,nil,nil,nil,4},{t[5],t[6],26,4,true,26,nil,nil,true},{t[7],t[8],26,4,true,26,nil,nil,true}},
  {0x3D9},nil,6,nil,{lift=0})
end

-- Weather Institute (Route 119, lab tileset): the potted plants (0x25D,
-- 0x266, 0x287): small round pot (rows 10..14), the bush (rows -3..9)
-- sitting right on it (named potbush: no stem, unlike the plant wrapper); the single-column desk (0x260 over 0x254 over 0x25C, the lab table's
-- half); the green chair 0x257 (backrest on the west, as 0x25E).
for _,mid in ipairs({0x25D,0x266,0x287})do
 add('em_wi_potbush_'..string.format('%X',mid),'lab',{{mid}},
  {{4,12,14,4,true,10,nil,'disc'},{1,15,2,7,true,-3,nil,'disc',nil,nil,4}},{0x252,0x269,0x202},nil,4,nil,{lift=0})
end
add('em_wi_desk','lab',{{0x260},{0x254},{0x25C}},{{2,14,2,13,true,1,6},{0,16,39,7,false,20}},{0x252,0x269,0x202},nil,7)
add('em_lab_chair_257','lab',{{0x257}},{{1,5,12,9,true,0,nil,nil,nil,nil,nil,{2,3}},{5,14,12,3,true,5,nil,nil,nil,nil,nil,{8,7}}},{0x252,0x269,0x202},nil,3)

-- Weather Institute white partitions (lab tileset; the cells were flat).
-- Drawn in the floor's own white and grey (keep). From the back wall: the
-- top strip (0x26B, 0x273) to row 36, the cap 37..42 and the 24-row end
-- face with its grey panel (0x270, 0x278) down to 0x280; the free segment
-- starting at its rounded north end (0x268); on 2F the segment from the
-- south wall up to its rounded north end (0x281), its sides white.
local wiG={0x252,0x269,0x202}
add('em_wi_partition_a','lab',{{0x26B},{0x273},{0x270},{0x278},{0x280}},
 {{1,15,42,24,true,0,nil,nil,true,nil,nil,nil,true}},wiG,nil,24,nil,{maxH=32})
add('em_wi_partition_b','lab',{{0x268},{0x270},{0x278},{0x280}},
 {{1,15,26,24,true,9,nil,nil,true,nil,nil,nil,true}},wiG,nil,24,nil,{maxH=32})
add('em_wi_partition_c','lab',{{0x281},{0x26B},{0x26B},{0x26B}},
 {{1,15,39,24,true,9,nil,nil,true,nil,nil,{8,8}}},wiG,nil,24,nil,{maxH=32})

-- Lilycove Museum 1F (lilycove_museum): the Pokemon statue (0x22B over
-- 0x233): a square plinth (top rows 19..24, its 6-row face) with the statue
-- standing on it, round (top rows 0..8, its 18-row body the face); the
-- small bust (0x22C): plinth (top rows 5..10, 4-row face), bust on it.
local lm={0x202,0x203}
add('em_lmuseum_statue','lilycove_museum',{{0x22B},{0x233}},
 {{0,16,24,6,true,19,nil,nil,true},{2,15,8,18,true,0,nil,true,true,nil,6}},lm,nil,24,nil,{lift=0})
add('em_lmuseum_bust','lilycove_museum',{{0x22C}},
 {{0,16,10,4,true,5,nil,nil,true},{2,14,4,6,true,0,nil,true,true,nil,4}},lm,nil,10,nil,{lift=0})

-- Lilycove Museum 2F: the six display cases (4x4 from 0x264): a glass top
-- (rows 8..21, the floor seen through it) and the tall front with the
-- gold-framed exhibit (rows 22..54), its sides the case's green.
local lm2={0x268,0x269,0x270,0x271}
add('em_lmuseum_case','lilycove_museum',
 {{0x264,0x265,0x266,0x267},{0x286,0x26E,0x26E,0x26F},{0x28E,0x258,0x259,0x277},{0x27C,0x27D,0x27E,0x27F}},
 {{0,64,21,32,true,8,nil,nil,true,nil,nil,{8,30}}},lm2,nil,32,nil,{lift=0,maxH=32,back=true})
-- the two statues by the stairs (0x284/0x285 over 0x28C/0x28D), as on 1F,
-- drawn on the grey wall band (sampled out)
for _,c in ipairs({{0x284,0x28C},{0x285,0x28D}})do
 add('em_lmuseum_statue_'..string.format('%X',c[1]),'lilycove_museum',{{c[1]},{c[2]}},
  {{0,16,24,6,true,19,nil,nil,true},{2,15,8,18,true,0,nil,true,nil,nil,6}},lm2,{{0,0},{1,2},{15,9}},24,nil,{lift=0})
end

-- Lilycove Museum 1F: the big low display dais (6x4 from 0x248), drawn in
-- the floor's own colours (keep): its rounded rim (top rows 0..57, 6-row
-- front) with the glass case raised on it (cols 15..81, rows 10..46, 4 tall).
-- It also takes over the auto-relief posts at its corners.
add('em_lmuseum_dais','lilycove_museum',
 {{0x248,0x253,0x241,0x253,0x240,0x249},{0x210,0x24D,0x23F,0x23F,0x23F,0x210},{0x238,0x234,0x23B,0x23B,0x23B,0x239},{0x252,0x253,0x253,0x253,0x253,0x254}},
 {{1,95,57,6,true,0,nil,nil,true},{15,82,46,4,true,10,nil,nil,true,nil,6}},lm,nil,6,nil,{lift=0})

-- Department Store 2F-5F goods racks: pairs of tall shelf units seen from
-- the front (each 16 wide): the top shelf seen from above (rows 0..10), the
-- shelves of goods down the face to the base; three rows tall on 2F/3F,
-- two on 4F/5F; their hidden sides the units' grey.
local dsF={0x201,0x206,0x208,0x204,0x202,0x2F2,0x2F4,0x2FA,0x2F5,0x2FC,0x2FD,0x2F3}
for _,r in ipairs({{{0x2AA,0x2AB},{0x233,0x234},{0x2B2,0x2B3}},{{0x22B,0x22C},{0x233,0x234},{0x23B,0x23C}}})do
 add('em_store_rack3_'..string.format('%X',r[1][1]),'shop',r,
  {{0,15,10,37,true,0,nil,nil,true,nil,nil,{1,42}},{17,32,10,37,true,0,nil,nil,true,nil,nil,{30,42}}},dsF,nil,37,nil,{lift=0,maxH=37})
end
add('em_store_rack2','shop',{{0x2AA,0x2AB},{0x2B2,0x2B3}},
 {{0,15,10,21,true,0,nil,nil,true,nil,nil,{1,26}},{17,32,10,21,true,0,nil,nil,true,nil,nil,{30,26}}},dsF,nil,21,nil,{lift=0})

-- Department Store back counters (3F six cells, 5F seven): glass top with
-- the small displays (rows 0..12) and the glass-cased front (13..29), the
-- register end on the left; and the 4F U-counter, 2F's one cell narrower.
add('em_store_back_counter6','shop',{{0x2A4,0x243,0x2AE,0x2AE,0x2AE,0x2A5},{0x2AC,0x2A2,0x2A2,0x2A2,0x2A2,0x2AD}},
 {{0,96,12,17,true,0,nil,nil,true,nil,nil,{40,26}}},dsF,nil,17,nil,{lift=0})
add('em_store_back_counter7','shop',{{0x2A4,0x2FE,0x2F6,0x2F6,0x2F6,0x2F6,0x2A5},{0x2AC,0x2A2,0x2A2,0x2A2,0x2A2,0x2A2,0x2AD}},
 {{0,112,12,17,true,0,nil,nil,true,nil,nil,{40,26}}},dsF,nil,17,nil,{lift=0})
add('em_store_counter5','shop',
 {{0x2DD,0x29B,0x29B,0x29B,0x2DD},{0x29E,0x2A3,0x2A3,0x2A3,0x29E},{0x2A4,0x20B,0x208,0x208,0x29E},{0x2DE,0x206,0x201,0x201,0x2D1}},
 {{16,64,21,10,true,12},{0,16,53,10,true,12,nil,nil,true},{64,80,53,10,true,12,nil,nil,true}},
 {0x201,0x208,0x206},nil,10)

-- The generic TV where the cell above is plain wall (0x21E over 0x238,
-- Fan Club and others): the cabinet (top row 15, 8-row face) with the tube
-- set on it (top rows -3..2, 13-row face), reaching back like a cube.
add('em_generic_tv2','generic_building',{{0x21E},{0x238}},
 {{0,16,15,8,true,14},{1,15,2,13,true,-3,4,nil,nil,nil,8}},{0x224,0x223},nil,8)

-- Steven's house (Mossdeep): the long table under its cloth (4x2 from 0x2E8;
-- the orange triangles at its corners are the cloth's corners, not chairs):
-- one low block in the cloth's cream, the book lying on it; and his
-- rock showcases (0x35B over 0x363): a glass case on a wooden stand.
add('em_steven_table','generic_building',{{0x2E8,0x2E9,0x2E9,0x2EA},{0x2F0,0x2F1,0x2F1,0x2F2}},
 {{3,61,23,6,true,0,nil,nil,nil,nil,nil,{30,10}},
  {34,46,22,2,true,16,nil,nil,true,nil,6}},{0x223},nil,6)
add('em_steven_showcase','generic_building',{{0x35B},{0x363}},
 {{0,16,21,9,false,21},{0,16,12,8,true,3,nil,nil,true,nil,9}},{0x223},nil,17,nil,{lift=0})

-- Mossdeep Game Corner 1F (mossdeep_game_corner). Floor 0x20A/0x209.
local mg={0x20A,0x209,0x201,0x202}
-- the blue glass tables (2x2 from 0x218): glass top rows -3..27 on short legs
add('em_mgc_table','mossdeep_game_corner',{{0x218,0x219},{0x220,0x221}},{{1,31,27,3,false,-3}},mg,nil,3)
-- the round cushion stools round them (north 0x210/0x211, west 0x216, east 0x215)
for _,mid in ipairs({0x210,0x211,0x215,0x216})do
 add('em_mgc_stool_'..string.format('%X',mid),'mossdeep_game_corner',{{mid}},{{2,14,10,4,true,1,nil,'disc'}},mg,nil,4,nil,{lift=0})
end
-- the long wooden bench along the back (either side of the doorway; its top
-- drawn in the floor's colour, keep) and the tall striped wooden cabinet at
-- each end, backed onto the wall
add('em_mgc_bench','mossdeep_game_corner',{{0x222,0x223,0x224,0x232,0x225,0x226,0x227}},
 {{0,48,9,4,false,-3,nil,nil,true},{64,112,9,4,false,-3,nil,nil,true}},mg,nil,4)
for _,c in ipairs({{0x212,0x21A},{0x217,0x21F}})do
 add('em_mgc_cabinet_'..string.format('%X',c[1]),'mossdeep_game_corner',{{c[1]},{c[2]}},
  {{0,16,6,22,true,5,0,nil,true,nil,nil,nil,true}},mg,nil,22,nil,{maxH=30})
end

-- Sootopolis (House3, Mystery Events house): the slatted yellow bench (2x2
-- from 0x3DD): slats on top (rows 1..23), a 4-row front rail, open on its
-- corner legs (to row 30); sides in the slats' yellow, not a navy drum.
add('em_soot_bench','generic_building',{{0x3DD,0x3DE},{0x3E5,0x3DF}},
 {{1,31,27,7,false,1,nil,nil,true,nil,nil,{3,10}}},{0x3FE,0x3FF},nil,7)

-- Mystery Events House 1F (mystery_events_house tileset, floor 0x235): the
-- yellow table (2x2 from 0x216) on its legs, a chair either side of it
-- (0x210 backrest west, 0x211 east), like the Lilycove house chairs.
local mev={0x235,0x236}
add('em_mev_table','mystery_events_house',{{0x216,0x217},{0x21E,0x21F}},{{2,30,22,8,false,0}},mev,nil,8)
add('em_mev_chair_w','mystery_events_house',{{0x210}},{{2,6,4,9,true,0},{6,15,12,4,true,5}},mev,{{0,0}},4,nil,{lift=0})
add('em_mev_chair_e','mystery_events_house',{{0x211}},{{10,14,4,9,true,0},{1,10,12,4,true,5}},mev,{{15,0}},4,nil,{lift=0})

-- Abandoned Ship / S.S. Tidal cabins (general__inside_ship; Opus did the
-- walls). Carpet 0x238 and its edge rows.
local shp={0x238,0x23B,0x23D,0x23A,0x23C}
local SG={primary='general'}
-- the bunks (2x2 from 0x250, headboard on the west; 0x254 mirrored): a
-- headboard (rows 4..9 drawn tall) and the green mattress on its frame
add('em_ship_bed_w','inside_ship',{{0x250,0x251},{0x258,0x259}},
 {{8,31,9,8,true,4,nil,nil,true},{8,31,27,6,false,10,nil,nil,true}},shp,nil,6,nil,SG)
add('em_ship_bed_e','inside_ship',{{0x254,0x255},{0x25C,0x25D}},
 {{1,24,9,8,true,4,nil,nil,true},{1,24,27,6,false,10,nil,nil,true}},shp,nil,6,nil,SG)
-- the green square table (2x2 from 0x256) on its legs (not 'keep': the
-- carpet seen between its legs is floor, so the legs stand open)
add('em_ship_table','inside_ship',{{0x256,0x257},{0x25E,0x25F}},{{1,31,25,6,false,0}},shp,nil,6,nil,SG)
-- wooden chairs (0x260 backrest west, 0x261 east): slatted seat on legs
add('em_ship_chair_260','inside_ship',{{0x260}},{{2,6,4,11,true,0,nil,nil,true},{6,14,11,4,false,4,nil,nil,true}},shp,nil,4,nil,{primary='general',lift=0})
for _,mid in ipairs({0x266,0x267,0x21E})do   -- the same chair on other carpets
 add('em_ship_chair_'..string.format('%X',mid),'inside_ship',{{mid}},{{2,6,4,11,true,0,nil,nil,true},{6,14,11,4,false,4,nil,nil,true}},{0x238,0x23B,0x23D,0x23A,0x23C},nil,4,nil,{primary='general',lift=0})
end
add('em_ship_chair_261','inside_ship',{{0x261}},{{10,14,4,11,true,0,nil,nil,true},{2,10,11,4,false,4,nil,nil,true}},shp,nil,4,nil,{primary='general',lift=0})
-- the round white bin (0x262) and the white floor cushion (0x264 0x265)
add('em_ship_bin','inside_ship',{{0x262}},{{2,14,8,7,true,0,nil,'disc',true}},shp,nil,7,nil,{primary='general',lift=0})
add('em_ship_cushion','inside_ship',{{0x264,0x265}},{{0,32,13,4,true,1,nil,nil,true}},shp,nil,4,nil,{primary='general',lift=0})

-- Abandoned Ship Captain's Office (facility tileset): the two control
-- consoles against the north wall (0x2B8/0x2B9 over 0x2C0/0x2C1; tops rows
-- 1..6, 16-row panel faces), the machine on the NE (0x20E/0x20F over
-- 0x216/0x217: top rows 8..21, 10-row face) and the white side desk on the
-- west wall (0x3B4 over 0x3B5).
local cpt={0x202,0x203,0x204}
add('em_capt_consoles','facility',{{0x2B8,0x2B9},{0x2C0,0x2C1}},
 {{1,15,6,16,true,1,nil,nil,true},{17,31,6,16,true,1,nil,nil,true}},cpt,nil,16,nil,{lift=0})
add('em_capt_machine','facility',{{0x20E,0x20F},{0x216,0x217}},{{0,32,21,10,true,8,nil,nil,true}},cpt,nil,10,nil,{lift=0})
add('em_capt_side_desk','facility',{{0x3B4},{0x3B5}},{{1,15,23,8,true,1,nil,nil,true}},cpt,nil,8,nil,{lift=0})
-- S.S. Tidal cabins: the long dining table (4x2), the writing desk with its
-- chair tucked in (0x299/0x29A over 0x2A1/0x2A2), the blue bed (0x271 over
-- 0x279), the chair 0x27C (as 0x261) and more bins
add('em_ship_long_table','inside_ship',{{0x256,0x270,0x270,0x257},{0x25E,0x278,0x278,0x25F}},{{1,63,25,6,false,0}},shp,nil,6,nil,SG)
add('em_ship_desk','inside_ship',{{0x299,0x29A},{0x2A1,0x2A2}},
 {{1,31,13,10,false,2,nil,nil,true},{10,23,27,5,true,18,nil,nil,true}},shp,nil,10,nil,{primary='general',lift=0})
add('em_ship_bed_blue','inside_ship',{{0x271,0x272},{0x279,0x27A}},
 {{1,23,8,6,true,4,nil,nil,true},{1,23,26,5,false,9,nil,nil,true}},shp,nil,5,nil,SG)
add('em_ship_chair_27C','inside_ship',{{0x27C}},{{10,14,4,11,true,0,nil,nil,true},{2,10,11,4,false,4,nil,nil,true}},shp,nil,4,nil,{primary='general',lift=0})
for _,mid in ipairs({0x277,0x268,0x235})do
 add('em_ship_bin_'..string.format('%X',mid),'inside_ship',{{mid}},{{2,14,8,7,true,0,nil,'disc',true}},shp,nil,7,nil,{primary='general',lift=0})
end

-- Abandoned Ship hidden floor: the same green table drawn with a darker
-- carpet behind it (0x20F/0x217 over 0x25E/0x25F) and the writing desk with
-- its chair pulled out (0x2A0 under 0x299)
add('em_ship_table_20F','inside_ship',{{0x20F,0x217},{0x25E,0x25F}},{{1,31,25,6,false,0}},shp,nil,6,nil,SG)
add('em_ship_desk_2A0','inside_ship',{{0x299,0x29A},{0x2A0,0x2A2}},
 {{1,31,13,10,false,2,nil,nil,true},{10,23,27,5,true,18,nil,nil,true}},shp,nil,10,nil,{primary='general',lift=0})
-- S.S. Tidal lower deck: the cargo crates, one column of cells each. The lid
-- is the first cell (rows 0..15, slats seen from above), the slatted face
-- runs down from it (light upper boards, the dark lower ones) to the front
-- cell's row 14 (0x2F0..0x2F5): 31 tall for a 3-cell column, 15 for a crate
-- drawn on two cells; the deck plates round it stay floor.
local sst={0x20D,0x2E7,0x2EE,0x2F6,0x21D,0x2E6}
local crates={}
for _,t in ipairs({{0x2E0,0x2E8,0x2F0},{0x2E0,0x2EB,0x2F3},{0x2E1,0x2E9,0x2F1},{0x2E1,0x2EC,0x2F4},
 {0x2E2,0x2EA,0x2F2},{0x2E2,0x2ED,0x2F5},{0x2E3,0x2E8,0x2F0},{0x2E3,0x2EB,0x2F3},{0x2E4,0x2EC,0x2F4},
 {0x2E5,0x2EA,0x2F2},{0x2E5,0x2ED,0x2F5},{0x2E8,0x2E3,0x2F3},{0x2E8,0x2E8,0x2F0},{0x2EA,0x2E5,0x2F5},
 {0x2EA,0x2EA,0x2F2},{0x2EB,0x2EB,0x2F3},{0x2EC,0x2EC,0x2F4},{0x2ED,0x2ED,0x2F5}})do
 add(string.format('em_tidal_crate_%X_%X_%X',t[1],t[2],t[3]),'inside_ship',{{t[1]},{t[2]},{t[3]}},
  {{1,15,15,31,true,0,nil,nil,true,nil,nil,nil,true}},sst,nil,31,nil,{primary='general',lift=0})
end
-- a crate stacked on a crate (four cells: lid, face, the lower crate's
-- lid-edge row, front), one 47-tall block
for _,t in ipairs({{0x2E0,0x2E8,0x2E3,0x2F3},{0x2E2,0x2EA,0x2E5,0x2F5}})do
 add(string.format('em_tidal_crate_%X_%X_%X_%X',t[1],t[2],t[3],t[4]),'inside_ship',{{t[1]},{t[2]},{t[3]},{t[4]}},
  {{1,15,15,47,true,0,nil,nil,true,nil,nil,nil,true}},sst,nil,47,nil,{primary='general',lift=0})
end
for _,t in ipairs({{0x2E0,0x2F0},{0x2E2,0x2F2},{0x2E3,0x2F3},{0x2E5,0x2F5}})do
 add(string.format('em_tidal_crate_%X_%X',t[1],t[2]),'inside_ship',{{t[1]},{t[2]}},
  {{1,15,15,15,true,0,nil,nil,true,nil,nil,nil,true}},sst,nil,15,nil,{primary='general',lift=0})
end

-- Frontier lounges: the potted plant on the glass display square in the
-- middle of the room (0x3DC over 0x3E4): its round pot (top rows 18..24,
-- 6-row face) with the leafy crown seated on it.
add('em_lounge_centre_plant','battle_frontier',{{0x3DC},{0x3E4}},
 {{2,14,24,6,true,18,nil,'disc'},{1,15,9,9,true,3,nil,'disc',nil,nil,6}},{0x3C8,0x3C9},{{1,1},{15,16}},6)

-- Battle Pike rooms: the rows of gold theatre seats, one whole seat per
-- cell. 0x2F9 (the blocked rows): backrest rows 0..8, cushion rows 9..14;
-- 0x30D (the aisles' seats): backrest rows 1..5, cushion 6..12. The cushion
-- a low block, the backrest standing on its back edge; the floor round
-- them stays floor.
local pk={0x2C1}   -- the plain pink floor only (0x2DA/0x2DD carry seat-edge colours)
for _,mid in ipairs({0x2F9,0x23E})do   -- 0x23E: the row's end seat at the west wall
 add('em_pike_seat_'..string.format('%X',mid),'battle_pike',{{mid}},{{1,15,14,4,true,9,nil,nil,nil,nil,nil,{3,11}},{3,13,8,8,true,0,nil,nil,nil,nil,4,{4,0}}},pk,nil,4,nil,{lift=0})
end
for _,mid in ipairs({0x30D,0x234,0x237,0x314})do
 add('em_pike_seat_'..string.format('%X',mid),'battle_pike',{{mid}},{{1,15,12,4,true,6,nil,nil,nil,nil,nil,{5,11}},{3,13,5,8,true,1,nil,nil,nil,nil,4,{5,2}}},pk,nil,4,nil,{lift=0})
end

-- Safari Zone rest house: the yellow-clothed table (2x2 from 0x2E8) on its
-- legs, and the wooden chairs either side (0x234 back on the west, 0x23C on
-- the east): an upright backrest and a slatted seat on legs.
add('em_rest_table','generic_building',{{0x2E8,0x2EA},{0x2F0,0x2F2}},{{2,30,22,8,false,0,nil,nil,true}},{0x223,0x224},nil,8)
add('em_rest_chair_w','generic_building',{{0x234}},{{1,5,3,11,true,0,nil,nil,true,nil,nil,{2,8}},{5,15,10,4,false,4,nil,nil,true,nil,nil,{8,8}}},{0x223},nil,4,nil,{lift=0})
add('em_rest_chair_e','generic_building',{{0x23C}},{{11,15,3,11,true,0,nil,nil,true,nil,nil,{13,8}},{1,11,10,4,false,4,nil,nil,true,nil,nil,{6,8}}},{0x223},nil,4,nil,{lift=0})

-- Trade Center (cable club tileset): the trading machine in the middle (4x3
-- from 0x20B): its two screens and the keyboards seen from above (rows
-- 3..17), the 17-row front panel; the brown chairs either side facing it
-- (backrest on the outer side, seat toward the machine).
add('em_trade_machine','cable_club',{{0x20B,0x20C,0x20D,0x20E},{0x213,0x214,0x215,0x216},{0x21B,0x21C,0x21D,0x21E}},
 {{16,48,22,17,true,3,nil,nil,true},
  {1,5,26,10,true,19,nil,nil,true,nil,nil,{2,26}},{5,12,30,4,true,23,nil,nil,true,nil,nil,{8,31}},
  {59,63,26,10,true,19,nil,nil,true,nil,nil,{61,26}},{52,59,30,4,true,23,nil,nil,true,nil,nil,{55,31}}},{0x208,0x202},{{31,0},{0,40}},17,nil,{lift=0,back=true})

-- Aqua Hideout (facility tileset, same pieces as the Shipyard): the big
-- capsule machines are the Shipyard engine's art with another top row
-- (0x22B..0x22E): same build.
for _,e in ipairs({{0x229,0x229},{0x228,0x2A1},{0x228,0x229},{0x229,0x2A1},{0x228,0x228},{0x2A9,0x2A1}})do
 add('em_aqua_capsule_'..string.format('%X_%X',e[1],e[2]),'facility',
 {{0x22B,0x22C,0x22D,0x22E},{0x233,0x234,0x235,0x236},{0x23B,0x23C,0x23D,0x23E},{0x243,0x244,0x245,0x246},{0x24B,0x24C,0x24D,0x24E},{e[1],0x255,0x256,e[2]}},
 lyingTank(lyingTank({{0,64,66,5,true,9,nil,nil,true},{16,48,90,5,true,72,nil,nil,true},
  {21,43,76,12,true,72,nil,nil,true,nil,5}},9,55,9,62,20,5),21,43,60,75,7,5),sy,nil,25,nil,{lift=0})
end
-- the robot-arm machines (2x3 from 0x282): the base console (vent box and
-- control panel, top rows 26..30, 16-row face) and the arm rising behind it
-- on its round pivot.
add('em_aqua_robot_arm','facility',{{0x282,0x283},{0x288,0x289},{0x290,0x291}},
 {{0,32,30,16,true,26,nil,nil,true},{9,23,20,18,true,1,nil,'disc',true}},{0x228,0x229,0x202},nil,18,nil,{lift=0})

-- Aqua Hideout: the wooden cargo crates (2 wide; the lid, light slats, the
-- dark lower boards: 0x3D8/0x3D9 over 0x3DA/0x3DB over 0x3DC/0x3DD, as the
-- S.S. Tidal's) and a pair stacked (two 0x3DA rows, one 47-tall block);
-- the white round floor hatches (0x2DF) a low disc
local ahf={0x228,0x229,0x22A,0x202,0x203,0x259}
add('em_aqua_crate','facility',{{0x3D8,0x3D9},{0x3DA,0x3DB},{0x3DC,0x3DD}},{{1,31,15,31,true,0,nil,nil,true,nil,nil,nil,true}},ahf,nil,31,nil,{lift=0})
add('em_aqua_crate_stack','facility',{{0x3D8,0x3D9},{0x3DA,0x3DB},{0x3DA,0x3DB},{0x3DC,0x3DD}},{{1,31,15,47,true,0,nil,nil,true,nil,nil,nil,true}},ahf,nil,47,nil,{lift=0})
-- the wall consoles (0x230/0x231: a 22-row panel of lamps and dials, a box
-- 12 deep), the blueprint table (0x3F0/0x3F1 over 0x3F8/0x3F9, as the
-- Shipyard's work table) and the blue egg chairs (one cell each)
for _,mid in ipairs({0x230,0x231})do
 add('em_aqua_console_'..string.format('%X',mid),'facility',{{mid}},{{0,16,0,22,true,0,11,nil,true}},ahf,nil,22,nil,{lift=0})
end
add('em_aqua_table','facility',{{0x3F0,0x3F1},{0x3F8,0x3F9}},{{0,32,24,6,false,1,nil,nil,true}},ahf,nil,6,nil,{lift=0})
-- the glass display case against the wall (drawn up into the wall row above
-- 0x3E3: glass top rows -13..-4, a 19-row panel face on legs; the red carpet
-- below it, 0x3EA, stays floor)
add('em_aqua_glass_case','facility',{{0x3E3},{0x3EA}},{{1,15,-4,19,true,-13,nil,nil,true,nil,nil,{5,6}}},ahf,nil,19,nil,{lift=0})
for _,mid in ipairs({0x3E1,0x3E8,0x3E9,0x3EB})do
 add('em_aqua_chair_'..string.format('%X',mid),'facility',{{mid}},{{2,14,13,9,true,0,nil,nil,true}},ahf,nil,9,nil,{lift=0})
end
-- more of the same crates (Slateport/Lilycove harbours): the lid drawn as
-- 0x3DE/0x3DF, and a low crate (lid over the dark boards, 15 tall)
add('em_aqua_crate_3DE','facility',{{0x3DE,0x3DF},{0x3DA,0x3DB},{0x3DC,0x3DD}},{{1,31,15,31,true,0,nil,nil,true,nil,nil,nil,true}},ahf,nil,31,nil,{lift=0})
add('em_aqua_crate_low','facility',{{0x3D8,0x3D9},{0x3DC,0x3DD}},{{1,31,15,15,true,0,nil,nil,true,nil,nil,nil,true}},ahf,nil,15,nil,{lift=0})
-- Aqua Hideout: the robot-arm machine with the other top-left cell (0x28A),
-- the boss's white table with its navy top (0x3F3/0x3F4 over 0x3C3/0x3C5
-- over 0x3FB/0x3FC: top rows 5..29 on legs, as Devon's) and the little drawer cabinet (0x232)
add('em_aqua_robot_arm_28A','facility',{{0x28A,0x283},{0x288,0x289},{0x290,0x291}},
 {{0,32,30,16,true,26,nil,nil,true},{9,23,20,18,true,1,nil,'disc',true}},{0x228,0x229,0x202},nil,18,nil,{lift=0})
add('em_aqua_office_table','facility',{{0x3F3,0x3F4},{0x3C3,0x3C5},{0x3FB,0x3FC}},{{0,32,29,10,false,5,nil,nil,true,nil,nil,{8,31}}},{0x3E6,0x3E5,0x3ED},nil,10,nil,{lift=0})
add('em_aqua_drawers','facility',{{0x232}},{{1,15,6,16,true,1,nil,nil,true}},ahf,nil,16,nil,{lift=0})
-- steel beams lying loose (cells not part of a full em_ship_beams stack): a
-- body cell (0x227) an 8-tall bar, an end cell (0x22F, 0x2B1) the bar's last
-- 8 rows with its two-layer end face
add('em_ship_beam_body','facility',{{0x227}},{{0,16,15,8,true,0,nil,nil,true,nil,nil,{3,4}}},sy,nil,8,nil,{lift=0})
for _,mid in ipairs({0x22F,0x2B1})do
 add('em_ship_beam_end_'..string.format('%X',mid),'facility',{{mid}},{{0,16,7,8,true,0,nil,nil,true,nil,nil,{3,4}}},sy,nil,8,nil,{lift=0})
end
-- Mt. Pyre: the gravestones on a wide base (0x2ED, 0x3D7)
for _,mid in ipairs({0x2ED,0x3D7})do
 add('em_pyre_grave_wide_'..string.format('%X',mid),'facility',{{mid}},{{0,16,3,11,true,0,nil,true,true}},{0x2E6,0x2E7},nil,11,nil,{primary='general',lift=4})
end
-- Shipyard 2F: the desks without a computer (0x240 0x242 over 0x248 0x24A)
add('em_ship_desk_plain','facility',{{0x240,0x242},{0x248,0x24A}},{{0,32,26,5,false,11}},sy,nil,5,nil,{lift=0})
-- Lanette's work table (0x250 0x251 over 0x258 0x259): the two chair backs
-- behind (13 tall) and the table on its legs (top rows 15..23)
add('em_lan_table','lab',{{0x250,0x251},{0x258,0x259}},
 {{2,14,2,13,true,1,6},{18,30,2,13,true,1,6},{0,32,23,7,false,15}},{0x202},nil,7)
-- S.S. Tidal lower deck: the white bucket (0x27F)
add('em_tidal_bucket','inside_ship',{{0x27F}},{{3,13,8,5,true,1,nil,'disc',true}},{0x20D,0x21D,0x2EE},nil,5,nil,{primary='general',lift=0})
-- Contest stage: the small white box with the gold clasp (0x26F over 0x277:
-- lid rows 10..15, a 7-row front)
for _,pr in ipairs({false,'general'})do
 add('em_contest_box'..(pr and '_g' or ''),'contest',{{0x26F},{0x277}},{{0,16,15,7,true,10,nil,nil,true}},{0x271},{{0,23}},7,nil,{primary=pr or nil,lift=0})
end
-- Contest stage: the low orange-cushioned kerb round the stage, 3 px high
for _,pr in ipairs({false,'general'})do
 for _,mid in ipairs({0x268,0x269,0x26A,0x270,0x272,0x278,0x279,0x27A})do
  add('em_contest_kerb_'..string.format('%X',mid)..(pr and '_g' or ''),'contest',{{mid}},{{0,16,15,3,true,0}},{0x271,0x225,0x260,0x261},nil,3,nil,{primary=pr or nil,lift=0})
 end
end
add('em_aqua_hatch','facility',{{0x2DF}},{{0,16,15,3,true,0,nil,'disc',true}},ahf,nil,3,nil,{lift=0})

-- The white fridge in the generic-house kitchens (0x278 over 0x280 over
-- 0x288, at the east end of the back wall; it had no recipe and stood as a
-- piece of wall): white top rows 10..17, its two doors the 19-row face, the
-- wall band above it kept on the wall plane; every pixel kept (the door
-- gaps are drawn in the floor's colour).
add('em_generic_fridge','generic_building',{{0x278},{0x280},{0x288}},
 {{1,15,17,19,true,10,nil,nil,true,nil,nil,{8,15}}},{0x224,0x223},nil,19,10,{lift=0,maxH=28})

-- Audit pass, generic_building: the remaining automatic stand-ins.
-- Pacifidlog's 0x3B7 is plain plank floor by the wall: flat.
add('em_pac_floor_3B7','generic_building',{{0x3B7}},{{0,16,12,0}},{0x3B7},nil,0)
-- Fortree treehouse glass cabinet (2x2 from 0x3E3), backed onto the wall
add('em_fortree_cabinet','generic_building',{{0x3E3,0x3E4},{0x3EB,0x3EC}},
 {{2,23,8,22,true,3,nil,nil,true,nil,nil,{12,6}}},{0x3D9},nil,22,3,{lift=0,maxH=30})
-- the Fossil Maniac's fossil display case (2x2 from 0x306): top rows 5..10,
-- the fossils under the glass front to row 30
add('em_fossil_case','generic_building',{{0x306,0x307},{0x30E,0x30F}},
 {{1,31,10,20,true,5,nil,nil,true}},{0x229},nil,20,nil,{lift=0})
-- Sootopolis potted plant (0x294 over 0x29C) and fridge (0x2BD over 0x2C5)
add('em_soot_plant','generic_building',{{0x294},{0x29C}},
 {{3,13,25,6,true,18,nil,'disc'},{0,16,9,9,true,1,nil,'disc',nil,nil,6}},{0x3FE,0x3FF,0x223},nil,6)
add('em_soot_fridge','generic_building',{{0x2BD},{0x2C5}},
 {{1,15,9,19,true,3,nil,nil,true,nil,nil,{8,15}}},{0x3FE,0x3FF,0x223},nil,19,3,{lift=0,maxH=28})
-- Wanda's small bed (3x2 from 0x2D2): headboard and mattress on legs
add('em_wanda_bed','generic_building',{{0x2D2,0x2D3,0x2D4},{0x2DA,0x2DB,0x2DC}},
 {{13,35,22,6,true,0,nil,nil,true},{14,34,3,6,true,0,nil,nil,true,nil,6}},{0x223},nil,6,nil,{lift=0})

-- Pokemon League lobby (Ever Grande): the Center desk without its west
-- curved end (it runs into the wall), and the second counter on the east
-- (curved west end with its Poke Ball, then plain counter with a gate).
add('em_league_center_desk','pokemon_center',{{0x273,0x22A,0x22B,0x207,0x25B,0x251},{0x221,0x221,0x221,0x205,0x221,0x259}},
 {{80,95,20,11,true,-7,nil,nil,true},{0,95,20,11,true,13,nil,nil,true},
  {17,47,6,8,true,-14,nil,nil,true},{65,79,-4,16,true,-7},
  {82,93,20,0,true,8,nil,'ball',true,nil,11}},{0x202},nil,11,nil,{lift=0})
add('em_league_counter_e','pokemon_center',{{0x250,0x27D,0x229,0x274,0x275},{0x258,0x221,0x205,0x221,0x221}},
 {{1,16,20,11,true,-7,nil,nil,true},{1,80,20,11,true,13,nil,nil,true}},{0x202,0x229,0x274,0x275,0x27D},nil,11,nil,{lift=0})

-- Trick House puzzle 2: the low wooden plank barriers winding through the
-- room (0x280..0x294: straights, bends and ends): each cell's plank pixels
-- stand as a 6-high board, the floor round them stays floor.
-- Trick House puzzle 8: the grey clay pots (0x26C, one cell): the mouth and
-- shoulders are the top (rows 0..6), the belly a 9-row round face
add('em_trick_pot','trick_house_puzzle',{{0x26C}},{{1,15,6,9,true,0,nil,'disc'}},{0x26B,0x210},nil,9,nil,{lift=0})
-- the same pot on the tatami strip (0x214)
add('em_trick_pot_214','trick_house_puzzle',{{0x214}},{{1,15,6,9,true,0,nil,'disc'}},{0x208,0x210},nil,9,nil,{lift=0})
for mid=0x280,0x294 do
 add('em_trick_plank_'..string.format('%X',mid),'trick_house_puzzle',{{mid}},{{0,16,15,6,true,0}},{0x208,0x210},nil,6,nil,{lift=0})
end

-- Battle Dome lobby (battle_dome; floor 0x340..0x343).
local dmf={0x340,0x341,0x342,0x343}
-- the two L-shaped side counters (2x4): the arm along the side wall and the
-- bar across its foot, cream tops on blue fronts (7 rows)
add('em_dome_counter_w','battle_dome',{{0x390,0x391},{0x398,0x399},{0x3A0,0x3A1},{0x3A8,0x3A9}},
 {{0,16,56,7,true,0,nil,nil,true},{0,32,56,7,true,48,nil,nil,true}},dmf,nil,7,nil,{lift=0})
add('em_dome_counter_e','battle_dome',{{0x371,0x372},{0x379,0x37A},{0x381,0x382},{0x389,0x38A}},
 {{16,32,56,7,true,0,nil,nil,true},{0,32,56,7,true,48,nil,nil,true}},dmf,nil,7,nil,{lift=0})
-- the capsule machines at the counters' ends (0x392/0x393 over 0x39A/0x39B)
for _,m in ipairs({{0x392,0x39A},{0x393,0x39B}})do
 add('em_dome_capsule_'..string.format('%X',m[1]),'battle_dome',{{m[1]},{m[2]}},
  {{1,15,9,15,true,4,nil,'disc',true}},dmf,nil,15,nil,{lift=0})
end
-- the small counter with the red machine on it (3x2 from 0x374)
add('em_dome_red_counter','battle_dome',{{0x374,0x375,0x376},{0x37C,0x37D,0x37E}},
 {{0,48,24,6,true,11,nil,nil,true},{16,32,9,13,true,4,nil,nil,true,nil,6}},dmf,nil,6,nil,{lift=0})
-- the PC terminal (0x373 over 0x37B over 0x383), a tube set on its stand
add('em_dome_pc','battle_dome',{{0x373},{0x37B},{0x383}},{{0,16,16,23,true,8,nil,nil,true}},dmf,nil,23,nil,{lift=0})
-- the monitor console (3x2 from 0x360): counter and the deep monitor on it
add('em_dome_monitor','battle_dome',{{0x360,0x361,0x362},{0x368,0x369,0x36A}},
 {{0,48,24,6,true,11,nil,nil,true},{9,39,4,15,true,1,10,nil,true,nil,6}},dmf,nil,6,nil,{lift=0})

-- the velvet-rope barriers (0x2DB..0x2E0, drawn side-on: a silver post at
-- each end, the red rope slung between): a thin card, so the gap under the
-- rope stays open (the profile had them as solid walls)
for mid=0x2DB,0x2E0 do
 add('em_dome_rope_'..string.format('%X',mid),'battle_dome',{{mid}},{{0,16,0,15,true,0,3,'card'}},dmf,nil,15,nil,{lift=0,maxH=15})
end

-- Battle Factory lobby (battle_factory): the PC (the Center PC's drawing,
-- one solid tube block), the plant 0x23C over 0x34F, the teal kiosks at the
-- pillars' feet (0x218 over 0x220) and the grey benches round them (top
-- rows 12..22 across the two cells, an 8-row front).
local fcf={0x201,0x202,0x203,0x204,0x334}
add('em_factory_pc','battle_factory',{{0x239},{0x241},{0x249}},
 {{1,15,15,24,true,8,28,nil,true,nil,nil,{8,13}}},fcf,nil,24,nil,{lift=0})
add('em_factory_plant_23C_34F','battle_factory',{{0x23C},{0x34F}},
 {{3,13,24,6,true,19,nil,'disc'},{0,16,8,10,true,3,nil,'disc',nil,nil,6}},fcf,nil,6)
add('em_factory_kiosk','battle_factory',{{0x218},{0x220}},{{1,15,8,15,true,4,nil,nil,true}},fcf,nil,15,nil,{lift=0})
for _,m in ipairs({{0x361,0x213},{0x22E,0x212},{0x22D,0x211},{0x33B,0x212},{0x22F,0x213}})do
 add('em_factory_bench_'..string.format('%X_%X',m[1],m[2]),'battle_factory',{{m[1]},{m[2]}},{{0,16,22,8,true,12}},fcf,nil,8,nil,{lift=0})
end
add('em_factory_bench_221','battle_factory',{{0x221}},{{0,16,6,8,true,-4}},fcf,nil,8,nil,{lift=0})
-- Battle Pike: the armchairs in the corridors and rooms (back cell over seat
-- cell, facing the camera): the seat (top rows 18..21, 6-row front) and the
-- backrest standing behind it (rows 2..17 its face)
local pkf={0x2C1,0x2D9,0x2DA,0x2DE,0x2E0,0x2E3,0x2E6,0x340,0x358,0x2C2,0x2D4}
for _,m in ipairs({{0x224,0x22C},{0x216,0x21E},{0x2DB,0x2DC},{0x31B,0x22D},{0x235,0x23D},{0x234,0x23C},{0x31B,0x31C}})do
 add('em_pike_armchair_'..string.format('%X_%X',m[1],m[2]),'battle_pike',{{m[1]},{m[2]}},
  {{1,15,21,6,true,18},{2,14,1,16,true,1}},pkf,nil,6,nil,{lift=0})
end
-- the Pike lobby's big screen on its stand (3x3 from 0x32A) and the two
-- tube PCs on the back wall (0x328/0x329 over 0x330/0x331 over 0x338/0x339)
add('em_pike_screen','battle_pike',{{0x32A,0x32B,0x32C},{0x332,0x333,0x334},{0x33A,0x33B,0x33C}},
 {{9,39,17,18,true,17,26,nil,true,nil,4},{18,30,39,4,true,36,nil,nil,true}},pkf,nil,22,nil,{lift=0})
for _,c in ipairs({{0x328,0x330,0x338},{0x329,0x331,0x339}})do
 add('em_pike_pc_'..string.format('%X',c[2]),'battle_pike',{{c[1]},{c[2]},{c[3]}},
  {{1,15,15,24,true,8,28,nil,true,nil,nil,{8,13}}},pkf,nil,24,nil,{lift=0})
end

-- Trainer Hill entrance (trainer_hill): the round café stools (0x309), the
-- PC by the west wall (the Center PC's drawing on a stand: 0x32E over 0x004
-- over 0x30A) and the ticket machine at the counter's end (0x314 over 0x31C).
local thf={0x330,0x331,0x335,0x316,0x337,0x336,0x301}
-- the roof's four thin aerial poles (0x3CE over 0x3CF, walkable): the pole
-- and its foot stand as a 4 px thick cutout, its shadow stays on the roof
-- the roof's side rails (0x3C5, the last one 0x3C6): a row of posts, each
-- drawn head-over-foot across two cells -- the cap (rows 9..12 of the cell
-- above) and its 12-row body down to the foot at this cell's row 8. Its
-- cream is the roof's (keep).
for _,mid in ipairs({0x3C5,0x3C6})do
 add('em_th_roof_post_'..string.format('%X',mid),'trainer_hill',{{mid}},{{4,13,-4,12,true,-7,nil,nil,true,nil,nil,{7,-6}}},{0x36B},nil,12,nil,{lift=0})
end
add('em_th_roof_pole','trainer_hill',{{0x3CE},{0x3CF}},{{4,12,7,20,true,8,24,'card'}},{0x36B},nil,20,nil,{lift=0})
add('em_th_stool','trainer_hill',{{0x309}},{{1,15,9,5,true,0,nil,'disc'}},thf,nil,5,nil,{lift=0})
add('em_th_pc','trainer_hill',{{0x32E},{0x004},{0x30A}},
 {{1,15,15,24,true,8,28,nil,true,nil,nil,{8,13}},{1,15,46,7,false,39}},thf,nil,24,nil,{lift=0})
add('em_th_machine','trainer_hill',{{0x314},{0x31C}},{{1,15,20,26,true,3,nil,nil,true}},thf,nil,26,nil,{lift=0,maxH=30})

-- Battle Palace lobby: the white sectional sofas (two L groups each side):
-- deep cushions in the two-cell columns, short ones in the third, a 9-row
-- front with the gold feet.
local plf={0x201,0x203,0x207,0x20F,0x216,0x222,0x29E}
for _,r in ipairs({{0x296,0x231,0x2A8},{0x296,0x231,0x2AB}})do
 add('em_palace_sofa_a_'..string.format('%X',r[3]),'battle_palace',{{0x220,0x221,0x203},{0x28E,0x229,0x22A},r},
  {{0,32,30,9,true,1,nil,nil,nil,nil,nil,{8,8}},{32,48,30,9,true,17,nil,nil,nil,nil,nil,{40,24}}},plf,nil,9,nil,{lift=0})
end
for _,r in ipairs({{0x2AA,0x291,0x292},{0x2AD,0x291,0x292}})do
 add('em_palace_sofa_b_'..string.format('%X',r[1]),'battle_palace',{{0x203,0x240,0x241},{0x288,0x289,0x28A},r},
  {{0,16,30,9,true,17,nil,nil,nil,nil,nil,{8,24}},{16,48,30,9,true,1,nil,nil,nil,nil,nil,{24,8}}},plf,nil,9,nil,{lift=0})
end
-- Battle Arena lobby: the wooden desk with its monitor (3x2 from 0x291), the
-- planter cabinets and the long wooden cabinet down the east wall, the PCs
local arf={0x201,0x202,0x203,0x204,0x205,0x20B,0x20A}
add('em_arena_desk','battle_arena',{{0x291,0x292,0x293},{0x299,0x29A,0x29B}},
 {{1,47,18,8,true,1,nil,nil,true},{12,36,15,10,true,7,nil,nil,true,nil,8}},arf,nil,8,nil,{lift=0})
for _,m in ipairs({{0x289,0x2A7},{0x285,0x2A1},{0x289,0x20F}})do
 add('em_arena_cabinet_'..string.format('%X_%X',m[1],m[2]),'battle_arena',{{m[1]},{m[2]}},
  {{1,15,22,10,true,12,nil,nil,true},{2,14,10,8,true,1,nil,'disc',nil,nil,10}},arf,nil,10,nil,{lift=0})
end
for _,mid in ipairs({0x287,0x28D,0x28F,0x286,0x28E,0x297})do
 add('em_arena_long_cabinet_'..string.format('%X',mid),'battle_arena',{{mid}},{{1,15,15,10,true,0,nil,nil,true}},arf,nil,10,nil,{lift=0})
end
add('em_arena_pc','battle_arena',{{0x280},{0x004},{0x290}},
 {{1,15,15,24,true,8,28,nil,true,nil,nil,{8,13}}},arf,nil,24,nil,{lift=0})
add('em_arena_kiosk','battle_arena',{{0x211},{0x219}},{{1,15,15,20,true,4,nil,nil,true}},arf,nil,20,nil,{lift=0})
-- Battle Tower lobby: the yellow-topped counter spines from the wall with
-- the terminal at their foot (4 cells tall)
local btf={0x200,0x201,0x202,0x203,0x204}
for _,c in ipairs({{0x218,0x29D},{0x219,0x221}})do
 add('em_tower_spine_'..string.format('%X',c[2]),'battle_frontier',{{0x210},{0x210},{c[1]},{c[2]}},
  {{1,15,52,6,true,0,nil,nil,true},{2,14,44,14,true,36,nil,nil,true,nil,6}},btf,nil,6,nil,{lift=0})
end
-- Battle Tower battle rooms: the round bins in the corners (lid and body)
for _,m in ipairs({{0x23F,0x247},{0x23F,0x215},{0x27E,0x27F},{0x23E,0x246}})do
 add('em_tower_bin_'..string.format('%X',m[2]),'battle_frontier',{{m[1]},{m[2]}},
  {{2,14,15,16,true,8,nil,'disc',true}},btf,nil,16,nil,{lift=0})
end
-- Exchange Service Corner: the prize display counters against the back wall
for _,r in ipairs({{{0x2FD,0x2FE},{0x305,0x306}},{{0x30B,0x30C},{0x313,0x314}}})do
 add('em_exchange_case_'..string.format('%X',r[1][1]),'battle_frontier',r,
  {{0,32,7,24,true,1,0,nil,true}},btf,nil,24,nil,{lift=0,maxH=28})
end

-- Slateport Pokemon Fan Club (pokemon_fan_club): the record-player cabinets
-- against the back wall (2x2), the tall wood wardrobes (0x21C over 0x224 /
-- 0x225), the potted plants (crown cell over pot cell) and the glass coffee
-- table in front of the sofa.
local fcl={0x201,0x202,0x204,0x205,0x206,0x229,0x231,0x234,0x237}
for _,r in ipairs({{{0x240,0x241},{0x248,0x249}},{{0x242,0x243},{0x24A,0x24B}}})do
 add('em_fanclub_cabinet_'..string.format('%X',r[1][1]),'pokemon_fan_club',r,{{2,30,18,12,true,11,nil,nil,true}},fcl,nil,12,nil,{lift=0})
end
for _,m in ipairs({0x224,0x225})do
 add('em_fanclub_wardrobe_'..string.format('%X',m),'pokemon_fan_club',{{0x21C},{m}},{{1,15,5,23,true,2,0,nil,true}},fcl,nil,23,nil,{lift=0,maxH=30})
end
for _,m in ipairs({{0x244,0x24C},{0x245,0x24D},{0x246,0x24E},{0x247,0x24F}})do
 add('em_fanclub_plant_'..string.format('%X',m[2]),'pokemon_fan_club',{{m[1]},{m[2]}},
  {{3,13,24,6,true,19,nil,'disc'},{1,15,10,9,true,3,nil,'disc',nil,nil,6}},fcl,nil,6)
end
-- the green sofa north of the table (5x2 from 0x250, facing south): its
-- backrest (top rows 9..13, standing 10) behind the seat and arms (top rows
-- 19..26, a 5-row front); the two green armchairs beside the table (one
-- cell over another, facing it): a tall back and the seat between its arms
local fcr={0x229,0x231,0x201,0x202,0x22A,0x232,0x228,0x230}
add('em_fanclub_sofa','pokemon_fan_club',{{0x250,0x251,0x251,0x252,0x253},{0x258,0x259,0x259,0x25A,0x25B}},
 {{0,64,13,10,true,9,nil,nil,true,nil,nil,{20,11}},{0,64,26,5,true,19,nil,nil,true,nil,nil,{20,23}}},fcr,{{0,0},{66,20}},5,nil,{lift=0})
add('em_fanclub_armchair_w','pokemon_fan_club',{{0x22E},{0x236}},
 {{0,7,19,11,true,0,nil,nil,true,nil,nil,{3,10}},{7,16,25,5,true,4,nil,nil,true,nil,nil,{10,14}}},fcr,{{15,14}},5,nil,{lift=0})
add('em_fanclub_armchair_e','pokemon_fan_club',{{0x22D},{0x235}},
 {{9,16,19,11,true,0,nil,nil,true,nil,nil,{12,10}},{0,9,25,5,true,4,nil,nil,true,nil,nil,{5,14}}},fcr,{{0,14}},5,nil,{lift=0})
add('em_fanclub_table','pokemon_fan_club',{{0x260,0x261,0x261,0x262},{0x25C,0x25D,0x25E,0x25F}},{{1,63,24,6,false,0}},fcl,nil,6,nil,{lift=0})
-- Record Corner / 4P Colosseum (cable_club): the big record table (4x3 from
-- 0x2B8): its surface rows 3..21, the 18-row front
add('em_record_table','cable_club',{{0x2B8,0x2B9,0x2BA,0x2BB},{0x2C0,0x2C1,0x2C2,0x2C3},{0x2C8,0x2C9,0x2CA,0x2CB}},
 {{0,64,21,18,true,3,nil,nil,true}},{0x2F6,0x2F7,0x2EE,0x2C4,0x2C6},nil,18,nil,{lift=0,back=true})
-- the four white pod seats round the record table (head cell over seat
-- cell): the cushion seen from above is the top (rows 5..15), the base with
-- its round socket the 15-row front; they stood as flat cards
for _,m in ipairs({{0x2B4,0x2BC},{0x2B5,0x2BD},{0x2B6,0x2BE},{0x2B7,0x2BF}})do
 add('em_record_seat_'..string.format('%X',m[2]),'cable_club',{{m[1]},{m[2]}},{{0,16,15,15,true,5,nil,nil,true,nil,nil,{8,8}}},{0x2C4},{{0,0},{15,0},{0,31},{15,31}},15,nil,{lift=0})
end
-- Hall of Fame (cable_club): the record machine (3x3 from 0x2E9) with its
-- screen the 29-row face and depth, and the two lamp posts either side
add('em_hof_machine','cable_club',{{0x2E9,0x2EA,0x2F0},{0x2F1,0x2F2,0x2F3},{0x2F9,0x2FA,0x2FB}},
 {{8,40,10,29,true,8,24,nil,true},{2,8,22,10,true,17,nil,nil,true},{40,46,22,10,true,17,nil,nil,true}},{0x2F6},nil,29,nil,{lift=0,maxH=32})

-- Audit pass 3: the remaining small pieces, one block each.
local function block(name,sec,rows,parts,ground,h,o)
 add(name,sec,rows,parts,ground,nil,h,nil,o or {lift=0})
end
-- Lanette's crates (lab)
local lbf={0x202,0x228,0x229,0x232,0x234,0x220}
block('em_lan_crate_221','lab',{{0x221}},{{1,15,8,9,true,0,nil,nil,true}},lbf,9)
block('em_lan_crate_231','lab',{{0x231}},{{1,15,8,9,true,0,nil,nil,true}},lbf,9)
block('em_lan_crates_23A','lab',{{0x23A},{0x242}},{{1,15,15,16,true,0,nil,nil,true}},lbf,16)
add('em_lab_flat_292','lab',{{0x292}},{{0,16,12,0}},{0x202},nil,0)
-- Battle Pyramid lobby: fire baskets on their stands and the PC
local pyf={0x20B,0x201,0x223,0x21F,0x20D}
for _,mid in ipairs({0x20C,0x216})do
 block('em_pyramid_fire_'..string.format('%X',mid),'battle_pyramid',{{mid}},{{2,14,7,10,true,0,nil,'disc',true}},pyf,10)
end
-- Battle Pyramid lobby. Its upper floor's front wall is Opus's (the cells
-- above these are wall faces closed to furniture), so each piece is anchored
-- on its floor cell and reads the rest of its drawing from the cells above
-- (negative rows), standing against the wall's foot.
-- the PC (0x22E; drawn up over 0x226/0x21E): top rows -24..-21, a 27-row face
add('em_pyramid_lobby_pc','battle_pyramid',{{0x22E}},{{0,16,-21,27,true,-24,0,nil,true}},{0x20B},nil,27,nil,{lift=0})
-- the record kiosk (0x2D8; screen drawn over 0x2D0/0x2C8): the screen a 4 px
-- slab on its stand (base 6), the stem and the round foot on the floor
add('em_pyramid_kiosk','battle_pyramid',{{0x2D8}},
 {{0,16,-21,20,true,-20,-4,nil,true,nil,6},{6,10,2,6,true,1,nil,nil,true},{4,12,6,1,true,3,nil,'disc',true}},{0x20B},nil,20,nil,{lift=0})
-- the rules board on its two feet (0x2DA 0x2DB 0x2DC; drawn up over the row
-- above): a 2 px card
add('em_pyramid_board','battle_pyramid',{{0x2DA,0x2DB,0x2DC}},
 {{9,39,-16,19,true,-15,2,'card',nil,nil,2},{18,30,7,2,true,4}},{0x20B},nil,19,nil,{lift=0})
-- Battle Pike: two more armchair pairings
for _,m in ipairs({{0x225,0x22C},{0x2DB,0x22C}})do   -- 0x2DB is a backrest, never a seat
 add('em_pike_armchair_'..string.format('%X_%X',m[1],m[2]),'battle_pike',{{m[1]},{m[2]}},
  {{1,15,21,6,true,18},{2,14,1,16,true,1}},{0x2C1,0x2D9,0x2DA,0x2DE,0x2E0,0x2E3,0x2E6,0x340,0x358,0x2C2,0x2D4},nil,6,nil,{lift=0})
end
-- Ranking Hall: the green armchairs (one cell over another, facing south):
-- the back cushion (top row 6, face rows 7..22, 16 tall) stands behind the
-- seat (top rows 15..22, face 23..30 with the feet, 8 tall).
for _,m in ipairs({{0x22B,0x233},{0x241,0x249},{0x246,0x24E},{0x22C,0x234},{0x22D,0x235},{0x22E,0x236},{0x22F,0x237},{0x23B,0x243}})do
 add('em_ranking_chair_'..string.format('%X',m[2]),'battle_frontier_ranking_hall',{{m[1]},{m[2]}},
  {{0,16,22,8,true,15},{1,15,6,16,true,6}},{0x202,0x203,0x204,0x205,0x20A,0x20B,0x20C,0x20D},nil,8,nil,{lift=0})
end
-- Ranking Hall: the kiosk and the big record display (3x3 from 0x24B)
local rkf={0x202,0x203,0x204,0x20C}
block('em_ranking_kiosk','battle_frontier_ranking_hall',{{0x207},{0x20F}},{{2,14,10,16,true,0,nil,nil,true}},rkf,16)
block('em_ranking_display','battle_frontier_ranking_hall',{{0x24B,0x24C,0x24D},{0x253,0x254,0x255},{0x25B,0x25C,0x25D}},
 {{4,44,10,24,true,2,20,nil,true}},rkf,24,{lift=0,maxH=30})
-- Seashore House stool, Battle Tent PC, Fortree Gym bush, Devon 3F display
block('em_seashore_stool','seashore_house',{{0x227}},{{3,13,8,8,true,0,nil,'disc'}},{0x22C,0x212,0x21E},8)
block('em_tent_pc','battle_tent',{{0x216},{0x21E}},{{1,15,12,20,true,0,nil,nil,true}},{0x210,0x211,0x209,0x208,0x277,0x21F},20)
add('em_fortree_bush_23C','fortree_gym',{{0x23C}},{{0,16,12,13,true,1,nil,'disc'}},{0x202,0x201},nil,13)
block('em_devon_display','facility',{{0x2E5}},{{2,14,12,16,true,0,nil,nil,true}},{0x2DD,0x380,0x381},16)
-- Contest Hall: the potted greens on the round pedestal table (0x24A over
-- 0x252), built piece by piece so nothing floats: the pedestal and foot
-- (7 px), the round table top on it, the white vase on the table and the
-- leaves on the vase. (Not named 'plant': the plant helper would reseat it.)
add('em_contest_stand_greens','contest',{{0x24A},{0x252}},
 {{5,11,23,7,true,18,nil,true},{0,16,21,2,true,15,nil,'disc',nil,nil,7},
  {5,11,13,5,true,12,nil,true,nil,nil,9},{0,16,5,6,true,0,nil,'disc',nil,nil,14}},{0x260},nil,7,nil,{lift=0})
-- the orange audience sofas (one cell over another, seen side-on): a tall
-- back cushion on the outer side (top rows 1..18, a 10-row face) and the two
-- seat cushions (top rows 6..24, a 4-row front); 0x249/0x251 is the mirror
add('em_contest_seat_w','contest',{{0x248},{0x250}},
 {{0,7,18,10,true,1,nil,nil,nil,nil,nil,{3,5}},{6,15,24,4,true,6,nil,nil,nil,nil,nil,{9,10}}},{0x260},{{15,16},{15,25},{0,28},{0,31}},4,nil,{lift=0})
add('em_contest_seat_e','contest',{{0x249},{0x251}},
 {{9,16,18,10,true,1,nil,nil,nil,nil,nil,{12,5}},{1,10,24,4,true,6,nil,nil,nil,nil,nil,{6,10}}},{0x260},{{0,16},{0,25},{15,28},{15,31}},4,nil,{lift=0})
-- Mauville Gym: the north-south electric bolt (0x248, drawn top-down as a
-- zigzag between the pylon at (6,8) and the one below): the drawing itself
-- hovers as a 1-px zigzag strand (non-solid slab, base 8) at the height of
-- Opus's em_mauville_lightning beams, in its own bright pixels; the floor
-- round it flat. The white cap 0x250 is the lower pylon's top.
add('em_mauvgym_bolt_248','mauville_gym',{{0x248}},{{0,16,15,1,false,0,nil,nil,nil,nil,8,{7,0}}},{0x20A,0x232,0x233},nil,1,nil,{lift=0,maxH=1})
block('em_mauvgym_pylon_250','mauville_gym',{{0x250}},{{5,11,10,14,true,0,nil,'disc',true}},{0x20A,0x232,0x233,0x218},14)
-- Mauville Game Corner: the slot machines by the west wall, the bins
local mgf={0x203,0x204,0x205,0x202,0x215}
block('em_mgc_slots_w','mauville_game_corner',{{0x20E,0x20F},{0x216,0x217}},{{0,32,10,20,true,0,nil,nil,true}},mgf,20)
for _,mid in ipairs({0x22E,0x236})do
 block('em_mgc_bin_'..string.format('%X',mid),'mauville_game_corner',{{mid}},{{3,13,9,9,true,0,nil,'disc',true}},mgf,9)
end
-- the prize counter (7x3 from 0x24C): a white U whose arms run back to the
-- shelf (tops from the cell above, rows -6..26) and whose front (top rows
-- 14..26) closes it; 12-row blue faces; the clerks' pink floor inside stays
-- floor
add('em_mgc_prize_counter','mauville_game_corner',
 {{0x24C,0x243,0x24D,0x24E,0x24D,0x24D,0x24F},{0x254,0x256,0x255,0x256,0x255,0x255,0x257},{0x25C,0x25D,0x25E,0x25E,0x25E,0x25D,0x25F}},
 {{0,16,26,12,true,-6,nil,nil,true},{96,112,26,12,true,-6,nil,nil,true},{16,96,26,12,true,14,nil,nil,true}},
 {0x203,0x204,0x205,0x202,0x215,0x243},nil,12,nil,{lift=0})
-- Mossdeep Game Corner: the bench backrests along the back wall
for mid=0x21B,0x21E do
 block('em_mossgc_backrest_'..string.format('%X',mid),'mossdeep_game_corner',{{mid}},{{0,16,3,12,true,0,nil,nil,true}},{0x20A,0x209,0x223,0x224,0x225,0x226},12)
end
-- Day Care: the cushioned chair behind the counter window
block('em_daycare_chair','pokemon_day_care',{{0x234}},{{2,14,9,8,true,0,nil,nil,true}},{0x207,0x21B},8)
-- the unused Pretty Petal prototype: flower shelf and register
block('em_petal_proto_shelf','pretty_petal_flower_shop',{{0x223,0x224},{0x22B,0x22C}},{{2,30,20,14,true,4,nil,nil,true}},{0x203,0x21F},14)
block('em_petal_proto_register','pretty_petal_flower_shop',{{0x21C},{0x22F}},{{2,14,20,10,true,10,nil,nil,true}},{0x237,0x220,0x226},10)
-- Mystery Events house: the potted plants (their crowns are drawn over the
-- doorway and wall: those colours are sampled out, so no wall rides along)
for _,m in ipairs({{0x240,0x21B,{{0,0},{12,0},{0,9}}},{0x241,0x21B,{{0,0},{15,6}}},{0x242,0x21B,{{0,0},{4,0},{5,0}}},
                   {0x213,0x21B,{{0,0},{2,5},{0,9},{0,15}}},{0x218,0x21B,{{0,0},{2,0}}},{0x223,0x21A,{}}})do
 add('em_mev_plant_'..string.format('%X_%X',m[1],m[2]),'mystery_events_house',{{m[1]},{m[2]}},
  {{3,13,28,6,true,21,nil,'disc'},{1,15,14,10,true,4,nil,'disc',nil,nil,6}},{0x235,0x236},m[3],6)
end

-- Day Care: the low picket fence by the yard door. The run along the yard
-- (0x241, and the corner 0x240) is drawn face-on: a thin card, so the gaps
-- between the pickets stay open; the short run back towards the wall (0x243
-- and the corner's west strip) is a narrow rail seen from above.
local dcf={0x201,0x204,0x207}
add('em_daycare_fence','pokemon_day_care',{{0x241}},{{0,16,0,15,true,0,3,'card'}},dcf,nil,15,nil,{lift=0,maxH=15})
add('em_daycare_fence_corner','pokemon_day_care',{{0x240}},{{8,16,0,15,true,0,3,'card'},{0,8,15,10,true,0,nil,nil,true}},dcf,nil,15,nil,{lift=0,maxH=15})
add('em_daycare_fence_side','pokemon_day_care',{{0x243}},{{1,7,15,10,true,0,nil,nil,true}},dcf,nil,10,nil,{lift=0})

-- Secret bases (the user, 2026-10-11): the decorations the player places are
-- map tiles (0x200 + the decoration's tile) in each of the six base tilesets,
-- the same drawing in every one over that base's own floor (0x20A). First
-- batch: the desks, chairs, bricks, the tire, the TVs, the tents, the laptop.
for _,sb in ipairs({'red_cave','brown_cave','blue_cave','yellow_cave','tree','shrub'})do
 local sec='secret_base_'..sb
 local G={0x20A}
 local function D(name,rows,parts,h,o)
  o=o or {};o.primary='secret_base';if o.lift==nil then o.lift=0 end
  add('em_sb_'..name..'_'..sb,sec,rows,parts,G,nil,h,nil,o)
 end
 -- the base's own laptop: keyboard deck with the screen standing at its back
 D('laptop',{{0x220}},{{1,15,11,3,true,6},{2,14,5,7,true,1,nil,nil,nil,nil,3}},3,{back=false})
 -- desks: the top seen from above, a low front; open ones stand on legs
 D('small_desk',{{0x287}},{{0,16,10,4,false,0}},4)
 D('ball_desk',{{0x28F}},{{0,16,9,5,true,0,nil,'disc'}},5)
 D('heavy_desk',{{0x290,0x291,0x292},{0x298,0x299,0x29A}},{{0,48,21,9,false,0}},9)
 D('ragged_desk',{{0x293,0x294,0x295},{0x29B,0x29C,0x29D}},{{0,48,22,7,true,0}},7)
 D('comfort_desk',{{0x296,0x297,0x2A3},{0x29E,0x29F,0x2AB}},{{0,48,24,6,false,0}},6)
 D('pretty_desk',{{0x2BD,0x2BE,0x2BF},{0x2C5,0x2C6,0x2C7},{0x2CD,0x2CE,0x2CF}},{{0,48,41,5,false,0}},5)
 D('brick_desk',{{0x2A0,0x2A1,0x2A2},{0x2A8,0x2A9,0x2AA},{0x2B0,0x2B1,0x2B2}},{{0,48,39,7,true,0}},7)
 D('camp_desk',{{0x2A4,0x2A5,0x2A6},{0x2AC,0x2AD,0x2AE},{0x2B4,0x2B5,0x2B6}},{{0,48,39,7,false,0}},7)
 D('hard_desk',{{0x2A7,0x2BB,0x2BC},{0x2AF,0x2C3,0x2C4},{0x2B7,0x2CB,0x2CC}},{{0,48,38,8,true,0}},8)
 -- chairs: stools on legs; the log and the rock are solid rounds
 for _,m in ipairs({0x2B8,0x2B9,0x2BA,0x2C0,0x2C1,0x2C2,0x2C8})do
  D('chair_'..string.format('%X',m),{{m}},{{2,14,9,5,false,1}},5)
 end
 D('log_chair',{{0x2C9}},{{2,14,8,6,true,1,nil,'disc'}},6)
 D('rock_chair',{{0x2CA}},{{2,14,8,6,true,1,nil,'disc'}},6)
 -- bricks: a tall block, its top the upper cell
 for _,m in ipairs({{0x225,0x22D},{0x226,0x22E},{0x227,0x22F}})do
  D('brick_'..string.format('%X',m[1]),{{m[1]},{m[2]}},{{0,16,19,12,true,0}},12,{back=true})
 end
 -- the tire lying flat: a thick disc
 D('tire',{{0x280,0x281},{0x288,0x289}},{{0,32,17,13,true,0,nil,'disc'}},13)
 -- TVs are tube sets: near-cube deep
 for _,m in ipairs({0x2F4,0x2F5,0x2F6})do
  D('tv_'..string.format('%X',m),{{m}},{{1,15,5,10,true,1,nil,nil,nil,nil,nil,nil,true}},10,{back=false})
 end
 -- tents: the player walks in at the door and out at the back, so a tent is
 -- two side walls with the roof spanning the open middle (the door's lintel its front edge)
 D('red_tent',{{0x230,0x231,0x232},{0x238,0x239,0x23A},{0x240,0x241,0x23B}},{{0,17,31,16,true,0,nil,true,nil,nil,nil,{3,40},true},{31,48,31,16,true,0,nil,true,nil,nil,nil,{44,40},true},{17,31,31,3,true,0,nil,nil,nil,nil,13}},16,{back=false})
 D('blue_tent',{{0x248,0x249,0x268},{0x250,0x251,0x270},{0x258,0x259,0x269}},{{0,17,31,16,true,0,nil,true,nil,nil,nil,{3,40},true},{31,48,31,16,true,0,nil,true,nil,nil,nil,{44,40},true},{17,31,31,3,true,0,nil,nil,nil,nil,13}},16,{back=false})
 -- potted plants: the pot a low round, the leaves a round crown seated on it
 for _,m in ipairs({{0x2D0,0x2D8},{0x2D2,0x2DA},{0x2D4,0x2DC}})do
  D('plant_'..string.format('%X',m[1]),{{m[1]},{m[2]}},{{3,13,27,4,true,22,nil,'disc'},{0,16,8,7,true,1,nil,'disc',nil,nil,4}},4)
 end
 for _,m in ipairs({{0x2E4,0x2E6,0x2EC,0x2ED},{0x2F0,0x2F2,0x2F8,0x2F9}})do
  D('bigplant_'..string.format('%X',m[1]),{{m[1],m[2]},{m[3],m[4]}},{{8,24,27,4,true,23,nil,'disc'},{0,32,12,9,true,1,nil,'disc',nil,nil,4}},4)
 end
 D('flowerbed',{{0x2E0,0x2E2},{0x2E8,0x2E9}},{{0,32,25,4,true,19,nil,'disc'},{2,30,11,7,true,3,nil,'disc',nil,nil,4}},4)
 -- balloons and the mud ball: real balls resting on the floor
 for _,m in ipairs({0x338,0x33C,0x340})do
  D('balloon_'..string.format('%X',m),{{m}},{{3,13,12,0,true,2,nil,'ball'}},10)
 end
 D('mudball',{{0x228}},{{3,13,12,0,true,4,nil,'ball'}},9)
 -- the base's own boulder / bush on the floor: a low round lump
 D('lump',{{0x20E}},{{1,15,10,5,true,5,nil,'disc'}},5)
 -- fences: the length runs north-south (a post seen end on), the width east-west
 D('fence_ns',{{0x233}},{{4,12,7,8,true,0}},8,{back=true})
 D('fence_ew',{{0x22C}},{{1,15,7,6,true,2,5,nil}},6,{back=true})
 -- the breakable door stands upright: a thin slab across the cell
 D('door',{{0x237},{0x23F}},{{0,16,4,27,true,5,24,'card'}},27)
 -- ornaments on their plinths: the sand tower (a block), the shields on a
 -- chest, the glass statue
 D('sand',{{0x285},{0x28D}},{{0,16,15,16,true,0,nil,true}},16,{back=true})
 for _,m in ipairs({{0x2D6,0x2DE},{0x32E,0x336}})do
  D('shield_'..string.format('%X',m[1]),{{m[1]},{m[2]}},{{0,16,21,10,true,16},{3,13,9,7,true,10,12,'card',nil,nil,10}},10,{back=true})
 end
 D('glass',{{0x282},{0x28A}},{{0,16,23,8,true,19},{2,16,0,19,true,1,14,'card',nil,nil,8}},8,{back=true})
end

return R
