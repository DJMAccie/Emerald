-- Physical support from native stair topology and reviewed source surfaces.
-- The cell elevation nibble is also a height field: on Emerald's terrace maps
-- (Mossdeep, Lilycove, Fortree, Route 114) it runs 3 = ground, each step up one
-- course higher, and an overlay of it matches the drawn terraces exactly. The
-- nibble only rates the walkable floor, so it is read where a cell is walkable:
--   e3 -> 0, e4 -> COURSE, e5 -> 2*COURSE, e7 -> 4*COURSE, e9 -> 6*COURSE
-- e1 water keeps sea level 0, and e0 (903 of Mossdeep's 917) is blocked rock or
-- the odd connector, so those cells inherit the nearest floor. Because floors of
-- different elevation must not merge into one group -- a group takes the median
-- pin of its cells -- the layer test below is exact.
-- Fortree walks three real storeys: an e4 ridge (row 4), an e15 walkway (row 14)
-- and e3 ground (rows 6-19). Its e15 is a "very high" marker, not twelve drawn
-- courses (its walkway sits about two above the ridge), so the storey count is
-- clamped: e15 lands on the tallest step. MAX_STEP=3 puts the three storeys at
-- 0 / 16 / 48, which is the drawn three-tier town.
local V=...
local Levels=V.require('TerrainLevels')
local Pairs=V.require('Gen3Tilesets')
local cache=setmetatable({},{__mode='k'})
local M={}
M.MAX_FLIGHT=4   -- longest straight run of e0 cells taken for a flight between two floors
M.COURSE=16
M.MAX_STEP=3
-- Per-map height of one nibble step, and nibble remaps. Fortree: its wooden
-- walkways (e4) run at treetop level, the top of the forest canopy mass
-- (Gen3Scene CANOPY_HEIGHT), and its e15 cells are the same walkway where it
-- bridges the path below (not a third storey).
M.COURSE_BY_MAP={EM_FORTREE_CITY=32,EM_ROUTE110=48}
-- Route 109's beach: the deck chairs (0x2E9/0x2F1) are rated e4 over the
-- e3 sand so the player walks round them; they are furniture on the sand, not
-- a ledge (furniture session)
M.ELEV_REMAP={EM_FORTREE_CITY={[15]=4},EM_ROUTE110={[15]=4},EM_ROUTE109={[4]=3},
 -- Route 119's log bridge: its span over the river (e15) is level with its ends (e4)
 EM_ROUTE119={[15]=4}}
-- Route 110: the Seaside Cycling Road is one deck, e4 over land and e15 over
-- the sea, 48 px up (its 32-row fascia on 16-row legs, Gen3CyclingRoad); the
-- three 0x2D4 stair rows by the north gate are one flight down to the ground
M.STEP_MIDS={EM_ROUTE110={[0x2D4]=true}}
-- (stepped decks: Gen3Decks; their stairs are flights between the decks)
for id,d in pairs(V.require('Gen3Decks').MAPS)do M.STEP_MIDS[id]=d.steps end
-- Treads per flight cell by tileset pair and mid: a copy of Gen3Scene's FLIGHT_TREADS (keep the two in step);
-- TerrainLevels stands an actor on the tread under its feet. Other flights use 4.
local FLIGHT_TREADS={general__mauville={[0x2D4]=8},general__mossdeep={[0xAF]=2,[0xCF]=2},general__lilycove={[0xAF]=2,[0xCF]=2},general__sootopolis={[0x244]=2,[0x245]=2}}
-- Raised room floors the cartridge draws but rates flat: rows y0..y1 stand h
-- px up, the rest of the walkable floor at 0. Trick House entrance: the
-- tatami (rows 0-6, its yellow lip and 8-row face drawn on row 6) over the
-- grey entry strip.
-- Daises the cartridge rates flat: every cell in a rect stands h px up (its
-- rim and edge tiles drawn flat at that height, so the dais's sides show the
-- rim's own art), the step ids are flights down to the floor. Lilycove
-- Contest Hall: the three stages (rim 0x20C-0x20E/0x224/0x226, judges' strip,
-- green stage, steps at the front), user via the furniture session.
M.DAIS={EM_LILYCOVE_CITY_CONTEST_HALL={h=10,rects={{18,7,32,16},{6,19,20,28},{30,19,44,28}},
 steps={[0x283]=true,[0x284]=true,[0x285]=true,[0x293]=true,[0x294]=true,[0x295]=true,[0x2B3]=true,[0x2B4]=true,[0x2B5]=true},
 -- (furniture: tiles on the stage that keep their furniture recipes, raised
 -- with it -- the white box with the gold clasp, the cushioned kerb round each
 -- stage floor; furniture session)
 furniture={[0x26F]=true,[0x277]=true,[0x268]=true,[0x269]=true,[0x26A]=true,[0x270]=true,[0x272]=true,[0x278]=true,[0x279]=true,[0x27A]=true}}}
-- Battle Arena lobby: the pale plank platform behind the reception, its
-- edge (0x21F/0x223-0x226, 0x215/0x216) and planks (0x201) stand 8 px up;
-- the plants, PC and machine on it keep their furniture (mids filter)
M.DAIS.EM_BATTLE_FRONTIER_BATTLE_ARENA_LOBBY={h=8,rects={{0,3,15,7}},steps={},
 mids={[0x201]=true,[0x21F]=true,[0x223]=true,[0x224]=true,[0x225]=true,[0x226]=true,[0x215]=true,[0x216]=true}}
-- Ever Grande's halls between the Elite Four rooms: a staircase climbing
-- north between orange rails to the landing (rows 3-4) before the next door,
-- over a dark drop (0x2E7) on both sides. steps apply map-wide (anySteps),
-- the drop and the landing's front ledge settle (low: to the foot).
do
 local hall={h=48,anySteps=true,steps={[0x2E1]=true,[0x2E2]=true,[0x2D9]=true,[0x2DA]=true},low={[0x2E7]=true}}
 for n=1,5 do local d={};for k,v in pairs(hall)do d[k]=v end;d.rects={{0,3,10,4}};M.DAIS['EM_EVER_GRANDE_CITY_HALL'..n]=d end
end
local function daisAt(d,x,y,mid)
 if d.mids and mid and not d.mids[mid] then return false end
 for _,r in ipairs(d.rects)do if x>=r[1] and x<=r[3] and y>=r[2] and y<=r[4] then return true end end
end
-- before props and stairs are claimed: the dais cells are flat stage, not
-- walls or relief props (the same ids are walls elsewhere in the tileset)
function M.daisPrepare(cells,def)
 local d=def and M.DAIS[def.id];if not d then return end
 for _,c in pairs(cells)do
  if daisAt(d,c.cx,c.cy,c.mid) then
   c.shape=d.steps[c.mid] and {kind='steps',height=6} or {kind='flat',reviewedSurface=true}
   if not (d.furniture and d.furniture[c.mid]) then c.noFurniture=true end
  elseif d.anySteps and d.steps[c.mid] then
   c.shape={kind='steps',height=6};c.noFurniture=true
  end
 end
end
-- after the heights are bound: the drop beside a raised walkway stays at the foot
function M.daisSettle(cells,def)
 local d=def and M.DAIS[def.id];if not d then return end
 if d.low then for _,c in pairs(cells)do if d.low[c.mid] then c.base=0 end end end
 -- furniture standing on the dais stands at its height (a piece at the
 -- dais's front edge would take the floor's height from the cell before it)
 if d.furniture then
  for _,c in pairs(cells)do
   if d.furniture[c.mid] and daisAt(d,c.cx,c.cy,c.mid) then
    c.base=d.h
    if c.prop then c.prop.groundHeight=d.h end
   end
  end
 end
end
M.RAISED={EM_ROUTE110_TRICK_HOUSE_ENTRANCE={y0=0,y1=6,h=8},
 EM_ROUTE111_OLD_LADYS_REST_STOP={y0=0,y1=6,h=8}}   -- same tatami step
M.MARKER_CELLS=4  -- walkable e15 patches this small are markers, not walkways
local blocked={{[0x30]=true,[0x34]=true,[0x36]=true},{[0x31]=true,[0x35]=true,[0x37]=true},
 {[0x33]=true,[0x36]=true,[0x37]=true},{[0x32]=true,[0x34]=true,[0x35]=true}}
local opposite={2,1,4,3}
function M.field(def)
 local l=def and def.midLayout;if not l then return end
 local keys={};for k in pairs(l.overrides or {})do keys[#keys+1]=k end;table.sort(keys)
 local edits={tostring(l.cells)};for _,k in ipairs(keys)do local c=l.overrides[k];edits[#edits+1]=table.concat({k,c.mid or 0,c.coll or 255,c.elev or 0},',')end
 local signature=table.concat(edits,';');local old=cache[l]
 if old and old.signature==signature then return old end
 local behaviors=require('src.core.game3.scripting.interaction_scripts').behaviors[l.pair]or{}
 local spec=Pairs.resolve(l.pair,require('src.import.gba.versions').TILESET_PAIRS)
 local shapes=V.require('Gen3TileShape')
 local drop={[0x38]={1,0},[0x39]={-1,0},[0x3A]={0,-1},[0x3B]={0,1}}
 local outdoor=Pairs.outdoor(def)
 local cave=def.mapType==4
 local deck=def.id=="FR_CERULEAN_CITY_GYM" or def.id=="FR_SSANNE_EXTERIOR" or def.id=="FR_THREE_ISLAND_PORT"
 local Terraces=V.require('Gen3EmeraldTerraces')
 local pins
 for _,row in ipairs(Terraces.enabled and (Terraces.on or {})[def.id] and Terraces.maps[def.id] or {})do pins=pins or {};pins[row[1]..':'..row[2]]=row[3]*Terraces.COURSE end
 -- generated platforms where stairs climb between floors the cartridge rates
 -- the same level (Gen3StairTerraces, tools/elevation/stair_platforms.py)
 local okS,StairT=pcall(V.require,'Gen3StairTerraces')
 local gen=okS and type(StairT)=='table' and Terraces.enabled and StairT[def.id] and ((Terraces.onStairs or {})[def.id] or StairT[def.id].cave or StairT[def.id].on) and StairT[def.id]
 local stairCells={}
 local zoneOf={}
 local keepRated=false
 if gen then
  for _,c in ipairs(gen.stairs)do stairCells[c[1]..':'..c[2]]=true end
  -- a pin row's flood. With on=true every row floods its floor (walkable cells of the same rating reached from
  -- the anchor without crossing a stair). A 'zone' row ({x,y,level,'zone',{x0,y0,x1,y1}?}) floods only its
  -- own floor - never across a jump ledge or water, and inside its box when it has one - and makes that floor
  -- a group of its own (the group test below compares zones): one connected floor of one rating can then
  -- hold several levels (Jagged Pass falls south through ledges and stairs on floors the cartridge rates all
  -- alike; Frontier West's walled garden sits a stair below the plaza), its height its own pins' median
  local function floodPin(zi,row,h)
   local a0=l:cellAt(row[1],row[2])
   local zone=row[4]=='zone';local box=zone and row[5]
   local function inZone(n,nx,ny)
    if not zone then return true end
    if box and (nx<box[1] or ny<box[2] or nx>box[3] or ny>box[4]) then return false end
    local beh=behaviors[n.mid]
    if beh and ((beh>=0x38 and beh<=0x3F) or beh==0x2A or beh==0x1D0) then return false end
    return shapes.of(spec.primary,spec.secondary,n.mid,beh,n.coll).kind~='water'
   end
   local stack,seen={{row[1],row[2]}},{[row[1]..':'..row[2]]=true}
   while #stack>0 do local q=table.remove(stack);pins[q[1]..':'..q[2]]=h
    if zone then zoneOf[q[1]..':'..q[2]]=zi end
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local nx,ny=q[1]+d[1],q[2]+d[2];local k=nx..':'..ny
     local n=not seen[k] and nx>=0 and ny>=0 and nx<l.width and ny<l.height and l:cellAt(nx,ny)
     if n and n.coll~=7 and n.elev==a0.elev and not stairCells[k] and n.mid~=0xAF and n.mid~=0xCF and n.mid~=0xE8 and inZone(n,nx,ny) then seen[k]=true;stack[#stack+1]={nx,ny} end
    end
   end
  end

  if gen.on then
   -- on=true: only the floors a stair moves against the cartridge's rating
   -- are listed; each pin covers its whole floor (walkable cells of the same
   -- rating reached from the anchor without crossing a stair), and every
   -- other cell keeps its rated height (keepRated below)
   pins=pins or {};keepRated=true
   for zi,row in ipairs(gen.pins)do floodPin(zi,row,row[3]*(gen.rise or 16)) end
   -- single cells at a level, no flood ({x,y,level} or a box {x0,y0,x1,y1,level}): the rock round a floor
   -- that moved off its rating, held where the drawing stands it (TerrainLevels seeds its support with them)
   for _,c in ipairs(gen.cells or {})do
    local x0,y0,x1,y1,lv=c[1],c[2],c[1],c[2],c[3]
    if c[5] then x1,y1,lv=c[3],c[4],c[5] end
    for y=y0,y1 do for x=x0,x1 do pins[x..':'..y]=lv*(gen.rise or 16) end end
   end
  else
   -- anchor-only map: a plain row pins its own cell; a 'zone' row still floods its floor as its own group
   for zi,row in ipairs(gen.pins)do pins=pins or {}
    local h=row[3]*(gen.rise or StairT.rise or Terraces.COURSE)
    if row[4]=='zone' then floodPin(zi,row,h) else pins[row[1]..':'..row[2]]=h end
   end
   for _,c in ipairs(gen.cells or {})do
    local x0,y0,x1,y1,lv=c[1],c[2],c[1],c[2],c[3]
    if c[5] then x1,y1,lv=c[3],c[4],c[5] end
    for y=y0,y1 do for x=x0,x1 do pins[x..':'..y]=lv*(gen.rise or StairT.rise or Terraces.COURSE) end end
   end
  end
 end
 local dais=M.DAIS[def.id]
 if dais then
  pins=pins or {}
  for y=0,l.height-1 do for x=0,l.width-1 do
   local raw=l:cellAt(x,y)
   if daisAt(dais,x,y,raw and raw.mid) then
    if not dais.steps[raw.mid] then pins[x..':'..y]=dais.h;stairCells[x..':'..y]=nil end
   elseif raw and raw.coll~=7 then pins[x..':'..y]=0 end
  end end
 end
 -- stepped decks (Gen3Decks): every cell of a deck at that deck's height
 local decks=V.require('Gen3Decks').MAPS[def.id]
 if decks then
  pins=pins or {}
  for y=0,l.height-1 do for x=0,l.width-1 do
   local raw=l:cellAt(x,y)
   local h=x<(decks.w or 1e9) and y<(decks.h or 1e9) and ((decks.pinAt and decks.pinAt(x,y)) or decks.wall(x,y) or decks.level(x,y))
   if h and raw and not (decks.steps[raw.mid] and raw.coll==0) then pins[x..':'..y]=h end
  end end
 end
 local raised=M.RAISED[def.id]
 -- any room of the shared house tileset with the tatami step: a row of the
 -- yellow edge 0x318 (13 rooms: Dewford, Lilycove, Lavaridge houses, Mr.
 -- Briney's, the cable car stations...). Rows down to it stand 8 up.
 if not raised and tostring(l.pair):find('generic_building') then
  for y=0,l.height-1 do
   local n=0
   for x=0,l.width-1 do local r=l:cellAt(x,y);if r and r.mid==0x318 then n=n+1 end end
   if n>=4 then raised={y0=0,y1=y,h=8};break end
  end
 end
 if raised then
  pins=pins or {}
  for y=0,l.height-1 do for x=0,l.width-1 do
   local raw=l:cellAt(x,y)
   if raw and raw.coll~=7 then pins[x..':'..y]=(y>=raised.y0 and y<=raised.y1) and raised.h or 0 end
  end end
 end
 -- A staircase is a strip of walkable elevation-0 cells with different levels
 -- at its ends (Route 114 14,49 joins an e3 floor to an e4 one). Emerald gives
 -- those cells no stair behaviour, so the solver would otherwise see one flat
 -- floor group and no flight at all. Only a cell whose walkable neighbours
 -- disagree about their level is claimed.
 -- Indoors, a tiny walkable patch rated above the floor (Brendan's 2F bed
 -- sides are e4) is furniture the player stands beside, not a terrace: it
 -- is floor level, and the e0 cells round it are not stairs.
 local flatIn={}
 if tonumber(def.mapType)==8 then
  local seen={}
  for y=0,l.height-1 do for x=0,l.width-1 do
   local raw=l:cellAt(x,y)
   if raw and raw.coll==0 and raw.elev>=4 and raw.elev~=15 and not seen[x..':'..y] then
    local list,stack={}, {{x,y}};seen[x..':'..y]=true
    while #stack>0 do local p=table.remove(stack);list[#list+1]=p
     for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
      local nx,ny=p[1]+d[1],p[2]+d[2];local n=l:cellAt(nx,ny)
      if n and n.coll==0 and n.elev==raw.elev and not seen[nx..':'..ny] then seen[nx..':'..ny]=true;stack[#stack+1]={nx,ny} end
     end
    end
    if #list<=M.MARKER_CELLS then for _,p in ipairs(list)do flatIn[p[1]..':'..p[2]]=3 end end
   end
  end end
 end
 local function elevAt(x,y,n)return flatIn[x..':'..y] or n.elev end
 local climb={}
 do
  local decks={{1,0},{-1,0},{0,1},{0,-1}}
  for y=0,l.height-1 do for x=0,l.width-1 do
   local raw=l:cellAt(x,y)
   if raw and raw.coll==0 and raw.elev==0 then
    local lo,hi
    for _,d in ipairs(decks)do
     local n=l:cellAt(x+d[1],y+d[2])
     if n and n.coll==0 and n.elev>=3 then local e=elevAt(x+d[1],y+d[2],n);lo=math.min(lo or e,e);hi=math.max(hi or e,e) end
    end
    if (lo and hi and hi>lo) or stairCells[x..':'..y] then climb[x..':'..y]=true end
   end
  end end
  -- A flight longer than one cell (Lilycove's two-row stairs): its cells touch only each other and the two floors
  -- at its ends, so no single cell sees both levels. A straight run of walkable e0 cells whose two ends meet
  -- floors of different level is a flight (rows or columns).
  local function flat(x,y)local r=l:cellAt(x,y);return r and r.coll==0 and r.elev==0 end
  local function floorAt(x,y)local r=l:cellAt(x,y);return r and r.coll==0 and r.elev>=3 and elevAt(x,y,r) or nil end
  for _,d in ipairs({{0,1},{1,0}})do
   for y=0,l.height-1 do for x=0,l.width-1 do
    if flat(x,y) and not flat(x-d[1],y-d[2]) then
     local n,ex,ey=0,x,y
     while flat(ex,ey) and n<=M.MAX_FLIGHT do n=n+1;ex,ey=ex+d[1],ey+d[2] end
     local a,b=floorAt(x-d[1],y-d[2]),floorAt(ex,ey)
     if a and b and a~=b and n<=M.MAX_FLIGHT and n>=2 then
      for k=0,n-1 do climb[(x+d[1]*k)..':'..(y+d[2]*k)]=true end
     end
    end
   end end
  end
 end
 -- ELEVATION_MULTI_LEVEL (15) is a marker, not a height. On a walkway or a
 -- bridge (Fortree, Routes 110/119/120) it borders cliffs, water or another
 -- level and stays raised. A small patch entirely surrounded by walkable
 -- ground of one level marks a spot an object stands on (Littleroot's two
 -- moving-van cells): it takes that level instead of rising as a pillar.
 local relevel={}
 do
  local seen={}
  local dirs={{1,0},{-1,0},{0,1},{0,-1}}
  for y=0,l.height-1 do for x=0,l.width-1 do
   local raw=l:cellAt(x,y)
   if raw and raw.coll==0 and raw.elev==15 and not seen[x..':'..y] then
    local list,stack={}, {{x,y}};seen[x..':'..y]=true
    local votes={}
    while #stack>0 do
     local p=table.remove(stack);list[#list+1]=p
     for _,d in ipairs(dirs)do
      local nx,ny=p[1]+d[1],p[2]+d[2];local n=l:cellAt(nx,ny)
      if n and n.coll==0 and n.elev==15 and not seen[nx..':'..ny] then seen[nx..':'..ny]=true;stack[#stack+1]={nx,ny}
      elseif n and n.coll==0 and n.elev>=3 and n.elev~=15 then votes[n.elev]=(votes[n.elev] or 0)+1
      elseif not (n and n.coll==0 and n.elev==15) then votes.open=true end   -- cliff, water, edge: a real deck
     end
    end
    -- a marker sits INSIDE flat ground: every neighbour walkable, one level
    local levels=0;local best
    for e in pairs(votes)do if e~='open' then levels=levels+1;best=e end end
    if #list<=M.MARKER_CELLS and not votes.open and levels==1 then
     for _,p in ipairs(list)do relevel[p[1]..':'..p[2]]=best end
    end
   end
  end end
 end
 -- A cave's bridge (walkable e15 cells spanning a lower passage: Victory
 -- Road, Shoal Cave, Meteor Falls) is level with the floors at its ends --
 -- the highest floor touching the patch -- not twelve courses up (it stood
 -- as a tall block). Only the height: the layer stays 15, so it stays a deck.
 local bridgeElev={}
 -- (outdoors too: Route 120's log bridges stood 48 px up between banks 16 px up)
 do
  local seen={}
  for y=0,l.height-1 do for x=0,l.width-1 do
   local raw=l:cellAt(x,y)
   if raw and raw.coll~=7 and raw.elev==15 and not seen[x..':'..y] then
    local list,stack,top={}, {{x,y}},nil;seen[x..':'..y]=true
    while #stack>0 do local p=table.remove(stack);list[#list+1]=p
     for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
      local nx,ny=p[1]+d[1],p[2]+d[2];local n=l:cellAt(nx,ny)
      if n and n.coll~=7 then
       if n.elev==15 then if not seen[nx..':'..ny] then seen[nx..':'..ny]=true;stack[#stack+1]={nx,ny} end
       elseif n.elev>=3 then top=math.max(top or 0,n.elev) end
      end
     end
    end
    if top then for _,p in ipairs(list)do bridgeElev[p[1]..':'..p[2]]=top end end
   end
  end end
 end
 local flightPair=def.midLayout and Pairs.canonical(def.midLayout.pair)
 Levels.mapId=def.id
 local f=Levels.build(l.width,l.height,function(x,y)
  local raw=l:cellAt(x,y);local beh=behaviors[raw.mid]
  if relevel[x..':'..y] then raw={mid=raw.mid,coll=raw.coll,elev=relevel[x..':'..y]} end
  if flatIn[x..':'..y] then raw={mid=raw.mid,coll=raw.coll,elev=3} end
  -- the remap sets only the HEIGHT (the pin below); the layer keeps e15 so the
  -- bridge stays a deck (Gen3Scene isDeck) over the path running under it
  local remap=M.ELEV_REMAP[def.id]
  local hElev=(remap and remap[raw.elev]) or bridgeElev[x..':'..y] or raw.elev
  local dz=dais and daisAt(dais,x,y,raw.mid)
  local step=((dz or (dais and dais.anySteps)) and dais.steps[raw.mid]) or beh==0x2A or beh==0x1D0 or climb[x..':'..y]==true or stairCells[x..':'..y]==true or (M.STEP_MIDS[def.id] and M.STEP_MIDS[def.id][raw.mid] and raw.coll==0) or false;local jump=beh and beh>=0x38 and beh<=0x3F  -- 0x1D0: Emerald MUDDY_SLOPE
  local shape=shapes.of(spec.primary,spec.secondary,raw.mid,beh,raw.coll)
  -- The nibble rates the walkable floor, so only a walkable cell is pinned: the
  -- cliff between two levels is blocked and keeps the solver's own height.
  local pinned=raw.coll~=7 and not step and not jump and raw.elev>=3 and shape.kind~='water'
  -- No seed once the nibble sets the height: the old +6 was a stand-in for the
  -- one-step floors the nibble now states outright, and a seed on top of a pin
  -- lifts every e4 floor twice (and a stair flight on top of that).
  return {floor=(dz and not step) or (raw.coll~=7 and not step and not jump),step=step,drop=drop[beh],layer=raw.elev,behavior=beh,
   treads=step and ((FLIGHT_TREADS[flightPair] or {})[raw.mid] or 4) or nil,
   waterfall=beh==0x13 or beh==0x113,
   kind=shape.kind,seed=0,anchor=(pins and pins[x..':'..y]~=nil) or nil,zone=zoneOf[x..':'..y],
   -- an authored terrace map pins only its anchors: the cartridge's flat
   -- nibble (all e3) would otherwise outvote each anchor in its group's median
   -- (a walkable cell rated water level that is not water -- a bridge's post
   -- standing in a lake -- is at water level, not at the bridge's height)
   pin=(pins and pins[x..':'..y]) or ((not pins or keepRated) and raw.coll~=7 and raw.elev==1 and shape.kind~='water' and 0) or ((not pins or keepRated) and pinned and math.min(hElev-3,M.MAX_STEP)*(M.COURSE_BY_MAP[def.id] or M.COURSE) or nil)}
 end,function(a,b,d)
  -- One floor, one level: floors of different elevation stay separate groups so
  -- each group's median pin is that terrace's height. Stairs and ledges bridge
  -- the levels through f.flights, not by merging the groups.
  local layer=a.layer==b.layer and a.zone==b.zone
  return layer and (a.kind=='water')==(b.kind=='water') and not blocked[d][a.behavior] and not blocked[opposite[d]][b.behavior]
 end,6,V.require('BuildBudget').tick)
 -- A bridge (cells on layer 15) spans between the floors at its ends: on an authored terrace map
 -- its cells over the water took the bank's rating and hung a floor or two below the cliff tops
 -- they join (Route 119's log bridge sagged between its piers). Each run of bridge cells takes the
 -- highest walkable non-bridge floor touching it.
 if pins then
  local seen={}
  for y=0,l.height-1 do for x=0,l.width-1 do
   local c=f.cells[Levels.key(x,y)]
   if c and c.layer==15 and not seen[c] then
    local run,stack,top={},{{x,y}},nil;seen[c]=true
    while #stack>0 do
     local p=table.remove(stack);run[#run+1]=f.cells[Levels.key(p[1],p[2])]
     for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
      local nx,ny=p[1]+d[1],p[2]+d[2]
      local n=nx>=0 and ny>=0 and nx<l.width and ny<l.height and f.cells[Levels.key(nx,ny)]
      if n then
       if n.layer==15 then if not seen[n] then seen[n]=true;stack[#stack+1]={nx,ny} end
       elseif n.floor and n.kind~='water' and n.height and not n.step then top=math.max(top or n.height,n.height) end
      end
     end
    end
    if top then for _,q in ipairs(run)do if (q.height or 0)<top then q.height=top;q.high=nil;q.low=nil end end end
   end
  end end
 end
 -- Ramps (gen.ramps={{x0,y0,x1,y1},...}): a corridor round a ledge island, drawn as plain ground, joins
 -- a floor north of it to a lower one south of it (Jagged Pass). Its floor cells descend row by row
 -- between the floors just outside the box, so one path can fall through several ledges' worth of height.
 -- ax='x' runs the ramp west to east instead, column by column between the floors just west and east of
 -- the box (Route 120: the field drawn level with the area east of it, across the cartridge's level-0
 -- column 34). smooth=true marks the ramp's cells relief connectors, so Gen3Scene gives them sloped tops
 -- joined to the floors either side (a ramp of flat blocks stands as rows of risers).
 if gen and gen.ramps then
  local function edgeHeight(x0,x1,y0,y1)
   local hs={}
   for y=y0,y1 do for x=x0,x1 do local c=f.cells[Levels.key(x,y)]
    if c and c.floor and c.height and not c.step and c.kind~='water' then hs[#hs+1]=c.height end
   end end
   table.sort(hs);return hs[math.ceil(#hs/2)]
  end
  for _,r in ipairs(gen.ramps)do
   local ew=r.ax=='x'
   local hn,hs
   if ew then hn,hs=edgeHeight(r[1]-1,r[1]-1,r[2],r[4]),edgeHeight(r[3]+1,r[3]+1,r[2],r[4])
   else hn,hs=edgeHeight(r[1],r[3],r[2]-1,r[2]-1),edgeHeight(r[1],r[3],r[4]+1,r[4]+1)end
   if hn and hs then
    local span=ew and (r[3]+1)-(r[1]-1) or (r[4]+1)-(r[2]-1)
    for y=r[2],r[4]do for x=r[1],r[3]do local c=f.cells[Levels.key(x,y)]
     -- (a smooth ramp takes in the level-0 "step" cells the cartridge puts between two ratings, Route 120's
     -- column 34: drawn as plain ground, they slope with the ramp instead of standing as a flight)
     if c and (c.floor or (r.smooth and c.step)) and (r.smooth or not c.step) and c.kind~='water' then
      local t=ew and (x-(r[1]-1)) or (y-(r[2]-1))
      c.height=hn+(hs-hn)*t/span;c.high=nil;c.low=nil
      if r.smooth then c.relief=true;c.connector=true;c.step=false;c.floor=true end
     end
    end end
   end
  end
 end
 f.signature=signature
 cache[l]=f;return f
end
function M.cell(def,x,y)
 local f=M.field(def);return f and f.cells[Levels.key(x,y)]
end
function M.at(def,x,z)return Levels.at(M.field(def),x,z)end
-- Fill outside the map (Gen3Boundary's donors: the forest, plain ground and rock the engine lays
-- round a map's edge) used to take the nearest floor's height outright. Beside a tall map edge that
-- stood the fill on the edge's own level, and because the fill is many cells wide the shelf showed as
-- flat plates hanging in the air over the drop (Route 112's west margin, seen from the orbit camera).
-- A fill cell may now stand no higher than the ground it actually touches: any floor or fill beside
-- it, stepped down one course (COURSE) so the wall between them closes, and closed onto the map's own
-- ground when it touches no floor at all (a lone plate has no support anywhere).
-- (Run once every cell is bound, over the fill cells in row order until nothing moves: it used to run
-- inside the binding loop, once per cell, while cells later in pairs() order had no base yet, so the
-- same map's edge came out at different heights from one visit to the next, at O(cells^2) cost.)
function M.supportFill(cells,regions)
 local changed,limit=true,512
 local function walkable(c)
  return c and c.floor and c.floor.height and c.floor.kind~='water' and (c.collision or 0)==0
 end
 local fill={}
 for _,c in pairs(cells)do if c.boundary then fill[#fill+1]=c end end
 table.sort(fill,function(a,b)if a.cy~=b.cy then return a.cy<b.cy end return a.cx<b.cx end)
 while changed and limit>0 do
  changed=false;limit=limit-1
  for _,c in ipairs(fill)do
   if (c.base or 0)>0 then
    local support
    for _,d in ipairs(Levels.directions)do
     local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
     if n then
      local h
      if n.boundary then h=(n.base or 0)+M.COURSE
      elseif walkable(n) then h=n.floor.height+M.COURSE end
      if h and (not support or h<support) then support=h end
     end
    end
    if support==nil then
     for _,r in ipairs(regions)do
      local x=math.max(0,math.min(r.w-1,c.cx-r.x));local y=math.max(0,math.min(r.h-1,c.cy-r.y))
      local q=r.floorField and r.floorField.cells[Levels.key(x,y)]
      if q and q.floor and q.height and q.kind~='water' then
       local h=q.height+(r.floorOffset or 0);if not support or h<support then support=h end
      end
     end
    end
    if support==nil then support=0 end
    if (c.base or 0)>support then c.base=support;c.floorHigh=nil;changed=true end
   end
  end
 end
end
M.STOOP=12   -- a door's stoop: one stair row's rise (Gen3StairTerraces.rise)
M.BOULDER_MAX=14
M.PROP_STEP=16   -- a prop is moved at most one terrace to meet its ground
function M.bind(cells,regions)
 -- (only the maps the built window reaches need their floors solved: entering Mossdeep solved seven
 -- connected maps' floors, two hops out, before the first view - a third of its build without the JIT;
 -- a map the window does not reach has no cells to stand on them)
 local bx0,by0,bx1,by1=1e9,1e9,-1e9,-1e9
 for _,c in pairs(cells)do
  if c.cx<bx0 then bx0=c.cx end;if c.cx>bx1 then bx1=c.cx end
  if c.cy<by0 then by0=c.cy end;if c.cy>by1 then by1=c.cy end
 end
 for i,region in ipairs(regions)do
  local reach=i==1 or (region.x<=bx1+1 and region.x+region.w>=bx0-1 and region.y<=by1+1 and region.y+region.h>=by0-1)
  region.floorField=reach and M.field(region.def) or nil
 end
 Levels.align(regions)
 for _,c in pairs(cells)do
  for _,r in ipairs(regions)do local x,y=c.cx-r.x,c.cy-r.y
   if x>=0 and y>=0 and x<r.w and y<r.h then
    local floor=r.floorField and r.floorField.cells[Levels.key(x,y)]
    c.floor=floor;c.base=(floor and floor.height or 0)+r.floorOffset
    c.floorHigh=floor and floor.high and floor.high+r.floorOffset;break
   end
  end
  if c.base==nil then
   local distance,donor
   for _,r in ipairs(regions)do
    local x=math.max(0,math.min(r.w-1,c.cx-r.x));local y=math.max(0,math.min(r.h-1,c.cy-r.y))
    local d=(c.cx-r.x-x)^2+(c.cy-r.y-y)^2
    if not distance or d<distance then
     local q=r.floorField and r.floorField.cells[Levels.key(x,y)]
     distance,donor=d,(q and q.height or 0)+r.floorOffset
    end
   end
   c.base=donor or 0
  end
 end
 M.supportFill(cells,regions)
 -- Complete assemblies use a single foundation, sampled at their entrance (from the bound heights:
 -- an entrance cell belonging to another assembly already moved to that one's foundation in pairs()
 -- order, so Route 110's gatehouse stood at 0 or 48 px from one visit to the next).
 local bound={}
 for _,c in pairs(cells)do bound[c]=c.base end
 for _,c in pairs(cells)do
  local g=c.column and c.column.group or c.civic or c.prop
  if g then
   if g.groundHeight==nil then
    local x=g.cx or c.cx;local y=g.cy or c.cy
    if g.front then x=math.floor((g.left+g.right)/32);y=math.floor(g.front/16)
    else x=x+math.floor((g.width or (g.w or 16)/16)/2);y=y+(g.depth or (g.d or 16)/16)end
    local below=cells[x..':'..y]or c;g.groundHeight=bound[below] or 0
    -- (a drawn stair at the door that the solver did not make a flight - a stoop, rated as the path
    -- below it: the building stands a stair's rise up, or the stair lies flat - Sootopolis' houses)
    if below~=c and below.shape and below.shape.kind=='steps' and not (below.floor and below.floor.step) then
     g.groundHeight=g.groundHeight+M.STOOP end
   end
   c.base=g.groundHeight
  end
 end
 -- open ground an assembly reaches over keeps its own height: a walkable cell of it that joins walkable
 -- ground outside it at that height is the path, not the building (Sootopolis' boxes claim the row
 -- above their roofs, and that row of the plaza stood 24-96 px up as a step nobody could climb)
 local function owner(c)return c.column and c.column.group or c.civic or c.prop end
 local grew=true
 while grew do   -- (along the row: a cell beside one found open is open too)
  grew=false
  for _,c in pairs(cells)do
   local g=owner(c)
   if g and c.collision==0 and not c.boundary and bound[c]~=c.base then
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
     if n and (owner(n)~=g or n.base==bound[n]) and n.collision==0 and not n.boundary and n.base==bound[c] then c.base=bound[c];grew=true;break end
    end
   end
  end
 end
 -- Standing things take the ground they stand on, not the cell's own rated height.
 -- (a) a two-wide tree (its left and right halves) stands at one height: its taller half's, so a half
 --     rated at the ramp's foot no longer sinks into the plateau beside it (Route 115 22-23,60-62);
 local function tree(c)return c.shape and c.shape.kind=='tree' and not c.shape.canopy end
 -- (a tree's halves are two tiles side by side, the right one the next tile after the left one; the left one
 -- is the even tile, the ash forest's 0x26B-0x276 the odd one. A tile is in one pair only, so the result is
 -- the same in whatever order the cells are visited: pairing any two neighbouring trees let one tall half
 -- pass its height on along a whole run of trees, or not, from one visit to the next - Oldale's forest
 -- margin stood at 0 or 8 px)
 local function leftHalf(mid)
  if mid>=0x26B and mid<=0x276 then return mid%2==1 end
  return mid%2==0
 end
 for _,c in pairs(cells)do
  if tree(c) and leftHalf(c.mid) then
   local r=cells[(c.cx+1)..':'..c.cy]
   if r and tree(r) and r.mid==c.mid+1 and c.base~=r.base and math.abs(c.base-r.base)<=M.PROP_STEP and not c.boundary and not r.boundary then
    local h=math.max(c.base,r.base);c.base=h;r.base=h
   end
  end
 end
 -- (b) a small cluster of rock (one or two cliff cells, no other rock or cave wall touching) is a boulder:
 --     it rests on the lowest open ground it touches and stands no taller than BOULDER_MAX, so it neither
 --     floats above a slope nor towers over a beach (Route 115's pink rock 30,62 and the stone at 11,62-63).
 local seen={}
 local function inMap(c)
  for _,r in ipairs(regions)do if c.cx>=r.x and c.cy>=r.y and c.cx<r.x+r.w and c.cy<r.y+r.h then return true end end
  return false
 end
 for _,c0 in pairs(cells)do
  if c0.shape and c0.shape.kind=='cliff' and not c0.boundary and not seen[c0] and inMap(c0) then
   local group,stack,small={c0},{c0},true
   seen[c0]=true
   while #stack>0 do
    local c=table.remove(stack)
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local n=cells[(c.cx+d[1])..':'..(c.cy+d[2])]
     if n and n.shape and (n.shape.kind=='caveWall' or n.boundary) then small=false
     elseif n and n.shape and n.shape.kind=='cliff' and not seen[n] then seen[n]=true;group[#group+1]=n;stack[#stack+1]=n end
    end
    if #group>2 then small=false end
   end
   if small then
    local low
    for _,c in ipairs(group)do for dx=-1,1 do for dy=-1,1 do
     local n=cells[(c.cx+dx)..':'..(c.cy+dy)]
     if n and n.shape and n.shape.kind~='water' and n.shape.kind~='cliff' and n.shape.kind~='caveWall' then low=math.min(low or n.base,n.base) end
    end end end
    for _,c in ipairs(group)do
     if low and low<c.base then c.base=math.max(low,c.base-M.PROP_STEP) end
     if c.shape.height and c.shape.height>M.BOULDER_MAX then c.shape=setmetatable({height=M.BOULDER_MAX},{__index=c.shape}) end
    end
   end
  end
 end
end
function M.lift(vertices,start,height,back)
 if height==0 then return end
 -- (setBack: a stepped deck stands as far south of its drawing as it is lifted, Gen3Decks)
 for i=(start or 0)+1,#vertices do local v=vertices[i];v[2]=v[2]+height
  -- (the third anchor value is the height a card pivots and sways about; 0 means
  -- "no anchor": a solid tree model of a standing object carries {0,0,0}, and
  -- lifting that to its terrace height made the shader lean and sway the whole
  -- model like a card, so trees on raised ground hung in the sky from the
  -- turned and low cameras)
  if v[9] and v[9]~=0 then v[9]=v[9]+height end
  if back then v[3]=v[3]+height end
 end
end
function M.invalidate()cache=setmetatable({},{__mode='k'})end
return M
