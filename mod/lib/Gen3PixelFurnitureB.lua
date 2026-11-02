-- Pixel-voxel furniture recipes, second author
local R={}
local BACK_YES={'crate','box','load','bucket','bin','seat','chair','stool','sofa','bench','cushion','cot','bed',
 'stand','pedestal','planter','plant','pot','potbush','basket','statue','bust','grave','table','tablet','stump','log','trunk',
 'pillar','post','pole','cube','capsule','cooler','pylon','backrest','bush','beacon','benche','wide'}
local BACK_NO={'cabinet','counter','desk','pc','tv','shelf','machine','console','kiosk','fridge','sink','board',
 'display','screen','monitor','register','rack','wardrobe','drawer','server','engine','generator','vending','slot',
 'roulette','gate','partition','fence','rail','railflag','flag','umbrella','kitchen','stove','laptop','appliance','case','showcase'}
local function add(...)
 local a={...}
 if a[1]:find('plant') and not a[1]:find('planter') then
  a[9]=a[9] or {};a[9].lift=0
  local pot,leaves
  for _,pt in ipairs(a[4])do if pt[11] then leaves=pt else pot=pt end end
  if pot and leaves then
   local L0,L1=leaves[6],leaves[3]+leaves[4]
   local n=math.floor((L1-L0+1)/2) -- half the rows deep, half tall
   local c=(pot[6]+pot[3])/2+pot[4] -- the pot's middle (depth)
   local F=math.floor(c+.5)
   if a[9].crownCentre then F=math.floor(c+n/2+.5) end
   leaves[3]=L0+n-1;leaves[4]=L1-leaves[3];leaves[11]=math.max(pot[4]+1,F-1-L1)
   local cx=math.floor((pot[1]+pot[2])/2)
   a[4][#a[4]+1]={cx-2,cx+2,L1,leaves[11]-pot[4],true,L1-3,nil,'disc',nil,nil,pot[4]}
  end
 end
 local back=a[9] and a[9].back
 if back==nil then
  local yes,no=false,false
  for tok in a[1]:gsub('^em_gate_','em_'):gmatch('[^_]+')do -- em_gate_*: the Reception Gate's pieces, not gates
   tok=tok:gsub('%d+$',''):gsub('s$','')
   for _,w in ipairs(BACK_NO)do if tok:sub(-#w)==w then no=true end end
   for _,w in ipairs(BACK_YES)do if tok:sub(-#w)==w then yes=true end end
  end
  back=yes and not no
 end
 if back then for _,pt in ipairs(a[4])do
  if pt[5]==true and (not pt[8] or pt[8]==true) and pt[14]==nil then -- plain and round=true parts (not disc/card/ball)
   pt[14]=true
  end
 end end
 R[#R+1]=a
 if a[2]=='facility' then
  local b={};for i=1,9 do b[i]=a[i] end
  b[1]=a[1]..'_g';local o={};for k,v in pairs(a[9] or {})do o[k]=v end;o.primary='general';b[9]=o
  R[#R+1]=b
 end
end

for _,m in ipairs({{0x20C,0x214},{0x20D,0x215}})do
 add('em_school_desk_'..string.format('%X',m[1]),'pokemon_school',{{m[1]},{m[2]}},
  {{0,16,9,7,true},{3,13,19,4,false,13}},{0x201},{{0,17},{2,18}},7)
end
add('em_school_desk_20E','pokemon_school',{{0x20E},{0x216}},
 {{0,16,9,7,true},{2,6,16,4,false,13},{6,9,19,4,false,13},{9,14,17,4,false,12}},{0x201},{{0,17},{2,21}},7)
add('em_school_blackboard','pokemon_school',{{0x228,0x229,0x22A,0x22B},{0x230,0x231,0x232,0x233}},
 {{0,64,19,12,true,18,nil,nil,true},{0,64,-1,18,true,0,16,nil,true,nil,12}},{0x201,0x221},nil,12,nil,{lift=0})
add('em_school_teacher_desk','pokemon_school',{{0x21C,0x21D},{0x224,0x225}},
 {{0,32,22,8,true}},{0x201,0x221},{{2,8}},8)

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

add('em_fortree_platform','fortree_gym',{{0x21B,0x21C,0x21D,0x21E,0x21F},{0x240,0x241,0x242,0x243,0x244}},
 {{1,3,23,4,true},{3,5,23,5,true},{5,7,23,6,true},{7,16,23,7,true},{16,63,23,8,true},
  {63,73,23,7,true},{73,75,23,6,true},{75,77,23,5,true},{77,79,23,4,true}},{0x202},{{0,7}},8,nil,{dais=true})

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

add('em_center_pc','pokemon_center',{{0x20C},{0x004},{0x224}},
 {{1,15,15,24,true,8,28,nil,true,nil,nil,{8,13}}},{0x202},{{1,42}},24,32,{lift=0})
add('em_center_laptop','pokemon_center',{{0x004},{0x2B6}},
 {{0,16,15,5,true,9},{0,16,-1,9,true,0,nil,'card',nil,nil,5}},{0x202},nil,14)
add('em_center_bookshelf','pokemon_center',{{0x271,0x272},{0x279,0x27A}},{{0,32,8,15,true}},{0x202},{{2,25}},15)

add('em_center_desk','pokemon_center',{{0x250,0x22A,0x22B,0x207,0x25B,0x251},{0x258,0x221,0x221,0x205,0x221,0x259}},
 {{1,16,20,11,true,-7,nil,nil,true},{80,95,20,11,true,-7,nil,nil,true},{1,95,20,11,true,13,nil,nil,true},
  {17,47,6,8,true,-14,nil,nil,true},{65,79,-4,16,true,-7},
  {3,14,20,0,true,8,nil,'ball',true,nil,11},{82,93,20,0,true,8,nil,'ball',true,nil,11}},{0x202},nil,11,nil,{lift=0})

add('em_center_plant','pokemon_center',{{0x211},{0x219}},
 {{3,13,16,6,true,11,nil,'disc'},{0,16,2,11,true,0,nil,'disc',nil,nil,6}},{0x202},{{0,0},{0,8},{0,15},{0,16}},6)

add('em_center_plant_2f','pokemon_center',{{0x25E},{0x266}},
 {{3,13,24,6,true,19,nil,'disc'},{0,16,7,11,true,3,nil,'disc',nil,nil,6}},{0x202},{{1,26}},6)

add('em_center_plant_wall_e','pokemon_center',{{0x20A},{0x212}},
 {{3,13,24,6,true,19,nil,'disc'},{0,13,7,11,true,3,nil,'disc',nil,nil,6}},{0x202,0x240},{{15,0},{1,26}},6)

for _,mid in ipairs({0x2D6,0x2E0,0x2D7,0x2D5})do
 add('em_center_2f_counter_'..string.format('%X',mid),'pokemon_center',{{mid}},
  {{0,16,8,7,true,-4,nil,nil,true,12}},{0x202},nil,7)
end

add('em_center_2f_gate','pokemon_center',{{0x25D}},{{0,16,8,7,true,-4,nil,nil,true,12,nil,{6,6}}},{0x202},nil,7)

for _,m in ipairs({{0x2DB,0x2E3},{0x2DA,0x2E2}})do
 add('em_center_link_'..string.format('%X',m[1]),'pokemon_center',{{m[1]},{m[2]}},
  {{2,14,24,6,true,23},{1,15,11,11,true,8,nil,nil,nil,nil,6}},{0x202},{{0,31}},6,nil,{lift=0})
end

-- 0x23C on its own (Center 2F, beside a link machine) is only floor shadow.
add('em_center_flat_23C','pokemon_center',{{0x23C}},{{0,16,15,0}},{0x202},nil,0)

add('em_center_floor_marks','pokemon_center',{{0x23C},{0x225}},{{0,16,22,0}},{0x202},nil,0)

for _,b in ipairs({0x230,0x221})do
 add('em_mart_wall_shelf_'..string.format('%X',b),'shop',{{0x223,0x224},{0x228,0x229},{b,0x231}},
  {{0,32,17,22,true,15,nil,nil,nil,38}},{0x201},nil,22)
end

add('em_mart_counter_arm','shop',{{0x22A},{0x232},{0x23A},{0x242}},{{0,16,54,8,true,8,nil,nil,true,58,nil,{1,9}}},{0x201},nil,8)
add('em_mart_counter_front','shop',{{0x320,0x241}},{{0,32,6,8,true,-3,nil,nil,true,10,nil,{1,2}}},{0x201},nil,8)
for _,c in ipairs({{0x22B,0x233,0x23B},{0x22C,0x234,0x23C},{0x2AA,0x233,0x2B2},{0x2AB,0x234,0x2B3}})do
 add('em_mart_rack_'..string.format('%X',c[1]),'shop',{{c[1]},{c[2]},{c[3]}},
  {{0,16,3,36,true,0,nil,nil,nil,nil,nil,{2,15}},{0,16,17,26,true,14,nil,nil,nil,nil,nil,{2,15}},{0,16,31,16,true,28,nil,nil,nil,nil,nil,{2,15}}},{0x201},nil,16,nil,{lift=0})
end

add('em_mart_plant','shop',{{0x225},{0x22D}},
 {{2,14,23,7,true,17,nil,'disc'},{0,16,4,12,true,0,nil,'disc',nil,nil,7}},{0x201},{{0,0},{2,0},{0,3}},7)

add('em_generic_plant','generic_building',{{0x222},{0x22A}},
 {{2,14,24,7,true,18,nil,'disc'},{0,16,4,13,true,1,nil,'disc',nil,nil,7}},{0x223},nil,7)
add('em_generic_plant_wall','generic_building',{{0x290},{0x298}},
 {{2,14,24,7,true,18,nil,'disc'},{0,16,4,13,true,1,nil,'disc',nil,nil,7}},{0x223},{{0,0},{0,20}},7)
add('em_generic_plant_291','generic_building',{{0x291},{0x299}},
 {{2,14,24,7,true,18,nil,'disc'},{0,16,4,13,true,1,nil,'disc',nil,nil,7}},{0x223},nil,7)
add('em_generic_tv','generic_building',{{0x230},{0x21E},{0x238}},
 {{0,16,31,8,true,30},{0,16,15,14,true,13,17,nil,nil,nil,8}},{0x224,0x223},{{0,8}},8)
add('em_generic_sink_stove','generic_building',{{0x26C,0x26D},{0x274,0x275}},
 {{0,32,16,7,true,5,nil,nil,nil,22}},{0x224,0x223},nil,7)

for _,mid in ipairs({0x246,0x247,0x24E,0x240,0x218,0x243})do
 add('em_mauville_post_'..string.format('%X',mid),'mauville_gym',{{mid}},
  {{0,16,-4,18,true,-9,nil,'disc',nil,2}},{0x20A,0x209},mid==0x240 and {{7,0}} or nil,18)
end
add('em_rustboro_platform','rustboro_gym',{{0x208,0x209,0x20A,0x20B,0x20C},{0x210,0x211,0x212,0x213,0x214}},
 {{0,80,23,8,true,0,nil,nil,true}},{0x201,0x202,0x203,0x204},nil,8,nil,{dais=true,lift=0})
add('em_mauville_stage','mauville_gym',{{0x224,0x225,0x226,0x227},{0x22C,0x22D,0x22E,0x22F}},
 {{1,63,23,7,true,0}},{0x20A},nil,7,nil,{dais=true})

add('em_petalburg_platform','petalburg_gym',{{0x233,0x234,0x235,0x236,0x237},{0x23B,0x23C,0x23D,0x23E,0x23F}},
 {{1,80,23,7,true,1,nil,nil,true},{16,65,25,6,true,24,nil,nil,true},{16,65,29,2,true,28,nil,nil,true}},
 {0x201},nil,7,nil,{dais=true})

add('em_mossdeep_stage','mossdeep_gym',{{0x218,0x219,0x21A,0x21B},{0x220,0x221,0x222,0x223}},
 {{0,64,23,6,true,0},{16,48,27,4,true,26}},{0x20A},nil,6,nil,{dais=true})

add('em_sootopolis_platform','sootopolis_gym',{{0x231,0x22A,0x22B,0x22C,0x236},{0x204,0x232,0x233,0x234,0x205}},
 {{1,79,25,6,true,1,nil,nil,true}},{0x23E},nil,6,nil,{dais=true})
add('em_sootopolis_fountain','sootopolis_gym',{{0x268,0x269},{0x270,0x271},{0x278,0x279}},
 {{2,30,10,21,true,8,nil,nil,true},{3,29,42,3,true,32,nil,nil,true}},{0x23E},nil,3)

add('em_dewford_ring','dewford_gym',{{0x232,0x233,0x234,0x235},{0x210,0x210,0x210,0x210}},
 {{1,63,24,7,true,0},{1,6,1,6,true,0,nil,nil,nil,nil,7},{58,63,1,6,true,0,nil,nil,nil,nil,7}},
 {0x201,0x210},nil,7,nil,{dais=true})
add('em_dewford_speaker','dewford_gym',{{0x22E},{0x236}},{{0,16,7,24,true,0,nil,nil,nil,27}},{0x201,0x210},nil,24)

add('em_lavaridge_platform','lavaridge_gym',{{0x218,0x219,0x21A,0x21B,0x21C},{0x220,0x221,0x222,0x223,0x224}},
 {{1,16,23,6,true,2},{64,79,23,6,true,2},{16,64,23,8,true,2}},{0x208,0x209},{{0,31}},8,nil,{dais=true})

local tentFloor={0x210,0x211,0x209,0x208}
add('em_tent_counter_left','battle_tent',
 {{0x268,0x269,0x209,0x208},{0x270,0x209,0x210,0x211},{0x278,0x279,0x27A,0x27B},{0x280,0x281,0x282,0x283},{0x288,0x289,0x28A,0x28B}},
 {{1,6,50,6,true,0},{6,12,53,6,true,0},{12,24,56,6,true,0},{15,32,15,6,true,9},{24,56,56,6,true,0},{24,56,69,2,true,63,nil,nil,true},{56,64,56,6,true,44}},
 tentFloor,nil,6)
add('em_tent_counter_right','battle_tent',
 {{0x208,0x209,0x26E,0x26F},{0x211,0x210,0x209,0x277},{0x27C,0x27D,0x27E,0x27F},{0x284,0x285,0x286,0x287}},
 {{0,48,57,5,true,45},{48,54,57,5,true,0},{54,60,53,5,true,0},{60,64,50,5,true,0}},
 tentFloor,nil,5)

add('em_store_counter','shop',
 {{0x2DD,0x29B,0x29B,0x29B,0x29B,0x2DD},{0x29E,0x2A3,0x2A3,0x2A3,0x2A3,0x29E},{0x2A4,0x20B,0x208,0x208,0x208,0x29E},{0x2DE,0x206,0x201,0x201,0x201,0x2D1}},
 {{16,80,21,10,true,12},{0,16,53,10,true,12,nil,nil,true},{80,96,53,10,true,12,nil,nil,true}},
 {0x201,0x208,0x206},nil,10)
add('em_store_case_arm','shop',{{0x306},{0x29E},{0x29E},{0x2D1}},{{0,16,53,9,true,12,nil,nil,true}},{0x2F2,0x2F4,0x2F7,0x2F3,0x2FA,0x2FD},nil,9,nil,{lift=0})
add('em_store_case','shop',{{0x2F7},{0x2A3}},{{0,16,22,9,true,13,nil,nil,true}},{0x2F2,0x2F4,0x2F3,0x2FA,0x2FD},nil,9,nil,{lift=0})
add('em_store_plant','shop',{{0x26D},{0x275}},
 {{3,13,24,6,true,19,nil,'disc'},{0,16,8,10,true,3,nil,'disc',nil,nil,6}},{0x201},{{0,3},{0,12},{15,12}},6)
add('em_store_reception','shop',
 {{0x29C,0x290,0x290,0x290,0x290,0x29D},{0x2A4,0x2D4,0x298,0x299,0x298,0x2A5},{0x2AC,0x2A1,0x2A0,0x2A1,0x2A0,0x2AD}},
 {{16,80,12,3,true,8},{0,16,39,7,true,8},{80,96,39,7,true,8},{0,96,39,7,true,28}},{0x268,0x270},nil,7)
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
for _,lo in ipairs({0x264,0x274})do
 add('em_safari_plant_'..string.format('%X',lo),'shop',{{0x25C},{lo}},
  {{3,13,24,6,true,19,nil,'disc'},{0,16,7,11,true,3,nil,'disc',nil,nil,6}},{0x268,0x270,0x280,0x278},
  {{0,0},{15,0},{3,0},{1,1},{13,0},{15,16},{0,31},{15,31}},6)
end
local rtf={0x24A,0x24D,0x25B}
add('em_roof_vending','shop',{{0x26F},{0x277}},{{1,15,9,21,true,1,nil,nil,true}},{0x24A,0x253,0x281},nil,21,nil,{lift=0})
-- Department Store 1F: the round red-checked stools by the counter (0x26E)
add('em_store_stool','shop',{{0x26E}},{{2,14,9,5,true,0,nil,'disc',true}},{0x268,0x270},{{0,0}},5,nil,{lift=0})
add('em_roof_planter','shop',{{0x2C9,0x2CA},{0x2CB,0x2CC}},{{0,31,22,7,true,9,nil,nil,true}},rtf,{{0,0},{8,0},{12,0},{3,4}},7,nil,{lift=0})
add('em_roof_bench','shop',{{0x2C1,0x2C2}},{{1,31,10,5,true,3,nil,nil,true}},rtf,{{0,0},{12,0}},5,nil,{lift=0})
add('em_roof_chair','shop',{{0x2C0}},{{11,15,11,9,true,1,nil,nil,nil,nil,nil,{12,6}},{1,12,11,4,true,4,nil,nil,nil,nil,nil,{6,7}}},rtf,{{0,0},{4,0}},4,nil,{lift=0})
-- 1F plants on the orange floor (0x26C over 0x274).
add('em_store_plant_1f','shop',{{0x26C},{0x274}},
 {{3,13,24,6,true,19,nil,'disc'},{0,16,8,10,true,3,nil,'disc',nil,nil,6}},{0x268,0x270},{{0,0}},6)
add('em_store_produce_table','shop',{{0x2DF,0x267},{0x261,0x262}},{{0,31,22,9,false,9}},{0x268,0x270},nil,9)

add('em_contest_counter','contest',
 {{0x2D0,0x2D1,0x29E,0x2D7,0x2D7,0x2AE,0x2D1,0x2E0},{0x2D8,0x2D9,0x2A6,0x2DF,0x2DF,0x2B6,0x2D9,0x2E8}},
 {{0,16,20,10,true,0},{112,128,20,10,true,0},{16,112,3,1,true,0},{32,96,20,10,true,12},
  {16,32,20,10,false,12},{96,112,20,10,false,12}},{0x260,0x221},nil,10)
add('em_contest_sofa_left','contest',{{0x238},{0x240}},{{0,7,28,9,true,0},{6,15,28,5,true,6}},{0x260},nil,5)
add('em_contest_sofa_right','contest',{{0x239},{0x241}},{{9,16,28,9,true,0},{1,10,28,5,true,6}},{0x260},nil,5)
-- The small display tables (0x2DD): top rows 0..11, a 3-row face.
add('em_contest_table','contest',{{0x2DD}},{{0,16,11,3,true,0}},{0x260},{{15,14}},3)

add('em_omuseum_cube','oceanic_museum',{{0x221},{0x229}},{{0,16,22,9,true,5}},{0x201,0x202},nil,9)
-- Glass tube exhibits (0x220 over 0x228): a round tube, top rows 0..9, 21 tall.
add('em_omuseum_tube','oceanic_museum',{{0x220},{0x228}},{{0,16,9,21,true,0,nil,'disc'}},{0x201,0x202},nil,21)
add('em_omuseum_wall_case','oceanic_museum',{{0x226,0x227},{0x22E,0x22F},{0x236,0x237}},
 {{1,23,7,31,true,0}},{0x201,0x202},nil,31,nil,{lift=0})
for _,mid in ipairs({{0x248,0x249},{0x249,0x233}})do
 add('em_omuseum_counter_'..string.format('%X',mid[2]),'oceanic_museum',
  {{0x222,0x223,0x223,0x224},{0x255,mid[1],mid[2],0x256},{0x23E,0x244,0x203,0x23E},{0x260,0x243,0x201,0x260}},
  {{16,48,24,7,true,14,nil,nil,nil,nil,nil,{6,20}},{0,16,52,10,true,14,nil,nil,nil,nil,nil,{6,20}},{48,64,52,10,true,14,nil,nil,nil,nil,nil,{6,20}}},{0x201,0x202},nil,10)
end

local om={0x201,0x202,0x203,0x243,0x24B}
add('em_omuseum_table_blobs','oceanic_museum',{{0x238,0x239,0x240,0x22C},{0x232,0x233,0x233,0x234}},
 {{0,64,24,7,true,0,nil,nil,true},{9,30,7,6,true,0,nil,nil,true,nil,7},{35,46,6,5,true,2,nil,nil,true,nil,7}},om,nil,7,nil,{lift=0})
add('em_omuseum_table_ship','oceanic_museum',{{0x22A,0x230,0x231,0x22C},{0x232,0x233,0x233,0x234}},
 {{0,64,24,7,true,0,nil,nil,true},{17,46,8,6,true,0,nil,nil,true,nil,7}},om,nil,7,nil,{lift=0})
add('em_omuseum_pillar','oceanic_museum',{{0x22D},{0x235}},
 {{1,15,-14,28,true,-15,0,nil,true,nil,nil,nil,true}},om,nil,28,nil,{lift=0,maxH=28})
add('em_omuseum_console','oceanic_museum',{{0x253,0x254},{0x25B,0x25C}},
 {{0,24,24,7,true,12,nil,nil,true},{3,15,10,9,true,8,10,nil,true,nil,7}},om,nil,7,nil,{lift=0})
-- the submarine model on its case (2x2 from 0x251)
add('em_omuseum_sub','oceanic_museum',{{0x251,0x252},{0x259,0x25A}},
 {{0,32,21,9,true,11,nil,nil,true},{4,30,14,7,true,9,nil,nil,true,nil,9}},om,nil,9,nil,{lift=0})

add('em_devon_desk','facility',{{0x386,0x38D,0x38D,0x38D,0x387},{0x38E,0x39C,0x39C,0x39C,0x38F}},
 {{0,80,25,6,false,14}},{0x380,0x381},nil,6)
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
for _,mid in ipairs({0x336,0x285})do -- 0x285: the red one (unused Ruby map)
 add('em_aqua_stool_'..string.format('%X',mid),'facility',{{mid}},{{2,14,9,5,true,1,nil,'disc',true}},{0x228,0x229,0x202},nil,5,nil,{lift=0})
end
add('em_devon_showcase','facility',{{0x2DD},{0x2E5}},{{0,16,28,15,true,19}},dvo,{{2,17}},15,nil,{lift=0})
add('em_devon_planter','facility',{{0x3F6},{0x3FE}},{{0,16,20,10,true,8,nil,'disc'}},{0x380,0x381},nil,10)

for _,m in ipairs({{0x26E,0x276},{0x25F,0x267}})do
 add('em_frontier_plant_'..string.format('%X',m[1]),'battle_frontier',{{m[1]},{m[2]}},
  {{3,13,24,6,true,19,nil,'disc'},{0,16,8,10,true,1,nil,'disc',nil,nil,6}},{0x200},{{0,0},{15,0}},6)
end
add('em_frontier_booth','battle_frontier',{{0x210},{0x210},{0x218},{0x220}},
 {{1,15,35,20,true,-9},{1,15,42,12,true,36,nil,nil,nil,nil,8},{0,16,54,8,true,44}},{0x200,0x203,0x204},nil,8,nil,{lift=0})
for _,mid in ipairs({0x212,0x214})do
 add('em_frontier_counter_'..string.format('%X',mid),'battle_frontier',{{mid}},{{0,16,6,8,true,-4}},{0x200},nil,8,nil,{lift=0})
end

for _,t in ipairs({0x3C6,0x3C7})do for _,b in ipairs({0x3D7,0x3CE,0x3CF})do
 add('em_lounge_plant_'..string.format('%X_%X',t,b),'battle_frontier',{{t},{b}},
  {{2,14,23,7,true,17,nil,'disc'},{0,16,6,10,true,2,nil,'disc',nil,nil,7}},{0x3C8,0x3C9},{{1,0},{0,2},{15,24},{0,0},{1,4},{8,4},{0,7},{0,10},{0,12}},7)
end end
local bch={0x124}
for _,u in ipairs({{0x2E4,0x2E5,0x2EC,0x2ED,0x2F4,0x2F5},{0x2E2,0x2E3,0x2EA,0x2EB,0x2F2,0x2F3},{0x2E6,0x2E7,0x2EE,0x2EF,0x2F6,0x2F7}})do
 add('em_beach_umbrella_'..string.format('%X',u[1]),'slateport',{{u[1],u[2]},{u[3],u[4]},{u[5],u[6]}},
  {{0,32,28,3,true,3,nil,'disc',nil,nil,24},{15,17,31,24,true,32,nil,nil,nil,nil,nil,{15,36}}},bch,{{0,34},{0,40},{3,29}},3,nil,{primary='general',lift=0})
end
add('em_beach_chair','slateport',{{0x2E1},{0x2E9},{0x2F1}},
 {{1,14,33,3,false,26,nil,nil,true,nil,nil,{4,30}},{1,14,12,13,true,9,nil,nil,true,nil,3,{4,14}}},bch,nil,3,nil,{primary='general',lift=0})
add('em_beach_bin','slateport',{{0x2E0},{0x2E8},{0x2F0}},{{1,16,14,5,false,9},{1,16,44,3,false,15}},bch,nil,5,nil,{primary='general',lift=0})

local mkf={0x211,0x210,0x212,0x209}
for _,m in ipairs({{0x20C,{{15,10}}},{0x28E,{{15,10}}},{0x21B,{{15,6}}},{0x21C,{{15,6}}},{0x22B,{{15,5}}},{0x223,{{15,5}}},{0x20B,{{15,6}}}})do
 add('em_market_pot_'..string.format('%X',m[1]),'slateport',{{m[1]}},{{0,16,9,5,true,0,nil,'disc',true}},mkf,m[2],5,nil,{primary='general',lift=0})
end
for _,m in ipairs({0x344,0x213})do
 add('em_market_basket_'..string.format('%X',m),'slateport',{{m}},{{1,15,9,4,true,0,nil,'disc',true}},mkf,nil,4,nil,{primary='general',lift=0})
end
for _,c in ipairs({{0x32E,0x336},{0x32F,0x337}})do
 add('em_market_crates_'..string.format('%X',c[1]),'slateport',{{c[1]},{c[2]}},{{0,15,15,16,true,0,nil,nil,true}},mkf,{{15,5}},16,nil,{primary='general',lift=0})
end
for _,m in ipairs({0x33E,0x33F})do
 add('em_market_crate_'..string.format('%X',m),'slateport',{{m}},{{0,15,8,7,true,0,nil,nil,true}},mkf,{{15,5}},7,nil,{primary='general',lift=0})
end

for _,sec in ipairs({'battle_frontier_outside_west','battle_frontier_outside_east'})do
 add('em_bf_flag_'..sec:sub(-4),sec,{{0x39E,0x39F}},{{3,22,-1,16,true,0,14,'card'}},{0x05E},nil,16,nil,{primary='general',lift=0})
 for _,b in ipairs({0x3F7,0x39F})do
  add('em_bf_railflag_'..sec:sub(-4)..'_'..string.format('%X',b),sec,{{0x3F6,b}},{{4,22,-1,15,true,0,13,'card'}},{0x05E,0x109},nil,15,nil,{primary='general',lift=0})
 end
end

do
 local K=function(x0,x1,front,h,first)return {x0,x1,front,h,true,first,nil,nil,true}end
 add('em_truck_load','inside_of_truck',
  {{0x201,0x202,0x203,0x204},{0x209,0x20A,0x20B,0x20C},{0x211,0x212,0x213,0x214},{0x219,0x21A,0x21B,0x21C},{0x221,0x222,0x223,0x224}},
  {K(0,16,13,9,3),K(16,32,18,4,8),K(32,64,10,12,0),K(0,16,61,9,24),K(16,32,50,5,40),K(32,48,61,9,40),
   K(16,32,66,4,56),K(48,64,66,4,56)},{0x20A},nil,12,nil,{primary='general',lift=0})
end

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
for _,t in ipairs({{0x358,0x359},{0x392,0x393}})do for _,b in ipairs({{0x360,0x361},{0x39A,0x39B}})do
 add(string.format('em_magma_drill_%X_%X',t[1],b[1]),'lavaridge',{t,b},{{0,32,-1,32,true,0,12,'card'}},mgh,nil,32,nil,MG)
end end
for _,t in ipairs({{0x35A,0x35B},{0x394,0x395},{0x365,0x366}})do for _,b in ipairs({{0x362,0x363},{0x39C,0x39D}})do
 add(string.format('em_magma_domedrill_%X_%X',t[1],b[1]),'lavaridge',{t,b},{{0,32,-1,32,true,0,12,'card'}},mgh,nil,32,nil,MG)
end end

add('em_lilycove_beacon','lilycove',{{0x240},{0x2A2}},
 {{1,15,22,6,true,18,nil,'disc'},{0,16,17,0,true,6,nil,'ball',nil,nil,6},{4,12,5,0,true,0,nil,'ball',nil,nil,18}},
 {0x19E,0x002,0x001},{{0,0},{1,0},{2,2},{0,16},{1,17},{3,17},{0,23},{15,12}},6,nil,{primary='general',lift=0})

local gtf={0x05E}
add('em_gate_desk_w','battle_frontier',{{0x350,0x351},{0x358,0x359},{0x368,0x369},{0x370,0x371}},
 {{0,16,21,9,true,12,nil,nil,true},{16,32,53,9,true,12,nil,nil,true},{0,16,53,9,true,44,nil,nil,true}},gtf,nil,9,nil,{primary='general',lift=0})
add('em_gate_desk_e','battle_frontier',{{0x352,0x353},{0x35A,0x35B},{0x36A,0x36B},{0x372,0x373}},
 {{16,32,21,9,true,12,nil,nil,true},{0,16,53,9,true,12,nil,nil,true},{16,32,53,9,true,44,nil,nil,true}},gtf,nil,9,nil,{primary='general',lift=0})
add('em_gate_pedestal','battle_frontier',{{0x364},{0x36C}},{{2,14,13,17,true,8,nil,'disc',true}},gtf,nil,17,nil,{primary='general',lift=0})
add('em_gate_chair_w','battle_frontier',{{0x2C5}},{{1,5,3,9,true,0,nil,nil,true,nil,nil,{2,6}},{5,14,11,4,true,4,nil,nil,true,nil,nil,{8,7}}},gtf,nil,4,nil,{primary='general',lift=0})
add('em_gate_chair_e','battle_frontier',{{0x2BD}},{{11,15,3,9,true,0,nil,nil,true,nil,nil,{12,6}},{2,11,11,4,true,4,nil,nil,true,nil,nil,{7,7}}},gtf,nil,4,nil,{primary='general',lift=0})
add('em_gate_palm_plant','battle_frontier',{{0x354},{0x35C}},
 {{3,13,24,6,true,19,nil,'disc'},{0,16,7,11,true,3,nil,'disc',nil,nil,6}},{0x05E,0x364,0x36C,0x3A8},nil,6,nil,{primary='general'})
for _,mid in ipairs({0x3EF,0x3F7})do -- backrest on the left
 add('em_lounge_chair_'..string.format('%X',mid),'battle_frontier',{{mid}},
  {{1,5,11,9,true,1,nil,nil,nil,nil,nil,{3,6}},{4,15,11,4,true,4,nil,nil,nil,nil,nil,{8,8}}},{0x3C8,0x3C9},nil,4,nil,{lift=0})
end
for _,mid in ipairs({0x3DF,0x3E7,0x3DA})do -- backrest on the right
 add('em_lounge_chair_'..string.format('%X',mid),'battle_frontier',{{mid}},
  {{11,15,11,9,true,1,nil,nil,nil,nil,nil,{12,6}},{1,12,11,4,true,4,nil,nil,nil,nil,nil,{7,8}}},{0x3C8,0x3C9},nil,4,nil,{lift=0})
end
add('em_lounge_bench_3DD','battle_frontier',{{0x3DD}},{{1,4,15,9,true,1},{4,15,15,3,true,1}},{0x3C8,0x3C9},nil,3)
add('em_lounge_bench_3E5','battle_frontier',{{0x3E5}},{{1,4,15,9,true,0},{4,15,15,3,true,0}},{0x3C8,0x3C9},nil,3)
add('em_lounge_bench_3ED','battle_frontier',{{0x3ED}},{{1,4,11,9,true,0},{4,15,11,3,true,0}},{0x3C8,0x3C9},nil,3)

local petal={0x201,0x203}
add('em_petal_planter','pretty_petal_flower_shop',{{0x22E},{0x236}},{{0,16,23,7,true,0}},petal,nil,7)
add('em_petal_planter_long','pretty_petal_flower_shop',{{0x22E},{0x22E},{0x236}},{{0,16,39,7,true,0}},petal,nil,7)
add('em_petal_planter_short','pretty_petal_flower_shop',{{0x236}},{{0,16,7,7,true,0}},petal,nil,7)
add('em_petal_plant_stand','pretty_petal_flower_shop',{{0x225},{0x22D},{0x235}},
 {{0,16,41,6,false,6},
  {2,14,6,7,true,1,nil,'disc',nil,nil,6},{2,14,18,7,true,13,nil,'disc',nil,nil,6},{2,14,30,7,true,25,nil,'disc',nil,nil,6}},
 petal,nil,6,nil,{lift=0})
add('em_petal_flower_table','pretty_petal_flower_shop',{{0x233,0x234},{0x23B,0x23C}},{{0,32,25,5,false,3}},petal,{{0,0}},5)
add('em_petal_stool','pretty_petal_flower_shop',{{0x23D}},{{2,14,6,7,false,0}},petal,nil,7,nil,{lift=0})
add('em_petal_counter','pretty_petal_flower_shop',{{0x245,0x237},{0x23E,0x23F},{0x246,0x247}},
 {{2,14,9,4,false,0},{0,16,36,3,true,26,nil,nil,nil,nil,nil,{5,30}},{16,32,37,9,true,0,nil,nil,nil,nil,nil,{20,20}}},petal,nil,9)

-- Pokemon Day Care (Route 117). UNVERIFIED.
add('em_daycare_plant','pokemon_day_care',{{0x21D},{0x225}},
 {{2,14,24,6,true,19,nil,'disc'},{0,16,8,10,true,3,nil,'disc',nil,nil,6}},{0x201},{{1,0}},6)
-- The wooden table (2x2 from 0x229): plank top rows 2..23, open legs (7).
add('em_daycare_table','pokemon_day_care',{{0x229,0x22A},{0x231,0x232}},{{0,32,23,7,false,2}},{0x201,0x204},nil,7)
for _,mid in ipairs({0x228,0x230})do
 add('em_daycare_stool_'..string.format('%X',mid),'pokemon_day_care',{{mid}},{{2,14,9,5,false,1}},{0x201,0x204},nil,5)
end
add('em_daycare_counter','pokemon_day_care',{{0x218,0x226,0x219,0x226,0x21B},{0x220,0x22E,0x221,0x22E,0x223}},
 {{0,72,24,6,true,12},{64,78,24,6,true,0}},{0x201,0x206,0x207},nil,6)

add('em_lmuseum_tablet','lilycove_museum',
 {{0x242,0x228,0x229,0x22A,0x244},{0x24A,0x230,0x231,0x232,0x24C},{0x252,0x253,0x253,0x253,0x254}},
 {{0,80,41,5,true,0,nil,nil,true},{16,64,17,6,true,1,nil,nil,nil,nil,5}},{0x202,0x203,0x23F},nil,5)

local sea={0x21A,0x225,0x22A,0x224}
-- Wooden tables (one row of cells): plank top rows 0..12 on short legs.
add('em_seashore_table3','seashore_house',{{0x218,0x210,0x219}},{{0,48,12,3,false,0}},sea,nil,3)
add('em_seashore_table_l','seashore_house',{{0x220,0x219}},{{0,32,12,3,false,0}},sea,nil,3)
add('em_seashore_table_r','seashore_house',{{0x218,0x221}},{{0,32,12,3,false,0}},sea,nil,3)
add('em_seashore_cooler','seashore_house',{{0x206,0x207},{0x20E,0x20F}},{{0,32,6,24,true,0,nil,nil,true}},sea,nil,24)

local gc={0x202,0x204}
add('em_gamecorner_slots','mauville_game_corner',{{0x224,0x225},{0x22C,0x22D},{0x22C,0x22D},{0x22C,0x22D},{0x234,0x235}},
 {{0,32,71,4,true,0,nil,nil,nil,74}},gc,{{0,76}},4)
add('em_gamecorner_stool_226','mauville_game_corner',{{0x226}},
 {{5,13,10,5,false,3},{2,6,2,8,true,1,3,nil,nil,nil,5,{3,4}}},gc,nil,5,nil,{lift=0})
add('em_gamecorner_stool_227','mauville_game_corner',{{0x227}},
 {{3,11,10,5,false,3},{10,14,2,8,true,1,3,nil,nil,nil,5,{11,4}}},gc,nil,5,nil,{lift=0})
add('em_gamecorner_bench','mauville_game_corner',{{0x21E,0x21F}},{{1,31,12,3,false,0}},gc,nil,3)
-- Roulette tables (2x3 from 0x222): felt top rows 0..43 on a 3-row skirt.
add('em_gamecorner_roulette','mauville_game_corner',{{0x222,0x223},{0x22A,0x22B},{0x232,0x233}},{{0,32,43,3,false,0}},gc,nil,3)
-- Potted plants by the back wall (0x22F over 0x237).
add('em_gamecorner_plant','mauville_game_corner',{{0x22F},{0x237}},
 {{3,13,24,6,true,19,nil,'disc'},{0,16,8,10,true,1,nil,'disc',nil,nil,6}},gc,{{0,0},{0,9}},6)

local labFloor={0x252,0x27A}
-- Bookshelves (2x2 from 0x22C): top rows 0..11, shelves on a 20-row face.
add('em_lab_bookshelf','lab',{{0x22C,0x22D},{0x234,0x235}},{{0,32,11,20,true,0,nil,nil,nil,26,nil,{4,2}}},labFloor,nil,20)
add('em_lab_table','lab',{{0x260,0x261},{0x253,0x254},{0x28A,0x28B}},
 {{2,14,2,13,true,1,6},{18,30,2,13,true,1,6},{0,32,39,7,false,20}},labFloor,nil,7)
-- the same table with the other pair of chairs behind (0x264/0x265, 2F)
add('em_lab_table_264','lab',{{0x264,0x265},{0x253,0x254},{0x28A,0x28B}},
 {{2,14,2,13,true,1,6},{18,30,2,13,true,1,6},{0,32,39,7,false,20}},labFloor,nil,7)
add('em_wi_bed','lab',{{0x26C,0x26D},{0x274,0x275}},
 {{5,27,4,12,true,0,nil,nil,true},{4,28,26,5,false,10,nil,nil,true}},{0x252,0x272},nil,5,nil,{lift=0})
-- Green chairs beside them (0x25E backrest left, 0x256 right).
add('em_lab_chair_25E','lab',{{0x25E}},{{1,5,12,9,true,0,nil,nil,nil,nil,nil,{2,3}},{5,14,12,3,true,5,nil,nil,nil,nil,nil,{8,7}}},labFloor,nil,3)
add('em_lab_chair_256','lab',{{0x256}},{{11,15,12,9,true,0,nil,nil,nil,nil,nil,{12,3}},{2,11,12,3,true,5,nil,nil,nil,nil,nil,{6,7}}},labFloor,nil,3)

for _,m in ipairs({{0x384,0x385},{0x386,0x387},{0x38B,0x38C},{0x327,0x32F},{0x384,0x387},{0x386,0x385}})do
 add('em_dome_plant_'..string.format('%X_%X',m[1],m[2]),'battle_dome',{{m[1]},{m[2]}},
  {{3,13,24,6,true,19,nil,'disc'},{0,16,7,11,true,3,nil,'disc',nil,nil,6}},{0x340,0x341},nil,6)
end

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

for _,m in ipairs({{0x23C,0x23A},{0x34F,0x23B},{0x23C,0x23B},{0x33D,0x35F},{0x230,0x231}})do
 add('em_factory_plant_'..string.format('%X_%X',m[1],m[2]),'battle_factory',{{m[1]},{m[2]}},
  {{4,12,24,6,true,19,nil,'disc',true},{0,16,7,11,true,3,nil,'disc',nil,nil,6}},{0x201,0x202},{{0,1},{0,18}},6)
end
add('em_factory_bin','battle_factory',{{0x205},{0x20D}},{{0,16,14,17,true,6,nil,'disc',true}},{0x201,0x202},nil,17)

for _,m in ipairs({{0x204,0x20C},{0x206,0x20C},{0x214,0x21C},{0x205,0x20D}})do
 add('em_pike_chair_'..string.format('%X_%X',m[1],m[2]),'battle_pike',{{m[1]},{m[2]}},
  {{1,15,14,6,true,2,nil,nil,true,nil,nil,{2,6}},{3,13,15,16,true,15,12,nil,nil,nil,nil,{5,18}}},{0x2C2,0x2D4},nil,6,nil,{lift=0})
end
add('em_pike_table','battle_pike',{{0x2B2,0x2B3,0x2B4},{0x2BA,0x2BB,0x2BC}},{{8,40,29,3,true,7,nil,'disc'}},{0x2C2,0x2D4},nil,3)

add('em_bm_kitchen','brendans_mays_house',{{0x230,0x231,0x232,0x233,0x234},{0x238,0x239,0x23A,0x23B,0x23C}},
 {{0,16,8,22,true,2,nil,nil,true,27},{16,48,23,7,true,9,nil,nil,true,28},{49,72,8,22,true,3,nil,nil,true,23}},
 {0x205,0x201},nil,7,nil,{maxH=38})
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
add('em_bm_tv','brendans_mays_house',{{0x002},{0x24A}},{{0,16,3,20,true,-3,11}},{0x201},nil,20,nil,{lift=0})
add('em_bm_tv_top','brendans_mays_house',{{0x242}},{},{0x201},nil,0)

add('em_may_dish_cabinet','brendans_mays_house',{{0x243,0x244},{0x24B,0x24C}},{{9,32,8,22,true,3,nil,nil,true,23}},{0x205,0x201},nil,22,nil,{maxH=38})
add('em_may_sink','brendans_mays_house',{{0x231,0x232},{0x239,0x23A}},{{0,32,23,7,true,9,nil,nil,true,28}},{0x205,0x201},nil,7,nil,{maxH=38})
add('em_may_fridge','brendans_mays_house',{{0x230},{0x238}},{{0,16,8,22,true,2,nil,nil,true,27}},{0x205,0x201},nil,22,nil,{maxH=38})
add('em_may_tv','brendans_mays_house',{{0x003},{0x2B3}},{{0,16,3,20,true,-3,11}},{0x201},nil,20,nil,{lift=0})
add('em_may_tv_top','brendans_mays_house',{{0x246}},{},{0x201},nil,0)
add('em_may_moving_box','brendans_mays_house',{{0x240,0x241},{0x2B1,0x2B2}},{{0,31,13,10,true,1}},{0x201},nil,10)

add('em_may_table','brendans_mays_house',{{0x2B9,0x2BA},{0x2C1,0x2C2}},{{2,30,26,5,false,1}},{0x2A3,0x2AC,0x2A4},nil,5)
add('em_may_chair_w','brendans_mays_house',{{0x2C0}},{{1,5,6,9,true,nil,nil,nil,nil,nil,nil,{2,3}},{5,15,10,5}},{0x2A3,0x2AC,0x2A4},{{0,8}},5)
add('em_may_chair_e','brendans_mays_house',{{0x2C3}},{{11,15,6,9,true,nil,nil,nil,nil,nil,nil,{12,3}},{1,11,10,5}},{0x2A3,0x2AC,0x2A4},{{15,8}},5)

add('em_bm_bed','brendans_mays_house',{{0x27B,0x27C,0x27D},{0x283,0x284,0x285},{0x28B,0x28C,0x28D}},
 {{13,36,17,12,true,14},{12,36,38,6,false,23,nil,nil,nil,nil,nil,{20,30}}},{0x201},nil,6)
-- May's bed: the same drawing on her own tiles (0x280..0x292).
add('em_may_bed','brendans_mays_house',{{0x280,0x281,0x282},{0x288,0x289,0x28A},{0x290,0x291,0x292}},
 {{13,36,17,12,true,14},{12,36,38,6,false,23,nil,nil,nil,nil,nil,{20,30}}},{0x201},nil,6)
add('em_bm_desk','brendans_mays_house',{{0x252,0x254},{0x25A,0x25B},{0x262,0x263}},
 {{1,32,31,6,false,21},{1,16,15,16,true,9,20,nil,nil,nil,6,{3,27}},{5,14,42,5,false,37},{1,5,36,11,true,33}},
 {0x201},nil,6,nil,{lift=0})
add('em_may_desk','brendans_mays_house',{{0x258,0x259},{0x260,0x261}},
 {{0,17,15,7,false,4},{17,32,15,7,false,15},{17,31,6,8,true,0,4,nil,nil,nil,7,{20,3}},{17,29,27,4,false,20}},{0x201},nil,7,nil,{lift=0})
add('em_bm_tv_2f','brendans_mays_house',{{0x002},{0x25D}},{{1,15,3,20,true,0,13}},{0x201},nil,20,nil,{lift=0})
add('em_may_gamecube','brendans_mays_house',{{0x257},{0x267}},{{3,13,8,12,true,8}},{0x201},nil,12,nil,{lift=0})
add('em_bm_gamecube','brendans_mays_house',{{0x265},{0x266}},{{3,13,13,9,true,8}},{0x201},nil,9,nil,{lift=0})

for _,mid in ipairs({0x23F,0x24F,0x23E,0x23D,0x247,0x226,0x22A})do
 add('em_lab_floor_'..string.format('%X',mid),'lab',{{mid}},{{0,16,12,0}},{0x202},nil,0)
end
add('em_lab_pc_desk','lab',{{0x21A,0x21B},{0x222,0x223}},
 {{0,24,15,7,false,12},{24,32,15,7,false,4},{1,24,1,13,true,0,1,nil,nil,nil,7}},{0x202},nil,7,nil,{lift=0})
add('em_lab_book_desk','lab',{{0x20B,0x20C,0x20D,0x20E},{0x222,0x233,0x222,0x233}},
 {{0,20,15,7,false,4},{20,32,15,7,false,12},{32,51,15,7,false,4},{51,61,15,7,false,12},{61,64,15,7,false,4},
  {20,31,4,7,true,3,nil,nil,nil,nil,7},{51,61,2,9,true,1,nil,nil,nil,nil,7}},{0x202},nil,7,nil,{lift=0})
add('em_lab_corner_shelf','lab',{{0x218,0x219},{0x220,0x221},{0x228,0x202}},
 {{0,32,2,21,true,0,nil,nil,true},{0,15,34,12,true,25}},{0x202},nil,21,nil,{maxH=30})
for _,l in ipairs({{0x224,0x225},{0x236,0x237}})do
 add('em_lab_low_shelf_'..string.format('%X',l[1]),'lab',{{l[1],l[2]},{0x22C,0x22D},{0x234,0x235}},
  {{0,32,26,20,true,5,nil,nil,true,nil,nil,{2,20}},{8,23,8,7,true,2,nil,nil,nil,nil,20}},{0x202},nil,20,nil,{lift=0})
end
add('em_lab_crates','lab',{{0x229,0x23A},{0x231,0x242}},{{0,15,24,7,true,10},{16,31,10,21,true,5}},{0x202},nil,7,nil,{lift=0})
for _,c in ipairs({{0x230,0x238,0x240},{0x23B,0x243,0x24B}})do
 add('em_lab_side_desk_'..string.format('%X',c[1]),'lab',{{c[1]},{c[2]},{c[3]}},
  {{0,16,39,7,false,16},{1,16,4,11,true,1,4,nil,nil,nil,7}},{0x202},nil,7,nil,{lift=0})
end
add('em_lab_chair_241','lab',{{0x241}},{{1,12,10,5,false,4},{11,15,0,8,true,0,nil,nil,nil,nil,5}},{0x202},nil,5,nil,{lift=0})
add('em_lab_chair_249','lab',{{0x249}},{{4,15,10,5,false,4},{1,5,0,8,true,0,nil,nil,nil,nil,5}},{0x202},nil,5,nil,{lift=0})
add('em_lab_chair_239','lab',{{0x239}},{{2,14,12,3,false,7},{2,14,0,6,true,0,nil,nil,nil,nil,3}},{0x202},nil,3,nil,{lift=0})
for _,mid in ipairs({0x244,0x22E})do
 add('em_lab_plant_'..string.format('%X',mid),'lab',{{mid}},
  {{3,13,10,4,true,6,nil,'disc'},{0,16,1,4,true,-3,nil,'disc',nil,nil,4}},{0x202},nil,4)
end
for _,mid in ipairs({0x29A,0x248,0x232})do
 add('em_lab_books_'..string.format('%X',mid),'lab',{{mid}},{{1,15,7,8,true,0}},{0x202},nil,8,nil,{lift=0})
end
add('em_lab_machine','lab',{{0x214,0x215},{0x21C,0x21D}},
 {{0,32,13,18,true,0,nil,'disc',true},{8,25,6,7,true,1,nil,'disc',nil,nil,18}},{0x202},nil,18,nil,{lift=0})
add('em_lab_server','lab',{{0x216},{0x21E}},{{1,15,14,17,true,14,nil,nil,nil,nil,nil,{3,20}}},{0x202},nil,17,nil,{lift=0})

add('em_gb_table_plain','generic_building',{{0x24A,0x24B},{0x252,0x253}},{{2,30,22,8,false,1}},{0x223,0x23E},{{7,28}},8,nil,{floorFrom='neighbour'})
add('em_gb_chair_w_22B','generic_building',{{0x22B}},{{2,6,7,8,true,nil,nil,nil,nil,nil,nil,{3,3}},{5,15,10,5}},{0x223,0x23E},nil,5,nil,{floorFrom='neighbour'})
add('em_gb_chair_e_22C','generic_building',{{0x22C}},{{10,15,7,8,true,nil,nil,nil,nil,nil,nil,{12,3}},{1,10,10,5}},{0x223,0x23E},nil,5,nil,{floorFrom='neighbour'})
-- its mirror on the rug's west side (0x2E1: backrest on the west)
add('em_gb_chair_w_2E1','generic_building',{{0x2E1}},{{2,6,7,8,true,nil,nil,nil,nil,nil,nil,{3,3}},{5,15,10,5}},{0x23E,0x223},nil,5,nil,{floorFrom='neighbour'})
add('em_gb_chair_e_2E2','generic_building',{{0x2E2}},{{10,15,7,8,true,nil,nil,nil,nil,nil,nil,{12,3}},{1,10,10,5}},{0x23E,0x223},nil,5,nil,{floorFrom='neighbour'})

add('em_gb_cloth_table','generic_building',{{0x24C,0x24D},{0x254,0x255}},{{1,31,23,7,false,1}},{0x223,0x23E},nil,7,nil,{floorFrom='neighbour'})
add('em_gb_bed','generic_building',{{0x25A,0x25B},{0x262,0x263}},
 {{4,28,4,12,true,0,nil,nil,nil,nil,nil,{7,1}},{4,28,24,6,false,11,nil,nil,nil,nil,nil,{12,13}}},{0x223,0x23E},nil,6,nil,{floorFrom='neighbour'})

add('em_gb_tea_table','generic_building',{{0x24E,0x24F},{0x256,0x257}},{{2,30,23,7}},{0x229,0x221,0x223},{{0,0},{0,31}},7,nil,{lift=0,floorFrom='neighbour'})
for _,mid in ipairs({0x2B3,0x2B4})do
 add('em_gb_clay_pot_'..string.format('%X',mid),'generic_building',{{mid}},{{1,15,5,9,true,1,nil,'disc'}},{0x229,0x221},{{0,0},{0,15}},9,nil,{lift=0,floorFrom='neighbour'})
end

local rf={0x32C,0x32B}
add('em_rust_table','generic_building',{{0x37E,0x37F,0x38E},{0x386,0x387,0x38F}},{{3,45,25,4,false,1,nil,nil,true}},rf,nil,4,nil,{lift=0})
-- Chairs: backrest on the west (0x344) or east (0x345), seat on legs.
add('em_rust_chair_w','generic_building',{{0x344}},{{2,6,7,8,true,0,nil,nil,nil,nil,nil,{3,2}},{6,14,11,4,false,5}},rf,nil,4,nil,{lift=0})
add('em_rust_chair_e','generic_building',{{0x345}},{{10,14,7,8,true,0,nil,nil,nil,nil,nil,{12,2}},{2,10,11,4,false,5}},rf,nil,4,nil,{lift=0})
for _,m in ipairs({{0x343,0x34E},{0x346,0x34E},{0x347,0x34F},{0x343,0x34F},{0x346,0x34F}})do
 local t=m[1]
 add('em_rust_plant_'..string.format('%X_%X',m[1],m[2]),'generic_building',{{m[1]},{m[2]}},
  {{3,13,26,6,true,18,nil,'disc'},{0,16,8,8,true,1,nil,'disc',nil,nil,6}},rf,nil,6)
end
add('em_rust_sofa','generic_building',{{0x354,0x355},{0x35C,0x35D}},{{1,31,25,5,false,9,nil,nil,true}},rf,nil,5,nil,{lift=0})
add('em_rust_small_table','generic_building',{{0x248,0x25E},{0x250,0x251}},{{2,30,22,9,false,1}},{0x37C,0x38C,0x32C,0x32B},nil,9,nil,{lift=0,floorFrom='neighbour'})
add('em_rust_cot','generic_building',{{0x23A,0x321,0x32F},{0x384,0x3B6,0x3FD}},{{12,36,9,8,true,2,nil,nil,true},{12,36,22,6,false,10,nil,nil,true}},{0x37C,0x38C,0x32C,0x32B,0x23A},nil,6,nil,{lift=0,floorFrom='neighbour'})
-- The green cabinet (0x349 over 0x351): top rows 1..6, doors to row 22.
add('em_rust_cabinet','generic_building',{{0x349},{0x351}},{{1,15,6,16,true,1,nil,nil,true}},rf,nil,16)

local dv={0x380,0x381}
add('em_devon_desk_pc','facility',{{0x3A3,0x3A4},{0x3AB,0x3AC}},
 {{0,32,24,7,false,11},{1,16,10,13,true,8,12,nil,nil,nil,7,{4,20}}},dv,nil,7,nil,{lift=0})
add('em_devon_stool','facility',{{0x3A7}},{{2,14,9,5,true,1,nil,'disc',true}},dv,nil,5,nil,{lift=0})
add('em_devon_bin','facility',{{0x39D}},{{2,14,8,7,true,0,nil,'disc'}},dv,nil,7,nil,{lift=0})
add('em_devon_worktable','facility',{{0x3A5,0x3A6},{0x3AD,0x3AE}},{{0,32,24,6,false,1,nil,nil,true}},dv,nil,6,nil,{lift=0})

add('em_devon_conf_table','facility',
 {{0x3B8,0x3B9,0x3B9,0x3B9,0x3BA},{0x3C0,0x3C1,0x3C1,0x3C1,0x3C2},{0x3BB,0x3BC,0x3BC,0x3BC,0x3BD},{0x3C3,0x3C4,0x3C4,0x3C4,0x3C5},{0x3BE,0x3C6,0x3C6,0x3C6,0x3BF}},
 {{0,80,61,10,false,13,nil,nil,true,nil,nil,{8,63}}},{0x380,0x381},nil,10,nil,{lift=0})
add('em_devon_side_table','facility',
 {{0x3B8,0x3BA},{0x3C0,0x3C2},{0x3BB,0x3BD},{0x3C3,0x3C5},{0x3BE,0x3BF}},
 {{0,32,61,10,false,13,nil,nil,true,nil,nil,{8,63}}},{0x380,0x381},nil,10,nil,{lift=0})

for _,mid in ipairs({0x244,0x259})do
 add('em_gb_cushion_'..string.format('%X',mid),'generic_building',{{mid}},{{1,15,11,3,true,3,nil,nil,true}},{0x229,0x221},{{0,0},{0,1}},3,nil,{lift=0})
end

-- Dewford: the tea table variant with 0x25F in its top-right cell.
add('em_gb_tea_table_b','generic_building',{{0x24E,0x25F},{0x256,0x257}},{{2,30,23,7}},{0x229,0x221,0x223},{{0,0},{0,31}},7,nil,{lift=0,floorFrom='neighbour'})
local pl={0x223,0x239}
add('em_hall_oval_table','generic_building',{{0x2E8,0x2E9,0x2EA},{0x2F0,0x2F1,0x2F2}},{{3,45,22,3,false,2,nil,nil,true}},pl,nil,3,nil,{lift=0})
add('em_hall_cloth_table','generic_building',{{0x27B,0x27C},{0x252,0x253}},{{3,29,22,8,false,1}},pl,nil,8,nil,{lift=0})
add('em_hall_bed','generic_building',{{0x283,0x284},{0x28B,0x28C}},{{1,31,26,4,false,9,nil,nil,true}},pl,nil,4,nil,{lift=0})
add('em_hall_drawers','generic_building',{{0x268},{0x270}},{{1,15,8,15,true,1}},pl,nil,15,nil,{lift=0})

local sy={0x202,0x229,0x228}
-- desks with a computer (2x2 from 0x241): desktop on legs, monitor on it
add('em_ship_desk_pc','facility',{{0x241,0x242},{0x249,0x24A}},
 {{0,32,26,5,false,11},{1,16,11,12,true,8,12,nil,nil,nil,5,{4,20}}},sy,nil,5,nil,{lift=0})
add('em_ship_stool','facility',{{0x21D}},{{2,14,9,5,true,1,nil,'disc',true}},sy,nil,5,nil,{lift=0})
add('em_ship_worktable','facility',{{0x20C,0x20D},{0x214,0x215}},{{0,32,24,6,false,1,nil,nil,true}},sy,nil,6,nil,{lift=0})
for n=0,3 do
 for _,e in ipairs({{{0x22F},7,8},{{0x237},-1,16},{{0x22F,0x237},7,24}})do
  local rows={{0x21F}};for i=1,n do rows[#rows+1]={0x227} end
  local endAt=#rows*16
  for _,m in ipairs(e[1])do rows[#rows+1]={m} end
  add('em_ship_beams_'..n..'_'..e[3],'facility',rows,
   {{0,16,endAt+e[2],e[3],true,0,nil,nil,true,nil,nil,{3,20}}},sy,nil,e[3],nil,{lift=0})
 end
end
for _,rows in ipairs({{0x23F,0x247,0x24F},{0x335,0x25F,0x25F,0x257},{0x335,0x25F,0x257},{0x335,0x257,0x257},{0x335,0x257}})do
 local r={};for i,m in ipairs(rows)do r[i]={m} end
 local f=#rows*16-1-8
 local nm='em_ship_truss';for _,m in ipairs(rows)do nm=nm..'_'..string.format('%X',m) end
 add(nm,'facility',r,
  {{0,4,f,8,true,0,nil,nil,true,nil,nil,{2,20}},{12,16,f,8,true,0,nil,nil,true,nil,nil,{2,20}},
   {4,12,f,8,false,0}},sy,{{5,5}},8,nil,{lift=0})
end

add('em_ship_partition_a','facility',{{0x211},{0x20A},{0x20A},{0x209},{0x211},{0x20A},{0x209},{0x210},{0x220},{0x212}},
 {{1,15,116,35,true,0,nil,nil,true,nil,nil,nil,true}},sy,nil,35,nil,{lift=0})
add('em_ship_partition_b','facility',{{0x208},{0x211},{0x20A},{0x20A},{0x20A}},
 {{1,15,47,32,true,9,nil,nil,true,nil,nil,{8,15}}},sy,nil,32,nil,{lift=0})
add('em_ship_beam','facility',{{0x20B,0x20B,0x20B,0x20B,0x20B,0x20B,0x20B,0x20B}},
 {{0,128,20,4,true,12,nil,nil,true,nil,nil,nil,true}},sy,nil,4)
add('em_ship_beam_post','facility',{{0x226},{0x210},{0x220}},
 {{0,16,20,27,true,9,nil,nil,true,nil,nil,nil,true}},sy,nil,27,nil,{lift=0})
local function lyingTank(parts,x0,x1,first,capD,hmax,base)
 local c,R=(x0+x1)/2,(x1-x0)/2
 for x=x0,x1-1,2 do
  local m=(x+1-c)/R
  local h=math.max(3,math.floor(hmax*math.sqrt(math.max(0,1-m*m))+.5))
  parts[#parts+1]={x,math.min(x+2,x1),capD-h,h,true,first,nil,nil,true,nil,base}
 end
 return parts
end
add('em_ship_engine','facility',
 {{0x2D0,0x2D1,0x2D2,0x2D3},{0x233,0x234,0x235,0x236},{0x23B,0x23C,0x23D,0x23E},{0x243,0x244,0x245,0x246},{0x24B,0x24C,0x24D,0x24E},{0x229,0x255,0x256,0x229}},
 lyingTank(lyingTank({{0,64,66,5,true,9,nil,nil,true},{16,48,90,5,true,72,nil,nil,true},
  {21,43,76,12,true,72,nil,nil,true,nil,5}},9,55,9,62,20,5),21,43,60,75,7,5),sy,nil,25,nil,{lift=0})
add('em_ship_control','facility',{{0x25B,0x25C},{0x263,0x264},{0x26B,0x26C}},
 {{0,32,17,21,true,0,nil,nil,true}},sy,nil,21,nil,{lift=0})

add('em_ship_engine_2f','facility',
 {{0x23B,0x23C,0x23D,0x23E},{0x243,0x244,0x245,0x246},{0x24B,0x24C,0x24D,0x24E},{0x229,0x255,0x256,0x229}},
 lyingTank(lyingTank({{0,64,34,5,true,0,nil,nil,true},{16,48,58,5,true,40,nil,nil,true},
  {21,43,44,12,true,40,nil,nil,true,nil,5}},9,55,0,30,20,5),21,43,28,43,7,5),sy,nil,25,nil,{lift=0})
add('em_ship_control_2f','facility',{{0x263,0x264},{0x26B,0x26C}},
 {{0,32,1,21,true,0,nil,nil,true}},sy,nil,21,nil,{lift=0})
for _,mid in ipairs({0x250,0x251,0x252,0x268,0x269,0x297,0x26A})do
 add('em_ship_rail_'..string.format('%X',mid),'facility',{{mid}},{{0,16,2,6,false,0,nil,nil,true}},sy,nil,6,nil,{lift=0})
end
add('em_ship_rail_w','facility',{{0x260}},{{0,8,15,6,true,0,nil,nil,true}},sy,nil,6,nil,{lift=0})
add('em_ship_rail_e','facility',{{0x28D}},{{8,16,15,6,true,0,nil,nil,true}},sy,nil,6,nil,{lift=0})

local bk={0x23F,0x214}
local G={primary='general',lift=0}
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
add('em_bike_workbench','bike_shop',{{0x213,0x214,0x215,0x216},{0x21B,0x21C,0x21D,0x21E},{0x223,0x224,0x225,0x226}},
 {{0,49,26,12,false,7},{49,63,24,3,true,14},{1,15,-2,8,true,-7,nil,nil,true,nil,12}},bk,nil,12,nil,G)
-- the white partition off the north wall, ending at the display stand
add('em_bike_partition','bike_shop',{{0x238},{0x240}},
 {{0,8,3,24,true,-16,nil,nil,true,nil,nil,{3,10}}},bk,nil,24,nil,{primary='general',lift=0,maxH=28})
for _,mid in ipairs({0x239,0x23C})do
 add('em_bike_goods_'..string.format('%X',mid),'bike_shop',{{mid,0x23A}},
  {{0,32,-1,7,false,-12},{1,21,-6,4,true,-11,nil,nil,true,nil,7},{21,32,-9,7,true,-13,nil,nil,true,nil,7}},bk,nil,7,nil,G)
end
add('em_bike_stand_w','bike_shop',{{0x248,0x249},{0x250,0x251}},
 {{0,32,18,5,true,-4,nil,nil,true}},bk,nil,5,nil,G)
add('em_bike_east_rack','bike_shop',{{0x243,0x244},{0x24B,0x24C},{0x253,0x254},{0x245,0x246},{0x24D,0x24E},{0x255,0x256}},
 {{0,32,34,5,true,12,nil,nil,true},
  {9,31,32,15,true,32,44,'card'},{9,31,48,15,true,48,60,'card'},{9,31,64,15,true,64,76,'card'},
  {3,5,44,8,true,44,49,'card'},{3,5,60,8,true,60,65,'card'},{3,5,76,8,true,76,81,'card'}},bk,nil,15,nil,G)

for _,m in ipairs({{0x319,0x327},{0x31A,0x322}})do
 add('em_trick_plant_'..string.format('%X',m[1]),'generic_building',{{m[1]},{m[2]}},
  {{2,14,24,7,true,17,nil,'disc'},{0,16,8,8,true,1,nil,'disc',true,nil,7}},{0x229},nil,7)
end

add('em_gate_counter','shop',{{0x2A8,0x299,0x298,0x299,0x299,0x2A9},{0x2B0,0x2A1,0x2A0,0x2A1,0x2A1,0x2B1}},
 {{0,16,23,8,true,-8,nil,nil,true,nil,nil,{5,4}},{80,96,23,8,true,-8,nil,nil,true,nil,nil,{5,4}},
  {16,80,23,8,true,12,nil,nil,true,nil,nil,{5,4}},{16,80,-1,8,true,-8,nil,nil,true,nil,nil,{5,4}}},{0x268,0x270},nil,8)

add('em_cable_benches','facility',{{0x303},{0x30B},{0x313},{0x31B},{0x323}},
 {{4,16,32,6,false,13},{0,4,29,11,true,8,nil,nil,true,nil,nil,{1,15}},
  {4,16,64,6,false,45},{0,4,61,11,true,40,nil,nil,true,nil,nil,{1,47}}},{0x2F0},nil,11,nil,{lift=0})
-- the ticket machine (white box, its panel the face) and the round bin
add('em_cable_machine','facility',{{0x2FA},{0x302},{0x2FB}},
 {{1,16,15,15,true,0,nil,nil,true},{2,14,40,6,true,32,nil,'disc',true}},{0x2F0},nil,15,nil,{lift=0})
-- the timetable board standing at the platform edge: a thin card
add('em_cable_sign','facility',{{0x2F4,0x2F5}},{{0,32,0,15,true,0,12,'card'}},{0x2F0},nil,15,nil,{lift=0})

local nmG={0x210,0x22F,0x27D,0x27E,0x27F,0x275}
local NG={primary='general',lift=0}
add('em_nm_generator','bike_shop',{{0x2D0,0x2D1,0x2D2,0x2D3},{0x2D8,0x2D9,0x2DA,0x2DB},{0x2E0,0x2E1,0x2E2,0x2E3},{0x2E8,0x2E9,0x2EA,0x2EB}},
 {{0,64,58,4,true,8,nil,nil,true},{9,56,35,18,true,1,nil,'disc',true,nil,4}},nmG,nil,22,nil,NG)
add('em_nm_rack','bike_shop',{{0x2A9,0x2AA}},{{3,29,-12,18,true,-12,0,nil,true}},nmG,nil,18,nil,{primary='general',lift=0,maxH=24})
for _,mid in ipairs({0x2DF,0x2EF})do
 add('em_nm_console_'..string.format('%X',mid),'bike_shop',{{mid}},{{1,15,-10,15,true,-15,0,nil,true}},nmG,nil,15,nil,NG)
end
for _,mid in ipairs({0x2DE,0x2EE})do
 add('em_nm_console_'..string.format('%X',mid),'bike_shop',{{mid}},{{1,15,-12,18,true,-16,0,nil,true}},nmG,nil,18,nil,NG)
end
add('em_nm_tank_machine','bike_shop',{{0x2DC,0x2DD},{0x2E4,0x2E5}},
 {{8,24,-7,22,true,-15,nil,'disc',true},{0,16,19,11,true,16,nil,nil,true},
  {16,32,14,16,true,10,nil,nil,true},{24,32,-3,12,true,-4,nil,nil,true,nil,16}},nmG,nil,22,nil,NG)
-- the orange bench on its blue frame (open underneath)
add('em_nm_bench','bike_shop',{{0x2A3,0x2A4},{0x2AB,0x2AC}},{{0,32,18,12,false,7}},nmG,nil,12,nil,NG)
for _,mid in ipairs({0x2C0,0x2C1,0x2C2,0x2C3,0x258})do
 add('em_nm_crate_'..string.format('%X',mid),'bike_shop',{{mid}},{{0,13,9,5,true,0,nil,nil,true}},nmG,nil,5,nil,NG)
end
-- the drawer cabinet with a box on it, the box with its lid, the desk
add('em_nm_cabinet','bike_shop',{{0x2B0,0x2B1},{0x2B8,0x2B9}},
 {{0,32,10,12,true,4,nil,nil,true},{1,15,4,6,true,0,nil,nil,true,nil,12}},nmG,nil,12,nil,NG)
add('em_nm_box','bike_shop',{{0x2B3},{0x2BB}},{{0,13,16,6,true,8,nil,nil,true}},nmG,nil,6,nil,NG)
add('em_nm_desk','bike_shop',{{0x2BC}},{{0,16,-6,12,true,-12,nil,nil,true}},nmG,nil,12,nil,NG)

local hb={0x268,0x270}
add('em_herb_counter','shop',{{0x316,0x2A6,0x2A6,0x2A6,0x2A6,0x2A5},{0x2A2,0x2A2,0x2A2,0x2A2,0x2A2,0x2AD}},
 {{0,80,15,14,true,13,nil,nil,true},{80,96,21,10,true,0,nil,nil,true}},hb,nil,14,nil,{maxH=16})
add('em_herb_side_shelf','shop',{{0x312},{0x233},{0x314}},
 {{1,15,38,9,true,0,nil,nil,true,nil,nil,nil,true}},hb,nil,9,nil,{lift=0})
for _,m in ipairs({{0x2DF,0x267},{0x266,0x25A}})do
 add('em_herb_planter_'..string.format('%X',m[1]),'shop',{{m[1],m[2]},{0x261,0x262}},
  {{0,31,22,9,true,9,nil,nil,true}},hb,nil,9)
end

add('em_lava_sand_pit','lavaridge',{{0x298},{0x2A0}},{{1,15,20,2,true,7,nil,'disc'}},{0x2A8},nil,2,nil,{primary='general',lift=0})

for _,c in ipairs({{0x2B0,0x2B8,0x2C0},{0x2B2,0x2BA,0x2C2}})do
 add('em_lavapc_plant_'..string.format('%X',c[2]),'pokemon_center',{{c[1]},{c[2]},{c[3]}},
  {{3,13,34,4,true,27,nil,'disc'},{0,16,22,8,true,11,nil,'disc',nil,nil,4}},{0x202},{{0,1},{0,4},{0,5},{0,7},{0,8},{12,7},{11,8},{12,9},{0,0},{2,0},{0,16},{2,16},{0,24}},4,24)
end

add('em_lan_cabinet','lab',{{0x220},{0x228}},{{0,15,17,14,true,9,nil,nil,true}},{0x202},nil,14,nil,{lift=0,back=true})
add('em_lan_cabinet_low','lab',{{0x24A}},{{0,15,8,7,true,2,nil,nil,true}},{0x202},nil,7,nil,{lift=0,back=true})
-- the blue swivel chairs (0x232): seat on its stem, backrest at the back
add('em_lan_chair','lab',{{0x232}},{{2,14,15,4,false,8},{4,13,4,8,true,0,nil,nil,nil,nil,4}},{0x202},nil,4,nil,{lift=0})
-- the white appliance on legs (0x250 over 0x258)
add('em_lan_appliance','lab',{{0x250},{0x258}},{{0,16,13,17,false,1}},{0x202},nil,17,nil,{lift=0})
-- the low yellow crate across two cells (0x236 0x225)
add('em_lan_crate','lab',{{0x236,0x225}},{{0,32,24,7,true,18,nil,nil,true}},{0x202},nil,7,nil,{lift=0})

add('em_fortree_trunk','generic_building',{{0x3BE,0x3BF},{0x3BE,0x3BF},{0x3BE,0x3BF},{0x3C6,0x3C7}},
 {{2,30,23,40,true,0,nil,'disc',true}},{0x3D9},nil,40,nil,{lift=0,maxH=40})

for _,t in ipairs({{{0x3ED,0x3EE,0x3CF},{0x3F5,0x3F6,0x3D7},11,45,12,15,41,44},
                   {{0x3CE,0x3EE,0x3EF},{0x3D6,0x3F6,0x3F7},3,37,4,7,33,36}})do
 add('em_decor_table_'..string.format('%X',t[1][1]),'generic_building',{t[1],t[2]},
  {{t[3],t[4],24,2,true,12,nil,nil,nil,nil,4},{t[5],t[6],26,4,true,26,nil,nil,true},{t[7],t[8],26,4,true,26,nil,nil,true}},
  {0x3D9},nil,6,nil,{lift=0})
end

for _,mid in ipairs({0x25D,0x266,0x287})do
 add('em_wi_potbush_'..string.format('%X',mid),'lab',{{mid}},
  {{4,12,14,4,true,10,nil,'disc'},{1,15,2,7,true,-3,nil,'disc',nil,nil,4}},{0x252,0x269,0x202},nil,4,nil,{lift=0})
end
add('em_wi_desk','lab',{{0x260},{0x254},{0x25C}},{{2,14,2,13,true,1,6},{0,16,39,7,false,20}},{0x252,0x269,0x202},nil,7)
add('em_lab_chair_257','lab',{{0x257}},{{1,5,12,9,true,0,nil,nil,nil,nil,nil,{2,3}},{5,14,12,3,true,5,nil,nil,nil,nil,nil,{8,7}}},{0x252,0x269,0x202},nil,3)

local wiG={0x252,0x269,0x202}
add('em_wi_partition_a','lab',{{0x26B},{0x273},{0x270},{0x278},{0x280}},
 {{1,15,42,24,true,0,nil,nil,true,nil,nil,nil,true}},wiG,nil,24,nil,{maxH=32})
add('em_wi_partition_b','lab',{{0x268},{0x270},{0x278},{0x280}},
 {{1,15,26,24,true,9,nil,nil,true,nil,nil,nil,true}},wiG,nil,24,nil,{maxH=32})
add('em_wi_partition_c','lab',{{0x281},{0x26B},{0x26B},{0x26B}},
 {{1,15,39,24,true,9,nil,nil,true,nil,nil,{8,8}}},wiG,nil,24,nil,{maxH=32})

local lm={0x202,0x203}
add('em_lmuseum_statue','lilycove_museum',{{0x22B},{0x233}},
 {{0,16,24,6,true,19,nil,nil,true},{2,15,8,18,true,0,nil,true,true,nil,6}},lm,nil,24,nil,{lift=0})
add('em_lmuseum_bust','lilycove_museum',{{0x22C}},
 {{0,16,10,4,true,5,nil,nil,true},{2,14,4,6,true,0,nil,true,true,nil,4}},lm,nil,10,nil,{lift=0})

local lm2={0x268,0x269,0x270,0x271}
add('em_lmuseum_case','lilycove_museum',
 {{0x264,0x265,0x266,0x267},{0x286,0x26E,0x26E,0x26F},{0x28E,0x258,0x259,0x277},{0x27C,0x27D,0x27E,0x27F}},
 {{0,64,21,32,true,8,nil,nil,true,nil,nil,{8,30}}},lm2,nil,32,nil,{lift=0,maxH=32,back=true})
for _,c in ipairs({{0x284,0x28C},{0x285,0x28D}})do
 add('em_lmuseum_statue_'..string.format('%X',c[1]),'lilycove_museum',{{c[1]},{c[2]}},
  {{0,16,24,6,true,19,nil,nil,true},{2,15,8,18,true,0,nil,true,nil,nil,6}},lm2,{{0,0},{1,2},{15,9}},24,nil,{lift=0})
end

add('em_lmuseum_dais','lilycove_museum',
 {{0x248,0x253,0x241,0x253,0x240,0x249},{0x210,0x24D,0x23F,0x23F,0x23F,0x210},{0x238,0x234,0x23B,0x23B,0x23B,0x239},{0x252,0x253,0x253,0x253,0x253,0x254}},
 {{1,95,57,6,true,0,nil,nil,true},{15,82,46,4,true,10,nil,nil,true,nil,6}},lm,nil,6,nil,{lift=0})

local dsF={0x201,0x206,0x208,0x204,0x202,0x2F2,0x2F4,0x2FA,0x2F5,0x2FC,0x2FD,0x2F3}
for _,r in ipairs({{{0x2AA,0x2AB},{0x233,0x234},{0x2B2,0x2B3}},{{0x22B,0x22C},{0x233,0x234},{0x23B,0x23C}}})do
 add('em_store_rack3_'..string.format('%X',r[1][1]),'shop',r,
  {{0,15,10,37,true,0,nil,nil,true,nil,nil,{1,42}},{17,32,10,37,true,0,nil,nil,true,nil,nil,{30,42}}},dsF,nil,37,nil,{lift=0,maxH=37})
end
add('em_store_rack2','shop',{{0x2AA,0x2AB},{0x2B2,0x2B3}},
 {{0,15,10,21,true,0,nil,nil,true,nil,nil,{1,26}},{17,32,10,21,true,0,nil,nil,true,nil,nil,{30,26}}},dsF,nil,21,nil,{lift=0})

add('em_store_back_counter6','shop',{{0x2A4,0x243,0x2AE,0x2AE,0x2AE,0x2A5},{0x2AC,0x2A2,0x2A2,0x2A2,0x2A2,0x2AD}},
 {{0,96,12,17,true,0,nil,nil,true,nil,nil,{40,26}}},dsF,nil,17,nil,{lift=0})
add('em_store_back_counter7','shop',{{0x2A4,0x2FE,0x2F6,0x2F6,0x2F6,0x2F6,0x2A5},{0x2AC,0x2A2,0x2A2,0x2A2,0x2A2,0x2A2,0x2AD}},
 {{0,112,12,17,true,0,nil,nil,true,nil,nil,{40,26}}},dsF,nil,17,nil,{lift=0})
add('em_store_counter5','shop',
 {{0x2DD,0x29B,0x29B,0x29B,0x2DD},{0x29E,0x2A3,0x2A3,0x2A3,0x29E},{0x2A4,0x20B,0x208,0x208,0x29E},{0x2DE,0x206,0x201,0x201,0x2D1}},
 {{16,64,21,10,true,12},{0,16,53,10,true,12,nil,nil,true},{64,80,53,10,true,12,nil,nil,true}},
 {0x201,0x208,0x206},nil,10)

add('em_generic_tv2','generic_building',{{0x21E},{0x238}},
 {{0,16,15,8,true,14},{1,15,2,13,true,-3,4,nil,nil,nil,8}},{0x224,0x223},nil,8)

add('em_steven_table','generic_building',{{0x2E8,0x2E9,0x2E9,0x2EA},{0x2F0,0x2F1,0x2F1,0x2F2}},
 {{3,61,23,6,true,0,nil,nil,nil,nil,nil,{30,10}},
  {34,46,22,2,true,16,nil,nil,true,nil,6}},{0x223},nil,6)
add('em_steven_showcase','generic_building',{{0x35B},{0x363}},
 {{0,16,21,9,false,21},{0,16,12,8,true,3,nil,nil,true,nil,9}},{0x223},nil,17,nil,{lift=0})

local mg={0x20A,0x209,0x201,0x202}
-- the blue glass tables (2x2 from 0x218): glass top rows -3..27 on short legs
add('em_mgc_table','mossdeep_game_corner',{{0x218,0x219},{0x220,0x221}},{{1,31,27,3,false,-3}},mg,nil,3)
for _,mid in ipairs({0x210,0x211,0x215,0x216})do
 add('em_mgc_stool_'..string.format('%X',mid),'mossdeep_game_corner',{{mid}},{{2,14,10,4,true,1,nil,'disc'}},mg,nil,4,nil,{lift=0})
end
add('em_mgc_bench','mossdeep_game_corner',{{0x222,0x223,0x224,0x232,0x225,0x226,0x227}},
 {{0,48,9,4,false,-3,nil,nil,true},{64,112,9,4,false,-3,nil,nil,true}},mg,nil,4)
for _,c in ipairs({{0x212,0x21A},{0x217,0x21F}})do
 add('em_mgc_cabinet_'..string.format('%X',c[1]),'mossdeep_game_corner',{{c[1]},{c[2]}},
  {{0,16,6,22,true,5,0,nil,true,nil,nil,nil,true}},mg,nil,22,nil,{maxH=30})
end

add('em_soot_bench','generic_building',{{0x3DD,0x3DE},{0x3E5,0x3DF}},
 {{1,31,27,7,false,1,nil,nil,true,nil,nil,{3,10}}},{0x3FE,0x3FF},nil,7)

local mev={0x235,0x236}
add('em_mev_table','mystery_events_house',{{0x216,0x217},{0x21E,0x21F}},{{2,30,22,8,false,0}},mev,nil,8)
add('em_mev_chair_w','mystery_events_house',{{0x210}},{{2,6,4,9,true,0},{6,15,12,4,true,5}},mev,{{0,0}},4,nil,{lift=0})
add('em_mev_chair_e','mystery_events_house',{{0x211}},{{10,14,4,9,true,0},{1,10,12,4,true,5}},mev,{{15,0}},4,nil,{lift=0})

local shp={0x238,0x23B,0x23D,0x23A,0x23C}
local SG={primary='general'}
add('em_ship_bed_w','inside_ship',{{0x250,0x251},{0x258,0x259}},
 {{8,31,9,8,true,4,nil,nil,true},{8,31,27,6,false,10,nil,nil,true}},shp,nil,6,nil,SG)
add('em_ship_bed_e','inside_ship',{{0x254,0x255},{0x25C,0x25D}},
 {{1,24,9,8,true,4,nil,nil,true},{1,24,27,6,false,10,nil,nil,true}},shp,nil,6,nil,SG)
add('em_ship_table','inside_ship',{{0x256,0x257},{0x25E,0x25F}},{{1,31,25,6,false,0}},shp,nil,6,nil,SG)
-- wooden chairs (0x260 backrest west, 0x261 east): slatted seat on legs
add('em_ship_chair_260','inside_ship',{{0x260}},{{2,6,4,11,true,0,nil,nil,true},{6,14,11,4,false,4,nil,nil,true}},shp,nil,4,nil,{primary='general',lift=0})
for _,mid in ipairs({0x266,0x267,0x21E})do -- the same chair on other carpets
 add('em_ship_chair_'..string.format('%X',mid),'inside_ship',{{mid}},{{2,6,4,11,true,0,nil,nil,true},{6,14,11,4,false,4,nil,nil,true}},{0x238,0x23B,0x23D,0x23A,0x23C},nil,4,nil,{primary='general',lift=0})
end
add('em_ship_chair_261','inside_ship',{{0x261}},{{10,14,4,11,true,0,nil,nil,true},{2,10,11,4,false,4,nil,nil,true}},shp,nil,4,nil,{primary='general',lift=0})
-- the round white bin (0x262) and the white floor cushion (0x264 0x265)
add('em_ship_bin','inside_ship',{{0x262}},{{2,14,8,7,true,0,nil,'disc',true}},shp,nil,7,nil,{primary='general',lift=0})
add('em_ship_cushion','inside_ship',{{0x264,0x265}},{{0,32,13,4,true,1,nil,nil,true}},shp,nil,4,nil,{primary='general',lift=0})

local cpt={0x202,0x203,0x204}
add('em_capt_consoles','facility',{{0x2B8,0x2B9},{0x2C0,0x2C1}},
 {{1,15,6,16,true,1,nil,nil,true},{17,31,6,16,true,1,nil,nil,true}},cpt,nil,16,nil,{lift=0})
add('em_capt_machine','facility',{{0x20E,0x20F},{0x216,0x217}},{{0,32,21,10,true,8,nil,nil,true}},cpt,nil,10,nil,{lift=0})
add('em_capt_side_desk','facility',{{0x3B4},{0x3B5}},{{1,15,23,8,true,1,nil,nil,true}},cpt,nil,8,nil,{lift=0})
add('em_ship_long_table','inside_ship',{{0x256,0x270,0x270,0x257},{0x25E,0x278,0x278,0x25F}},{{1,63,25,6,false,0}},shp,nil,6,nil,SG)
add('em_ship_desk','inside_ship',{{0x299,0x29A},{0x2A1,0x2A2}},
 {{1,31,13,10,false,2,nil,nil,true},{10,23,27,5,true,18,nil,nil,true}},shp,nil,10,nil,{primary='general',lift=0})
add('em_ship_bed_blue','inside_ship',{{0x271,0x272},{0x279,0x27A}},
 {{1,23,8,6,true,4,nil,nil,true},{1,23,26,5,false,9,nil,nil,true}},shp,nil,5,nil,SG)
add('em_ship_chair_27C','inside_ship',{{0x27C}},{{10,14,4,11,true,0,nil,nil,true},{2,10,11,4,false,4,nil,nil,true}},shp,nil,4,nil,{primary='general',lift=0})
for _,mid in ipairs({0x277,0x268,0x235})do
 add('em_ship_bin_'..string.format('%X',mid),'inside_ship',{{mid}},{{2,14,8,7,true,0,nil,'disc',true}},shp,nil,7,nil,{primary='general',lift=0})
end

add('em_ship_table_20F','inside_ship',{{0x20F,0x217},{0x25E,0x25F}},{{1,31,25,6,false,0}},shp,nil,6,nil,SG)
add('em_ship_desk_2A0','inside_ship',{{0x299,0x29A},{0x2A0,0x2A2}},
 {{1,31,13,10,false,2,nil,nil,true},{10,23,27,5,true,18,nil,nil,true}},shp,nil,10,nil,{primary='general',lift=0})
local sst={0x20D,0x2E7,0x2EE,0x2F6,0x21D,0x2E6}
for _,t in ipairs({{0x2E0,0x2E8,0x2F0},{0x2E0,0x2EB,0x2F3},{0x2E1,0x2E9,0x2F1},{0x2E1,0x2EC,0x2F4},
 {0x2E2,0x2EA,0x2F2},{0x2E2,0x2ED,0x2F5},{0x2E3,0x2E8,0x2F0},{0x2E3,0x2EB,0x2F3},{0x2E4,0x2EC,0x2F4},
 {0x2E5,0x2EA,0x2F2},{0x2E5,0x2ED,0x2F5},{0x2E8,0x2E3,0x2F3},{0x2E8,0x2E8,0x2F0},{0x2EA,0x2E5,0x2F5},
 {0x2EA,0x2EA,0x2F2},{0x2EB,0x2EB,0x2F3},{0x2EC,0x2EC,0x2F4},{0x2ED,0x2ED,0x2F5}})do
 add(string.format('em_tidal_crate_%X_%X_%X',t[1],t[2],t[3]),'inside_ship',{{t[1]},{t[2]},{t[3]}},
  {{1,15,15,31,true,0,nil,nil,true,nil,nil,nil,true}},sst,nil,31,nil,{primary='general',lift=0})
end
for _,t in ipairs({{0x2E0,0x2E8,0x2E3,0x2F3},{0x2E2,0x2EA,0x2E5,0x2F5}})do
 add(string.format('em_tidal_crate_%X_%X_%X_%X',t[1],t[2],t[3],t[4]),'inside_ship',{{t[1]},{t[2]},{t[3]},{t[4]}},
  {{1,15,15,47,true,0,nil,nil,true,nil,nil,nil,true}},sst,nil,47,nil,{primary='general',lift=0})
end
for _,t in ipairs({{0x2E0,0x2F0},{0x2E2,0x2F2},{0x2E3,0x2F3},{0x2E5,0x2F5}})do
 add(string.format('em_tidal_crate_%X_%X',t[1],t[2]),'inside_ship',{{t[1]},{t[2]}},
  {{1,15,15,15,true,0,nil,nil,true,nil,nil,nil,true}},sst,nil,15,nil,{primary='general',lift=0})
end

add('em_lounge_centre_plant','battle_frontier',{{0x3DC},{0x3E4}},
 {{2,14,24,6,true,18,nil,'disc'},{1,15,9,9,true,3,nil,'disc',nil,nil,6}},{0x3C8,0x3C9},{{1,1},{15,16}},6)

local pk={0x2C1}
for _,mid in ipairs({0x2F9,0x23E})do -- 0x23E: the row's end seat at the west wall
 add('em_pike_seat_'..string.format('%X',mid),'battle_pike',{{mid}},{{1,15,14,4,true,9,nil,nil,nil,nil,nil,{3,11}},{3,13,8,8,true,0,nil,nil,nil,nil,4,{4,0}}},pk,nil,4,nil,{lift=0})
end
for _,mid in ipairs({0x30D,0x234,0x237,0x314})do
 add('em_pike_seat_'..string.format('%X',mid),'battle_pike',{{mid}},{{1,15,12,4,true,6,nil,nil,nil,nil,nil,{5,11}},{3,13,5,8,true,1,nil,nil,nil,nil,4,{5,2}}},pk,nil,4,nil,{lift=0})
end

add('em_rest_table','generic_building',{{0x2E8,0x2EA},{0x2F0,0x2F2}},{{2,30,22,8,false,0,nil,nil,true}},{0x223,0x224},nil,8)
add('em_rest_chair_w','generic_building',{{0x234}},{{1,5,3,11,true,0,nil,nil,true,nil,nil,{2,8}},{5,15,10,4,false,4,nil,nil,true,nil,nil,{8,8}}},{0x223},nil,4,nil,{lift=0})
add('em_rest_chair_e','generic_building',{{0x23C}},{{11,15,3,11,true,0,nil,nil,true,nil,nil,{13,8}},{1,11,10,4,false,4,nil,nil,true,nil,nil,{6,8}}},{0x223},nil,4,nil,{lift=0})

add('em_trade_machine','cable_club',{{0x20B,0x20C,0x20D,0x20E},{0x213,0x214,0x215,0x216},{0x21B,0x21C,0x21D,0x21E}},
 {{16,48,22,17,true,3,nil,nil,true},
  {1,5,26,10,true,19,nil,nil,true,nil,nil,{2,26}},{5,12,30,4,true,23,nil,nil,true,nil,nil,{8,31}},
  {59,63,26,10,true,19,nil,nil,true,nil,nil,{61,26}},{52,59,30,4,true,23,nil,nil,true,nil,nil,{55,31}}},{0x208,0x202},{{31,0},{0,40}},17,nil,{lift=0,back=true})

for _,e in ipairs({{0x229,0x229},{0x228,0x2A1},{0x228,0x229},{0x229,0x2A1},{0x228,0x228},{0x2A9,0x2A1}})do
 add('em_aqua_capsule_'..string.format('%X_%X',e[1],e[2]),'facility',
 {{0x22B,0x22C,0x22D,0x22E},{0x233,0x234,0x235,0x236},{0x23B,0x23C,0x23D,0x23E},{0x243,0x244,0x245,0x246},{0x24B,0x24C,0x24D,0x24E},{e[1],0x255,0x256,e[2]}},
 lyingTank(lyingTank({{0,64,66,5,true,9,nil,nil,true},{16,48,90,5,true,72,nil,nil,true},
  {21,43,76,12,true,72,nil,nil,true,nil,5}},9,55,9,62,20,5),21,43,60,75,7,5),sy,nil,25,nil,{lift=0})
end
add('em_aqua_robot_arm','facility',{{0x282,0x283},{0x288,0x289},{0x290,0x291}},
 {{0,32,30,16,true,26,nil,nil,true},{9,23,20,18,true,1,nil,'disc',true}},{0x228,0x229,0x202},nil,18,nil,{lift=0})

local ahf={0x228,0x229,0x22A,0x202,0x203,0x259}
add('em_aqua_crate','facility',{{0x3D8,0x3D9},{0x3DA,0x3DB},{0x3DC,0x3DD}},{{1,31,15,31,true,0,nil,nil,true,nil,nil,nil,true}},ahf,nil,31,nil,{lift=0})
add('em_aqua_crate_stack','facility',{{0x3D8,0x3D9},{0x3DA,0x3DB},{0x3DA,0x3DB},{0x3DC,0x3DD}},{{1,31,15,47,true,0,nil,nil,true,nil,nil,nil,true}},ahf,nil,47,nil,{lift=0})
for _,mid in ipairs({0x230,0x231})do
 add('em_aqua_console_'..string.format('%X',mid),'facility',{{mid}},{{0,16,0,22,true,0,11,nil,true}},ahf,nil,22,nil,{lift=0})
end
add('em_aqua_table','facility',{{0x3F0,0x3F1},{0x3F8,0x3F9}},{{0,32,24,6,false,1,nil,nil,true}},ahf,nil,6,nil,{lift=0})
add('em_aqua_glass_case','facility',{{0x3E3},{0x3EA}},{{1,15,-4,19,true,-13,nil,nil,true,nil,nil,{5,6}}},ahf,nil,19,nil,{lift=0})
for _,mid in ipairs({0x3E1,0x3E8,0x3E9,0x3EB})do
 add('em_aqua_chair_'..string.format('%X',mid),'facility',{{mid}},{{2,14,13,9,true,0,nil,nil,true}},ahf,nil,9,nil,{lift=0})
end
add('em_aqua_crate_3DE','facility',{{0x3DE,0x3DF},{0x3DA,0x3DB},{0x3DC,0x3DD}},{{1,31,15,31,true,0,nil,nil,true,nil,nil,nil,true}},ahf,nil,31,nil,{lift=0})
add('em_aqua_crate_low','facility',{{0x3D8,0x3D9},{0x3DC,0x3DD}},{{1,31,15,15,true,0,nil,nil,true,nil,nil,nil,true}},ahf,nil,15,nil,{lift=0})
add('em_aqua_robot_arm_28A','facility',{{0x28A,0x283},{0x288,0x289},{0x290,0x291}},
 {{0,32,30,16,true,26,nil,nil,true},{9,23,20,18,true,1,nil,'disc',true}},{0x228,0x229,0x202},nil,18,nil,{lift=0})
add('em_aqua_office_table','facility',{{0x3F3,0x3F4},{0x3C3,0x3C5},{0x3FB,0x3FC}},{{0,32,29,10,false,5,nil,nil,true,nil,nil,{8,31}}},{0x3E6,0x3E5,0x3ED},nil,10,nil,{lift=0})
add('em_aqua_drawers','facility',{{0x232}},{{1,15,6,16,true,1,nil,nil,true}},ahf,nil,16,nil,{lift=0})
add('em_ship_beam_body','facility',{{0x227}},{{0,16,15,8,true,0,nil,nil,true,nil,nil,{3,4}}},sy,nil,8,nil,{lift=0})
for _,mid in ipairs({0x22F,0x2B1})do
 add('em_ship_beam_end_'..string.format('%X',mid),'facility',{{mid}},{{0,16,7,8,true,0,nil,nil,true,nil,nil,{3,4}}},sy,nil,8,nil,{lift=0})
end
for _,mid in ipairs({0x2ED,0x3D7})do
 add('em_pyre_grave_wide_'..string.format('%X',mid),'facility',{{mid}},{{0,16,3,11,true,0,nil,true,true}},{0x2E6,0x2E7},nil,11,nil,{primary='general',lift=4})
end
-- Shipyard 2F: the desks without a computer (0x240 0x242 over 0x248 0x24A)
add('em_ship_desk_plain','facility',{{0x240,0x242},{0x248,0x24A}},{{0,32,26,5,false,11}},sy,nil,5,nil,{lift=0})
add('em_lan_table','lab',{{0x250,0x251},{0x258,0x259}},
 {{2,14,2,13,true,1,6},{18,30,2,13,true,1,6},{0,32,23,7,false,15}},{0x202},nil,7)
-- S.S. Tidal lower deck: the white bucket (0x27F)
add('em_tidal_bucket','inside_ship',{{0x27F}},{{3,13,8,5,true,1,nil,'disc',true}},{0x20D,0x21D,0x2EE},nil,5,nil,{primary='general',lift=0})
for _,pr in ipairs({false,'general'})do
 add('em_contest_box'..(pr and '_g' or ''),'contest',{{0x26F},{0x277}},{{0,16,15,7,true,10,nil,nil,true}},{0x271},{{0,23}},7,nil,{primary=pr or nil,lift=0})
end
for _,pr in ipairs({false,'general'})do
 for _,mid in ipairs({0x268,0x269,0x26A,0x270,0x272,0x278,0x279,0x27A})do
  add('em_contest_kerb_'..string.format('%X',mid)..(pr and '_g' or ''),'contest',{{mid}},{{0,16,15,3,true,0}},{0x271,0x225,0x260,0x261},nil,3,nil,{primary=pr or nil,lift=0})
 end
end
add('em_aqua_hatch','facility',{{0x2DF}},{{0,16,15,3,true,0,nil,'disc',true}},ahf,nil,3,nil,{lift=0})

add('em_generic_fridge','generic_building',{{0x278},{0x280},{0x288}},
 {{1,15,17,19,true,10,nil,nil,true,nil,nil,{8,15}}},{0x224,0x223},nil,19,10,{lift=0,maxH=28})

add('em_pac_floor_3B7','generic_building',{{0x3B7}},{{0,16,12,0}},{0x3B7},nil,0)
-- Fortree treehouse glass cabinet (2x2 from 0x3E3), backed onto the wall
add('em_fortree_cabinet','generic_building',{{0x3E3,0x3E4},{0x3EB,0x3EC}},
 {{2,23,8,22,true,3,nil,nil,true,nil,nil,{12,6}}},{0x3D9},nil,22,3,{lift=0,maxH=30})
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

add('em_league_center_desk','pokemon_center',{{0x273,0x22A,0x22B,0x207,0x25B,0x251},{0x221,0x221,0x221,0x205,0x221,0x259}},
 {{80,95,20,11,true,-7,nil,nil,true},{0,95,20,11,true,13,nil,nil,true},
  {17,47,6,8,true,-14,nil,nil,true},{65,79,-4,16,true,-7},
  {82,93,20,0,true,8,nil,'ball',true,nil,11}},{0x202},nil,11,nil,{lift=0})
add('em_league_counter_e','pokemon_center',{{0x250,0x27D,0x229,0x274,0x275},{0x258,0x221,0x205,0x221,0x221}},
 {{1,16,20,11,true,-7,nil,nil,true},{1,80,20,11,true,13,nil,nil,true}},{0x202,0x229,0x274,0x275,0x27D},nil,11,nil,{lift=0})

add('em_trick_pot','trick_house_puzzle',{{0x26C}},{{1,15,6,9,true,0,nil,'disc'}},{0x26B,0x210},nil,9,nil,{lift=0})
-- the same pot on the tatami strip (0x214)
add('em_trick_pot_214','trick_house_puzzle',{{0x214}},{{1,15,6,9,true,0,nil,'disc'}},{0x208,0x210},nil,9,nil,{lift=0})
for mid=0x280,0x294 do
 add('em_trick_plank_'..string.format('%X',mid),'trick_house_puzzle',{{mid}},{{0,16,15,6,true,0}},{0x208,0x210},nil,6,nil,{lift=0})
end

local dmf={0x340,0x341,0x342,0x343}
add('em_dome_counter_w','battle_dome',{{0x390,0x391},{0x398,0x399},{0x3A0,0x3A1},{0x3A8,0x3A9}},
 {{0,16,56,7,true,0,nil,nil,true},{0,32,56,7,true,48,nil,nil,true}},dmf,nil,7,nil,{lift=0})
add('em_dome_counter_e','battle_dome',{{0x371,0x372},{0x379,0x37A},{0x381,0x382},{0x389,0x38A}},
 {{16,32,56,7,true,0,nil,nil,true},{0,32,56,7,true,48,nil,nil,true}},dmf,nil,7,nil,{lift=0})
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

for mid=0x2DB,0x2E0 do
 add('em_dome_rope_'..string.format('%X',mid),'battle_dome',{{mid}},{{0,16,0,15,true,0,3,'card'}},dmf,nil,15,nil,{lift=0,maxH=15})
end

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
local pkf={0x2C1,0x2D9,0x2DA,0x2DE,0x2E0,0x2E3,0x2E6,0x340,0x358,0x2C2,0x2D4}
for _,m in ipairs({{0x224,0x22C},{0x216,0x21E},{0x2DB,0x2DC},{0x31B,0x22D},{0x235,0x23D},{0x234,0x23C},{0x31B,0x31C}})do
 add('em_pike_armchair_'..string.format('%X_%X',m[1],m[2]),'battle_pike',{{m[1]},{m[2]}},
  {{1,15,21,6,true,18},{2,14,1,16,true,1}},pkf,nil,6,nil,{lift=0})
end
add('em_pike_screen','battle_pike',{{0x32A,0x32B,0x32C},{0x332,0x333,0x334},{0x33A,0x33B,0x33C}},
 {{9,39,17,18,true,17,26,nil,true,nil,4},{18,30,39,4,true,36,nil,nil,true}},pkf,nil,22,nil,{lift=0})
for _,c in ipairs({{0x328,0x330,0x338},{0x329,0x331,0x339}})do
 add('em_pike_pc_'..string.format('%X',c[2]),'battle_pike',{{c[1]},{c[2]},{c[3]}},
  {{1,15,15,24,true,8,28,nil,true,nil,nil,{8,13}}},pkf,nil,24,nil,{lift=0})
end

local thf={0x330,0x331,0x335,0x316,0x337,0x336,0x301}
for _,mid in ipairs({0x3C5,0x3C6})do
 add('em_th_roof_post_'..string.format('%X',mid),'trainer_hill',{{mid}},{{4,13,-4,12,true,-7,nil,nil,true,nil,nil,{7,-6}}},{0x36B},nil,12,nil,{lift=0})
end
add('em_th_roof_pole','trainer_hill',{{0x3CE},{0x3CF}},{{4,12,7,20,true,8,24,'card'}},{0x36B},nil,20,nil,{lift=0})
add('em_th_stool','trainer_hill',{{0x309}},{{1,15,9,5,true,0,nil,'disc'}},thf,nil,5,nil,{lift=0})
add('em_th_pc','trainer_hill',{{0x32E},{0x004},{0x30A}},
 {{1,15,15,24,true,8,28,nil,true,nil,nil,{8,13}},{1,15,46,7,false,39}},thf,nil,24,nil,{lift=0})
add('em_th_machine','trainer_hill',{{0x314},{0x31C}},{{1,15,20,26,true,3,nil,nil,true}},thf,nil,26,nil,{lift=0,maxH=30})

local plf={0x201,0x203,0x207,0x20F,0x216,0x222,0x29E}
for _,r in ipairs({{0x296,0x231,0x2A8},{0x296,0x231,0x2AB}})do
 add('em_palace_sofa_a_'..string.format('%X',r[3]),'battle_palace',{{0x220,0x221,0x203},{0x28E,0x229,0x22A},r},
  {{0,32,30,9,true,1,nil,nil,nil,nil,nil,{8,8}},{32,48,30,9,true,17,nil,nil,nil,nil,nil,{40,24}}},plf,nil,9,nil,{lift=0})
end
for _,r in ipairs({{0x2AA,0x291,0x292},{0x2AD,0x291,0x292}})do
 add('em_palace_sofa_b_'..string.format('%X',r[1]),'battle_palace',{{0x203,0x240,0x241},{0x288,0x289,0x28A},r},
  {{0,16,30,9,true,17,nil,nil,nil,nil,nil,{8,24}},{16,48,30,9,true,1,nil,nil,nil,nil,nil,{24,8}}},plf,nil,9,nil,{lift=0})
end
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
local btf={0x200,0x201,0x202,0x203,0x204}
for _,c in ipairs({{0x218,0x29D},{0x219,0x221}})do
 add('em_tower_spine_'..string.format('%X',c[2]),'battle_frontier',{{0x210},{0x210},{c[1]},{c[2]}},
  {{1,15,52,6,true,0,nil,nil,true},{2,14,44,14,true,36,nil,nil,true,nil,6}},btf,nil,6,nil,{lift=0})
end
for _,m in ipairs({{0x23F,0x247},{0x23F,0x215},{0x27E,0x27F},{0x23E,0x246}})do
 add('em_tower_bin_'..string.format('%X',m[2]),'battle_frontier',{{m[1]},{m[2]}},
  {{2,14,15,16,true,8,nil,'disc',true}},btf,nil,16,nil,{lift=0})
end
for _,r in ipairs({{{0x2FD,0x2FE},{0x305,0x306}},{{0x30B,0x30C},{0x313,0x314}}})do
 add('em_exchange_case_'..string.format('%X',r[1][1]),'battle_frontier',r,
  {{0,32,7,24,true,1,0,nil,true}},btf,nil,24,nil,{lift=0,maxH=28})
end

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
local fcr={0x229,0x231,0x201,0x202,0x22A,0x232,0x228,0x230}
add('em_fanclub_sofa','pokemon_fan_club',{{0x250,0x251,0x251,0x252,0x253},{0x258,0x259,0x259,0x25A,0x25B}},
 {{0,64,13,10,true,9,nil,nil,true,nil,nil,{20,11}},{0,64,26,5,true,19,nil,nil,true,nil,nil,{20,23}}},fcr,{{0,0},{66,20}},5,nil,{lift=0})
add('em_fanclub_armchair_w','pokemon_fan_club',{{0x22E},{0x236}},
 {{0,7,19,11,true,0,nil,nil,true,nil,nil,{3,10}},{7,16,25,5,true,4,nil,nil,true,nil,nil,{10,14}}},fcr,{{15,14}},5,nil,{lift=0})
add('em_fanclub_armchair_e','pokemon_fan_club',{{0x22D},{0x235}},
 {{9,16,19,11,true,0,nil,nil,true,nil,nil,{12,10}},{0,9,25,5,true,4,nil,nil,true,nil,nil,{5,14}}},fcr,{{0,14}},5,nil,{lift=0})
add('em_fanclub_table','pokemon_fan_club',{{0x260,0x261,0x261,0x262},{0x25C,0x25D,0x25E,0x25F}},{{1,63,24,6,false,0}},fcl,nil,6,nil,{lift=0})
add('em_record_table','cable_club',{{0x2B8,0x2B9,0x2BA,0x2BB},{0x2C0,0x2C1,0x2C2,0x2C3},{0x2C8,0x2C9,0x2CA,0x2CB}},
 {{0,64,21,18,true,3,nil,nil,true}},{0x2F6,0x2F7,0x2EE,0x2C4,0x2C6},nil,18,nil,{lift=0,back=true})
for _,m in ipairs({{0x2B4,0x2BC},{0x2B5,0x2BD},{0x2B6,0x2BE},{0x2B7,0x2BF}})do
 add('em_record_seat_'..string.format('%X',m[2]),'cable_club',{{m[1]},{m[2]}},{{0,16,15,15,true,5,nil,nil,true,nil,nil,{8,8}}},{0x2C4},{{0,0},{15,0},{0,31},{15,31}},15,nil,{lift=0})
end
add('em_hof_machine','cable_club',{{0x2E9,0x2EA,0x2F0},{0x2F1,0x2F2,0x2F3},{0x2F9,0x2FA,0x2FB}},
 {{8,40,10,29,true,8,24,nil,true},{2,8,22,10,true,17,nil,nil,true},{40,46,22,10,true,17,nil,nil,true}},{0x2F6},nil,29,nil,{lift=0,maxH=32})

local function block(name,sec,rows,parts,ground,h,o)
 add(name,sec,rows,parts,ground,nil,h,nil,o or {lift=0})
end
local lbf={0x202,0x228,0x229,0x232,0x234,0x220}
block('em_lan_crate_221','lab',{{0x221}},{{1,15,8,9,true,0,nil,nil,true}},lbf,9)
block('em_lan_crate_231','lab',{{0x231}},{{1,15,8,9,true,0,nil,nil,true}},lbf,9)
block('em_lan_crates_23A','lab',{{0x23A},{0x242}},{{1,15,15,16,true,0,nil,nil,true}},lbf,16)
add('em_lab_flat_292','lab',{{0x292}},{{0,16,12,0}},{0x202},nil,0)
local pyf={0x20B,0x201,0x223,0x21F,0x20D}
for _,mid in ipairs({0x20C,0x216})do
 block('em_pyramid_fire_'..string.format('%X',mid),'battle_pyramid',{{mid}},{{2,14,7,10,true,0,nil,'disc',true}},pyf,10)
end
add('em_pyramid_lobby_pc','battle_pyramid',{{0x22E}},{{0,16,-21,27,true,-24,0,nil,true}},{0x20B},nil,27,nil,{lift=0})
add('em_pyramid_kiosk','battle_pyramid',{{0x2D8}},
 {{0,16,-21,20,true,-20,-4,nil,true,nil,6},{6,10,2,6,true,1,nil,nil,true},{4,12,6,1,true,3,nil,'disc',true}},{0x20B},nil,20,nil,{lift=0})
add('em_pyramid_board','battle_pyramid',{{0x2DA,0x2DB,0x2DC}},
 {{9,39,-16,19,true,-15,2,'card',nil,nil,2},{18,30,7,2,true,4}},{0x20B},nil,19,nil,{lift=0})
for _,m in ipairs({{0x225,0x22C},{0x2DB,0x22C}})do -- 0x2DB is a backrest, never a seat
 add('em_pike_armchair_'..string.format('%X_%X',m[1],m[2]),'battle_pike',{{m[1]},{m[2]}},
  {{1,15,21,6,true,18},{2,14,1,16,true,1}},{0x2C1,0x2D9,0x2DA,0x2DE,0x2E0,0x2E3,0x2E6,0x340,0x358,0x2C2,0x2D4},nil,6,nil,{lift=0})
end
for _,m in ipairs({{0x22B,0x233},{0x241,0x249},{0x246,0x24E},{0x22C,0x234},{0x22D,0x235},{0x22E,0x236},{0x22F,0x237},{0x23B,0x243}})do
 add('em_ranking_chair_'..string.format('%X',m[2]),'battle_frontier_ranking_hall',{{m[1]},{m[2]}},
  {{0,16,22,8,true,15},{1,15,6,16,true,6}},{0x202,0x203,0x204,0x205,0x20A,0x20B,0x20C,0x20D},nil,8,nil,{lift=0})
end
local rkf={0x202,0x203,0x204,0x20C}
block('em_ranking_kiosk','battle_frontier_ranking_hall',{{0x207},{0x20F}},{{2,14,10,16,true,0,nil,nil,true}},rkf,16)
block('em_ranking_display','battle_frontier_ranking_hall',{{0x24B,0x24C,0x24D},{0x253,0x254,0x255},{0x25B,0x25C,0x25D}},
 {{4,44,10,24,true,2,20,nil,true}},rkf,24,{lift=0,maxH=30})
block('em_seashore_stool','seashore_house',{{0x227}},{{3,13,8,8,true,0,nil,'disc'}},{0x22C,0x212,0x21E},8)
block('em_tent_pc','battle_tent',{{0x216},{0x21E}},{{1,15,12,20,true,0,nil,nil,true}},{0x210,0x211,0x209,0x208,0x277,0x21F},20)
add('em_fortree_bush_23C','fortree_gym',{{0x23C}},{{0,16,12,13,true,1,nil,'disc'}},{0x202,0x201},nil,13)
block('em_devon_display','facility',{{0x2E5}},{{2,14,12,16,true,0,nil,nil,true}},{0x2DD,0x380,0x381},16)
add('em_contest_stand_greens','contest',{{0x24A},{0x252}},
 {{5,11,23,7,true,18,nil,true},{0,16,21,2,true,15,nil,'disc',nil,nil,7},
  {5,11,13,5,true,12,nil,true,nil,nil,9},{0,16,5,6,true,0,nil,'disc',nil,nil,14}},{0x260},nil,7,nil,{lift=0})
add('em_contest_seat_w','contest',{{0x248},{0x250}},
 {{0,7,18,10,true,1,nil,nil,nil,nil,nil,{3,5}},{6,15,24,4,true,6,nil,nil,nil,nil,nil,{9,10}}},{0x260},{{15,16},{15,25},{0,28},{0,31}},4,nil,{lift=0})
add('em_contest_seat_e','contest',{{0x249},{0x251}},
 {{9,16,18,10,true,1,nil,nil,nil,nil,nil,{12,5}},{1,10,24,4,true,6,nil,nil,nil,nil,nil,{6,10}}},{0x260},{{0,16},{0,25},{15,28},{15,31}},4,nil,{lift=0})
add('em_mauvgym_bolt_248','mauville_gym',{{0x248}},{{0,16,15,1,false,0,nil,nil,nil,nil,8,{7,0}}},{0x20A,0x232,0x233},nil,1,nil,{lift=0,maxH=1})
block('em_mauvgym_pylon_250','mauville_gym',{{0x250}},{{5,11,10,14,true,0,nil,'disc',true}},{0x20A,0x232,0x233,0x218},14)
local mgf={0x203,0x204,0x205,0x202,0x215}
block('em_mgc_slots_w','mauville_game_corner',{{0x20E,0x20F},{0x216,0x217}},{{0,32,10,20,true,0,nil,nil,true}},mgf,20)
for _,mid in ipairs({0x22E,0x236})do
 block('em_mgc_bin_'..string.format('%X',mid),'mauville_game_corner',{{mid}},{{3,13,9,9,true,0,nil,'disc',true}},mgf,9)
end
add('em_mgc_prize_counter','mauville_game_corner',
 {{0x24C,0x243,0x24D,0x24E,0x24D,0x24D,0x24F},{0x254,0x256,0x255,0x256,0x255,0x255,0x257},{0x25C,0x25D,0x25E,0x25E,0x25E,0x25D,0x25F}},
 {{0,16,26,12,true,-6,nil,nil,true},{96,112,26,12,true,-6,nil,nil,true},{16,96,26,12,true,14,nil,nil,true}},
 {0x203,0x204,0x205,0x202,0x215,0x243},nil,12,nil,{lift=0})
for mid=0x21B,0x21E do
 block('em_mossgc_backrest_'..string.format('%X',mid),'mossdeep_game_corner',{{mid}},{{0,16,3,12,true,0,nil,nil,true}},{0x20A,0x209,0x223,0x224,0x225,0x226},12)
end
block('em_daycare_chair','pokemon_day_care',{{0x234}},{{2,14,9,8,true,0,nil,nil,true}},{0x207,0x21B},8)
block('em_petal_proto_shelf','pretty_petal_flower_shop',{{0x223,0x224},{0x22B,0x22C}},{{2,30,20,14,true,4,nil,nil,true}},{0x203,0x21F},14)
block('em_petal_proto_register','pretty_petal_flower_shop',{{0x21C},{0x22F}},{{2,14,20,10,true,10,nil,nil,true}},{0x237,0x220,0x226},10)
for _,m in ipairs({{0x240,0x21B,{{0,0},{12,0},{0,9}}},{0x241,0x21B,{{0,0},{15,6}}},{0x242,0x21B,{{0,0},{4,0},{5,0}}},
                   {0x213,0x21B,{{0,0},{2,5},{0,9},{0,15}}},{0x218,0x21B,{{0,0},{2,0}}},{0x223,0x21A,{}}})do
 add('em_mev_plant_'..string.format('%X_%X',m[1],m[2]),'mystery_events_house',{{m[1]},{m[2]}},
  {{3,13,28,6,true,21,nil,'disc'},{1,15,14,10,true,4,nil,'disc',nil,nil,6}},{0x235,0x236},m[3],6)
end

local dcf={0x201,0x204,0x207}
add('em_daycare_fence','pokemon_day_care',{{0x241}},{{0,16,0,15,true,0,3,'card'}},dcf,nil,15,nil,{lift=0,maxH=15})
add('em_daycare_fence_corner','pokemon_day_care',{{0x240}},{{8,16,0,15,true,0,3,'card'},{0,8,15,10,true,0,nil,nil,true}},dcf,nil,15,nil,{lift=0,maxH=15})
add('em_daycare_fence_side','pokemon_day_care',{{0x243}},{{1,7,15,10,true,0,nil,nil,true}},dcf,nil,10,nil,{lift=0})

for _,sb in ipairs({'red_cave','brown_cave','blue_cave','yellow_cave','tree','shrub'})do
 local sec='secret_base_'..sb
 local G={0x20A}
 local function D(name,rows,parts,h,o)
  o=o or {};o.primary='secret_base';if o.lift==nil then o.lift=0 end
  add('em_sb_'..name..'_'..sb,sec,rows,parts,G,nil,h,nil,o)
 end
 D('laptop',{{0x220}},{{1,15,11,3,true,6},{2,14,5,7,true,1,nil,nil,nil,nil,3}},3,{back=false})
 D('small_desk',{{0x287}},{{0,16,10,4,false,0}},4)
 D('ball_desk',{{0x28F}},{{0,16,9,5,true,0,nil,'disc'}},5)
 D('heavy_desk',{{0x290,0x291,0x292},{0x298,0x299,0x29A}},{{0,48,21,9,false,0}},9)
 D('ragged_desk',{{0x293,0x294,0x295},{0x29B,0x29C,0x29D}},{{0,48,22,7,true,0}},7)
 D('comfort_desk',{{0x296,0x297,0x2A3},{0x29E,0x29F,0x2AB}},{{0,48,24,6,false,0}},6)
 D('pretty_desk',{{0x2BD,0x2BE,0x2BF},{0x2C5,0x2C6,0x2C7},{0x2CD,0x2CE,0x2CF}},{{0,48,41,5,false,0}},5)
 D('brick_desk',{{0x2A0,0x2A1,0x2A2},{0x2A8,0x2A9,0x2AA},{0x2B0,0x2B1,0x2B2}},{{0,48,39,7,true,0}},7)
 D('camp_desk',{{0x2A4,0x2A5,0x2A6},{0x2AC,0x2AD,0x2AE},{0x2B4,0x2B5,0x2B6}},{{0,48,39,7,false,0}},7)
 D('hard_desk',{{0x2A7,0x2BB,0x2BC},{0x2AF,0x2C3,0x2C4},{0x2B7,0x2CB,0x2CC}},{{0,48,38,8,true,0}},8)
 for _,m in ipairs({0x2B8,0x2B9,0x2BA,0x2C0,0x2C1,0x2C2,0x2C8})do
  D('chair_'..string.format('%X',m),{{m}},{{2,14,9,5,false,1}},5)
 end
 D('log_chair',{{0x2C9}},{{2,14,8,6,true,1,nil,'disc'}},6)
 D('rock_chair',{{0x2CA}},{{2,14,8,6,true,1,nil,'disc'}},6)
 for _,m in ipairs({{0x225,0x22D},{0x226,0x22E},{0x227,0x22F}})do
  D('brick_'..string.format('%X',m[1]),{{m[1]},{m[2]}},{{0,16,19,12,true,0}},12,{back=true})
 end
 D('tire',{{0x280,0x281},{0x288,0x289}},{{0,32,17,13,true,0,nil,'disc'}},13)
 for _,m in ipairs({0x2F4,0x2F5,0x2F6})do
  D('tv_'..string.format('%X',m),{{m}},{{1,15,5,10,true,1,nil,nil,nil,nil,nil,nil,true}},10,{back=false})
 end
 D('red_tent',{{0x230,0x231,0x232},{0x238,0x239,0x23A},{0x240,0x241,0x23B}},{{0,17,31,16,true,0,nil,true,nil,nil,nil,{3,40},true},{31,48,31,16,true,0,nil,true,nil,nil,nil,{44,40},true},{17,31,31,3,true,0,nil,nil,nil,nil,13}},16,{back=false})
 D('blue_tent',{{0x248,0x249,0x268},{0x250,0x251,0x270},{0x258,0x259,0x269}},{{0,17,31,16,true,0,nil,true,nil,nil,nil,{3,40},true},{31,48,31,16,true,0,nil,true,nil,nil,nil,{44,40},true},{17,31,31,3,true,0,nil,nil,nil,nil,13}},16,{back=false})
 for _,m in ipairs({{0x2D0,0x2D8},{0x2D2,0x2DA},{0x2D4,0x2DC}})do
  D('plant_'..string.format('%X',m[1]),{{m[1]},{m[2]}},{{3,13,27,4,true,22,nil,'disc'},{0,16,8,7,true,1,nil,'disc',nil,nil,4}},4)
 end
 for _,m in ipairs({{0x2E4,0x2E6,0x2EC,0x2ED},{0x2F0,0x2F2,0x2F8,0x2F9}})do
  D('bigplant_'..string.format('%X',m[1]),{{m[1],m[2]},{m[3],m[4]}},{{8,24,27,4,true,23,nil,'disc'},{0,32,12,9,true,1,nil,'disc',nil,nil,4}},4)
 end
 D('flowerbed',{{0x2E0,0x2E2},{0x2E8,0x2E9}},{{0,32,25,4,true,19,nil,'disc'},{2,30,11,7,true,3,nil,'disc',nil,nil,4}},4)
 for _,m in ipairs({0x338,0x33C,0x340})do
  D('balloon_'..string.format('%X',m),{{m}},{{3,13,12,0,true,2,nil,'ball'}},10)
 end
 D('mudball',{{0x228}},{{3,13,12,0,true,4,nil,'ball'}},9)
 D('lump',{{0x20E}},{{1,15,10,5,true,5,nil,'disc'}},5)
 D('fence_ns',{{0x233}},{{4,12,7,8,true,0}},8,{back=true})
 D('fence_ew',{{0x22C}},{{1,15,7,6,true,2,5,nil}},6,{back=true})
 D('door',{{0x237},{0x23F}},{{0,16,4,27,true,5,24,'card'}},27)
 D('sand',{{0x285},{0x28D}},{{0,16,15,16,true,0,nil,true}},16,{back=true})
 for _,m in ipairs({{0x2D6,0x2DE},{0x32E,0x336}})do
  D('shield_'..string.format('%X',m[1]),{{m[1]},{m[2]}},{{0,16,21,10,true,16},{3,13,9,7,true,10,12,'card',nil,nil,10}},10,{back=true})
 end
 D('glass',{{0x282},{0x28A}},{{0,16,23,8,true,19},{2,16,0,19,true,1,14,'card',nil,nil,8}},8,{back=true})
end

return R
