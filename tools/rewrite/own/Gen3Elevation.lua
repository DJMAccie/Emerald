-- LIFTED OWN CODE from lib/Gen3Elevation.lua (/Users/user/Documents/battle-art-notquiteog, base 03882a9)
-- Our added blocks, verbatim and in order; every --@HOLE line is an upstream-
-- derived region the implementer writes from docs/specs/HeightField.md.
-- Do not move code across holes: hole ids and order are the contract.

--@HOLE file-header: MIT header + module job in one line [spec HeightField §6.1]
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
--@HOLE requires: V, TerrainLevels, Gen3Tilesets, the weak field cache, M [spec HeightField §6.2]
local okP,PinData=pcall(V.require,'Gen3PinData')
if not okP then PinData=nil end
M.PINS_ON=true   -- the hand-drawn heights (Gen3PinData) set the floors of the maps listed there
M.pinZones={}
M.CONNECTOR_MAX=12   -- cells: the longest run of unmarked walkable cells between floors of one mark that is flattened to it
M.BLOCKED_MARK_REACH=8   -- cells: a mark drawn on a tree or blocked ground (no walkable floor to flood) stands the unclaimed trees and blocked ground round it, nearest mark first, through blocked non-rock cells, this far (Route 120 (33..39,77..83): a closed grass-and-tree plateau marked 3 / 4 / 3)
-- Tree cells the flood stood on the wrong plateau, fixed by hand: {x0,x1,y0,y1,courses} per map (only blocked tree cells inside the box change).
-- Route 120 (33..38,85..86): the strip of trees under the cliff band took the ramp mark's 2 through tree-to-tree spread while the ground south of it is 0
-- (and the ramp cell (34,87) is 1); Route 111 (12,131) stood at 2 beside a rim of 1
M.TREE_SETTLE={EM_ROUTE120={{35,38,85,86,0},{34,34,85,86,1}},EM_ROUTE111={{12,12,131,131,1}}}
M.BLOCKED_WATER=true   -- (builder 12) a mark on blocked water (Route 119's lake / river tile 0x206: water you cannot surf, collision 7) floods that water, and the boardwalk legs drawn on it (M.WATER_LEGS), as WATER at the mark: they were blocked non-floor cells, so the classifier left them OTHER at the grass height round them (coordinator 4 finding 3; user's 8 on the lake, grass 9)
M.WATER_LEGS={fortree={[0x0F5]=true,[0x0F8]=true,[0x0F9]=true,[0x0FA]=true,[0x0FC]=true}}   -- (Gen3EmeraldShapes: 'the white boardwalk's legs standing in it are drawn on water too')
M.WATER_DECKS={fortree={[0x0ED]=true,[0x0F0]=true,[0x0F1]=true,[0x0F2]=true,[0x0FB]=true,[0x0E8]=true,[0x0EC]=true,[0x0F3]=true,[0x0F4]=true,[0x0F7]=true,[0x0FD]=true}}   -- (the boardwalk drawn over that water, Gen3Scene SHAPE_BY_MAP.EM_ROUTE119 underWater: the water flood passes under it, the deck keeps its own height; Route 119's lake is split in two by the boardwalk at x=9)
M.PIN_PX=16   -- px per drawn course for the hand-drawn marks (ONE constant: Gen3Relief.LEVEL and Gen3Rock.COURSE follow it; user 2026-10-27: the height felt exaggerated at 24)
-- maps whose marks are not applied yet: Battle Frontier E/W show missing-floor patches in the 2026-10-27 shots (b2); judge before enabling
M.PIN_SKIP={}   -- (Battle Frontier E/W were skipped while their frames showed missing floor; with Gen3Blocks their 44 marks are exact and the plaza, garden terraces and pyramid plateau close: docs/faults/pins/blocks/SHEET_frontier_L4/L6.png)
M.BLOCKS_ON=true   -- the PLATEAU RULE classifier on hand-drawn maps (rock heights per plateau; Gen3Blocks builds them)
M.BLOCKS_SLACK=2  -- cells: a rock cell takes sources this much further than its nearest one (a 2-3 row band stands whole at its upper plateau)
M.RAMP_EXT=false;M.SLOPE_DEG=45;M.RAMP_EXT_MAX=3;M.RAMP_EXT_TREES=false   -- ramp extension (grass / sand lifted at the foot of a ridge), see the pass after the FACE heights: OFF since user 2026-10-28 (R-33: "no switch those off"; grass and sand are never a slope)
M.PLAIN_GRASS_MIDS={[0x001]=true,[0x002]=true}   -- plain grass tiles an elevation-0 transition cell may be (no flight there, see climb)
M.ORPHAN_MAX=24   -- cells: the largest unmarked floor behind a plain-grass transition cell that takes the height of the zone the cell touches (see the pin flood); one that reaches the map's edge is never taken (a strip that goes on in the next map, Route 120's east side)
M.STAIR_EXT=true   -- the foot extension of steep flights
M.STAIR_PROFILE=true   -- the final stair profile pass (R-34), see STAIR PROFILE
M.LEDGES=true;M.LEDGE_MIN=8;M.LEDGE_MAX=3   -- hidden ledges: (maps in LEDGE_SKIP build none) a plateau edge with no band tile gets a rock wedge on the lower plain cell(s), see the HIDDEN LEDGES pass (user 2026-10-28: 45 degree rock ledges all round the platform; grass itself never slopes, R-33); MIN = smallest rise (px) that is a ledge, MAX = rows of wedge at most (a taller rise is steeper, never a vertical grass wall)
M.LEDGE_SKIP={EM_FORTREE_CITY=true}   -- (coordinator 3, sheet SHEET_fled3y0_L6/L7 (37,19): Fortree's pinned 2 is the treehouse decks and rope bridges over the trees, not a rock plateau; its rise is the tree trunk climbed by the rope ladder, so a wedge there came out in plank and ladder art and stretched the ladder; no rock ledge rings a treehouse)
M.BAND_LEVEL='lower'   -- (user 2026-10-27, on the round-1 install: "the stones are in completely different places. completely mangled": with 'upper' the band's rows read as plateau top and the edge moved 2-3 cells; the ortho-45 overlay docs/faults/pins/blocks/ORTHO_AB.png shows 'lower' keeps the bands where the 2D draws them) where an unnumbered rock band (FACE) stands: 'upper' = whole at the upper plateau, the drop at its lower edge (the band's rows read as plateau top); 'lower' = flat at the lower plateau with its own face art on top and the 1-course wall at its upper edge (the band's dark rows stay where the 2D draws them)
M.POCKET_MAX=12   -- cells: a run of unmarked walkable cells up to this size, enclosed by rock and props, is a pocket of the plateau round it
M.BLOCKS_RMAX=12  -- cells: how far a rock cell looks for a plateau / number; beyond it the support fill's height stays
M.classes={}      -- mapId -> class counts of the last classify (gate)
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
M.SINK_MAPS={EM_MOSSDEEP_CITY=16}   -- maps whose solved floors all stand this many px lower (field(); the sea stays 0)
M.MARKER_CELLS=4  -- walkable e15 patches this small are markers, not walkways
--@HOLE field-prologue: layout/cache signature, behaviours, tileset spec, shapes, drop table, outdoor/cave/deck flags [spec HeightField §6.3]
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
 -- (finding 1, coordinator 4: on a hand-drawn map a plain GRASS tile (0x001 / 0x002) of elevation 0 between floors of different
 -- elevation is where the cartridge lets you walk from one level to the other, not a stair: it is no flight, only a floor the
 -- pin flood joins to one of the plateaus, the drop between them a hidden ledge (R-35); a real stair tile keeps its flight)
 local plainGrass=M.PLAIN_GRASS_MIDS and M.PINS_ON and not M.PIN_SKIP[def.id] and PinData and PinData.MAPS[def.id] and M.PLAIN_GRASS_MIDS or {}
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
    if (lo and hi and hi>lo and not plainGrass[raw.mid]) or stairCells[x..':'..y] then climb[x..':'..y]=true end
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
      for k=0,n-1 do local q=l:cellAt(x+d[1]*k,y+d[2]*k);if not plainGrass[q.mid] then climb[(x+d[1]*k)..':'..(y+d[2]*k)]=true end end
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
 -- The user's hand-drawn heights (Gen3PinData, docs/elevation/pins; courses of 16 px, relative to the map's ground,
 -- water 0). They replace every other pin source of the map: each mark floods ITS flat area (walkable cells of the
 -- mark's own rating and kind, not crossing a flight, a ledge or a stair tile; all marks grow one ring at a time, so
 -- a floor two marks share splits halfway between them) and that area becomes a zone of its own, standing at the
 -- mark. A mark on a blocked cell (a rock top) stands at its height and supports the cells beside it (TerrainLevels).
 -- Cells no mark reaches keep their rated height.
 local userPins=M.PINS_ON and not M.PIN_SKIP[def.id] and PinData and PinData.MAPS[def.id]
 if userPins then
  pins={};zoneOf={};keepRated=true
  local barrier=function(n,x,y,noClimb)
   local beh=behaviors[n.mid]
   return beh==0x13 or beh==0x113 or stairCells[x..':'..y] or (not noClimb and climb[x..':'..y]) or n.mid==0xAF or n.mid==0xCF or n.mid==0xE8 or (beh and ((beh>=0x38 and beh<=0x3F) or beh==0x2A or beh==0x1D0))
    or (M.STEP_MIDS[def.id] and M.STEP_MIDS[def.id][n.mid] and n.coll==0)
  end
  local function waterAt(n)return shapes.of(spec.primary,spec.secondary,n.mid,behaviors[n.mid],n.coll).kind=='water' end
  local function treeAt(n)return shapes.of(spec.primary,spec.secondary,n.mid,behaviors[n.mid],n.coll).kind=='tree' end
  local function riverAt(n)return shapes.of(spec.primary,spec.secondary,n.mid,behaviors[n.mid],n.coll).river==true end   -- (Gen3EmeraldShapes PINS 'river': the Fortree tileset's blocked river 0x206/0x20F)
  local front,claimed,info={},{},{}
  for zi,row in ipairs(userPins)do
   local x,y,h=row[1],row[2],row[3]*M.PIN_PX
   local n=x>=0 and y>=0 and x<l.width and y<l.height and l:cellAt(x,y)
   if n then
    local k=x..':'..y
    if not claimed[k] then
     claimed[k]=zi;pins[k]=h;zoneOf[k]=zi
     if n.coll~=7 and not row[4] then info[zi]={elev=elevAt(x,y,n),water=waterAt(n)};front[#front+1]={x,y,zi}
     elseif M.BLOCKED_WATER and not row[4] and riverAt(n) then info[zi]={elev=elevAt(x,y,n),water=true,blockedWater=true};front[#front+1]={x,y,zi} end
    end
   end
  end
  local head=1
  local passed={}
  while front[head]do
   local q=front[head];head=head+1
   local zi=q[3];local inf=info[zi]
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    local nx,ny=q[1]+d[1],q[2]+d[2];local k=nx..':'..ny
    local inMapN=nx>=0 and ny>=0 and nx<l.width and ny<l.height
    local nd=inf.blockedWater and inMapN and not passed[k] and l:cellAt(nx,ny)
    local n=not claimed[k] and inMapN and l:cellAt(nx,ny)
    if n and n.coll~=7 and not q[4] and elevAt(nx,ny,n)==inf.elev and waterAt(n)==inf.water and not barrier(n,nx,ny) then
     claimed[k]=zi;pins[k]=userPins[zi][3]*M.PIN_PX;zoneOf[k]=zi;front[#front+1]={nx,ny,zi}
    elseif n and n.coll==7 and inf.blockedWater and (riverAt(n) or (M.WATER_LEGS[spec.secondary] or {})[n.mid]) and not barrier(n,nx,ny) then
     -- (blocked water floods blocked water and the legs drawn on it; a walkable shore of its level is taken by the branch above)
     claimed[k]=zi;pins[k]=userPins[zi][3]*M.PIN_PX;zoneOf[k]=zi;front[#front+1]={nx,ny,zi}
    elseif nd and nd.coll~=7 and (M.WATER_DECKS[spec.secondary] or {})[nd.mid] then
     passed[k]=true;front[#front+1]={nx,ny,zi}   -- (under a boardwalk: on through, the deck cell itself unclaimed by this zone)
    elseif n and n.coll==7 and not inf.water and treeAt(n) then
     -- a tree stands on its hill: the cell is blocked (its nibble is 0, so no elevation test), so it only takes the zone's pin (it spreads to other trees
     -- of the clump, never on to walkable floor) and Levels stands it, and supports its neighbours, at that height
     claimed[k]=zi;pins[k]=userPins[zi][3]*M.PIN_PX;zoneOf[k]=zi;front[#front+1]={nx,ny,zi,true}
    end
   end
  end
  for _,b in ipairs(M.TREE_SETTLE[def.id] or {})do
   for y=b[3],b[4]do for x=b[1],b[2]do
    local n=x>=0 and y>=0 and x<l.width and y<l.height and l:cellAt(x,y)
    if n and n.coll==7 and treeAt(n) then local k=x..':'..y;claimed[k]=claimed[k] or 0;pins[k]=b[5]*M.PIN_PX;zoneOf[k]=nil end
   end end
  end
  -- A mark drawn on a tree or on blocked ground is the ground there (user 2026-10-27); a closed plateau of trees and blocked
  -- grass has no floor for the flood above, so each such mark grows through blocked, non-rock, non-water cells that no
  -- zone claimed, one ring at a time (the nearest mark wins), up to M.BLOCKED_MARK_REACH cells. Rock cells stop it.
  if M.BLOCKED_MARK_REACH>0 then
   local ring={}
   for zi,row in ipairs(userPins)do
    local x,y=row[1],row[2]
    local n=x>=0 and y>=0 and x<l.width and y<l.height and l:cellAt(x,y)
    if n and n.coll==7 and claimed[x..':'..y]==zi then
     local kind=shapes.of(spec.primary,spec.secondary,n.mid,behaviors[n.mid],n.coll).kind
     if kind~='cliff' and kind~='water' then ring[#ring+1]={x,y,zi} end
    end
   end
   for _=1,M.BLOCKED_MARK_REACH do
    local nxt={}
    for _,q in ipairs(ring)do for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local nx,ny=q[1]+d[1],q[2]+d[2];local k=nx..':'..ny
     local n=not claimed[k] and nx>=0 and ny>=0 and nx<l.width and ny<l.height and l:cellAt(nx,ny)
     if n and n.coll==7 then
      local kind=shapes.of(spec.primary,spec.secondary,n.mid,behaviors[n.mid],n.coll).kind
      if kind~='cliff' and kind~='water' and not barrier(n,nx,ny) then
       claimed[k]=q[3];pins[k]=userPins[q[3]][3]*M.PIN_PX;zoneOf[k]=q[3];nxt[#nxt+1]={nx,ny,q[3]}
      end
     end
    end end
    ring=nxt;if #ring==0 then break end
   end
  end
  -- A connector between two floors of the same mark is flat at it (user 2026-10-27, Route 120's bridge: both banks and the
  -- deck are 2, and the approach cells between them -- the cartridge rates them level 0 or 1 -- dipped to 16 / 24 px). A
  -- small run of walkable cells no mark reached, touching two zones, every claimed cell beside it at one height and none of it a stair or a
  -- ledge, takes that height and zone. (A flight between two different heights has neighbours at two heights: untouched.)
  do
   local dirs={{1,0},{-1,0},{0,1},{0,-1}}
   local function loose(n,x,y)return n and n.coll~=7 and n.elev~=1 and not claimed[x..':'..y] and not waterAt(n) end   -- (level 1 = water level: a shore or a shoal, never a connector)
   local done={}
   for y0=0,l.height-1 do for x0=0,l.width-1 do
    local n0=l:cellAt(x0,y0)
    if loose(n0,x0,y0) and not done[x0..':'..y0] then
     local comp,stack,bad,height,zone,zones={},{{x0,y0}},false,nil,nil,{}
     done[x0..':'..y0]=true
     while #stack>0 do
      local q=table.remove(stack);comp[#comp+1]=q
      local nq=l:cellAt(q[1],q[2])
      if barrier(nq,q[1],q[2],true) or #comp>M.CONNECTOR_MAX then bad=true end   -- (an e0 run between floors, taken for a flight, is what this joins)
      for _,d in ipairs(dirs)do
       local nx,ny=q[1]+d[1],q[2]+d[2];local k=nx..':'..ny
       local nn=nx>=0 and ny>=0 and nx<l.width and ny<l.height and l:cellAt(nx,ny)
       if nn then
        if claimed[k] then
         if nn.coll~=7 then
          if height==nil then height,zone=pins[k],claimed[k] elseif height~=pins[k] then bad=true end
          zones[claimed[k]]=true
         end
        elseif loose(nn,nx,ny) and not done[k] then done[k]=true;stack[#stack+1]={nx,ny} end
       end
      end
     end
     local nz=0;for _ in pairs(zones)do nz=nz+1 end
     if not bad and nz>=2 and #comp<=M.CONNECTOR_MAX then
      for _,q in ipairs(comp)do local k=q[1]..':'..q[2];claimed[k]=zone;pins[k]=height;zoneOf[k]=zone end
     end
    end
   end end
  end
  -- A small floor of another elevation that only an elevation-0 plain grass cell (finding 1) leads to, no mark reached (Route 119's
  -- (3..10,16..18): the ledge strip above a jump ledge, elev 3 inside the elev 4 plateau; unmarked it rated 0 and the jump-ledge
  -- pass then lifted it to the lower floor + LEDGE_DROP = a half-course grass riser, R-33): the cell and the floor behind it take
  -- the height of the one zone the cell touches (the cartridge's elevation nibble only marks where the walk goes between them)
  if next(plainGrass) then
   local dirs={{1,0},{-1,0},{0,1},{0,-1}}
   for y0=0,l.height-1 do for x0=0,l.width-1 do
    local t=l:cellAt(x0,y0);local tk=x0..':'..y0
    if t and t.coll==0 and t.elev==0 and plainGrass[t.mid] and not claimed[tk] then
     local hh,zone,bad
     local starts={}
     for _,d in ipairs(dirs)do
      local nx,ny=x0+d[1],y0+d[2];local nk=nx..':'..ny;local n=nx>=0 and ny>=0 and nx<l.width and ny<l.height and l:cellAt(nx,ny)
      if n and n.coll==0 then
       if claimed[nk] then
        if hh==nil then hh,zone=pins[nk],claimed[nk] elseif hh~=pins[nk] then bad=true end
       elseif n.elev>=3 and not waterAt(n) and not barrier(n,nx,ny) then starts[#starts+1]={nx,ny} end
      end
     end
     if hh and not bad and #starts>0 then
      local comp,seen,stack={}, {[tk]=true},{}
      for _,s in ipairs(starts)do local sk=s[1]..':'..s[2];if not seen[sk] then seen[sk]=true;stack[#stack+1]=s end end
      while #stack>0 and #comp<=M.ORPHAN_MAX and not bad do
       local q=table.remove(stack);comp[#comp+1]=q
       local qn=l:cellAt(q[1],q[2])
       if q[1]==0 or q[2]==0 or q[1]==l.width-1 or q[2]==l.height-1 then bad=true end
       for _,d in ipairs(dirs)do
        local nx,ny=q[1]+d[1],q[2]+d[2];local nk=nx..':'..ny;local n=nx>=0 and ny>=0 and nx<l.width and ny<l.height and l:cellAt(nx,ny)
        if n and n.coll==0 and not seen[nk] then
         if claimed[nk] then if pins[nk]~=hh then bad=true end
         elseif elevAt(nx,ny,n)==elevAt(q[1],q[2],qn) and not waterAt(n) and not barrier(n,nx,ny) then seen[nk]=true;stack[#stack+1]={nx,ny} end
        end
       end
      end
      if not bad and #comp<=M.ORPHAN_MAX then
       claimed[tk]=zone;pins[tk]=hh;zoneOf[tk]=zone
       for _,q in ipairs(comp)do local k=q[1]..':'..q[2];claimed[k]=zone;pins[k]=hh;zoneOf[k]=zone end
      end
     end
    end
   end end
  end
  M.pinZones[def.id]=zoneOf
 end
 local flightPair=def.midLayout and Pairs.canonical(def.midLayout.pair)
 Levels.mapId=def.id
 Levels.stretch=not(userPins and M.STAIR_PROFILE)   -- (pinned maps: the stair profile pass at the end of the field owns every flight)
--@HOLE build-open: Levels.build(w, h, read, compatible, 6, tick) - the read callback head [spec HeightField §6.4]
  if relevel[x..':'..y] then raw={mid=raw.mid,coll=raw.coll,elev=relevel[x..':'..y]} end
  if flatIn[x..':'..y] then raw={mid=raw.mid,coll=raw.coll,elev=3} end
  -- the remap sets only the HEIGHT (the pin below); the layer keeps e15 so the
  -- bridge stays a deck (Gen3Scene isDeck) over the path running under it
  local remap=M.ELEV_REMAP[def.id]
  local hElev=(remap and remap[raw.elev]) or bridgeElev[x..':'..y] or raw.elev
  local dz=dais and daisAt(dais,x,y,raw.mid)
  local step=((dz or (dais and dais.anySteps)) and dais.steps[raw.mid]) or beh==0x2A or beh==0x1D0 or climb[x..':'..y]==true or stairCells[x..':'..y]==true or (M.STEP_MIDS[def.id] and M.STEP_MIDS[def.id][raw.mid] and raw.coll==0) or false;local jump=beh and beh>=0x38 and beh<=0x3F  -- 0x1D0: Emerald MUDDY_SLOPE
--@HOLE read-shape: the cell's shape kind (water test) inside the read callback [spec HeightField §6.4]
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
--@HOLE compat-open: the compatible callback head [spec HeightField §6.5]
  -- One floor, one level: floors of different elevation stay separate groups so
  -- each group's median pin is that terrace's height. Stairs and ledges bridge
  -- the levels through f.flights, not by merging the groups.
  local layer=a.layer==b.layer and a.zone==b.zone
--@HOLE compat-close: the compatible callback body + the build call tail [spec HeightField §6.5]
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
 -- An e0 run the cartridge puts between two floors is taken for a flight; where the floors either side stand at one
 -- height (both ends of a bridge, Route 120's approaches: all 2) it is flat at it, never a ramp to something lower or
 -- higher. A drawn stair tile / jump / waterfall keeps its flight.
 if userPins then
  local dirs={{1,0},{-1,0},{0,1},{0,-1}}
  for y=0,l.height-1 do for x=0,l.width-1 do
   local c=f.cells[Levels.key(x,y)]
   if c and c.step and c.high~=nil and not stairCells[x..':'..y] then
    local raw=l:cellAt(x,y);local beh=behaviors[raw.mid]
    local hard=beh==0x13 or beh==0x113 or raw.mid==0xAF or raw.mid==0xCF or raw.mid==0xE8 or (beh and ((beh>=0x38 and beh<=0x3F) or beh==0x2A or beh==0x1D0))
     or (M.STEP_MIDS[def.id] and M.STEP_MIDS[def.id][raw.mid] and raw.coll==0)
    if not hard and raw.elev==0 then
     local H,n,same=nil,0,true
     for _,d in ipairs(dirs)do
      local q=f.cells[Levels.key(x+d[1],y+d[2])]
      if q and q.floor and not q.step and q.kind~='water' and q.height then
       n=n+1;if H==nil then H=q.height elseif H~=q.height then same=false end
      end
     end
     if same and n>=2 then c.height=H;c.high=H;c.low=H end
    end
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
    -- On a hand-drawn map a mark's flat area reaching into the box is a plateau (user 2026-10-27: Route 120's road
    -- marked 2 at (33,89) inside the ramp box stayed at 6.4 px): those cells keep their pin, and each run of cells no
    -- mark reached slopes between the nearest marked cell on either side along its line (or the floor outside the box),
    -- so a mark on a ramp cell sets that end of the ramp.
    local lines={}
    if ew then for y=r[2],r[4]do local L={};for x=r[1],r[3]do L[#L+1]={x,y} end;lines[#lines+1]=L end
    else for x=r[1],r[3]do local L={};for y=r[2],r[4]do L[#L+1]={x,y} end;lines[#lines+1]=L end end
    local function markAt(q)return q and userPins and pins[q[1]..':'..q[2]] or nil end
    for _,L in ipairs(lines)do
     local i=1
     while i<=#L do
      if markAt(L[i])~=nil then i=i+1
      else
       local j=i;while j<#L and markAt(L[j+1])==nil do j=j+1 end
       local a=markAt(L[i-1]) or hn;local b=markAt(L[j+1]) or hs
       local span=j-i+2
       for t=i,j do local x,y=L[t][1],L[t][2];local c=f.cells[Levels.key(x,y)]
        -- (a smooth ramp takes in the level-0 "step" cells the cartridge puts between two ratings, Route 120's
        -- column 34: drawn as plain ground, they slope with the ramp instead of standing as a flight)
        if c and (c.floor or (r.smooth and c.step)) and (r.smooth or not c.step) and c.kind~='water' then
         c.height=a+(b-a)*(t-i+1)/span;c.high=nil;c.low=nil
         if r.smooth then c.relief=true;c.connector=true;c.step=false;c.floor=true end
        end
       end
       i=j+1
      end
     end
    end
   end
  end
 end
 -- Mossdeep stands a block (16 px) too high: its shallow-water shelf was rated 16 over a sea at 0 and the town
 -- 16 over what the 2D has. Every floor drops by SINK_MAPS (never below the sea: the shelf lands on 0).
 local sink=not userPins and M.SINK_MAPS[def.id]   -- (a hand-drawn map is already drawn at its own heights)
 if sink then
  for _,c in pairs(f.cells)do
   for _,k in ipairs({'height','high','low','ledgeLow'})do
    if c[k]~=nil then c[k]=math.max(0,c[k]-sink) end
   end
  end
 end
 -- Waterfalls go straight up (user 2026-10-27): a fall stands at its upper pool's level and the foot's water is lower,
 -- so the step between them is a vertical sheet (Gen3Scene closes a water step with the fall tile's own drawing),
 -- never the slope the flood gave a fall between two marks. Each run of fall cells takes the highest water beside it.
 if userPins then
  local seen={}
  for y=0,l.height-1 do for x=0,l.width-1 do
   local c=f.cells[Levels.key(x,y)]
   if c and c.waterfall and not seen[c] then
    local run,stack,top={},{c},nil;seen[c]=true
    while #stack>0 do
     local a=table.remove(stack);run[#run+1]=a
     for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
      local n=f.cells[Levels.key(a.x+d[1],a.y+d[2])]
      if n and n.kind=='water' and n.floor then
       if n.waterfall then if not seen[n] then seen[n]=true;stack[#stack+1]=n end
       elseif n.height then top=math.max(top or n.height,n.height) end
      end
     end
    end
    if top then for _,q in ipairs(run)do q.height=top;q.high=nil;q.low=nil end end
   end
  end end
 end

 -- STAIR PROFILE, run twice: early (late=false) before the classifier, so the rock FACE cells that take their height from a
 -- flight's cells see its final profile; and last (late=true) after the ledges, which also grows the steep ones.
 -- (user 2026-10-28, R-34 "stairs follow the 45 degree principle"). TerrainLevels set every flight's profile
 -- once from its floor groups and stretched a one-course flight into the walkable floor at its foot (hidden 8..16 climb on
 -- flat-drawn grass); the pin passes moved the floors afterwards and left the profiles stale. Here every straight run of
 -- step cells (a column or a row, maximal) is profiled again from the FINAL heights of the floors at its two ends: equal
 -- ends = a flat deck; otherwise it climbs evenly from the lower floor to the upper (cell k of n: low = lo + R (k-1)/n,
 -- high = lo + R k/n, height = low, c.stairUp = the unit step towards the high end for TerrainLevels.at). A run steeper
 -- than one course per tile (R > 16 n) grows at its LOWER end into the plain ground beyond it (grass or sand, no mark, tree,
 -- prop tile, ledge or bare drop; parallel runs of one flight grow together), the new cells being stair cells in the
 -- flight's own art (c.stepMid, Gen3Scene.flightTreads); what still exceeds 45 degrees is counted in STAIR_STEEP.
 local function stairProfile(late,kindAt,cnt)
  local okKind={flat=true,sand=true}
  local markSet={}
  for _,m in ipairs(userPins)do markSet[m[1]..':'..m[2]]=true end
  local function C(x,y)return x>=0 and y>=0 and x<l.width and y<l.height and f.cells[Levels.key(x,y)] or nil end
  local function isStep(c)return c and c.step and not c.connector end
  local function endFloor(c)return c and c.floor and (not c.step or c.connector) and c.kind~='water' and c.cls~='WATER' and c.height~=nil and not c.treeLoose end
  local function plain(c)   -- true, or false + the reason (STAIR_STEEP lines)
   if not c then return false,'none' end
   if c.cls~='PLATEAU' then return false,'cls='..tostring(c.cls) end
   if not c.floor or c.step or c.height==nil or c.layer==15 or c.kind=='water' or c.treeLoose or c.connector then return false,'floor/step/deck/water/tree' end
   if c.relief or c.rampExt then return false,'relief' end
   if c.ledge then return false,'ledge' end
   if c.bareDrop then return false,'bareDrop' end
   local k=c.x..':'..c.y
   if markSet[k] then return false,'user mark' end
   if not okKind[kindAt[k] or ''] then return false,'kind='..tostring(kindAt[k]) end
   if (l:cellAt(c.x,c.y).coll or 0)~=0 then return false,'coll='..tostring(l:cellAt(c.x,c.y).coll) end
   return true
  end
  local runs,done,runOf={},{},{}
  local nSteep,nNoEnd,nExt,nFlat,nClimb=0,0,0,0,0
  if late then f.stairSteep={} end
  for y=0,l.height-1 do for x=0,l.width-1 do
   local c=C(x,y)
   if isStep(c) and not done[c] then
    local y0=y;while isStep(C(x,y0-1))do y0=y0-1 end
    local y1=y;while isStep(C(x,y1+1))do y1=y1+1 end
    local x0=x;while isStep(C(x0-1,y))do x0=x0-1 end
    local x1=x;while isStep(C(x1+1,y))do x1=x1+1 end
    local cand={}
    for _,a in ipairs({
     {axis='v',n=y1-y0+1,a=C(x,y0-1),b=C(x,y1+1),first={x,y0},d={0,1}},
     {axis='h',n=x1-x0+1,a=C(x0-1,y),b=C(x1+1,y),first={x0,y},d={1,0}}})do
     if endFloor(a.a) and endFloor(a.b) then
      a.R=math.abs(a.a.height-a.b.height);cand[#cand+1]=a
     end
    end
    local pick
    if #cand==1 then pick=cand[1]
    elseif #cand==2 then
     local v,h=cand[1],cand[2]
     if (v.R>=.25)==(h.R>=.25) then pick=(h.n<v.n) and h or v
     else pick=(v.R>=.25) and v or h end
    end
    if not pick then
     nNoEnd=nNoEnd+1
     done[c]=true   -- (no floor at one end, or none either way: the old profile stays)
    else
     -- cells ordered from the lower end to the upper end
     local lowA=pick.a.height<=pick.b.height   -- a = the north / west end
     local cells={}
     for i=0,pick.n-1 do cells[#cells+1]=C(pick.first[1]+pick.d[1]*i,pick.first[2]+pick.d[2]*i) end
     local up={-pick.d[1],-pick.d[2]}   -- the step from the lower end towards the upper end, if the lower end is north / west it is +d
     local lo,hi=pick.a.height,pick.b.height
     if lowA then up={pick.d[1],pick.d[2]} else lo,hi=hi,lo;local r={};for i=#cells,1,-1 do r[#r+1]=cells[i] end;cells=r end
     for _,q in ipairs(cells)do done[q]=true end
     runs[#runs+1]={cells=cells,up=up,lo=lo,hi=hi,R=hi-lo,n=#cells,axis=pick.axis}
     for _,q in ipairs(cells)do runOf[q]=runs[#runs] end
    end
   end
  end end
  -- extension room for each run, then the parallel runs of one flight share the least of it
  local function room(r,need)
   local q0=r.cells[1];local j=0
   r.why=nil
   while j<need do
    local q=C(q0.x-r.up[1]*(j+1),q0.y-r.up[2]*(j+1))
    local beyond=C(q0.x-r.up[1]*(j+2),q0.y-r.up[2]*(j+2))
    local ok,why=plain(q)
    -- (what lies beyond must be ground at the foot's level: a floor, or the flat deck of another flight - Route 119's landing between two stair runs)
    local fl=beyond and runOf[beyond]
    if ok and not((endFloor(beyond) and math.abs(beyond.height-r.lo)<.25) or (fl and fl.R<.25 and math.abs(fl.lo-r.lo)<.25)) then ok=false;why='nothing at the level beyond' end
    if ok then j=j+1 else r.why=why;break end
   end
   return j
  end
  for _,r in ipairs(runs)do
   r.need=0
   if late and M.STAIR_EXT and r.R>=.25 and r.R>16*r.n+.25 then r.need=math.ceil(r.R/16-1e-6)-r.n end
   r.room=room(r,r.need)
   r.group=r
  end
  -- union runs side by side: same axis, same step direction, same ends and length, lines next to each other
  local function find(r)while r.group~=r do r.group=r.group.group;r=r.group end return r end
  for i=1,#runs do for j=i+1,#runs do
   local a,b=runs[i],runs[j]
   if a.axis==b.axis and a.up[1]==b.up[1] and a.up[2]==b.up[2] and a.n==b.n and math.abs(a.lo-b.lo)<.25 and math.abs(a.hi-b.hi)<.25 then
    local ca,cb=a.cells[1],b.cells[1]
    local lineDist=(a.axis=='v') and math.abs(ca.x-cb.x) or math.abs(ca.y-cb.y)
    local same=(a.axis=='v') and ca.y==cb.y or ca.x==cb.x
    if lineDist==1 and same then local ra,rb=find(a),find(b);if ra~=rb then rb.group=ra end end
   end
  end end
  local gmin={}
  for _,r in ipairs(runs)do local g=find(r);gmin[g]=math.min(gmin[g] or r.room,r.room) end
  for _,r in ipairs(runs)do
   local ext=r.need>0 and math.min(gmin[find(r)],r.need) or 0
   local q0=r.cells[1]
   local all={}
   for j=ext,1,-1 do
    local q=C(q0.x-r.up[1]*j,q0.y-r.up[2]*j)
    q.step=true;q.floor=true;q.cls='DECK';q.stepExt=true;q.stepMid=l:cellAt(q0.x,q0.y).mid;q.treads=q0.treads
    all[#all+1]=q;nExt=nExt+1
   end
   for _,q in ipairs(r.cells)do all[#all+1]=q end
   local N=#all
   if r.R<.25 then
    for _,q in ipairs(all)do q.height=r.lo;q.low=r.lo;q.high=r.lo;q.stairUp=nil end
    nFlat=nFlat+1
   else
    for k,q in ipairs(all)do
     q.low=r.lo+r.R*(k-1)/N;q.high=r.lo+r.R*k/N;q.height=q.low;q.stairUp=r.up
    end
    nClimb=nClimb+1
    if late and r.R>16*N+.25 then
     nSteep=nSteep+1
     f.stairSteep[#f.stairSteep+1]=string.format('%s run x=%d y=%d n=%d R=%.1f axis=%s ext=%d why=%s',def.id,q0.x,q0.y,N,r.R,r.axis,ext,tostring(r.why or (ext<r.need and 'group limited' or '?')))
    end
   end
  end
  if late then cnt.STAIR_RUNS=#runs;cnt.STAIR_CLIMB=nClimb;cnt.STAIR_FLAT=nFlat;cnt.STAIR_EXT=nExt;cnt.STAIR_STEEP=nSteep;cnt.STAIR_NOEND=nNoEnd end
 end

 if userPins and M.STAIR_PROFILE then stairProfile(false) end

 -- PLATEAU RULE (user 2026-10-27, "do everything per platform"): on a hand-drawn map every cell is exactly one class
 -- (f.cells[k].cls): WATER, DECK (a bridge / stair / flight cell), PLATEAU (a walkable floor, or a tree the pin flood
 -- claimed), MASS (rock with a number on it: a flat-topped block at that number) or FACE (unnumbered rock: the band
 -- between two plateaus stands at the UPPER one, its face drops at the lower edge). Rock heights come from a search
 -- over the rock cells round each rock cell: the nearest numbered rock within SLACK cells of the nearest source
 -- wins (MASS), else the highest plateau / water / deck within that reach (FACE). A band beside one level only is
 -- flat at it (no rock stands where no number says so). Gen3Blocks builds the rock cells from these heights.
 if userPins and M.BLOCKS_ON then
  local isRock,rockK={},{}
  local cnt={PLATEAU=0,FACE=0,MASS=0,WATER=0,DECK=0,OTHER=0,TREE_FIX=0,ROCK_FAR=0}
  local kindAt={}
  for y=0,l.height-1 do for x=0,l.width-1 do
   local raw=l:cellAt(x,y);local k=x..':'..y;local c=f.cells[Levels.key(x,y)]
   local shape=shapes.of(spec.primary,spec.secondary,raw.mid,behaviors[raw.mid],raw.coll)
   kindAt[k]=shape.seaRock and 'seaRock' or shape.kind   -- (a sea rock keeps its own builder's height: never a plain blocked tile for OTHER_FIX)
   c.cls=nil;c.srcMax=nil;c.srcPin=nil
   if raw.coll==7 and shape.kind=='cliff' and not shape.seaRock then isRock[k]=true;rockK[#rockK+1]=k
   elseif c.layer==15 or c.step then c.cls='DECK'
   elseif c.kind=='water' and (c.floor or (M.BLOCKED_WATER and pins[k]~=nil and shape.river)) then c.cls='WATER'
   elseif c.floor or pins[k]~=nil then c.cls='PLATEAU'
   elseif shape.kind=='tree' then c.cls='PLATEAU';c.treeLoose=true
   else c.cls='OTHER' end
  end end
  local dirs={{1,0},{-1,0},{0,1},{0,-1}}
  local SLACK,RMAX=M.BLOCKS_SLACK,M.BLOCKS_RMAX
  local function sourceOf(k,c)
   -- a non-rock cell with a height is a source: numbered rock cells are sources of their own kind
   if isRock[k] then if pins[k]~=nil then return pins[k],true end return nil end
   if c.cls=='PLATEAU' or c.cls=='WATER' or c.cls=='DECK' then return c.height,false end
   if c.cls=='OTHER' and c.height then return c.height,false,true end   -- (a blocked non-rock cell: its support-fill height, only when nothing better is in reach)
   return nil
  end
  for _,k0 in ipairs(rockK)do
   local c0=f.cells[k0]
   if pins[k0]~=nil then c0.height=pins[k0];c0.high=nil;c0.low=nil;c0.cls='MASS';c0.srcPin=k0;c0.srcMax=pins[k0];cnt.MASS=cnt.MASS+1
   else
    local x0,y0=c0.x,c0.y
    local seen={[k0]=true};local ring={{x0,y0}};local d=0;local dmin
    local bestNum,bestNumK,bestMax,bestOther,bestMin
    while #ring>0 and d<=RMAX and (not dmin or d<=dmin+SLACK) do
     local nxt={}
     for _,q in ipairs(ring)do
      for _,dd in ipairs(dirs)do
       local nx,ny=q[1]+dd[1],q[2]+dd[2];local k=nx..':'..ny
       if not seen[k] and nx>=0 and ny>=0 and nx<l.width and ny<l.height then
        seen[k]=true
        local c=f.cells[Levels.key(nx,ny)]
        local lv,num,weak=sourceOf(k,c)
        if lv~=nil and weak then if not bestOther or lv>bestOther then bestOther=lv end
        elseif lv~=nil then
         if not dmin then dmin=d+1 end
         if num then if not bestNum or lv>bestNum then bestNum,bestNumK=lv,k end
         else if not bestMax or lv>bestMax then bestMax=lv end;if not bestMin or lv<bestMin then bestMin=lv end end
        end
        if isRock[k] then nxt[#nxt+1]={nx,ny} end
       end
      end
     end
     ring=nxt;d=d+1
    end
    if bestNum then c0.height=bestNum;c0.cls='MASS';c0.srcPin=bestNumK;c0.srcMax=bestNum;cnt.MASS=cnt.MASS+1
    elseif bestMax then c0.height=(M.BAND_LEVEL=='lower') and bestMin or bestMax;c0.cls='FACE';c0.srcMax=bestMax;c0.srcMin=bestMin;cnt.FACE=cnt.FACE+1
    elseif bestOther then c0.height=bestOther;c0.cls='FACE';c0.srcMax=bestOther;cnt.FACE=cnt.FACE+1
    else c0.cls='FACE';c0.srcMax=c0.height;cnt.FACE=cnt.FACE+1;cnt.ROCK_FAR=cnt.ROCK_FAR+1 end   -- (no source within reach: the support fill's height stays)
    c0.high=nil;c0.low=nil
   end
  end
  -- any other blocked non-rock cell (a sign, a fence, a blocked grass strip, a building's footprint) is part of the
  -- plateau it touches: it stands on the nearest PLATEAU / WATER cell with a height reached through non-rock cells,
  -- never through rock (the support fill left Mt Pyre's summit strip at 0 inside the 20 plateau: open shafts)
  -- ...and so is a small POCKET of walkable cells no mark reached (enclosed by rock and props, so the pin flood never
  -- got there: Mt Pyre's grave plots beside the pillars stood at 0, 20 courses down, and the view went through the
  -- mountain): a run of at most M.POCKET_MAX such cells takes the same nearest height
  cnt.OTHER_FIX=0;cnt.POCKET_FIX=0
  local function orphan(n,nk)return n.cls=='PLATEAU' and n.floor and pins[nk]==nil and not n.step and not n.treeLoose end
  local pocketOf={}
  for y=0,l.height-1 do for x=0,l.width-1 do
   local k=x..':'..y;local c=f.cells[Levels.key(x,y)]
   local isOther=c.cls=='OTHER' and kindAt[k]=='flat'   -- (plain blocked tiles only: sea rocks, ledges, rails, piers keep their builders' heights)
   local isPocket=false
   if not isOther and orphan(c,k) then
    if pocketOf[k]==nil then
     -- the run of unmarked walkable cells this one is in (through unmarked walkable cells only), capped
     local comp,stack,seen={},{{x,y}},{[k]=true}
     while #stack>0 and #comp<=M.POCKET_MAX do
      local q=table.remove(stack);comp[#comp+1]=q
      for _,dd in ipairs(dirs)do
       local nx,ny=q[1]+dd[1],q[2]+dd[2];local nk=nx..':'..ny
       if not seen[nk] and nx>=0 and ny>=0 and nx<l.width and ny<l.height then
        seen[nk]=true
        local n=f.cells[Levels.key(nx,ny)]
        if orphan(n,nk) then stack[#stack+1]={nx,ny} end
       end
      end
     end
     local small=#comp<=M.POCKET_MAX
     for _,q in ipairs(comp)do pocketOf[q[1]..':'..q[2]]=small end
    end
    isPocket=pocketOf[k]==true
   end
   if isOther or isPocket then
    local seen={[k]=true};local ring={{x,y}};local found
    for _=1,8 do
     local nxt={}
     for _,q in ipairs(ring)do for _,dd in ipairs(dirs)do
      local nx,ny=q[1]+dd[1],q[2]+dd[2];local nk=nx..':'..ny
      if not seen[nk] and nx>=0 and ny>=0 and nx<l.width and ny<l.height and not isRock[nk] then
       seen[nk]=true
       local n=f.cells[Levels.key(nx,ny)]
       local src=(n.cls=='PLATEAU' and pins[nk]~=nil) or n.cls=='WATER' or (n.cls=='PLATEAU' and n.floor and not orphan(n,nk))
       if src and n.height and not n.treeLoose then found=math.min(found or n.height,n.height)
       elseif n.cls=='OTHER' or n.treeLoose or orphan(n,nk) then nxt[#nxt+1]={nx,ny} end
      end
     end end
     if found then break end
     ring=nxt;if #ring==0 then break end
    end
    -- sealed in by rock on every side (Mt Pyre's grave plot (16,9)): the lowest rock beside it
    if not found then
     for _,dd in ipairs(dirs)do
      local nk=(x+dd[1])..':'..(y+dd[2])
      if isRock[nk] then local n=f.cells[Levels.key(x+dd[1],y+dd[2])];if n and n.height then found=math.min(found or n.height,n.height) end end
     end
    end
    if found and found~=c.height then
     c.height=found;c.high=nil;c.low=nil
     if isPocket then cnt.POCKET_FIX=cnt.POCKET_FIX+1 else cnt.OTHER_FIX=cnt.OTHER_FIX+1 end
    end
   end
  end end
  -- a tree no mark reached stands on the nearest floor it touches through other blocked ground, never through rock
  -- (a clump at a cliff's foot took the cliff top's height from the support fill). Runs AFTER the pocket pass: a pocket
  -- of walkable cells inside a marked tree clump (Route 121 (2,3)) had its support-fill height when the trees looked, so the clump sank 5 courses
  for y=0,l.height-1 do for x=0,l.width-1 do
   local k=x..':'..y;local c=f.cells[Levels.key(x,y)]
   if c.treeLoose then
    local seen={[k]=true};local ring={{x,y}};local found
    for _=1,8 do
     local nxt={}
     for _,q in ipairs(ring)do for _,dd in ipairs(dirs)do
      local nx,ny=q[1]+dd[1],q[2]+dd[2];local nk=nx..':'..ny
      if not seen[nk] and nx>=0 and ny>=0 and nx<l.width and ny<l.height and not isRock[nk] then
       seen[nk]=true
       local n=f.cells[Levels.key(nx,ny)]
       if n.floor and n.height and n.cls~='DECK' then found=math.min(found or n.height,n.height)
       elseif not n.floor then nxt[#nxt+1]={nx,ny} end
      end
     end end
     if found then break end
     ring=nxt;if #ring==0 then break end
    end
    if found and found~=c.height then c.height=found;c.high=nil;c.low=nil;cnt.TREE_FIX=cnt.TREE_FIX+1 end
   end
  end end
  -- RAMP EXTENSION (user 2026-10-27, "almost 45 degrees"; extend the footprint rather than steepen): a band (a connected run
  -- of FACE cells) rises from its lowest to its highest neighbouring plateau across its own rows; where that is steeper than
  -- SLOPE_DEG the walkable plain ground at the lower level beside it is lifted in a gradient so the slope starts further
  -- out: the foot of the band stands at hi - s*r (r = the rows of band across), each cell k rows out at hi - s*(r+k-1), to
  -- the lower level (s = 16*tan(SLOPE_DEG) px a row). The cells are flagged relief, so Gen3Scene's slope pass bends their
  -- tops and groundAt follows (it runs after the tree / blocked-ground passes, so a tree or a blocked flat tile there takes the lifted height too). Only ground no mark, stair, deck, tree or prop-blocking tile holds; a band that would need
  -- more than RAMP_EXT_MAX extra rows is left as it is (a mountain wall, not a ridge).
  if M.RAMP_EXT then
   local tanc=math.tan(math.rad(M.SLOPE_DEG))
   local sPx=16*tanc
   local okKind={flat=true,grass=true,flowers=true,sand=true}
   local orig={}
   local markSet={}   -- (the user's own marks only: `pins` also holds every cell a mark's flood claimed)
   for _,m in ipairs(userPins)do markSet[m[1]..':'..m[2]]=true end
   for y=0,l.height-1 do for x=0,l.width-1 do local c=f.cells[Levels.key(x,y)];orig[c]=c.height end end
   local function eligible(n,nk,hl)
    if n and n.cls=='OTHER' then return kindAt[nk]=='flat' and orig[n] and math.abs(orig[n]-hl)<.25 and not markSet[nk] end
    if not (n and n.cls=='PLATEAU' and orig[n] and math.abs(orig[n]-hl)<.25 and not markSet[nk] and not n.step and n.layer~=15) then return false end
    if M.RAMP_EXT_TREES and kindAt[nk]=='tree' then return true end
    return n.floor and not n.treeLoose and n.kind~='water' and okKind[kindAt[nk] or ''] and (l:cellAt(n.x,n.y).coll or 0)==0
   end
   local target,seeds={},{}
   -- every band cell with a lower-level plateau cell beside it: walk straight into the band to the first non-band cell
   -- (r = band cells across, hu = the level there); the rise hl..hu needs ceil((hu-hl)/s) rows in all
   for _,k0 in ipairs(rockK)do
    local c0=f.cells[Levels.key(tonumber(k0:match('^(%-?%d+)')),tonumber(k0:match(':(%-?%d+)$')))]
    if c0.cls=='FACE' then
     for _,dd in ipairs(dirs)do
      local nx,ny=c0.x+dd[1],c0.y+dd[2];local nk=nx..':'..ny
      local n=f.cells[Levels.key(nx,ny)]
      if n and n.cls~='FACE' and n.cls~='MASS' and orig[n] then
       local hl=orig[n]
       local r,qx,qy=0,c0.x,c0.y
       local u
       while true do
        local q=f.cells[Levels.key(qx,qy)]
        if q and q.cls=='FACE' then r=r+1;qx,qy=qx-dd[1],qy-dd[2]
        else u=q;break end
        if r>8 then break end
       end
       if u and (u.cls=='PLATEAU' or u.cls=='WATER' or u.cls=='DECK') and orig[u] and orig[u]>hl+.25 then
        local need=math.ceil((orig[u]-hl)/sPx-1e-6)
        local why
        if need<=r then why='OK_ALREADY'
        elseif need-r>M.RAMP_EXT_MAX then why='TALL'
        elseif n.cls~='PLATEAU' and n.cls~='OTHER' then why='LOWER_'..n.cls
        elseif not eligible(n,nk,hl) then why=markSet[nk] and 'MARK' or 'INELIGIBLE'
        else why='PLACED';seeds[#seeds+1]={n=n,hl=hl,hu=orig[u],r=r,need=need} end
        cnt['EXT_'..why]=(cnt['EXT_'..why] or 0)+1
       end
      end
     end
    end
   end
   for _,sd in ipairs(seeds)do
    local seen={[sd.n]=true};local ring={sd.n}
    for k=1,sd.need-sd.r do
     local nxt={}
     for _,n in ipairs(ring)do
      local h=math.max(sd.hl,sd.hu-sPx*(sd.r+k-1))
      if h>(target[n] or sd.hl) then target[n]=h end
      if k<sd.need-sd.r then
       for _,dd in ipairs(dirs)do
        local m=f.cells[Levels.key(n.x+dd[1],n.y+dd[2])];local mk=(n.x+dd[1])..':'..(n.y+dd[2])
        if m and not seen[m] and eligible(m,mk,sd.hl) then seen[m]=true;nxt[#nxt+1]=m end
       end
      end
     end
     ring=nxt
    end
   end
   local ext=0
   for n,h in pairs(target)do if h>n.height+.25 then n.height=h;n.relief=true;n.rampExt=true;n.high=nil;n.low=nil;ext=ext+1 end end
   cnt.RAMP_EXT=ext
  end
  -- HIDDEN LEDGES (user 2026-10-28, R-33 "only rock ledges or stairs" + "elevating rocks are on a 45 degree angle, all
  -- around the platform"; Safari NW crops: the edge behind the boulder and the edge under the tree row are "the same
  -- type ledge of 45 degrees"). Where a plateau cell stands over a lower plateau cell with no band tile between them
  -- (the top-down art hides those faces: only the rim line of tiles 002/0D3/0D4/239... is drawn), the lower plain cell
  -- beside the edge becomes a ROCK LEDGE: a wedge in the face art of the nearest band (Gen3Blocks.ledgeFaceUV),
  -- sloping at SLOPE_DEG from the upper edge down to the lower level over ceil(rise/s) rows (s = 16 tan(SLOPE_DEG) px
  -- a row), the convex corners rounded (a vertex stands at hu - s * its distance to the upper cell's square, so the
  -- diagonal cell at a corner is a quarter cone). Field heights stay (c.height = the lower level: the pin and class
  -- gates see nothing); the wedge is c.ledge = {nw,ne,se,sw} offsets from c.height, which Gen3Scene draws as a sloped
  -- top in face art and TerrainLevels.at stands the player on. Only plain walkable ground can become ledge (flat or
  -- sand kind, no mark, tree, stair, deck, water, tall grass or flowers: nothing stands on a slope); an edge whose
  -- lower cell cannot gets a plain riser in the face art instead (u.bareDrop, Gen3Scene's step walls). The upper cell
  -- may be anything that is not rock and has a height: grass, a tree, a boulder or a sign on the plateau's rim.
  if M.LEDGES and not M.LEDGE_SKIP[def.id] then
   local sPx=16*math.tan(math.rad(M.SLOPE_DEG))
   local okKind={flat=true,sand=true}
   local markSet={}
   for _,m in ipairs(userPins)do markSet[m[1]..':'..m[2]]=true end
   for _,c in pairs(f.cells)do c.ledge=nil;c.bareDrop=nil end
   -- (only plain outdoor kinds on either side: never a building, a jump ledge, a stair, a deck, a planter or town
   -- masonry, whose edges have builders of their own)
   local plainKind={flat=true,grass=true,flowers=true,sand=true,tree=true,shrub=true,rock=true,seaRock=true,sign=true,fence=true}
   local function upper(c)return c and c.height and (c.cls=='PLATEAU' or c.cls=='OTHER') and not c.step and c.layer~=15 and c.kind~='water' and not c.rampExt and plainKind[kindAt[c.x..':'..c.y] or ''] end
   local function lowerPlain(n,hu)return n and n.height and (n.cls=='PLATEAU' or n.cls=='OTHER' or (n.cls=='WATER' and hu-n.height>=32)) and not n.step and n.layer~=15 and (plainKind[kindAt[n.x..':'..n.y] or ''] or n.cls=='WATER') end   -- (toward water only a real sea cliff of two courses or more gets rock face art: a beach one course over the sea keeps its sand bank, a half-course platform its own edge: Pacifidlog)
   local function eligible(n,nk)
    return n and n.cls=='PLATEAU' and n.floor and n.height and not n.step and n.layer~=15 and n.kind~='water' and not n.treeLoose
     and not n.relief and not markSet[nk] and okKind[kindAt[nk] or ''] and (l:cellAt(n.x,n.y).coll or 0)==0
   end
   local vh={}   -- vertex (x,y of the NW corner of cell x,y) -> height
   local function vkey(x,y)return x..','..y end
   local placed,bare,tall=0,0,0
   local cellsHit={}
   for y=0,l.height-1 do for x=0,l.width-1 do
    local u=f.cells[Levels.key(x,y)]
    if upper(u) then
     local hu=u.height
     for _,dd in ipairs(dirs)do
      local nx,ny=x+dd[1],y+dd[2];local nk=nx..':'..ny
      local n=f.cells[Levels.key(nx,ny)]
      if lowerPlain(n,hu) and hu-n.height>=M.LEDGE_MIN then
       local hl=n.height
       if not eligible(n,nk) then u.bareDrop=true;bare=bare+1
       else
        local need=math.ceil((hu-hl)/sPx-1e-6)
        if need>M.LEDGE_MAX then tall=tall+1;u.bareDrop=true;goto nextdir end   -- (a mountain wall, not a ledge: Pyre summit 21 courses, Sootopolis crater 11, Ever Grande 8; no footprint for a slope, the riser stands in rock art)
        local s=(hu-hl)/need
        placed=placed+1
        -- the lower cells within `need` of u (Chebyshev), connected to u through eligible cells of this level
        local seen={[u]=true};local ring={u}
        for _=1,need do
         local nxt={}
         for _,q in ipairs(ring)do
          for ox=-1,1 do for oy=-1,1 do
           local mx,my=q.x+ox,q.y+oy
           if math.max(math.abs(mx-x),math.abs(my-y))<=need then
            local m=f.cells[Levels.key(mx,my)]
            if m and not seen[m] and eligible(m,mx..':'..my) and math.abs(m.height-hl)<.25 then seen[m]=true;nxt[#nxt+1]=m end
           end
          end end
         end
         for _,m in ipairs(nxt)do
          cellsHit[m]=true
          for _,v in ipairs({{m.x,m.y},{m.x+1,m.y},{m.x+1,m.y+1},{m.x,m.y+1}})do
           -- distance from the vertex to the closed square of u (cells x..x+1, y..y+1)
           local ddx=math.max(x-v[1],0,v[1]-(x+1));local ddy=math.max(y-v[2],0,v[2]-(y+1))
           local h=hu-s*math.sqrt(ddx*ddx+ddy*ddy)
           local k=vkey(v[1],v[2])
           if h>hl+1e-6 and h>(vh[k] or -1e9) then vh[k]=h end
          end
         end
         ring=nxt
        end
       end
      end
      ::nextdir::
     end
    end
   end end
   local ledges=0
   for m in pairs(cellsHit)do
    local hl=m.height
    local o={}
    for i,v in ipairs({{m.x,m.y},{m.x+1,m.y},{m.x+1,m.y+1},{m.x,m.y+1}})do
     local h=vh[vkey(v[1],v[2])]
     o[i]=h and math.max(0,h-hl) or 0
    end
    if o[1]>.25 or o[2]>.25 or o[3]>.25 or o[4]>.25 then m.ledge=o;ledges=ledges+1 end
   end
   cnt.LEDGE_EDGES=placed;cnt.LEDGE_CELLS=ledges;cnt.LEDGE_BARE=bare;cnt.LEDGE_TALL=tall
  end
  if M.STAIR_PROFILE then stairProfile(true,kindAt,cnt) end   -- (the final pass: with the extension, after the ledges)
  for _,c in pairs(f.cells)do if c.cls=='PLATEAU' or c.cls=='WATER' or c.cls=='DECK' or c.cls=='OTHER' then cnt[c.cls]=cnt[c.cls]+1 end end
  f.classes=cnt;M.classes[def.id]=cnt
 end
--@HOLE field-epilogue: cache store, M.cell, M.at [spec HeightField §6.6]
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
--@HOLE bind-open: M.bind(cells, regions) signature [spec HeightField §6.7]
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
--@HOLE bind-floor: per region, the cell's floor/base/floorHigh lookup [spec HeightField §6.7]
     -- BORDER (PLATEAU RULE, hand-drawn maps): the fill beyond the edge continues its own family's ground, never a
     -- rock's: grass or trees beside a cliff edge cell took that rock's height (stair-steps of lawn at Sootopolis's
     -- top-left, trees 15 courses up at Route 113's east end); water is the sea's 0
     if q and q.cls and r.floorField.classes and c.boundary then
      local want=(c.boundary=='mountain') and 'rock' or (c.boundary=='water') and 'water' or 'floor'
      local function fam(cell)
       if not cell then return nil end
       if cell.cls=='MASS' or cell.cls=='FACE' then return 'rock' end
       if cell.cls=='WATER' then return 'water' end
       if cell.cls=='PLATEAU' or cell.cls=='DECK' then return 'floor' end
       return nil
      end
      if want=='water' then q={height=0}
      elseif fam(q)~=want then
       -- along the edge (the clamped axis stays), outward up to 8 cells each way, the nearest cell of the family
       local best
       for dd=1,8 do
        for _,sgn in ipairs({-1,1})do
         local qx,qy=x,y
         if c.cx-r.x~=x then qy=y+sgn*dd else qx=x+sgn*dd end
         local cand=qx>=0 and qy>=0 and qx<r.w and qy<r.h and r.floorField.cells[Levels.key(qx,qy)]
         if cand and fam(cand)==want then best=cand;break end
        end
        if best then break end
       end
       if best then q=best elseif want=='floor' and fam(q)=='rock' then
        -- grass beside rock with no floor near on the edge: the lowest floor the rock's search saw, or the rock itself
        q={height=q.srcMax or q.height}
       end
      end
     end
--@HOLE bind-donor: the nearest-region donor fallback for c.base [spec HeightField §6.7]
 M.supportFill(cells,regions)
 -- Complete assemblies use a single foundation, sampled at their entrance (from the bound heights:
 -- an entrance cell belonging to another assembly already moved to that one's foundation in pairs()
 -- order, so Route 110's gatehouse stood at 0 or 48 px from one visit to the next).
 local bound={}
 for _,c in pairs(cells)do bound[c]=c.base end
--@HOLE bind-props-open: the props' groundHeight settle, head [spec HeightField §6.7]
    local below=cells[x..':'..y]or c;g.groundHeight=bound[below] or 0
    -- (a drawn stair at the door that the solver did not make a flight - a stoop, rated as the path
    -- below it: the building stands a stair's rise up, or the stair lies flat - Sootopolis' houses)
    if below~=c and below.shape and below.shape.kind=='steps' and not (below.floor and below.floor.step) then
     g.groundHeight=g.groundHeight+M.STOOP end
--@HOLE bind-props-close: the props' groundHeight settle, tail [spec HeightField §6.7]
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
 -- A stamped tree standing under a walkable crown cell (the cartridge draws the crown over the floor the
 -- player walks on: Gen3TreeStamps' General trees, shape.crownFloor) takes that cell's floor. Its own cell is
 -- blocked, so the solver rated it the open ground below the terrace while everything round it stands on the
 -- terrace: Route 112 32,23 beside the cable-car station was a one-cell hole 48 px deep with the tree in it.
 for _,c in pairs(cells)do
  if c.shape and c.shape.crownFloor then
   local n=cells[c.cx..':'..(c.cy-1)]
   if n and (n.collision or 0)==0 and not n.boundary then c.base=n.base;c.floorHigh=nil end
  end
 end
--@HOLE bind-close: end of the props loop / M.bind [spec HeightField §6.7]
function M.lift(vertices,start,height,back)
--@HOLE lift-guard: M.lift: return when height is 0 [spec HeightField §6.8]
 -- (setBack: a stepped deck stands as far south of its drawing as it is lifted, Gen3Decks)
--@HOLE lift-loop: M.lift: the vertex loop head [spec HeightField §6.8]
  -- (the third anchor value is the height a card pivots and sways about; 0 means
  -- "no anchor": a solid tree model of a standing object carries {0,0,0}, and
  -- lifting that to its terrace height made the shader lean and sway the whole
  -- model like a card, so trees on raised ground hung in the sky from the
  -- turned and low cameras)
  if v[9] and v[9]~=0 then v[9]=v[9]+height end
  if back then v[3]=v[3]+height end
--@HOLE lift-return: M.lift tail, M.invalidate, return M [spec HeightField §6.8]
