-- Physical support from native stair topology and reviewed source surfaces
local V=...
local Levels=V.require('TerrainLevels')
local Pairs=V.require('Gen3Tilesets')
local cache=setmetatable({},{__mode='k'})
local M={}
local okP,PinData=pcall(V.require,'Gen3PinData')
if not okP then PinData=nil end
M.PINS_ON=true
M.pinZones={}
M.CONNECTOR_MAX=12
M.BLOCKED_MARK_REACH=8
M.TREE_SETTLE={EM_ROUTE120={{35,38,85,86,0},{34,34,85,86,1}},EM_ROUTE111={{12,12,131,131,1}}}
M.BLOCKED_WATER=true
M.WATER_LEGS={fortree={[0x0F5]=true,[0x0F8]=true,[0x0F9]=true,[0x0FA]=true,[0x0FC]=true}}
M.WATER_DECKS={fortree={[0x0ED]=true,[0x0F0]=true,[0x0F1]=true,[0x0F2]=true,[0x0FB]=true,[0x0E8]=true,[0x0EC]=true,[0x0F3]=true,[0x0F4]=true,[0x0F7]=true,[0x0FD]=true}}
M.PIN_PX=16
M.PIN_SKIP={}
M.BLOCKS_ON=true
M.BLOCKS_SLACK=2
M.RAMP_EXT=false;M.SLOPE_DEG=45;M.RAMP_EXT_MAX=3;M.RAMP_EXT_TREES=false -- OFF (R-33): grass and sand are never a slope.
M.PLAIN_GRASS_MIDS={[0x001]=true,[0x002]=true}
M.ORPHAN_MAX=24
M.STAIR_EXT=true -- the foot extension of steep flights
M.STAIR_PROFILE=true -- stair profile pass (R-34)
M.LEDGES=true;M.LEDGE_MIN=8;M.LEDGE_MAX=3 -- hidden ledges (R-35): rock wedge on the lower cell of an unbanded plateau edge
M.LEDGE_SKIP={EM_FORTREE_CITY=true}
M.BAND_LEVEL='lower'
M.POCKET_MAX=12
M.BLOCKS_RMAX=12
M.classes={} -- mapId -> class counts of the last classify (gate)
M.MAX_FLIGHT=4
M.COURSE=16
M.MAX_STEP=3
M.COURSE_BY_MAP={EM_FORTREE_CITY=32,EM_ROUTE110=48}
M.ELEV_REMAP={EM_FORTREE_CITY={[15]=4},EM_ROUTE110={[15]=4},EM_ROUTE109={[4]=3},
 EM_ROUTE119={[15]=4}}
M.STEP_MIDS={EM_ROUTE110={[0x2D4]=true}}
for id,d in pairs(V.require('Gen3Decks').MAPS)do M.STEP_MIDS[id]=d.steps end
local FLIGHT_TREADS={general__mauville={[0x2D4]=8},general__mossdeep={[0xAF]=2,[0xCF]=2},general__lilycove={[0xAF]=2,[0xCF]=2},general__sootopolis={[0x244]=2,[0x245]=2}}
M.DAIS={EM_LILYCOVE_CITY_CONTEST_HALL={h=10,rects={{18,7,32,16},{6,19,20,28},{30,19,44,28}},
 steps={[0x283]=true,[0x284]=true,[0x285]=true,[0x293]=true,[0x294]=true,[0x295]=true,[0x2B3]=true,[0x2B4]=true,[0x2B5]=true},
 furniture={[0x26F]=true,[0x277]=true,[0x268]=true,[0x269]=true,[0x26A]=true,[0x270]=true,[0x272]=true,[0x278]=true,[0x279]=true,[0x27A]=true}}}
M.DAIS.EM_BATTLE_FRONTIER_BATTLE_ARENA_LOBBY={h=8,rects={{0,3,15,7}},steps={},
 mids={[0x201]=true,[0x21F]=true,[0x223]=true,[0x224]=true,[0x225]=true,[0x226]=true,[0x215]=true,[0x216]=true}}
do
 local hall={h=48,anySteps=true,steps={[0x2E1]=true,[0x2E2]=true,[0x2D9]=true,[0x2DA]=true},low={[0x2E7]=true}}
 for n=1,5 do local d={};for k,v in pairs(hall)do d[k]=v end;d.rects={{0,3,10,4}};M.DAIS['EM_EVER_GRANDE_CITY_HALL'..n]=d end
end
local function daisAt(d,x,y,mid)
 if d.mids and mid and not d.mids[mid] then return false end
 for _,r in ipairs(d.rects)do if x>=r[1] and x<=r[3] and y>=r[2] and y<=r[4] then return true end end
end
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
function M.daisSettle(cells,def)
 local d=def and M.DAIS[def.id];if not d then return end
 if d.low then for _,c in pairs(cells)do if d.low[c.mid] then c.base=0 end end end
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
 EM_ROUTE111_OLD_LADYS_REST_STOP={y0=0,y1=6,h=8}} -- same tatami step
M.SINK_MAPS={EM_MOSSDEEP_CITY=16}
M.MARKER_CELLS=4
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
 local pins
 local StairT=V.data('gen3_stair_terraces')
 local gen=StairT[def.id]
 local stairCells={}
 local zoneOf={}
 local keepRated=false
 if gen then
  for _,c in ipairs(gen.stairs)do stairCells[c[1]..':'..c[2]]=true end
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
   pins=pins or {};keepRated=true
   for zi,row in ipairs(gen.pins)do floodPin(zi,row,row[3]*(gen.rise or 16)) end
   for _,c in ipairs(gen.cells or {})do
    local x0,y0,x1,y1,lv=c[1],c[2],c[1],c[2],c[3]
    if c[5] then x1,y1,lv=c[3],c[4],c[5] end
    for y=y0,y1 do for x=x0,x1 do pins[x..':'..y]=lv*(gen.rise or 16) end end
   end
  else
   for zi,row in ipairs(gen.pins)do pins=pins or {}
    local h=row[3]*(gen.rise or StairT.rise)
    if row[4]=='zone' then floodPin(zi,row,h) else pins[row[1]..':'..row[2]]=h end
   end
   for _,c in ipairs(gen.cells or {})do
    local x0,y0,x1,y1,lv=c[1],c[2],c[1],c[2],c[3]
    if c[5] then x1,y1,lv=c[3],c[4],c[5] end
    for y=y0,y1 do for x=x0,x1 do pins[x..':'..y]=lv*(gen.rise or StairT.rise) end end
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
 -- Elevation-0 plain grass between floors is a walk-through, not a stair.
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
      elseif not (n and n.coll==0 and n.elev==15) then votes.open=true end -- cliff, water, edge: a real deck
     end
    end
    local levels=0;local best
    for e in pairs(votes)do if e~='open' then levels=levels+1;best=e end end
    if #list<=M.MARKER_CELLS and not votes.open and levels==1 then
     for _,p in ipairs(list)do relevel[p[1]..':'..p[2]]=best end
    end
   end
  end end
 end
 local bridgeElev={}
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
  local function riverAt(n)return shapes.of(spec.primary,spec.secondary,n.mid,behaviors[n.mid],n.coll).river==true end
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
     claimed[k]=zi;pins[k]=userPins[zi][3]*M.PIN_PX;zoneOf[k]=zi;front[#front+1]={nx,ny,zi}
    elseif nd and nd.coll~=7 and (M.WATER_DECKS[spec.secondary] or {})[nd.mid] then
     passed[k]=true;front[#front+1]={nx,ny,zi}
    elseif n and n.coll==7 and not inf.water and treeAt(n) then
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
  do
   local dirs={{1,0},{-1,0},{0,1},{0,-1}}
   local function loose(n,x,y)return n and n.coll~=7 and n.elev~=1 and not claimed[x..':'..y] and not waterAt(n) end -- level 1 = water level
   local done={}
   for y0=0,l.height-1 do for x0=0,l.width-1 do
    local n0=l:cellAt(x0,y0)
    if loose(n0,x0,y0) and not done[x0..':'..y0] then
     local comp,stack,bad,height,zone,zones={},{{x0,y0}},false,nil,nil,{}
     done[x0..':'..y0]=true
     while #stack>0 do
      local q=table.remove(stack);comp[#comp+1]=q
      local nq=l:cellAt(q[1],q[2])
      if barrier(nq,q[1],q[2],true) or #comp>M.CONNECTOR_MAX then bad=true end
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
 local flightPair=def.midLayout and def.midLayout.pair
 Levels.mapId=def.id
 Levels.stretch=not(userPins and M.STAIR_PROFILE)
 local f=Levels.build(l.width,l.height,function(x,y)
  local raw=l:cellAt(x,y);local beh=behaviors[raw.mid]
  if relevel[x..':'..y] then raw={mid=raw.mid,coll=raw.coll,elev=relevel[x..':'..y]} end
  if flatIn[x..':'..y] then raw={mid=raw.mid,coll=raw.coll,elev=3} end
  local remap=M.ELEV_REMAP[def.id]
  local hElev=(remap and remap[raw.elev]) or bridgeElev[x..':'..y] or raw.elev
  local dz=dais and daisAt(dais,x,y,raw.mid)
  local step=((dz or (dais and dais.anySteps)) and dais.steps[raw.mid]) or beh==0x2A or beh==0x1D0 or climb[x..':'..y]==true or stairCells[x..':'..y]==true or (M.STEP_MIDS[def.id] and M.STEP_MIDS[def.id][raw.mid] and raw.coll==0) or false;local jump=beh and beh>=0x38 and beh<=0x3F -- 0x1D0: Emerald MUDDY_SLOPE
  local shape=shapes.of(spec.primary,spec.secondary,raw.mid,beh,raw.coll)
  local pinned=raw.coll~=7 and not step and not jump and raw.elev>=3 and shape.kind~='water'
  return {floor=(dz and not step) or (raw.coll~=7 and not step and not jump),step=step,drop=drop[beh],layer=raw.elev,behavior=beh,
   treads=step and ((FLIGHT_TREADS[flightPair] or {})[raw.mid] or 4) or nil,
   waterfall=beh==0x13 or beh==0x113,
   kind=shape.kind,seed=0,anchor=(pins and pins[x..':'..y]~=nil) or nil,zone=zoneOf[x..':'..y],
   pin=(pins and pins[x..':'..y]) or ((not pins or keepRated) and raw.coll~=7 and raw.elev==1 and shape.kind~='water' and 0) or ((not pins or keepRated) and pinned and math.min(hElev-3,M.MAX_STEP)*(M.COURSE_BY_MAP[def.id] or M.COURSE) or nil)}
 end,function(a,b,d)
  local layer=a.layer==b.layer and a.zone==b.zone
  return layer and (a.kind=='water')==(b.kind=='water') and not blocked[d][a.behavior] and not blocked[opposite[d]][b.behavior]
 end,6,V.require('BuildBudget').tick)
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
 local sink=not userPins and M.SINK_MAPS[def.id]
 if sink then
  for _,c in pairs(f.cells)do
   for _,k in ipairs({'height','high','low','ledgeLow'})do
    if c[k]~=nil then c[k]=math.max(0,c[k]-sink) end
   end
  end
 end
 -- Waterfalls are vertical: a fall stands at its upper pool's level.
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

 -- Runs twice: before the classifier and last, after the ledges.
 local function stairProfile(late,kindAt,cnt)
  local okKind={flat=true,sand=true}
  local markSet={}
  for _,m in ipairs(userPins)do markSet[m[1]..':'..m[2]]=true end
  local function C(x,y)return x>=0 and y>=0 and x<l.width and y<l.height and f.cells[Levels.key(x,y)] or nil end
  local function isStep(c)return c and c.step and not c.connector end
  local function endFloor(c)return c and c.floor and (not c.step or c.connector) and c.kind~='water' and c.cls~='WATER' and c.height~=nil and not c.treeLoose end
  local function plain(c) -- true, or false + the reason (STAIR_STEEP lines)
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
     done[c]=true
    else
     local lowA=pick.a.height<=pick.b.height -- a = the north / west end
     local cells={}
     for i=0,pick.n-1 do cells[#cells+1]=C(pick.first[1]+pick.d[1]*i,pick.first[2]+pick.d[2]*i) end
     local up={-pick.d[1],-pick.d[2]}
     local lo,hi=pick.a.height,pick.b.height
     if lowA then up={pick.d[1],pick.d[2]} else lo,hi=hi,lo;local r={};for i=#cells,1,-1 do r[#r+1]=cells[i] end;cells=r end
     for _,q in ipairs(cells)do done[q]=true end
     runs[#runs+1]={cells=cells,up=up,lo=lo,hi=hi,R=hi-lo,n=#cells,axis=pick.axis}
     for _,q in ipairs(cells)do runOf[q]=runs[#runs] end
    end
   end
  end end
  local function room(r,need)
   local q0=r.cells[1];local j=0
   r.why=nil
   while j<need do
    local q=C(q0.x-r.up[1]*(j+1),q0.y-r.up[2]*(j+1))
    local beyond=C(q0.x-r.up[1]*(j+2),q0.y-r.up[2]*(j+2))
    local ok,why=plain(q)
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

 if userPins and M.BLOCKS_ON then
  local isRock,rockK={},{}
  local cnt={PLATEAU=0,FACE=0,MASS=0,WATER=0,DECK=0,OTHER=0,TREE_FIX=0,ROCK_FAR=0}
  local kindAt={}
  for y=0,l.height-1 do for x=0,l.width-1 do
   local raw=l:cellAt(x,y);local k=x..':'..y;local c=f.cells[Levels.key(x,y)]
   local shape=shapes.of(spec.primary,spec.secondary,raw.mid,behaviors[raw.mid],raw.coll)
   kindAt[k]=shape.seaRock and 'seaRock' or shape.kind
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
   if isRock[k] then if pins[k]~=nil then return pins[k],true end return nil end
   if c.cls=='PLATEAU' or c.cls=='WATER' or c.cls=='DECK' then return c.height,false end
   if c.cls=='OTHER' and c.height then return c.height,false,true end
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
    else c0.cls='FACE';c0.srcMax=c0.height;cnt.FACE=cnt.FACE+1;cnt.ROCK_FAR=cnt.ROCK_FAR+1 end
    c0.high=nil;c0.low=nil
   end
  end
  cnt.OTHER_FIX=0;cnt.POCKET_FIX=0
  local function orphan(n,nk)return n.cls=='PLATEAU' and n.floor and pins[nk]==nil and not n.step and not n.treeLoose end
  local pocketOf={}
  for y=0,l.height-1 do for x=0,l.width-1 do
   local k=x..':'..y;local c=f.cells[Levels.key(x,y)]
   local isOther=c.cls=='OTHER' and kindAt[k]=='flat'
   local isPocket=false
   if not isOther and orphan(c,k) then
    if pocketOf[k]==nil then
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
  if M.RAMP_EXT then
   local tanc=math.tan(math.rad(M.SLOPE_DEG))
   local sPx=16*tanc
   local okKind={flat=true,grass=true,flowers=true,sand=true}
   local orig={}
   local markSet={}
   for _,m in ipairs(userPins)do markSet[m[1]..':'..m[2]]=true end
   for y=0,l.height-1 do for x=0,l.width-1 do local c=f.cells[Levels.key(x,y)];orig[c]=c.height end end
   local function eligible(n,nk,hl)
    if n and n.cls=='OTHER' then return kindAt[nk]=='flat' and orig[n] and math.abs(orig[n]-hl)<.25 and not markSet[nk] end
    if not (n and n.cls=='PLATEAU' and orig[n] and math.abs(orig[n]-hl)<.25 and not markSet[nk] and not n.step and n.layer~=15) then return false end
    if M.RAMP_EXT_TREES and kindAt[nk]=='tree' then return true end
    return n.floor and not n.treeLoose and n.kind~='water' and okKind[kindAt[nk] or ''] and (l:cellAt(n.x,n.y).coll or 0)==0
   end
   local target,seeds={},{}
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
  if M.LEDGES and not M.LEDGE_SKIP[def.id] then
   local sPx=16*math.tan(math.rad(M.SLOPE_DEG))
   local okKind={flat=true,sand=true}
   local markSet={}
   for _,m in ipairs(userPins)do markSet[m[1]..':'..m[2]]=true end
   for _,c in pairs(f.cells)do c.ledge=nil;c.bareDrop=nil end
   local plainKind={flat=true,grass=true,flowers=true,sand=true,tree=true,shrub=true,rock=true,seaRock=true,sign=true,fence=true}
   local function upper(c)return c and c.height and (c.cls=='PLATEAU' or c.cls=='OTHER') and not c.step and c.layer~=15 and c.kind~='water' and not c.rampExt and plainKind[kindAt[c.x..':'..c.y] or ''] end
   local function lowerPlain(n,hu)return n and n.height and (n.cls=='PLATEAU' or n.cls=='OTHER' or (n.cls=='WATER' and hu-n.height>=32)) and not n.step and n.layer~=15 and (plainKind[kindAt[n.x..':'..n.y] or ''] or n.cls=='WATER') end
   local function eligible(n,nk)
    return n and n.cls=='PLATEAU' and n.floor and n.height and not n.step and n.layer~=15 and n.kind~='water' and not n.treeLoose
     and not n.relief and not markSet[nk] and okKind[kindAt[nk] or ''] and (l:cellAt(n.x,n.y).coll or 0)==0
   end
   local vh={}
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
        if need>M.LEDGE_MAX then tall=tall+1;u.bareDrop=true;goto nextdir end
        local s=(hu-hl)/need
        placed=placed+1
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
  if M.STAIR_PROFILE then stairProfile(true,kindAt,cnt) end
  for _,c in pairs(f.cells)do if c.cls=='PLATEAU' or c.cls=='WATER' or c.cls=='DECK' or c.cls=='OTHER' then cnt[c.cls]=cnt[c.cls]+1 end end
  f.classes=cnt;M.classes[def.id]=cnt
 end
 f.signature=signature
 cache[l]=f;return f
end
function M.cell(def,x,y)
 local f=M.field(def);return f and f.cells[Levels.key(x,y)]
end
function M.at(def,x,z)return Levels.at(M.field(def),x,z)end
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
M.STOOP=12
M.BOULDER_MAX=14
M.PROP_STEP=16
function M.bind(cells,regions)
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
        q={height=q.srcMax or q.height}
       end
      end
     end
     distance,donor=d,(q and q.height or 0)+r.floorOffset
    end
   end
   c.base=donor or 0
  end
 end
 M.supportFill(cells,regions)
 -- Iterate in map order: pairs() order varies per run (Route 110 gatehouse stood at 0 or 4).
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
    if below~=c and below.shape and below.shape.kind=='steps' and not (below.floor and below.floor.step) then
     g.groundHeight=g.groundHeight+M.STOOP end
   end
   c.base=g.groundHeight
  end
 end
 local function owner(c)return c.column and c.column.group or c.civic or c.prop end
 local grew=true
 while grew do
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
 local function tree(c)return c.shape and c.shape.kind=='tree' and not c.shape.canopy end
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
 for _,c in pairs(cells)do
  if c.shape and c.shape.crownFloor then
   local n=cells[c.cx..':'..(c.cy-1)]
   if n and (n.collision or 0)==0 and not n.boundary then c.base=n.base;c.floorHigh=nil end
  end
 end
end
function M.lift(vertices,start,height,back)
 if height==0 then return end
 for i=(start or 0)+1,#vertices do local v=vertices[i];v[2]=v[2]+height
  if v[9] and v[9]~=0 then v[9]=v[9]+height end
  if back then v[3]=v[3]+height end
 end
end
function M.invalidate()cache=setmetatable({},{__mode='k'})end
return M
