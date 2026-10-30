-- Shared presentation-only room framing. Native layouts, furniture, warps and
-- collision remain authoritative. Camera-facing walls open outside the room;
-- an eye inside the room sees all four walls and a ceiling.
local V=...
local M={background={.022,.032,.046,1}}
local cache=setmetatable({},{__mode='k'})
local materials={}
local themes={
 cave={{.38,.34,.30},{.35,.32,.28},{.33,.30,.27},{.42,.38,.34}},
 bush={{.30,.52,.26},{.27,.48,.24},{.24,.44,.22},{.36,.58,.30}},
 ice={{.35,.49,.60},{.33,.47,.57},{.31,.44,.54},{.43,.57,.66}},
 ship={{.86,.86,.89},{.52,.52,.60},{.29,.29,.35},{.92,.91,.72}},
 -- rooms whose own drawn walls bound them in the black: the shell's lip and plinth are the black itself
 void={{.04,.03,.034},{.04,.03,.034},{.04,.03,.034},{.04,.03,.034}},
 home={{.73,.71,.61},{.37,.35,.28},{.20,.22,.22},{.91,.87,.70}},
 shop={{.67,.76,.73},{.23,.43,.43},{.13,.25,.29},{.84,.94,.88}},
 center={{.79,.77,.70},{.45,.35,.32},{.22,.27,.30},{.97,.88,.72}},
 lab={{.69,.74,.73},{.29,.40,.43},{.17,.24,.28},{.83,.94,.92}},
 -- inside a Fortree tree: the orange plank wall's own colours
 tree={{.97,.55,.39},{.81,.39,.23},{.26,.29,.42},{1.0,.81,.55}},
 -- Mt. Pyre's halls: its grey-lavender stone wall
 pyre={{.65,.68,.87},{.39,.39,.48},{.26,.29,.42},{.75,.78,.92}},
}
-- per map: tiles that are the black outside of the room, drawn inside its
-- map (Devon Corp 1F's 0x201 above its front walls, the Route 121 Safari
-- Zone entrance's black south-west quarter). Gen3Scene leaves them unbuilt;
-- the shell follows the room's own outline round them.
M.VOID_BY_MAP={EM_RUSTBORO_CITY_DEVON_CORP_1F={[0x201]=true},
 EM_ROUTE121_SAFARI_ZONE_ENTRANCE={[0x001]=true},
 EM_BATTLE_FRONTIER_RANKING_HALL={[0x001]=true},   -- round the hall's floor islands
 EM_AQUA_HIDEOUT_1F={[0x201]=true},EM_AQUA_HIDEOUT_B1F={[0x201]=true},EM_AQUA_HIDEOUT_B2F={[0x201]=true},
 EM_MOSSDEEP_CITY_GYM={[0x208]=true},
 -- the ships: the black between and round the cabins and corridors
 EM_SS_TIDAL_LOWER_DECK={[0x201]=true},EM_SS_TIDAL_CORRIDOR={[0x201]=true},
 EM_ABANDONED_SHIP_CORRIDORS_1F={[0x201]=true},EM_ABANDONED_SHIP_CORRIDORS_B1F={[0x201]=true},EM_ABANDONED_SHIP_HIDDEN_FLOOR_CORRIDORS={[0x201]=true},
 EM_BATTLE_FRONTIER_BATTLE_DOME_PRE_BATTLE_ROOM={[0x001]=true},EM_BATTLE_FRONTIER_BATTLE_ARENA_CORRIDOR={[0x001]=true},
 EM_BIRTH_ISLAND_HARBOR={[0x201]=true},EM_NAVEL_ROCK_HARBOR={[0x201]=true},
 -- Trainer Hill: the black padding round the lobby and beside each floor
 EM_TRAINER_HILL_ENTRANCE={[0x208]=true},EM_TRAINER_HILL_1F={[0x208]=true},EM_TRAINER_HILL_2F={[0x208]=true},
 EM_TRAINER_HILL_3F={[0x208]=true},EM_TRAINER_HILL_4F={[0x208]=true}}   -- the warp-panel gym: rooms floating in black
-- the ships' cabins: besides the black between them, the cabins' side walls
-- seen from above (the white strips 0x23E/0x23F with their corners 0x236/
-- 0x237, and the wall's end at a doorway between two cabins, 0x246/0x247/
-- 0x24E/0x24F) are the room's outside: the shell's own walls stand there, so
-- every cabin is a walled room and two cabins side by side are not one hall.
-- A cabin's walls are as tall as its drawn back wall (32), and behind a
-- drawn back wall the shell adds no wall of its own (it would stand taller
-- than the drawing and hide the cabin behind it).
M.CABINS={}
for _,id in ipairs({'EM_SS_TIDAL_ROOMS','EM_ABANDONED_SHIP_ROOMS_1F','EM_ABANDONED_SHIP_ROOMS_B1F','EM_ABANDONED_SHIP_ROOMS2_1F',
  'EM_ABANDONED_SHIP_ROOMS2_B1F','EM_ABANDONED_SHIP_ROOM_B1F','EM_ABANDONED_SHIP_HIDDEN_FLOOR_ROOMS'})do
 M.CABINS[id]={walls='inside_ship',h=32,cap=1}   -- (a cabin's wall tops are drawn white)
 M.VOID_BY_MAP[id]={[0x201]=true,[0x236]=true,[0x237]=true,[0x23E]=true,[0x23F]=true,[0x246]=true,[0x247]=true,[0x24E]=true,[0x24F]=true}
end
-- New Mauville (rated a cave; it is a power plant's rooms and corridors in
-- the black): its own drawn walls stand (Gen3Scene), the shell leaves only a
-- low lip round each room
M.VOID_BY_MAP.EM_NEW_MAUVILLE_INSIDE={[0x208]=true}
-- the Frontier's lounges: the two black cut corners at the room's foot
for n=1,9 do M.VOID_BY_MAP['EM_BATTLE_FRONTIER_LOUNGE'..n]={[0x001]=true} end
-- the Trick House's corridor: an L of passage in black padding
M.VOID_BY_MAP.EM_ROUTE110_TRICK_HOUSE_CORRIDOR={[0x201]=true}
-- more rooms with black padding inside their map (the cut corners of the
-- link rooms, the Hall of Fame and the Frontier's shops, the black beside
-- Mauville Gym's floor and between Petalburg Gym's rooms, Mt. Pyre 1F's
-- outside): found by scanning every indoor map for all-black tiles
for id,mid in pairs({EM_BATTLE_COLOSSEUM_2P=0x201,EM_BATTLE_COLOSSEUM_4P=0x201,EM_TRADE_CENTER=0x201,EM_RECORD_CORNER=0x201,
  EM_EVER_GRANDE_CITY_HALL_OF_FAME=0x201,EM_UNION_ROOM=0x001,EM_BATTLE_FRONTIER_EXCHANGE_SERVICE_CORNER=0x001,
  EM_BATTLE_FRONTIER_SCOTTS_HOUSE=0x001,EM_EVER_GRANDE_CITY_CHAMPIONS_ROOM=0x001,EM_MAUVILLE_CITY_GYM=0x001,
  EM_PETALBURG_CITY_GYM=0x208,EM_MT_PYRE_1F=0x201,EM_SAFARI_ZONE_REST_HOUSE=0x001})do M.VOID_BY_MAP[id]={[mid]=true} end
-- rooms whose drawn walls are taller than the usual shell
M.HEIGHT_BY_MAP={EM_BATTLE_FRONTIER_BATTLE_DOME_CORRIDOR=68,EM_BATTLE_FRONTIER_BATTLE_ARENA_CORRIDOR=52,
 EM_BATTLE_FRONTIER_BATTLE_FACTORY_PRE_BATTLE_ROOM=100,EM_BATTLE_FRONTIER_BATTLE_TOWER_ELEVATOR=44,
 EM_LILYCOVE_CITY_HARBOR=68,EM_SLATEPORT_CITY_HARBOR=68,
 -- (the Pyramid's lobby: a floor 48 px up at the back, Gen3Decks)
 EM_BATTLE_FRONTIER_BATTLE_PYRAMID_LOBBY=88}
-- Ever Grande's halls between the Elite Four: the stairs climb to a landing 48 px up (Gen3Elevation
-- DAIS), and in first person the eye on them rose over a 40 px shell into the black
for n=1,5 do M.HEIGHT_BY_MAP['EM_EVER_GRANDE_CITY_HALL'..n]=96 end
-- rooms whose north wall drawing is this many rows: the shell's back sits
-- right behind the standing wall, no floor behind it
M.BACK_BY_MAP={EM_BATTLE_FRONTIER_BATTLE_PYRAMID_LOBBY=8,EM_LILYCOVE_CITY_HARBOR=4,EM_SLATEPORT_CITY_HARBOR=4,EM_BATTLE_FRONTIER_BATTLE_FACTORY_BATTLE_ROOM=2,EM_BATTLE_FRONTIER_BATTLE_TOWER_ELEVATOR=3,EM_BATTLE_FRONTIER_BATTLE_DOME_CORRIDOR=4,
 EM_BATTLE_FRONTIER_BATTLE_ARENA_CORRIDOR=3,EM_BATTLE_FRONTIER_BATTLE_FACTORY_PRE_BATTLE_ROOM=4}
-- maps whose rooms are islands in the void: their own drawn walls stand; the
-- shell only leaves a low lip round each island, and no ceiling
M.VOID_ISLANDS={EM_MOSSDEEP_CITY_GYM=true,EM_NEW_MAUVILLE_INSIDE=true}
function M.profile(def,gen)
 if not def then return end
 local id=def.id or '';local ts=def.tileset or '';local spec
 local cave=gen==1 and ts=='CAVERN' or gen==2 and def.environment=='CAVE' or gen==3 and (tonumber(def.mapType)==4 or tonumber(def.mapType)==9)
 if gen==3 then
  if tonumber(def.mapType)~=8 and not cave then return end
  -- a room under open sky (Lilycove Department Store's rooftop): no shell
  if id:find('DEPARTMENT_STORE_ROOFTOP') or id=='EM_TRAINER_HILL_ROOF' then return end
  -- the Battle Pyramid's top: the pyramid under the evening sky (Gen3Decks)
  if id:find('BATTLE_PYRAMID_TOP') then return end
  local pair=def.midLayout and def.midLayout.pair
  if not pair then return end
  spec=V.require('Gen3Tilesets').resolve(pair,require('src.import.gba.versions').TILESET_PAIRS)
  -- the Abandoned Ship (rated "underground"): its cabins and corridors are a
  -- ship's rooms, not a cave; its open deck takes no shell at all
  if id:find('ABANDONED_SHIP') then
   if id:find('DECK') then return end
   cave=false;spec={primary='general',secondary='rom_082d4d94',ship=true}
  end
  if id=='EM_NEW_MAUVILLE_INSIDE' then cave=false end
  -- two rooms are drawn with the General primary (Mauville Bike Shop,
  -- Mossdeep Space Center); other General indoor maps (the Fossil Maniac's
  -- tunnel, the truck, the S.S. Tidal) are not house-like rooms
  local generalRoom=spec.primary=='general' and (spec.secondary=='bike_shop' or spec.secondary=='facility' or spec.secondary=='battle_palace' or spec.secondary=='battle_frontier'
   or spec.secondary=='contest' or spec.secondary=='inside_of_truck' or spec.secondary=='inside_ship' or spec.secondary=='battle_tent')
  if not cave and spec.primary~='building' and not generalRoom and spec.secondary~='rom_082d4d94' then return end
 elseif gen==2 then
  if def.environment~='INDOOR' and def.environment~='GATE' and not cave then return end
 else
  -- Buildings and caves are enclosed; outdoor maps keep their scenery.
  --
  -- SHIP, CEMETERY and MANSION were missing here and every map that uses them
  -- was getting no room at all, so no ceiling: the S.S. Anne (12 maps), the
  -- Pokemon Tower (8) and the Celadon Mansion (5) all rendered as a black void
  -- in BOTH cameras. Confirmed against the data -- all 25 are interior maps
  -- with connections = {}.
  --
  -- Deliberately NOT a "no connections means a room" rule: 186 of 222 Gen 1
  -- maps have no connections, and that set includes genuinely outdoor
  -- tilesets (SHIP_PORT, PLATEAU, FOREST, UNDERGROUND), which would have put
  -- a lid over open ground.
  local allowed={REDS_HOUSE_1=true,REDS_HOUSE_2=true,HOUSE=true,HOUSE_1=true,
   HOUSE_2=true,MART=true,POKECENTER=true,DOJO=true,GYM=true,CLUB=true,
   LOBBY=true,LAB=true,FACILITY=true,INTERIOR=true,GATE=true,
   FOREST_GATE=true,MUSEUM=true,BEACH_HOUSE=true,
   SHIP=true,CEMETERY=true,MANSION=true}
  if not allowed[ts] and not cave then return end
 end
 local name=(id..' '..ts):upper()
 local theme=name:find('MART') and 'shop' or name:find('CENTER') and 'center' or name:find('LAB') and 'lab' or 'home'
 if spec and spec.secondary=='rom_082d4d94' then theme='ship' end
 -- the S.S. Tidal's cabins and decks: a ship's bare walls
 if spec and spec.secondary=='inside_ship' then theme='ship' end
 -- the moving truck: bare walls, no house windows
 if spec and spec.secondary=='inside_of_truck' then theme='ship' end
 if id:find('MT_PYRE') then theme='pyre' end
 if id=='EM_NEW_MAUVILLE_INSIDE' then theme='void' end
 -- the Battle Pyramid's floors: a maze in the dark, not a house with lit windows
 if id:find('BATTLE_PYRAMID_FLOOR') then theme='void' end
 -- Fortree's treehouses (five houses, the Decoration Shop, Route 119's
 -- house): the room is the inside of the tree, its back wall the orange
 -- planks 0x3C9 -- the shell takes their colours and is no taller, so no
 -- beige house wall shows round the planks (its back stays at row 0: the
 -- cabinet 0x3E0 against the wall stands in row 1)
 if gen==3 and def.midLayout and tostring(def.midLayout.pair):find('generic_building') then
  for y=0,math.min(1,def.height-1) do for x=0,def.width-1 do
   if def.midLayout:midAt(x,y)==0x3C9 then theme='tree' end
  end end
 end
 if cave then theme=(name:find('ICE') or name:find('SEAFOAM')) and 'ice' or 'cave' end
 -- a secret base in a shrub or a tree: leaves round it, not rock
 if id:find('SECRET_BASE_SHRUB') or id:find('SECRET_BASE_TREE') then theme='bush' end
 local unit=gen==3 and 16 or 32
 local b={0,0,def.width*unit,def.height*unit}
 local voidCells
 if gen==3 and not cave then
  -- Native layouts include padded black cells. Do not enclose that padding.
  local x0,z0,x1,z1=def.width,def.height,0,0
  local void=M.VOID_BY_MAP[def.id or '']
  for y=0,def.height-1 do for x=0,def.width-1 do
   local mid=def.midLayout:midAt(x,y)
   if mid and void and void[mid] then voidCells=voidCells or {};voidCells[x..':'..y]=true
   elseif mid and mid~=0 and mid~=8 and mid~=0x1A and mid~=0x1B and mid~=0x1C then
    x0,z0,x1,z1=math.min(x0,x),math.min(z0,y),math.max(x1,x+1),math.max(z1,y+1)
   end
  end end
  if x1<=x0 or z1<=z0 then return end
  b={x0*16,z0*16,x1*16,z1*16}
  local secondary=V.require('Gen3Tilesets').resolve(def.midLayout.pair,require('src.import.gba.versions').TILESET_PAIRS).secondary
  if secondary=='lab' or secondary=='pokemon_center' or def.midLayout.pair=='player_house' or def.midLayout.pair=='house' or theme=='shop' or secondary=='rom_082d4d94' or secondary=='inside_ship' or secondary=='bike_shop' or secondary=='facility' or (secondary=='generic_building' and theme~='tree') then
   -- The first two rows are the north wall drawing, not extra floor behind
   -- the cabinets. Its continuous backing sits just behind the native facade.
   b[2]=math.min(b[4]-16,(z0+2)*16)-.12
  end
  if def.midLayout.pair=='general__contest' then
   -- the link Contest Hall: one row of back wall drawing
   b[2]=math.min(b[4]-16,(z0+1)*16)-.12
  end
  if def.midLayout.pair=='general__battle_frontier' then
   -- the Reception Gate: two rows of north wall drawing
   b[2]=math.min(b[4]-16,(z0+2)*16)-.12
  end
  if secondary=='battle_tent' then
   -- the Battle Tents: two rows of north wall drawing
   b[2]=math.min(b[4]-16,(z0+2)*16)-.12
  end
  if def.midLayout.pair=='general__battle_palace' then
   -- the Battle Palace battle room: its north wall drawing stands from row 0;
   -- the backing sits behind the exit door's two rows
   b[2]=math.min(b[4]-16,(z0+2)*16)-.12
  end
  if secondary=='brendans_mays_house' then
   -- the player's house: its wall art stands from row 1 (row 0 is the wall's
   -- top drawn flat); the shell's back sits right behind it
   b[2]=math.min(b[4]-16,(z0+1)*16)-.12
  end
  if M.BACK_BY_MAP[def.id or ''] then b[2]=math.min(b[4]-16,(z0+M.BACK_BY_MAP[def.id])*16)-.12 end
  -- a staircase doorway in the back wall (Gen3WallStairs) must stay in the
  -- room: the shell's back goes no further forward than its row
  do
   local WS=V.require('Gen3WallStairs');local t=WS.CELLS[def.midLayout.pair or '']
   if t then
    for y=z0,math.min(z1-1,z0+3) do for x=x0,x1-1 do
     local mid=def.midLayout:midAt(x,y);local cell=def.midLayout:cellAt(x,y)
     if t[mid] and cell and cell.coll~=7 then b[2]=math.min(b[2],y*16-.12) end
    end end
   end
  end
 elseif gen==2 then
  local fronts={TILESET_PLAYERS_HOUSE=16,TILESET_PLAYERS_ROOM=16,TILESET_HOUSE=16,TILESET_LAB=16,TILESET_POKECENTER=16}
  if fronts[ts]then b[2]=fronts[ts]-.3 end
 end
 local artWalls,southWalls
 local cab=M.CABINS[id]
 if cab then
  -- the drawn north walls: wall cells with the room's floor at their foot
  -- (a wall drawn along a room's south edge has the void at its foot)
  local walls=V.require('Gen3EmeraldInteriors')[cab.walls].walls
  local function isWall(x,y)
   local mid=def.midLayout:midAt(x,y)
   return mid and walls[mid] and not (voidCells and voidCells[x..':'..y]) and (def.midLayout:collAt(x,y) or 0)~=0
  end
  artWalls={}
  for y=0,def.height-1 do for x=0,def.width-1 do
   if isWall(x,y) then
    local f=y+1
    while f<def.height and isWall(x,f) do f=f+1 end
    if f<def.height and def.midLayout:midAt(x,f) and not (voidCells and voidCells[x..':'..f]) then artWalls[x..':'..y]=true
    else southWalls=southWalls or {};southWalls[x..':'..y]=true end
   end
  end end
  if cab.theme then theme=cab.theme end
 end
 -- a cave whose floors stand on several levels (Gen3StairTerraces, read from
 -- its drawing): the shell's ceiling clears its highest floor
 local caveHeight
 if cave and gen==3 then
  local okS,StairT=pcall(V.require,'Gen3StairTerraces')
  local t=okS and type(StairT)=='table' and StairT[id]
  if t and t.cave then
   local top=0
   for _,row in ipairs(t.pins)do top=math.max(top,row[3]) end
   caveHeight=math.max(96,top*(t.rise or StairT.rise or 16)+72)
  end
 end
 return {artWalls=artWalls,southWalls=southWalls,noOpen=cab and cab.noOpen or nil,bounds=b,height=M.HEIGHT_BY_MAP[id] or cab and cab.h or caveHeight or cave and 96 or gen==3 and (theme=='lab' or theme=='center' or theme=='tree') and 32 or 40,theme=theme,gen=gen,cave=cave,voidCells=voidCells,voidIslands=M.VOID_ISLANDS[def.id or ''] or nil,artBack=(M.BACK_BY_MAP[def.id or ''] or cab) and true or nil,
  capSwatch=cab and cab.cap or nil,thick=cab and cab.thick or nil}
end
local function texture(theme)
 if materials[theme]then return materials[theme]end
 local data=love.image.newImageData(8,1)
 local colors=themes[theme]
 for i=1,8 do local c=colors[(i-1)%4+1];local shade=i>4 and .84 or 1
  data:setPixel(i-1,0,c[1]*shade,c[2]*shade,c[3]*shade,1)
 end
 local image=love.graphics.newImage(data);image:setFilter('nearest','nearest');data:release();materials[theme]=image;return image
end
-- A cave's surround (the strata past its footprint and its ceiling) is one flat
-- dark tone: the darkest common colour of the map's own wall tiles, at a
-- quarter of its brightness. Rock inside the footprint is Gen3Cave's own.
local function surroundColour(def)
 local L=def.midLayout;local Tiles=require('src.core.game3.tileset_native')
 local ts=Tiles._pairs and Tiles._pairs[L.pair] or Tiles.get(L.pair)
 if not ts or not ts.imageData or not ts.midToSlot then return end
 local seen,walls={},{}
 for y=0,def.height-1 do for x=0,def.width-1 do
  if (L:collAt(x,y) or 0)==7 then
   local mid=L:midAt(x,y)
   if mid and not seen[mid] and ts.midToSlot[mid] then seen[mid]=true;walls[#walls+1]=mid end
  end
 end end
 local count,total={},0
 for _,mid in ipairs(walls)do
  local slot=ts.midToSlot[mid];local px,py=slot%ts.cols*16,math.floor(slot/ts.cols)*16
  for sy=0,15 do for sx=0,15 do
   local r,g,b,a=ts.imageData:getPixel(px+sx,py+sy)
   if a>0 then
    local key=math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)
    count[key]=(count[key] or 0)+1;total=total+1
   end
  end end
 end
 local best
 for key,n in pairs(count)do
  if n>=math.max(1,total*.02)then
   local r,g,b=math.floor(key/65536),math.floor(key/256)%256,key%256
   local lum=.299*r+.587*g+.114*b
   if not best or lum<best.lum then best={lum=lum,r=r,g=g,b=b} end
  end
 end
 if not best then return end
 return {best.r/255*.25,best.g/255*.25,best.b/255*.25}
end
local function surroundTexture(c)
 local data=love.image.newImageData(8,1)
 for i=0,7 do data:setPixel(i,0,c[1],c[2],c[3],1)end
 local image=love.graphics.newImage(data);image:setFilter('nearest','nearest');data:release();return image
end
function M.geometry(p,side,opened)
 local b,h=p.bounds,p.height;local x0,z0,x1,z1=b[1],b[2],b[3],b[4]
 local verts,indices={},{}
 local function face(points,swatch,shade)
  local n=#verts
  for _,a in ipairs(points)do verts[#verts+1]={a[1],a[2],a[3],(swatch-.5)/8,.5,shade or 1}end
  for _,k in ipairs({1,2,3,1,3,4})do indices[#indices+1]=n+k end
 end
 local function box(a,y0,c,d,y1,f,swatch)
  face({{a,y1,c},{d,y1,c},{d,y1,f},{a,y1,f}},swatch,1)
  face({{a,y1,f},{d,y1,f},{d,y0,f},{a,y0,f}},swatch,.9)
  face({{d,y1,c},{a,y1,c},{a,y0,c},{d,y0,c}},swatch,.9)
  face({{a,y1,c},{a,y1,f},{a,y0,f},{a,y0,c}},swatch,.85)
  face({{d,y1,f},{d,y1,c},{d,y0,c},{d,y0,f}},swatch,.85)
 end
 if side==5 then
  -- The diorama plinth must not seal modeled stairs/escalators below floor.
  local xs,zs={x0-3,x1+3},{z0-3,z1+3}
  for _,q in ipairs(p.openings or {})do
   xs[#xs+1]=math.max(x0-3,math.min(x1+3,q[1]));xs[#xs+1]=math.max(x0-3,math.min(x1+3,q[3]))
   zs[#zs+1]=math.max(z0-3,math.min(z1+3,q[2]));zs[#zs+1]=math.max(z0-3,math.min(z1+3,q[4]))
  end
  -- (and under the room's void: the black outside shows there)
  for key in pairs(p.voidCells or {})do
   local vx,vy=key:match('(-?%d+):(-?%d+)');vx,vy=tonumber(vx)*16,tonumber(vy)*16
   for _,v in ipairs({vx,vx+16})do if v>x0-3 and v<x1+3 then xs[#xs+1]=v end end
   for _,v in ipairs({vy,vy+16})do if v>z0-3 and v<z1+3 then zs[#zs+1]=v end end
  end
  table.sort(xs);table.sort(zs)
  for i=1,#xs-1 do for j=1,#zs-1 do
   local a,c,d,f=xs[i],zs[j],xs[i+1],zs[j+1];local cut=false
   if p.voidCells then
    -- (the margin round the bounds belongs to the edge cell beside it)
    local mx=math.max(x0+1,math.min(x1-1,(a+d)/2));local mz=math.max(z0+1,math.min(z1-1,(c+f)/2))
    if p.voidCells[math.floor(mx/16)..':'..math.floor(mz/16)] then cut=true end
   end
   for _,q in ipairs(p.openings or {})do
    if (a+d)/2>q[1] and (a+d)/2<q[3] and (c+f)/2>q[2] and (c+f)/2<q[4]then cut=true;break end
   end
   if not cut and d>a and f>c then box(a,-4,c,d,-.25,f,3)end
  end end
 elseif side==6 then
  if not p.voidIslands then face({{x0,h,z0},{x1,h,z0},{x1,h,z1},{x0,h,z1}},1) end
 else
  local horizontal=side==1 or side==3
  local start,finish=horizontal and x0 or z0,horizontal and x1 or z1
  local line=side==1 and z0 or side==3 and z1 or side==2 and x1 or x0
  local outward=(side==1 or side==4)and -1 or 1
  local function part(a,y0,c,y1,swatch,depth,at)
   local function strip(l,r,at)
    -- (p.thick: the wall's own thickness; a deeper part stands that much proud of it)
    local near,far=at-outward*math.max(0,(depth or 3)-3),at+outward*math.max(depth or 3,p.thick or 3)
    if horizontal then box(l,y0,math.min(near,far),r,y1,math.max(near,far),swatch)
    else box(math.min(near,far),y0,l,math.max(near,far),y1,r,swatch)end
   end
   if at then strip(a,c,at)
   elseif side==1 and p.northFront then
    local cuts={a,c}
    for _,q in ipairs(p.northRecesses)do
     for _,x in ipairs({q[1],q[2]})do if x>a and x<c then cuts[#cuts+1]=x end end
    end
    table.sort(cuts)
    for i=1,#cuts-1 do
     local l,r=cuts[i],cuts[i+1];local at=p.northFront
     for _,q in ipairs(p.northRecesses)do if (l+r)/2>q[1] and (l+r)/2<q[2]then at=q[3]end end
     if r>l then strip(l,r,at)end
    end
   else strip(a,c,line)end
  end
  if side==1 and p.northFront then
   -- Closed returns around the stair bay, with backing behind the flight.
   -- Keeping the original front across this cell hid the entire staircase.
   for _,q in ipairs(p.northRecesses)do for _,x in ipairs({q[1],q[2]})do
    if x>start and x<finish then box(x-.3,opened and -3 or 0,q[3]-3,x+.3,opened and 0 or h,p.northFront,2)end
   end end
  end
  if opened then
   -- A low continuous foundation presents a finished cut edge without
   -- covering sprites, the entry mat, or interaction targets.
   if p.voidCells then
    local edge=horizontal and (side==1 and math.floor((z0+.5)/16) or math.floor((z1-.5)/16))
     or (side==4 and math.floor((x0+.5)/16) or math.floor((x1-.5)/16))
    local l
    for a=start,finish,16 do
     local k=math.floor((a+.5)/16)
     local open=a<finish and not (horizontal and p.voidCells[k..':'..edge] or not horizontal and p.voidCells[edge..':'..k])
     if open and not l then l=a elseif not open and l then part(l,-3,math.min(a,finish),0,3);l=nil end
    end
    -- (the side starts a hair off the cell grid where the back sits behind a drawn wall: close the last run)
    if l then part(l,-3,finish,0,3) end
   else part(start,-3,finish,0,3) end
  elseif p.cave then
   -- Continuous stone strata with a closed back, all outside the playable
   -- footprint. Native maze walls stay in front; no house trim or windows.
   for a=start,finish-1,16 do
    local c=math.min(finish,a+16)
    local floor,lintel=-4,-4
    for _,q in ipairs(p.passages and p.passages[side] or {})do
     if a<q[2] and c>q[1]then floor=q[3];lintel=math.max(lintel,floor+32)end
    end
    if lintel>-4 and floor>0 then part(a,-4,c,floor,3)end
    for y=lintel,h-1,12 do
     local band=math.floor(y/12);local swatch=1+(math.floor(a/16)*13+band*7+side*11)%3
     part(a,y,c,math.min(h,y+12),swatch,3+((math.floor(a/16)+band+side)%3)*.4)
    end
   end
  else
   -- one run of wall: its bands, and posts at both ends
   -- Recessed luminous wall panels: narrow mullions preserve pixel-art furniture as the visual focus.
   -- Side walls, and the south wall - seen only from inside in first person: the cartridge never draws
   -- it, and bare it was one flat colour filling the view (the Elite Four's rooms, the houses' fronts).
   -- (per run of wall, so walls built round void cells get them too)
   local function panels(l,r,at)
    if not (side==2 or side==3 or side==4) or p.theme=='ship' or p.theme=='tree' or p.theme=='pyre' or r-l<40 then return end
    local ln=at or line
    -- (one panel per ~72 px of wall, at least two: a wide hall's wall stood bare between two)
    local n=math.max(2,math.floor((r-l)/72))
    -- (a tall shell - Ever Grande's 96 px stair halls - gets a row of panels every 40 px of height)
    local rows=math.max(1,math.floor(((p.height or 40)-8)/40))
    for i=1,n do local c=l+(r-l)*((i-.5)/n)
     local function panel(lo,hi,y0,y1,swatch,offset)
      local q=ln-outward*offset
      if horizontal then face({{hi,y1,q},{lo,y1,q},{lo,y0,q},{hi,y0,q}},swatch)
      else face({{q,y1,lo},{q,y1,hi},{q,y0,hi},{q,y0,lo}},swatch) end
     end
     for k=0,rows-1 do local o=k*40
      panel(c-6,c+6,14+o,33+o,3,.12)
      panel(c-5,c+5,15+o,32+o,4,.18)
      panel(c-.4,c+.4,15+o,32+o,2,.25)
      panel(c-5,c+5,23+o,24+o,2,.25)
     end
    end
   end
   local function run(l,r,at)
    if p.voidIslands then part(l,-3,r,0,3,nil,at);return end
    panels(l,r,at)
    -- (a back wall that is all drawn art -- BACK_BY_MAP -- takes no skirting
    -- or posts of the shell's own: they would stand in front of the drawing)
    if side==1 and p.artBack and not at then
     part(l,0,r,h-2,1,nil,at)
     part(l,h-2,r,h+1.2,p.capSwatch or 3,3,at)
     return
    end
    part(l,8,r,h-3.5,1,nil,at)
    part(l,0,r,7,2,3.3,at)
    part(l,7,r,8,3,3.6,at)
    part(l,h-2,r,h+1.2,p.capSwatch or 3,4,at)
    part(l,h-3.5,r,h-2,2,3.5,at)
    for _,a in ipairs({l,r-2})do part(a,0,a+2,h,2,3.6,at)end
   end
   local V2=p.voidCells
   if not V2 then run(start,finish)
   else
    -- the shell's own side, cut where the room's edge cell is void
    local function isVoid(x,y)return V2[x..':'..y] end
    local edge=horizontal and (side==1 and math.floor((z0+.5)/16) or math.floor((z1-.5)/16))
     or (side==4 and math.floor((x0+.5)/16) or math.floor((x1-.5)/16))
    local l
    for a=start,finish,16 do
     local k=math.floor((a+.5)/16)
     local open=a<finish and not (horizontal and isVoid(k,edge) or not horizontal and isVoid(edge,k))
     if open and not l then l=a elseif not open and l then run(l,math.min(a,finish));l=nil end
    end
    if l then run(l,finish) end
    -- walls where the room meets its void, facing this side's way
    local dx,dz=({0,1,0,-1})[side],({-1,0,1,0})[side]
    local runs={}
    for key in pairs(V2)do
     local vx,vy=key:match('(-?%d+):(-?%d+)');vx,vy=tonumber(vx),tonumber(vy)
     local rx,ry=vx-dx,vy-dz      -- the room cell on the near side of this void cell
     if not isVoid(rx,ry) and rx*16>=x0-.5 and rx*16<x1 and ry*16>=z0-16 and ry*16<z1
       and not (p.artWalls and p.artWalls[rx..':'..ry])
       -- (a wall drawn along a room's south edge is that wall: none behind it)
       and not (side==3 and p.southWalls and p.southWalls[rx..':'..ry]) then
      local at=horizontal and (dz<0 and vy*16+16 or vy*16) or (dx<0 and vx*16+16 or vx*16)
      local along=horizontal and rx or ry
      runs[#runs+1]={at,along}
     end
    end
    table.sort(runs,function(u,v)return u[1]==v[1] and u[2]<v[2] or u[1]<v[1] end)
    local i=1
    while runs[i] do
     local j=i
     while runs[j+1] and runs[j+1][1]==runs[i][1] and runs[j+1][2]==runs[j][2]+1 do j=j+1 end
     -- (a stub of wall that runs into a side the camera has opened -- the
     -- cheeks of the entrance notch, a cut corner -- is lowered with it)
     local l,r=runs[i][2]*16,(runs[j][2]+1)*16
     local O=p.openedSides or {}
     local low=horizontal and ((O[4] and l<=x0+.5) or (O[2] and r>=x1-.5)) or not horizontal and ((O[1] and l<=z0+.5) or (O[3] and r>=z1-.5))
     if low then part(l,-3,r,0,3,nil,runs[i][1]) else run(l,r,runs[i][1]) end
     i=j+1
    end
    goto donewalls
   end
   ::donewalls::
  end
 end
 return verts,indices
end
function M.forMap(map,gen)
 local def=map and map.def or map
 if not def then return end
 local entry=cache[def]
 if entry~=nil then return entry or nil end
 local p=M.profile(def,gen)
 if not p then cache[def]=false;return end
 if p.cave then
  local field=gen==2 and V.require('Gen2Elevation').field(map) or gen==3 and V.require('Gen3Elevation').field(def)
  for _,c in pairs(field and field.cells or {})do p.height=math.max(p.height,(c.high or c.height or 0)+64)end
  -- Only native exits/connections open the shell. Several cave boundary
  -- drawings use walkable collision despite being walls. Interior warp
  -- stairs retain their separate floor cut.
  p.passages={{},{},{},{}}
  local w,h=def.width*(gen==3 and 1 or 2),def.height*(gen==3 and 1 or 2)
  local function passage(side,x,y,along)
   local walk
   if gen==3 then local cell=def.midLayout:cellAt(x,y);walk=cell and cell.coll~=7
   else walk=map.isWalkableCell and map:isWalkableCell(x,y) or map.isWaterCell and map:isWaterCell(x,y)end
   local exit=false
   for _,warp in ipairs(def.warps or {})do
    if warp.x==x and warp.y==y then exit=true;break end
   end
   -- Connected cave maps may expose a walkable seam without a warp event.
   local direction=({'north','east','south','west'})[side]
   for key,connection in pairs(def.connections or {})do
    if key==direction or connection.direction==direction then exit=true;break end
   end
   if walk and exit then
    local c=field and field.cells[x..':'..y]
    p.passages[side][#p.passages[side]+1]={along*16,(along+1)*16,c and c.height or 0}
   end
  end
  for x=0,w-1 do passage(1,x,0,x);passage(3,x,h-1,x)end
  for y=0,h-1 do passage(4,0,y,y);passage(2,w-1,y,y)end
 end
 if gen~=3 and type(map.tileAt)=='function' and type(map.tileset)=='table' then
  -- The room's foundation used to seal GB stairwells at y=-.25, hiding
  -- every descending tread. Use the same semantic openings as the mesher.
  local Shapes=V.require('TileShape');local shapes=Shapes.forMap(map)
  p.openings={};p.northRecesses={}
  for y=0,(map.heightCells or def.height*2)-1 do for x=0,(map.widthCells or def.width*2)-1 do
   local s=Shapes.at(map,shapes,map:tileAt(x*2,y*2),x*2,y*2)
   local c=s and s.class or ''
   if c:match('^stair_') and y*16<p.bounds[2]then
    p.northRecesses[#p.northRecesses+1]={x*16,(x+1)*16,y*16-.3}
   end
   if c=='ladder_down' or c:match('^stair_down_')then
    p.openings[#p.openings+1]={x*16,y*16,(x+1)*16,(y+1)*16}
   end
  end end
  if #p.northRecesses>0 then
   p.northFront=p.bounds[2]
   for _,q in ipairs(p.northRecesses)do p.bounds[2]=math.min(p.bounds[2],q[3])end
  end
 end
 -- a Gen3 cave (mapType 4): its surround is dark, not the beige strata
 if p.cave and gen==3 and tonumber(def.mapType)==4 then
  local c=surroundColour(def) or {themes.cave[3][1]*.25,themes.cave[3][2]*.25,themes.cave[3][3]*.25}
  p.surround=surroundTexture(c)
 end
 p.meshes={};cache[def]=p;return p
end
function M.setOpenings(p,openings)
 if not p then return end
 local keys={};for _,q in ipairs(openings or {})do keys[#keys+1]=table.concat(q,',')end;table.sort(keys)
 local signature=table.concat(keys,';')
 if signature==p.openingSignature then return end
 p.openingSignature=signature;p.openings=openings
 for key,mesh in pairs(p.meshes or {})do if key:match('^5:')then mesh:release();p.meshes[key]=nil end end
end
function M.camera(p,angle,aspect)
 if not p or p.cave then return end
 local b=p.bounds;local w,d=b[3]-b[1],b[4]-b[2]
 -- Compact rooms read as complete dioramas; large halls keep the player's
 -- scrolling camera. Free/first-person cameras never call this helper.
 if w>320 or d>256 then return end
 local a=math.max(.01,math.min(math.rad(75),angle or math.rad(35)))
 local fov=math.rad(48);local h=p.height
 local extent=math.max((w+10)*.5/math.max(.5,aspect or 1.5),(d*math.cos(a)+h*math.sin(a))*.5)
 local distance=extent/math.tan(fov*.5)+(d*math.sin(a)+h*math.cos(a))*.5+10
 local x,z=(b[1]+b[3])*.5,(b[2]+b[4])*.5
 return {eye={x,h*.35+distance*math.cos(a),z+distance*math.sin(a)},focus={x,h*.35,z},fov=fov,curve=0}
end
function M.configure(p)
 V.require('Voxel3D').interior=p
end
function M.draw(p)
 if not p then return end
 local R=V.require('Voxel3D');local eye=R.eye or {0,100,1000};local b=p.bounds
 local inside=eye[1]>b[1] and eye[1]<b[3] and eye[3]>b[2] and eye[3]<b[4] and eye[2]<p.height-.05
 local opened={not inside and eye[3]<b[2],not inside and eye[1]>b[3],not inside and eye[3]>b[4],not inside and eye[1]<b[1]}
 if not inside and not p.noOpen and not (opened[1] or opened[2] or opened[3] or opened[4])then
  -- Near-overhead cameras can project inside the footprint while still
  -- looking down from outside. Open their near wall too, without a ceiling.
  local dx,dz=(eye[1]-(b[1]+b[3])*.5)/(b[3]-b[1]),(eye[3]-(b[2]+b[4])*.5)/(b[4]-b[2])
  opened[math.abs(dx)>math.abs(dz) and (dx>0 and 2 or 4) or (dz<0 and 1 or 3)]=true
 end
 R.interiorClip(false)
 for side=1,inside and 6 or 5 do
  local key=side..':'..tostring(opened[side] or false)
  if p.voidCells then key=key..(opened[1] and 'n' or '')..(opened[2] and 'e' or '')..(opened[3] and 's' or '')..(opened[4] and 'w' or '') end
  p.openedSides=opened
  if not p.meshes[key]then local v,i=M.geometry(p,side,opened[side]);p.meshes[key]=R.newMesh(v,i)end
  R.draw(p.meshes[key],p.surround or texture(p.theme))
 end
 R.interiorClip(true)
end
return M
