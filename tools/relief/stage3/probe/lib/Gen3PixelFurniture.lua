-- Pixel-voxel furniture: a complete 3D object built from its own drawing,
-- one art pixel per voxel, nothing stretched.
--
-- Gen 3 draws a room obliquely: a point at height y and depth z appears on
-- drawing row z - y. A furniture drawing is therefore read as PARTS, each a
-- run of columns with
--   front = the last drawing row of its top surface,
--   h     = its height in pixels,
-- so that rows first..front lie flat on the top at height h (row r at depth
-- r + h) and rows front+1..front+h stand on the front face (row r at height
-- front + h - r). Seen from the game camera the object is the drawing
-- exactly; turned, it has a real top, front, sides and back.
--
-- The parts the drawing cannot show are made from its own pixels:
--   hollow parts (tables, seats) keep open space under the top; narrow runs
--   of the front face that reach the floor are legs, repeated at the back,
--   and the apron's colour closes the sides and back below the top;
--   solid parts (backrests, cabinets) are boxes in their edge colour.
-- Floor pixels (the ground tile's colours, plus sampled shadow points) are
-- never object.
local V=...
local M={}

-- Recipes (Gen3Furniture adds them; multi-cell ones outrank single reliefs).
-- parts: {x0,x1,front,h,solid,firstRow,backZ,round,keep,liftRow,base,matPixel,sideArt} (round='ball': the
-- circle drawn face-on in rows firstRow..front turned into a sphere on base; round='card': a
-- side-on thin object, each face row's runs extruded to backZ; round=true follows each
-- top row's pixel run; round='disc' trims to the inscribed ellipse) (backZ: a solid part reaches
-- back to this local depth, e.g. the wall plane); ground: floor tile ids whose interior
-- colours are not object; shadow: local points whose colour is not object.
M.recipes={}
-- wall: pixel rows of north-wall art inside the recipe (drawn on the wall
-- plane z = wall, so a cabinet against the wall keeps the wall behind it).
-- opts: extra recipe fields, e.g. {dais=true} lifts anyone standing on the
-- piece to its top (height h).
local function add(name,secondary,rows,parts,ground,shadow,h,wall,opts)
 M.recipes[#M.recipes+1]={name=name,primary='building',secondary=secondary,rows=rows,
  kind='pixel',parts=parts,pixelGround=ground,shadow=shadow or {},h=h or 0,wall=wall,
  ground=ground[1]}   -- the floor drawn under the object
 for k,v in pairs(opts or {})do M.recipes[#M.recipes][k]=v end
end
-- Brendan's / May's house 1F: the dining table on the rug and its four chairs
add('em_house_table','brendans_mays_house',{{0x21A,0x21B},{0x222,0x223}},
 {{2,30,23,8}},{0x220},{{12,29}},8)
for _,mid in ipairs({0x219,0x221})do         -- backrest on the west
 add('em_house_chair_w_'..mid,'brendans_mays_house',{{mid}},
  {{1,5,6,9,true},{5,15,10,5}},{0x220},{{7,15}},5)
end
for _,mid in ipairs({0x21C,0x224})do         -- backrest on the east
 add('em_house_chair_e_'..mid,'brendans_mays_house',{{mid}},
  {{11,15,6,9,true},{1,11,10,5}},{0x220},{{8,15}},5)
end

-- Brendan's / May's bedroom: the bed (headboard with the pillow against it,
-- mattress, footboard and legs) and the tall shelf in the corner.
add('em_player_bed','brendans_mays_house',{{0x27B,0x27C,0x27D},{0x283,0x284,0x285},{0x28B,0x28C,0x28D}},
 {{13,36,17,12,true,14},{12,36,38,6,false,23}},{0x201},nil,6)
add('em_player_shelf','brendans_mays_house',{{0x252},{0x25A},{0x262}},{{1,15,10,36,true,9,32}},{0x201},nil,36,9)

-- The shared house tileset (73 houses): dining table on the rug, chairs,
-- wardrobe and bed. Floor 0x223, rug 0x23E.
local house='generic_building'
add('em_generic_table',house,{{0x248,0x249},{0x250,0x251}},{{2,30,22,9}},{0x23E,0x223},nil,9)
-- these chairs stand on the rug in some houses and on wood in others: the
-- floor under them is copied from a neighbouring cell (floorFrom)
for _,mid in ipairs({0x2E2,0x22C})do
 add('em_generic_chair_e_'..mid,house,{{mid}},{{10,15,7,8,true},{1,10,10,5}},{0x23E,0x223},nil,5,nil,{floorFrom='neighbour'})
end
add('em_generic_chair_w_22B',house,{{0x22B}},{{2,6,7,8,true},{5,15,10,5}},{0x223,0x23E},nil,5,nil,{floorFrom='neighbour'})
add('em_generic_wardrobe',house,{{0x24C,0x24D},{0x254,0x255}},{{1,31,1,30,true}},{0x223},nil,30)
-- against the north wall: kitchen counter and bookshelf (wall art above
-- them kept on the wall plane), drawer units below the wall
add('em_generic_kitchen',house,{{0x286,0x287},{0x28E,0x28F},{0x296,0x297}},{{0,32,18,20,true,12}},{0x224},nil,20,32)
add('em_generic_bookshelf',house,{{0x279,0x27A},{0x281,0x282},{0x289,0x28A}},{{2,23,16,22,true,12}},{0x224},nil,22,32)
add('em_generic_drawers',house,{{0x268,0x269},{0x270,0x271}},{{0,32,1,22,true,0,16}},{0x224,0x223},nil,22)
-- low tea table on the tatami (Dewford, Lilycove motel...) and the square
-- table (Oldale House2 and others)
add('em_generic_tea_table',house,{{0x24E,0x24F},{0x256,0x257}},{{2,30,23,7}},{0x229,0x223},{{0,24},{31,17}},7)   -- shadow: the tatami's weave pixels, so the legs (cols 4-6, 25-27) read
add('em_generic_square_table',house,{{0x24A,0x24B},{0x252,0x253}},{{2,30,22,8}},{0x223},nil,8)
-- Sootopolis houses (floor 0x3FE) and Pacifidlog huts (rug 0x39D): dining
-- table and a chair either side
add('em_soot_table',house,{{0x3F3,0x3F4},{0x3FB,0x3FC}},{{2,30,22,9}},{0x3FE},{{8,27}},9)
add('em_soot_chair_w',house,{{0x2DD}},{{2,6,7,8,true},{5,15,10,5}},{0x3FE},{{0,8}},5)
add('em_soot_chair_e',house,{{0x2DE}},{{10,14,7,8,true},{1,10,10,5}},{0x3FE},{{15,8}},5)
add('em_pacif_table',house,{{0x3AA,0x3AB},{0x3B2,0x3B3}},{{1,31,23,8}},{0x39D},nil,8)
add('em_pacif_chair_w',house,{{0x3AE}},{{1,5,7,8,true},{5,15,10,5}},{0x39D},nil,5)
add('em_pacif_chair_e',house,{{0x3AF}},{{11,15,7,8,true},{1,11,10,5}},{0x39D},nil,5)
-- the Rustboro flats' two table drawings (floor 0x32C)
add('em_flat_table_a',house,{{0x368,0x369},{0x370,0x371}},{{2,30,22,8}},{0x32C},{{1,24}},8)
add('em_flat_table_b',house,{{0x36A,0x36B},{0x372,0x373}},{{1,31,23,7}},{0x32C},{{1,26}},7)
-- the Rustboro flats' white room partition: a thin wall drawn from above (its
-- top strip runs back to the north wall, its end face is the last 27 rows)
add('em_flat_partition',house,{{0x2D7},{0x300},{0x300},{0x300},{0x300},{0x300},{0x2DF},{0x2E7}},
 {{2,14,98,27,true,0,nil,nil,true,nil,nil,nil,true}},{0x32B,0x32C},nil,27,nil,{maxH=32})
-- Dewford Town Hall's two white partitions (plank floor 0x223/0x239), same
-- build: a north-south one off the north wall (end face the last 24 rows),
-- and an east-west one whose top strip is 11 rows deep with a 23-row face
-- (its west end 0x30A reaches the floor; the bed and drawers stand in front
-- of the rest, so the y6 cells beside it are not part of the recipe)
add('em_hall_partition_ns',house,{{0x2F8},{0x300},{0x300},{0x300},{0x300},{0x308},{0x310}},
 {{2,14,85,24,true,0,nil,nil,true,nil,nil,nil,true}},{0x223,0x239},nil,24,nil,{maxH=32})
-- the same partition one row shorter (Verdanturf, Wanda's house)
add('em_hall_partition_ns6',house,{{0x2F8},{0x300},{0x300},{0x300},{0x308},{0x310}},
 {{2,14,69,24,true,0,nil,nil,true,nil,nil,nil,true}},{0x223,0x239},nil,24,nil,{maxH=32})
add('em_hall_partition_ew',house,{{0x2FA,0x2FB,0x2FB,0x2FB},{0x302,0x303,0x303,0x303},{0x30A}},
 {{2,64,22,23,true,12,nil,nil,true,nil,nil,nil,true}},{0x223,0x239},nil,23,nil,{maxH=32})
-- Mauville bike shop yard: two bikes in side view per three cells (0x298-0x29A,
-- two rows of them). Each stands upright: its 13 drawn rows are the face of a
-- 4 px thin card (backZ, part field 8 'card': the outline keeps its gaps),
-- never lifted taller; the shadow rows below stay ground.
add('em_mauville_bikes','mauville',{{0x298,0x299,0x29A}},
 {{1,22,0,13,true,0,10,'card'},{25,46,0,13,true,0,10,'card'}},{0x001},nil,13,nil,{primary='general',maxH=13})
-- Mossdeep Space Center (general primary, facility secondary; floor 0x2F0).
-- Stools: round seats. Plotting tables (2x2): the blueprint top 8 up on
-- A-frame legs at both ends (hollow end parts), the middle a slab under the
-- top only, so the floor's grid lines are never read as legs. Computer desks
-- (2x2, two left halves): the same desk 6 up, the monitor and the paper unit
-- standing on it (base 6). The 2F gallery railing: a 2 px panel of its own
-- balusters (keep: its greys are the floor's).
local SC={primary='general',lift=0}
for _,mid in ipairs({0x361})do
 add('em_sc_stool_'..mid,'facility',{{mid}},{{2,14,9,5,true,1,nil,true}},{0x2F0,0x2F1},nil,5,nil,SC)
end
add('em_sc_plot_table','facility',{{0x368,0x369},{0x370,0x371}},
 {{0,6,22,8},{26,32,22,8},{6,26,22,3,true,1,nil,nil,nil,nil,5}},{0x2F0},nil,8,nil,SC)
for _,left in ipairs({{0x363,0x36B},{0x362,0x36A}})do
 add('em_sc_desk_'..left[1],'facility',{{left[1],0x364},{left[2],0x36C}},
  {{0,6,24,6},{26,32,24,6},{6,26,24,3,true,12,nil,nil,nil,nil,3},
   {3,15,10,6,true,9,nil,nil,nil,nil,6},{16,29,16,8,true,12,nil,nil,nil,nil,6}},{0x2F0},nil,6,nil,SC)
end
for _,mid in ipairs({0x373,0x356,0x374})do
 add('em_sc_rail_'..mid,'facility',{{mid}},{{0,16,0,12,true,0,11,'card',true}},{0x2F0,0x366},nil,12,nil,{primary='general'})
end
-- Fortree House1's yellow drawer cabinet against the plank wall (0x3E0 over
-- 0x3E8): top rows 2..8, two drawers on its face rows 9..22. Its yellow is
-- the plank floor's own colour, so the part keeps it (field 9), or the body
-- was carved hollow (user: "concave, not like a real cabinet").
add('em_tree_cabinet',house,{{0x3E0},{0x3E8}},{{1,15,8,14,true,2,nil,nil,true}},{0x3D9},nil,14,2)
-- Lilycove Fan Club's two short white half-walls: top strip rows 11..22, face
-- rows 23..31 (the rest of the face is behind the TV and the drawers in front
-- of it); the rounded end and its navy shadow outline are their own pixels.
-- Kept (field 9): their white is not floor; ends and sides in the wall's
-- white (field 12), not the navy shadow outline drawn at the outer end.
add('em_fanclub_partition_w',house,{{0x309,0x2FB,0x2FC},{0x303,0x303,0x304}},
 {{0,47,22,9,true,11,nil,nil,true,nil,nil,{10,14}}},{0x223},nil,9)
add('em_fanclub_partition_e',house,{{0x2FA,0x2FB,0x2FB},{0x302,0x303,0x303}},
 {{1,48,22,9,true,11,nil,nil,true,nil,nil,{20,14}}},{0x223},nil,9)
-- Mt. Pyre's gravestones (0x2EE on the floor, 0x326 by the wall edge): an
-- upright stone, rounded top rows 0..4 lying back, face rows 5..15 standing
-- 11 tall; its grey is the floor's grey, so it is kept (field 9).
for _,mid in ipairs({0x2EE,0x326})do
 add('em_pyre_grave_'..string.format('%X',mid),'facility',{{mid}},{{1,15,4,11,true,0,nil,true,true}},{0x2E6,0x2E7},nil,11,nil,{primary='general',lift=4})
end
-- Mt. Pyre outdoors (exterior and summit, grass 0x001): the grey (0x325) and
-- orange (0x324) gravestones, a headstone (top rows 0..2, face rows 3..6)
-- standing on a wide plinth (top rows 7..8, face rows 9..15); the summit
-- shrine's white stones (0x32A, 0x32B: rounded, top rows 0..5) and the orb
-- altar (0x32C-0x32E: two posts 12 tall, the plaque on its crossbar between).
local PY={primary='general'}
for _,mid in ipairs({0x324,0x325})do
 add('em_pyre_grave_out_'..string.format('%X',mid),'facility',{{mid}},
  {{0,16,8,7,true,7},{2,14,2,4,true,0,nil,nil,nil,nil,7}},{0x001},nil,7,nil,PY)
end
for _,mid in ipairs({0x32A,0x32B})do
 add('em_pyre_stone_'..string.format('%X',mid),'facility',{{mid}},{{0,16,5,10,true,0,nil,true}},{0x001},nil,10,nil,PY)
end
add('em_pyre_altar','facility',{{0x32C,0x32D,0x32E}},
 {{6,12,2,12,true,0},{36,42,2,12,true,0},{12,36,7,5,true,3,nil,nil,nil,nil,5}},{0x001},nil,12,nil,PY)
-- Mauville Gym's electric barriers (user: "the electricity is taken WITH
-- the floor"): only the lightning stands. The drawing (0x220/0x221 over
-- 0x228/0x229) is three wavy strands one behind another -- dark rows 10..14,
-- cyan 15..18, dark 19..23 -- so each is its own 1-px card hanging 6 px up
-- between the pylons, a beam of three strands; the checker floor stays floor.
add('em_mauville_lightning','mauville_gym',{{0x220,0x221},{0x228,0x229}},
 {{0,32,9,5,true,10,14,'card',nil,nil,6},{0,32,14,4,true,15,18,'card',nil,nil,6},
  {0,32,18,5,true,19,23,'card',nil,nil,6}},{0x20A,0x232,0x233},nil,5,nil,{lift=0,maxH=5})
add('em_generic_bed',house,{{0x25A,0x25B},{0x262,0x263}},
 {{4,28,4,12,true,0},{4,28,24,6,false,11}},{0x223},nil,6)

-- Pokemon Center 1F (34 Centers): round stools and the glass table.
for _,mid in ipairs({0x226,0x234})do
 add('em_center_stool_'..mid,'pokemon_center',{{mid}},{{1,15,9,5,true}},{0x202},{{1,11}},5)
end
add('em_center_glass_table','pokemon_center',{{0x23D,0x23E},{0x245,0x246}},{{1,31,25,5}},{0x202},{{1,10}},5)

-- More recipes from a second author (lib/Gen3PixelFurnitureB.lua returns a
-- list of add(...) argument lists), so two people never edit one file.
do
 local ok,more=pcall(function()return V and V.require and V.require('Gen3PixelFurnitureB')end)
 if ok and type(more)=='table' then for _,a in ipairs(more)do add(a[1],a[2],a[3],a[4],a[5],a[6],a[7],a[8],a[9])end end
end

-- p: placed prop; pixel(px,py) -> r,g,b,a of the drawing; colour(tileMid)
-- -> list of {r,g,b} interior colours; source/box/sample as in Gen3Furniture.
-- More depth than the flat original (user, 2026-10-05): every part stands
-- taller than its drawing implies. The extra height repeats one of its own
-- front-face rows (a leg row for open pieces, a middle row for solid ones),
-- so legs grow longer and cabinets taller from real pixels. Capped so
-- nothing outgrows the room (wall height 40).
M.LIFT=.6
function M.lift(h,r)
 if not h or h<=0 then return 0 end
 local L=math.max(0,math.min(math.floor(h*M.LIFT+.5),10,38-h))
 -- per recipe: opts {lift=n} caps the extra height, {maxH=n} caps the total
 -- (a PC or wardrobe against the back wall must stay under the wall top)
 if r and r.lift then L=math.min(L,r.lift) end
 if r and r.maxH then L=math.max(0,math.min(L,r.maxH-h)) end
 return L
end

function M.append(p,x,z,pixel,colours,source,box,sample)
 local r=p.recipe
 local W,D=p.w,p.d
 local floor={}
 local function key(cr,cg,cb)return math.floor(cr*255+.5)*65536+math.floor(cg*255+.5)*256+math.floor(cb*255+.5)end
 for _,mid in ipairs(r.pixelGround or {})do for _,c in ipairs(colours(mid))do floor[key(c[1],c[2],c[3])]=true end end
 for _,s in ipairs(r.shadow or {})do local cr,cg,cb=pixel(s[1],s[2]);floor[key(cr,cg,cb)]=true end
 local obj,objK={},{}
 -- keep: a part whose own colours equal the floor's (a cream counter on a
 -- cream floor) takes every opaque pixel as object
 local keepMode=false
 local function is(px,py)
  if px<0 or px>=W or py<-32 or py>=D+32 then return false end
  local k=py*W+px
  local t=keepMode and objK or obj
  if t[k]==nil then
   local cr,cg,cb,ca=pixel(px,py)
   t[k]=ca>.5 and (keepMode or not floor[key(cr,cg,cb)])
  end
  return t[k]
 end
 local function runs(py,x0,x1,f)
  local s
  for px=x0,x1 do
   local on=px<x1 and is(px,py)
   if on and not s then s=px elseif not on and s then f(s,px);s=nil end
  end
 end
 for _,part in ipairs(r.parts)do
  local x0,x1,front,h,solid=part[1],part[2],part[3],part[4],part[5]
  keepMode=part[9] and true or false
  -- base (part field 11): the part stands this many px above the floor (the
  -- leaves on a pot, a register on a counter); everything it emits is lifted
  local B=part[11] or 0
  local source,box=source,box
  if B~=0 then
   local s0,b0=source,box
   -- up AND forward by B: a screen row is depth - height, so the part's
   -- drawing stays exactly where the art has it at the game camera
   local function up(q)return {q[1],q[2]+B,q[3]+B}end
   source=function(sx,sy,sw,sh,a,b,c,d)return s0(sx,sy,sw,sh,up(a),up(b),up(c),up(d))end
   box=function(xa,ya,za,xb,yb,zb,m)return b0(xa,ya+B,za+B,xb,yb+B,zb+B,m)end
  end
  if part[8]=='ball' then
   -- round='ball': the circle drawn face-on in rows firstRow..front, cols
   -- x0..x1 (a Poke Ball: red top, white bottom, dark outline) becomes a
   -- sphere on the base. Each drawn pixel is a slice through the sphere
   -- running back in depth as far as the sphere is deep there, its front
   -- face the pixel itself (so the game camera sees the drawing), its other
   -- faces the same pixel's colour. Pixels outside the circle are skipped.
   local r0=part[6] or 0
   local R=math.min(x1-x0,front+1-r0)/2
   local cxp,cyp=(x0+x1)/2,(r0+front+1)/2
   local zc=z+cyp
   for py=r0,front do for px=x0,x1-1 do
    local dx,dy=px+.5-cxp,py+.5-cyp
    local q=R*R-dx*dx-dy*dy
    if q>0 then
     local dz=math.max(.5,math.sqrt(q))
     local y1=R-dy+.5;local y0=y1-1
     local X0,X1=x+px,x+px+1
     box(X0,y0,zc-dz,X1,y1,zc+dz,sample(px,py))
     source(px,py,1,1,{X0,y1,zc+dz+.02},{X1,y1,zc+dz+.02},{X1,y0,zc+dz+.02},{X0,y0,zc+dz+.02})
    end
   end end
   goto nextpart
  end
  local first
  for py=part[6] or 0,front do for px=x0,x1-1 do if not first and is(px,py)then first=py end end end
  first=first or front
  local zb,zf=z+first+h,z+front+1+h
  local L=M.lift(h,r);local H=h+L
  local disc=part[8]=='disc'
  local ecx,erx=(x0+x1)/2,(x1-x0)/2
  local ecz,erz=(first+front+1)/2,(front-first+1)/2
  -- the ellipse's last top row in column px (nil = column outside it)
  local function edge(px)
   local t=((px+.5-ecx)/erx)^2;if t>1 then return nil end
   return math.min(front,math.floor(ecz+erz*math.sqrt(1-t)-.5))
  end
  local function inside(px,py)
   if not disc then return true end
   local e=edge(px);if not e then return false end
   return py>=math.ceil(ecz-erz*math.sqrt(1-((px+.5-ecx)/erx)^2)-.5) and py<=e
  end
  local base=runs
  local function runs(py,a0,a1,f,face)
   if not disc then return base(py,a0,a1,f) end
   base(py,a0,a1,function(a,b)
    local s
    for px=a,b do
     local on=px<b and (face and edge(px) or (not face and inside(px,py)))
     if on and not s then s=px elseif not on and s then f(s,px);s=nil end
    end
   end)
  end
  -- the top, row by row (row r at depth r+h), raised to H
  -- (firstRow past front: no top, the part is only its face rows)
  if not(part[6] and part[6]>front) then
  for py=first,front do runs(py,x0,x1,function(a,b)
   local zz=z+py+h
   source(a,py,b-a,1,{x+a,H+.02,zz},{x+b,H+.02,zz},{x+b,H+.02,zz+1},{x+a,H+.02,zz+1})
  end)end
  end
  -- the apron: wide rows straight under the top
  local apronEnd=front
  for py=front+1,front+h do
   local wide=false
   runs(py,x0,x1,function(a,b)if b-a>(x1-x0)*.5 then wide=true end end)
   if wide and apronEnd==py-1 then apronEnd=py else break end
  end
  -- the face rows top-down, with the filler row repeated L times
  -- the row repeated for the extra height: part field 10 picks a plain one
  -- (a panel, a base) when the middle row is detail (a shelf of goods)
  local fill=part[10] or (solid and front+math.ceil(h/2) or math.min(apronEnd+1,front+h))
  local rows={}
  for py=front+1,front+h do
   rows[#rows+1]=py
   if py==fill then for _=1,L do rows[#rows+1]=py end end
  end
  for k,py in ipairs(rows)do
   local y1=H-k+1
   if disc then
    -- each face column stands at the ellipse's own front edge
    runs(py,x0,x1,function(a,b)
     for px=a,b-1 do
      local zc=z+edge(px)+1+h+.02
      source(px,py,1,1,{x+px,y1,zc},{x+px+1,y1,zc},{x+px+1,y1-1,zc},{x+px,y1-1,zc})
     end
    end,true)
   else
   runs(py,x0,x1,function(a,b)
    source(a,py,b-a,1,{x+a,y1,zf+.02},{x+b,y1,zf+.02},{x+b,y1-1,zf+.02},{x+a,y1-1,zf+.02})
   end)
   end
  end
  -- hidden sides take the part's commonest INTERIOR colour (not the outline
  -- drawn round its edge), so a backrest or cabinet seen from low down is its
  -- own material, not a dark slab
  local function material(ra,rb,fx,fy)
   -- part field 12 {px,py}: this pixel's colour for the hidden sides (an
   -- upholstered backrest whose face rows are mostly shadow and legs)
   if part[12] then return sample(part[12][1],part[12][2]) end
   local count,best,bx,by={},0,fx,fy
   for py=math.max(ra,1),math.min(rb,D-2) do for px=math.max(x0,1),math.min(x1-1,W-2) do
    if is(px,py) and is(px-1,py) and is(px+1,py) and is(px,py-1) and is(px,py+1) then
     local cr,cg,cb=pixel(px,py);local k=key(cr,cg,cb)
     count[k]=(count[k] or 0)+1
     if count[k]>best then best,bx,by=count[k],px,py end
    end
   end end
   return sample(bx,by)
  end
  if solid and part[8]=='card' then
   -- card: a thin object drawn side-on (a bike): each face row's pixel runs
   -- are extruded back to backZ, so the silhouette keeps its gaps (between
   -- spokes, under the frame); back, ends, tops and bottoms in the run's own
   -- pixels, the back mirrored as seen from behind
   local zback=part[7] and z+part[7] or zb
   for k,py in ipairs(rows)do
    local y1=H-k+1
    runs(py,x0,x1,function(a,b)
     source(a,py,b-a,1,{x+b,y1,zback},{x+a,y1,zback},{x+a,y1-1,zback},{x+b,y1-1,zback})
     source(a,py,1,1,{x+a,y1,zback},{x+a,y1,zf},{x+a,y1-1,zf},{x+a,y1-1,zback})
     source(b-1,py,1,1,{x+b,y1,zf},{x+b,y1,zback},{x+b,y1-1,zback},{x+b,y1-1,zf})
     source(a,py,b-a,1,{x+a,y1,zback},{x+b,y1,zback},{x+b,y1,zf},{x+a,y1,zf})
     source(a,py,b-a,1,{x+a,y1-1,zf},{x+b,y1-1,zf},{x+b,y1-1,zback},{x+a,y1-1,zback})
    end)
   end
  elseif solid and part[8] then
   -- round: the body follows each top row's own pixel outline, so turned
   -- it is a cylinder (a stump, a pot), not a box
   local mat=material(front+1,front+h,math.floor((x0+x1)/2),math.min(front+1,D-1))
   for py=first,front do runs(py,x0,x1,function(a,b)
    box(x+a+.03,0,z+py+h+.03,x+b-.03,H,z+py+h+.97,mat)
   end)end
   if part[14] and not disc then
    -- back art on a round part (gravestones seen from the north): each
    -- column's back, at the first top row that holds it, takes that column's
    -- own face pixels
    local back={}
    for py=first,front do runs(py,x0,x1,function(a,b)
     for px=a,b-1 do if not back[px] then back[px]=z+py+h+.01 end end
    end)end
    for px,zz in pairs(back)do for k,fr in ipairs(rows)do
     if is(px,fr)then local y1=H-k+1
      source(px,fr,1,1,{x+px+1,y1,zz},{x+px,y1,zz},{x+px,y1-1,zz},{x+px+1,y1-1,zz})
     end
    end end
   end
   if disc then
    -- bark: the sides repeat the face's own columns at the same height, so
    -- the stripes run all the way round
    -- A face row's outer columns are often floor (a round crown): take the
    -- nearest OBJECT pixel walking in toward the centre, and leave the
    -- height empty when the row has none, so no floor colour bands the bark
    -- and skip the row's darkest colour (the outline): the side shows the
    -- leaves/bark, only the silhouette edge stays dark. A row of nothing but
    -- outline still uses it.
    local mid=math.floor(ecx)
    local dark={}
    local function darkest(fr)
     if dark[fr]==nil then
      local best,bk=nil,false
      for c=x0,x1-1 do if is(c,fr)then
       local r,g,b=pixel(c,fr);local l=r*.3+g*.59+b*.11
       if not best or l<best then best,bk=l,key(r,g,b)end
      end end
      dark[fr]=bk
     end
     return dark[fr]
    end
    local function bark(col,fr)
     local step=col<=mid and 1 or -1
     local c,first=col,nil
     local dk=darkest(fr)
     while c>=x0 and c<x1 do
      if is(c,fr)then
       first=first or c
       local r,g,b=pixel(c,fr)
       if key(r,g,b)~=dk then return c end
      end
      if c==mid then break end
      c=c+step
     end
     return first
    end
    local back={}
    for py=first,front do runs(py,x0,x1,function(a,b)
     local zz=z+py+h
     for k,fr in ipairs(rows)do
      local y1=H-k+1
      local ca,cb=bark(a,fr),bark(b-1,fr)
      if ca then source(ca,fr,1,1,{x+a,y1,zz},{x+a,y1,zz+1},{x+a,y1-1,zz+1},{x+a,y1-1,zz})end
      if cb then source(cb,fr,1,1,{x+b,y1,zz+1},{x+b,y1,zz},{x+b,y1-1,zz},{x+b,y1-1,zz+1})end
     end
     for px=a,b-1 do if not back[px] then back[px]=zz end end
    end)end
    for px,zz in pairs(back)do for k,fr in ipairs(rows)do
     local y1=H-k+1
     local c=bark(px,fr)
     if c then source(c,fr,1,1,{x+px+1,y1,zz},{x+px,y1,zz},{x+px,y1-1,zz},{x+px+1,y1-1,zz})end
    end end
   end
  elseif solid then
   local mat=material(front+1,front+h,math.floor((x0+x1)/2),math.min(front+1,D-1))
   local zback=part[7] and z+part[7] or zb
   box(x+x0,0,zback,x+x1,H,zf,mat)
   if part[14] then
    -- back art (part field 14; furniture session, user: "do the backs as
    -- well"): the back plane repeats the part's own face rows pixel by pixel
    -- (like the disc branch); pixels that are not object keep the material
    for k,fr in ipairs(rows)do local y1=H-k+1
     for px=x0,x1-1 do if is(px,fr)then
      source(px,fr,1,1,{x+px+1,y1,zback-.02},{x+px,y1,zback-.02},{x+px,y1-1,zback-.02},{x+px+1,y1-1,zback-.02})
     end end
    end
   end
   if part[13] then
    -- side art (part field 13): both long sides repeat the end face's own
    -- edge columns row by row along the whole depth (a partition wall's
    -- stripes), like the bark of a round part
    local function edgeCol(col,step,fr)
     local c=col
     while c>=x0 and c<x1 do if is(c,fr)then return c end;c=c+step end
    end
    for k,fr in ipairs(rows)do
     local y1=H-k+1
     local ca,cb=edgeCol(x0,1,fr),edgeCol(x1-1,-1,fr)
     for zz=zback,zf-1 do
      if ca then source(ca,fr,1,1,{x+x0-.02,y1,zz},{x+x0-.02,y1,zz+1},{x+x0-.02,y1-1,zz+1},{x+x0-.02,y1-1,zz})end
      if cb then source(cb,fr,1,1,{x+x1+.02,y1,zz+1},{x+x1+.02,y1,zz},{x+x1+.02,y1-1,zz},{x+x1+.02,y1-1,zz+1})end
     end
    end
   end
   if not part[13] and part[7]~=0 then
    -- casing (first person, 2026-10-17): a box's hidden sides, and its back when it carries no
    -- back art (a counter, a cabinet, a TV's or a PC's casing), were one flat colour, a slab a
    -- step away. Each face row's colour just inside the part's edge - past the outline, the
    -- casing itself, never the screen or the drawers in the middle - runs along both sides and
    -- across the back at that row's height, so the hidden faces carry the front's own bands
    -- (rim, panel, kick strip) in the piece's own pixels.
    local function casing(col,step,fr)
     local dk,dl=nil,1e9
     for c=x0,x1-1 do if is(c,fr)then local r,g,b=pixel(c,fr);local l=r*.3+g*.59+b*.11;if l<dl then dl,dk=l,key(r,g,b)end end end
     local c,firstc=col,nil
     for _=1,3 do
      if c<x0 or c>=x1 then break end
      if is(c,fr)then firstc=firstc or c;local r,g,b=pixel(c,fr);if key(r,g,b)~=dk then return c end end
      c=c+step
     end
     return firstc
    end
    for k,fr in ipairs(rows)do
     local y1=H-k+1
     local ca,cb=casing(x0,1,fr),casing(x1-1,-1,fr)
     if ca then source(ca,fr,1,1,{x+x0-.02,y1,zback},{x+x0-.02,y1,zf},{x+x0-.02,y1-1,zf},{x+x0-.02,y1-1,zback})end
     if cb then source(cb,fr,1,1,{x+x1+.02,y1,zf},{x+x1+.02,y1,zback},{x+x1+.02,y1-1,zback},{x+x1+.02,y1-1,zf})end
     if not part[14] and ca then
      local xm=math.floor((x0+x1)/2)
      source(ca,fr,1,1,{x+xm,y1,zback-.02},{x+x0,y1,zback-.02},{x+x0,y1-1,zback-.02},{x+xm,y1-1,zback-.02})
      source(cb or ca,fr,1,1,{x+x1,y1,zback-.02},{x+xm,y1,zback-.02},{x+xm,y1-1,zback-.02},{x+x1,y1-1,zback-.02})
     end
    end
   end
  else
   -- a thin slab under the top, and an apron round the sides and back
   local edge=material(front+1,math.max(front+1,apronEnd),math.floor((x0+x1)/2),math.min(apronEnd,D-1))
   local yb=H-math.max(1,apronEnd-front)
   for py=first,front do runs(py,x0,x1,function(a,b)
    box(x+a,H-1,z+py+h,x+b,H,z+py+h+1,edge)
   end)end
   if apronEnd>front then
    box(x+x0,yb,zb,x+x0+1,H-1,zf,edge);box(x+x1-1,yb,zb,x+x1,H-1,zf,edge)
    box(x+x0,yb,zb,x+x1,H-1,zb+1,edge)
   end
   -- legs: narrow runs of the front face that reach the floor row, up to
   -- the apron, at the front and repeated at the back
   runs(front+h,x0,x1,function(a,b)
    if b-a<=(x1-x0)*.4 then
     local mat=sample(math.floor((a+b)/2),front+h)
     local dz=b-a
     box(x+a,0,zf-dz,x+b,yb,zf,mat)
     box(x+a,0,zb,x+b,yb,zb+dz,mat)
    end
   end)
  end
  ::nextpart::
 end
 -- the north wall's own art above/behind the piece, on the wall plane
 if r.wall then
  local zw=z+r.wall-.05
  for py=0,r.wall-1 do
   local y1=r.wall-py
   source(0,py,W,1,{x,y1,zw},{x+W,y1,zw},{x+W,y1-1,zw},{x,y1-1,zw})
  end
 end
end
-- back art (part field 14) on this file's own pieces whose backs read as plain
-- boxes beside the furniture session's (its report after turning it on for
-- its recipes): chairs, beds, stools, and Mt. Pyre's gravestones and stones
for _,r in ipairs(M.recipes)do
 local n=r.name or ''
 if n:find('^em_pacif_chair') or n:find('^em_house_chair') or n:find('^em_generic_chair_e') or n:find('^em_soot_chair')
   or n=='em_player_bed' or n=='em_generic_bed' or n:find('^em_sc_stool') or n:find('^em_pyre_grave') or n:find('^em_pyre_stone') then
  for _,pt in ipairs(r.parts or {})do
   if pt[5]==true and pt[8]~='card' and pt[8]~='ball' and pt[14]==nil then pt[14]=true end
  end
 end
end
return M
