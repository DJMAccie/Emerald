-- Presentation-only floor topology. Stair runs constrain whole floor regions;
-- collision layers separate regions but are never interpreted as world pixels.
local M={}
M.LEDGE_AT_TOP=true
M.CROWN_POCKET=8 -- walk-under crown groups this small stand on the floor round their forest
M.CROWN_REACH=6
M.logPockets=false
M.POCKET=2       -- floor pockets this small take the one floor round them
M.LEDGE_RELIEF=true -- lift the floor round a ledge that does not drop (see the ledge pass)
M.RELIEF_SLOPE=3     -- most two cells side by side on one floor may differ by when the floor is lifted
M.RELIEF_MAX=48      -- most a cell is lifted
M.RELIEF_MOVES=200000
M.logRelief=false
M.CONNECTOR_KINDS={flat=true,grass=true,flowers=true,sand=true} -- a stair drawn as this ground may be a connector
M.LEDGE_DROP=8   -- how far the floor above a jump ledge stands over the floor below it (a ledge's face is about this tall)
local directions={{1,0},{-1,0},{0,1},{0,-1}}
M.directions=directions
local function key(x,y)return x..':'..y end
M.key=key
function M.build(w,h,read,compatible,rise,tick)
 local f={width=w,height=h,cells={},groups={},flights={},conflicts={}}
 local cells=f.cells
 for y=0,h-1 do for x=0,w-1 do
  local c=read(x,y);c.x,c.y=x,y;cells[key(x,y)]=c
  if tick then tick()end
 end end
 for y=0,h-1 do for x=0,w-1 do local c=cells[key(x,y)]
  if c.floor and not c.group then
   local g={cells={},edges={}};f.groups[#f.groups+1]=g
   local queue={c};c.group=g;local head=1
   while queue[head]do local a=queue[head];head=head+1;g.cells[#g.cells+1]=a
    for d,dir in ipairs(directions)do local b=cells[key(a.x+dir[1],a.y+dir[2])]
     if b and b.floor and not b.group and (not compatible or compatible(a,b,d))then b.group=g;queue[#queue+1]=b end
    end
   end
  end
 end end
 -- One flight per column; adjacent columns independently prove equal heights.
 for y=0,h-1 do for x=0,w-1 do local c=cells[key(x,y)];local north=cells[key(x,y-1)]
  if c.step and not(north and north.step)then
   local bottom=y+1
   while cells[key(x,bottom)]and cells[key(x,bottom)].step do bottom=bottom+1 end
   local south=cells[key(x,bottom)]
   local flight={x=x,top=y,bottom=bottom,high=north and north.group,low=south and south.group,rise=(bottom-y)*(rise or 6)}
   f.flights[#f.flights+1]=flight
   if flight.high and flight.low and flight.high~=flight.low then
    local high,low=flight.high,flight.low
    high.edges[#high.edges+1]={low,-flight.rise};low.edges[#low.edges+1]={high,flight.rise}
   end
  end
 end end
 -- Jump strips can join separate stair networks. They cannot override a
 -- staircase or impose contradictory levels on a loop you can walk around.
 local function network(root)
  local seen={[root]=true};local todo={root};local head=1
  while todo[head]do local g=todo[head];head=head+1
   for _,e in ipairs(g.edges)do if not seen[e[1]]then seen[e[1]]=true;todo[#todo+1]=e[1]end end
  end
  return seen
 end
 for y=0,h-1 do for x=0,w-1 do local c=cells[key(x,y)]
  if c.drop then local dx,dy=c.drop[1],c.drop[2]
   local a,b=cells[key(x-dx,y-dy)],cells[key(x+dx,y+dy)]
   local high,low=a and a.group,b and b.group
   if high and low and high~=low and #high.edges>0 and #low.edges>0 and not network(high)[low]then
    high.edges[#high.edges+1]={low,-(rise or 6)};low.edges[#low.edges+1]={high,rise or 6}
   end
  end
 end end
 for _,root in ipairs(f.groups)do if root.height==nil then
  root.height=0;local queue={root};local head=1;local minimum=0
  while queue[head]do local a=queue[head];head=head+1
   for _,edge in ipairs(a.edges)do local b,delta=edge[1],edge[2];local target=a.height+delta
    if b.height==nil then b.height=target;minimum=math.min(minimum,target);queue[#queue+1]=b
    elseif b.height~=target then f.conflicts[#f.conflicts+1]={a=a,b=b,delta=delta}end
   end
  end
  local offset=0
  for _,g in ipairs(queue)do for _,c in ipairs(g.cells)do offset=math.max(offset,(c.seed or 0)-(g.height-minimum))end end
  for _,g in ipairs(queue)do
   g.height=g.height-minimum+offset
   for _,c in ipairs(g.cells)do c.height=g.height end
  end
 end end
 -- Authored heights (cell.pin) overrule the solved network: a group takes the
 -- median pin of its cells, and on a pinned map every unpinned scrap stands
 -- down so the nearest-support pass below hands it its neighbour's level.
 local anyPin=false
 for _,g in ipairs(f.groups)do
  local pins={}
  for _,c in ipairs(g.cells)do if c.pin then pins[#pins+1]=c.pin end;if c.anchor then g.anchored=true end end
  if #pins>0 then
   table.sort(pins);g.height=pins[math.ceil(#pins/2)];g.pinned=true;anyPin=true
   for _,c in ipairs(g.cells)do c.height=g.height end
  end
 end
 if anyPin then for _,g in ipairs(f.groups)do if not g.pinned then
  local stairs=#g.edges>0
  if not stairs then for _,c in ipairs(g.cells)do c.height=nil end end
 end end end
 -- A jump ledge is a drop: the floor you jump from stands a ledge higher than the floor you land on.
 -- Where the two are separate floors (no way round on foot) and the solved heights say otherwise
 -- (level, or the upper one lower: an unpinned pocket above a pinned terrace), the upper floor and
 -- every floor joined to it by stairs is raised. Authored anchors are never moved.
 if M.LEDGE_DROP then
  for _=1,4 do
   local changed=false
   for y=0,h-1 do for x=0,w-1 do local c=cells[key(x,y)]
    if c.drop then local dx,dy=c.drop[1],c.drop[2]
     local a,b=cells[key(x-dx,y-dy)],cells[key(x+dx,y+dy)]
     local high,low=a and a.group,b and b.group
     if M.log then print('[EM ledge]',x,y,'high',high and tostring(high.height),high and high.pinned,'low',low and tostring(low.height),low and low.pinned,high==low,high and low and network(high)[low]) end
     if high and low and high~=low and not network(high)[low] then
      if high.height==nil and low.height~=nil then
       high.height=low.height+M.LEDGE_DROP;changed=true
       for _,q in ipairs(high.cells)do q.height=high.height end
      elseif high.height~=nil and low.height~=nil and high.height<low.height+M.LEDGE_DROP then
       local net,fixed=network(high),false
       -- (a floor pinned by the cartridge's own level nibble may rise; an authored anchor may not)
       for g in pairs(net)do if g.anchored then fixed=true end end
       if not fixed then
        local delta=low.height+M.LEDGE_DROP-high.height
        for g in pairs(net)do if g.height~=nil then
         g.height=g.height+delta
         for _,q in ipairs(g.cells)do q.height=g.height end
        end end
        changed=true
       end
      end
     end
    end
   end end
   if not changed then break end
  end
  -- A ledge the pass above leaves level or upside down. A flat ledge has one floor either side of it,
  -- joined round its ends (Route 111's lips in the meadow, Route 113's ash field): the pass cannot part
  -- a floor from itself. Or the floors are tied by stairs or anchors, or the ledges make a loop (Petalburg
  -- Woods: the north path jumps down into the dell, the dell jumps down onto the south path, and both
  -- paths are one floor). The floor round such a ledge is lifted instead, cell by cell, as little as it
  -- can be while
  --  * the cell a jump starts from stands LEDGE_DROP over the cell it lands on (every ledge between two
  --    floors, not only the failing ones: Route 115's row-70 meadow rose for the row-72 ledge, and the
  --    row-69 ledge above it went level), and
  --  * two cells side by side on one floor differ by RELIEF_SLOPE at most, so a lift runs out round the
  --    ledge's ends as an even slope and dies away by itself.
  -- Cells beside a stair flight or on the map's edge are never lifted (stairs and seams stay put). The
  -- least lift is found by raising cells from a worklist until nothing moves (it only ever raises, so it
  -- ends; RELIEF_MAX caps a contradiction). Emerald's maps only: FireRed's are not surveyed for it.
  if M.LEDGE_RELIEF and tostring(M.mapId):match('^EM_') then
   local ledges,bad={},0
   for y=0,h-1 do for x=0,w-1 do local c=cells[key(x,y)]
    if c.drop then
     local a,b=cells[key(x-c.drop[1],y-c.drop[2])],cells[key(x+c.drop[1],y+c.drop[2])]
     if a and b and a.floor and b.floor and a.group and b.group and a.height~=nil and b.height~=nil
      and a.kind~='water' and b.kind~='water' then
      ledges[#ledges+1]={a,b}
      if a.height-b.height<M.LEDGE_DROP then bad=bad+1 end
     end
    end
   end end
   if bad>0 then local t0=os.clock()
    local above={}   -- cell landed on -> the cells jumped from
    for _,p in ipairs(ledges)do local l=above[p[2]] or {};l[#l+1]=p[1];above[p[2]]=l end
    local base,queue,head,moves={}, {},1,0
    -- A connector: a "stair" the cartridge rates between two layers (a walkable layer-0 cell) but draws
    -- as plain ground, with its floors standing level - Route 115's grass gap at 21,70 / 20,71 between
    -- its ledge rows. It is floor to the relief (lifted with the meadow, the cells beside it too), and the
    -- flight pass below leaves it: kept as a stair, the meadow beside it stayed down, 7-10 px under its
    -- lifted neighbours.
    local conn={}
    for y=0,h-1 do for x=0,w-1 do local c=cells[key(x,y)]
     if c.step and M.CONNECTOR_KINDS[c.kind or ''] then
      local level,n,same=nil,0,true
      for _,dir in ipairs(directions)do local b=cells[key(x+dir[1],y+dir[2])]
       if b and b.floor and b.group and b.height~=nil and b.kind~='water' then
        n=n+1;if level==nil then level=b.height elseif math.abs(b.height-level)>.001 then same=false end
       end
      end
      if n>=2 and same then conn[c]=true;c.height=level end
     end
    end end
    local function fixed(c)
     if c.x==0 or c.y==0 or c.x==w-1 or c.y==h-1 or c.kind=='water' then return true end
     for _,dir in ipairs(directions)do local b=cells[key(c.x+dir[1],c.y+dir[2])];if b and b.step and not conn[b] then return true end end
     return false
    end
    local function raise(c,v)
     if v>c.height+.001 and not fixed(c) then
      base[c]=base[c] or c.height;c.relief=true
      if v>base[c]+M.RELIEF_MAX then v=base[c]+M.RELIEF_MAX end
      if v>c.height+.001 then c.height=v;queue[#queue+1]=c;moves=moves+1 end
     end
    end
    for _,p in ipairs(ledges)do raise(p[1],p[2].height+M.LEDGE_DROP) end
    while queue[head] and moves<M.RELIEF_MOVES do local a=queue[head];head=head+1
     for _,dir in ipairs(directions)do local b=cells[key(a.x+dir[1],a.y+dir[2])]
      if b and b.height~=nil and ((b.floor and b.group==a.group) or (conn[b] and a.floor) or (conn[a] and (b.floor or conn[b]))) then
       raise(b,a.height-M.RELIEF_SLOPE)
      end
     end
     for _,hi in ipairs(above[a] or {})do raise(hi,a.height+M.LEDGE_DROP) end
    end
    -- a connector the meadow carried is floor from here on (Gen3Scene slopes it with the cells round it)
    for c in pairs(conn)do if c.relief then c.connector=true;c.step=false;c.floor=true end end
    if M.logRelief then local top,n=0,0;for c,b0 in pairs(base)do n=n+1;if c.height-b0>top then top=c.height-b0 end end
     bad=0;for _,p in ipairs(ledges)do if p[1].height-p[2].height<4 then bad=bad+1 end end
     print('[EM relief]',M.mapId,#ledges,n,top,moves,bad,os.clock()-t0) end
   end
  end
  -- the ledge cell itself is the foot of the drop: its face stands on the lower floor
  -- (the heights either side are its cells' own: a flat ledge's floor is bent round it, above)
  for y=0,h-1 do for x=0,w-1 do local c=cells[key(x,y)]
   if c.drop then
    local a,b=cells[key(x-c.drop[1],y-c.drop[2])],cells[key(x+c.drop[1],y+c.drop[2])]
    local high,low=a and a.group,b and b.group
    -- (the ledge stands at the top of its drop, its face running down to the floor below: at the foot,
    -- the plateau's step wall stood behind a low lip as a grass trench)
    if high and low and a.height~=nil and b.height~=nil and a.height>b.height then
     if M.LEDGE_AT_TOP then c.height=a.height;c.ledgeLow=b.height else c.height=b.height end
    end
   end
  end end
 end
 -- A walk-under tree crown in a forest (walkable, but no one reaches it: Route 113's ash forest) is no
 -- floor of its own: it stands on the floor round the forest. As its own little group it kept its rated
 -- height while the ledges lifted the floor beside the forest, and the trees round it (which take the
 -- nearest floor's height) sank 56 px into a pit walled with tree art.
 do
  local pocket={}
  for _,g in ipairs(f.groups)do
   if #g.cells<=M.CROWN_POCKET and #g.edges==0 and not g.anchored then
    local crown=true
    for _,c in ipairs(g.cells)do if c.kind~='tree' then crown=false;break end end
    if crown then pocket[g]=true end
   end
  end
  for g in pairs(pocket)do
   local seen,queue,head,found={}, {},1,nil
   for _,c in ipairs(g.cells)do seen[c]=0;queue[#queue+1]=c end
   while queue[head] and not found do local a=queue[head];head=head+1
    if seen[a]<M.CROWN_REACH then
     for _,dir in ipairs(directions)do local b=cells[key(a.x+dir[1],a.y+dir[2])]
      if b and seen[b]==nil then
       seen[b]=seen[a]+1
       if b.floor and b.group and not pocket[b.group] and b.group.height~=nil then found=b.group;break end
       if not b.floor or b.group==g then queue[#queue+1]=b end
      end
     end
    end
   end
   if found then g.height=found.height;for _,c in ipairs(g.cells)do c.height=g.height end end
  end
 end
 -- A floor pocket of one or two cells rated at another height than the one floor all round it -- a pit or
 -- a bump in it -- is that floor: a door's mat rated 3 in a yard the stairs lift to 48 (Route 119's
 -- Weather Institute stood on its mat, a one-cell pit, and sank 48 px into its yard). One that its own
 -- stairs place within a course of that floor (the institute's doorstep, 6 px up) stands where they put it.
 for _,g in ipairs(f.groups)do
  if #g.cells<=M.POCKET and not g.anchored and g.height~=nil and g.cells[1].kind~='water' then
   local inG={};for _,c in ipairs(g.cells)do inG[c]=true end
   local hh,n,one=nil,0,true
   -- (looking through unrated floor -- elevation 0, "any level", the cells beside a door's mat -- to the
   -- rated floor beyond, at most 3 steps; a pocket on the map's edge meets the next map: left alone)
   local edge=false
   local seen,queue,head={}, {},1
   for _,c in ipairs(g.cells)do seen[c]=0;queue[#queue+1]=c
    if c.x==0 or c.y==0 or c.x==w-1 or c.y==h-1 then edge=true end end
   while queue[head]do local a=queue[head];head=head+1
    for _,dir in ipairs(directions)do
     local b=cells[key(a.x+dir[1],a.y+dir[2])]
     if b and seen[b]==nil and not inG[b] and b.floor and b.kind~='water' and not b.step then
      seen[b]=seen[a]+1
      if b.group and b.group.height~=nil then
       n=n+1
       if hh==nil then hh=b.group.height elseif hh~=b.group.height then one=false end
      elseif seen[b]<3 then queue[#queue+1]=b end
     end
    end
   end
   local st,agree=nil,#g.edges>0
   for _,e in ipairs(g.edges)do
    local o=e[1].height;local v=o and o-e[2]
    if v==nil then agree=false elseif st==nil then st=v elseif st~=v then agree=false end
   end
   local t
   if not edge and one and hh and n>=2 and math.abs(hh-g.height)>=8 then
    t=hh
    if agree and st and math.abs(st-hh)<=16 then t=st end
   -- (walled in -- the mat between the institute's front pillars sees only its door -- but its stairs
   -- place it a storey or more from its rating: where the stairs put it)
   elseif not edge and agree and st and math.abs(st-g.height)>=32 then t=st end
   if t then
    if M.logPockets then print('[EM pocket]',M.mapId,g.cells[1].x,g.cells[1].y,#g.cells,g.height,'->',t) end
    g.height=t;for _,c in ipairs(g.cells)do c.height=t end
   end
  end
 end
 for _,s in ipairs(f.flights)do
  local low=s.low and s.low.height or 0
  local high=s.high and s.high.height or low+s.rise
  if not s.low then low=math.max(0,high-s.rise)end
  if high<low then high=low end
  -- A flight rising a full level over two rows would climb at 45 degrees (Lilycove's stairs). Past M.STEEP the
  -- ramp runs on into the walkable floor at its foot until it reaches M.GENTLE.
  local bottom=s.bottom
  if s.low and (high-low)/((bottom-s.top)*16)>M.STEEP then
   local want=math.ceil((high-low)/(16*M.GENTLE)-1e-6)
   while bottom-s.top<want do
    local c=cells[key(s.x,bottom)]
    if c and c.group==s.low and not c.step and c.kind~='water' then bottom=bottom+1 else break end
   end
  end
  for y=s.top,bottom-1 do local c=cells[key(s.x,y)]
   if c.connector then goto connector end   -- (lifted with the meadow round it by the ledge relief)
   do
   local fraction=(y-s.top)/(bottom-s.top)
   c.high=high-(high-low)*fraction;c.low=high-(high-low)*(fraction+1/(bottom-s.top));c.height=c.low
   -- (no floor north of it: a flight that climbs east-west, between the floors either side of it - Route
   -- 120's 21,67 joins the plateau to the bridge's approach a level below, and stood 6 px over the plateau)
   if not s.high then
    local wc,ec=cells[key(s.x-1,y)],cells[key(s.x+1,y)]
    local wh=wc and wc.floor and not wc.step and wc.group and wc.group.height
    local eh=ec and ec.floor and not ec.step and ec.group and ec.group.height
    if wh and eh and wh~=eh then c.high=math.max(wh,eh);c.low=math.min(wh,eh);c.height=(wh+eh)/2 end
   end
   end
   ::connector::
  end
 end
 -- Stable, full-map nearest support under props. It cannot change when a
 -- render window moves. Equal-distance ties follow source row order.
 -- (a blocked cell with an authored pin - rock framing a raised or sunk floor, Gen3StairTerraces
 -- `cells` - stands at its pin and supports what is beside it, instead of taking its nearest floor, and a
 -- pinned ledge stands at its pin whatever the ledge pass gave it: Frontier West's garden walls stay at the
 -- plaza's level round the sunk garden; Jagged Pass's row-14 ledge is the 13,13 stair's landing)
 local queue={};for y=0,h-1 do for x=0,w-1 do local c=cells[key(x,y)]
  if not c.floor and c.pin then c.height=c.pin end
  if c.height~=nil then c.distance=0;c.support=c;queue[#queue+1]=c end
 end end
 local head=1
 while queue[head]do local a=queue[head];head=head+1
  for _,dir in ipairs(directions)do local b=cells[key(a.x+dir[1],a.y+dir[2])]
   if b and b.distance==nil then b.height=a.height;b.distance=a.distance+1;b.support=a.support;queue[#queue+1]=b end
  end
 end
 -- A stretched ramp in a corridor of floor a few cells wide carries the corridor's whole row: Safari
 -- Zone SW's stair foot runs down between trees with one floor column beside it, which stood at the
 -- foot while the ramp beside it was still more than a level up (a walkable 19 px jump). (After
 -- the props' support: the trees beside the corridor keep standing on their own floor.)
 for y=0,h-1 do
  local x=0
  while x<w do
   local c=cells[key(x,y)]
   -- (a flight's own cells are part of the row: Route 120's stair foot at 22,77 broke the row there, and
   -- the floor beside it stayed at the bottom with the ramp 21 px up)
   if c and (c.floor or c.high~=nil) and c.kind~='water' and (not c.step or c.high~=nil) then
    local a,ramp=x,nil
    while x<w do
     local d=cells[key(x,y)]
     if not (d and (d.floor or d.high~=nil) and d.kind~='water' and (not d.step or d.high~=nil)) then break end
     if d.high~=nil and d.height and (not ramp or d.height>ramp) then ramp=d.height end
     x=x+1
    end
    if ramp and x-a<=M.CORRIDOR then
     for xx=a,x-1 do local d=cells[key(xx,y)]
      if d.high==nil and d.height~=nil and ramp-d.height>8 then d.height=ramp end
     end
    end
   else x=x+1 end
  end
 end
 -- A ledge's corner and end tiles (0x08D, 0x0D6, 0x06E/0x06F: no jump of their own, or a jump with no
 -- floor beyond it) take the drop of a ledge cell of the same floor beside them, so they lie flush with
 -- the run's lip instead of standing as a block on the plateau. Over the whole map in row order: done
 -- per build in Gen3Scene it hung on which neighbours the build window held (and on pairs() order),
 -- and Route 104's corners at 28,55 / 30,57 stood raised with sky showing through a hole under their
 -- face in one build, flush in the next.
 for _=1,4 do
  local changed=false
  for y=0,h-1 do for x=0,w-1 do local c=cells[key(x,y)]
   if c.kind=='ledge' and not c.ledgeLow and not c.pin and c.height~=nil then
    for _,dir in ipairs(directions)do local n=cells[key(x+dir[1],y+dir[2])]
     if n and n.kind=='ledge' and n.ledgeLow and n.height~=nil and math.abs(n.height-c.height)<=8 then
      c.height=n.height;c.ledgeLow=n.ledgeLow;changed=true;break
     end
    end
   end
  end end
  if not changed then break end
 end
 -- A body of water is one flat surface. Its cells take their height from
 -- the nearest bank, which stair-steps a river between banks of different
 -- levels (Route 119): settle each connected water group at its lowest
 -- cell, the foot of its banks. Waterfalls keep separate groups, so real
 -- drops between bodies stay.
 -- Waterfall cells (c.waterfall) are the drops: they split a river into
 -- bodies and keep their own height.
 local seen={}
 for _,g in ipairs(f.groups)do
  if g.cells[1] and g.cells[1].kind=='water' then
   for _,start in ipairs(g.cells)do
    if not seen[start] and not start.waterfall then
     local body,low,queue,head={}, nil,{start},1;seen[start]=true
     while queue[head]do local a=queue[head];head=head+1;body[#body+1]=a
      if a.height and (not low or a.height<low)then low=a.height end
      for _,dir in ipairs(directions)do local b=cells[key(a.x+dir[1],a.y+dir[2])]
       if b and b.group==g and not seen[b] and not b.waterfall then seen[b]=true;queue[#queue+1]=b end
      end
     end
     if low then for _,c in ipairs(body)do c.height=low end end
    end
   end
  end
 end
 return f
end
-- Match the actual walkable seam of connected maps. Each map keeps its
-- local terrain data; only its placement datum changes with the world origin.
M.STEEP=.9   -- rise over run above which a stair flight is stretched
M.GENTLE=.7  -- the slope it is stretched to
M.CORRIDOR=4 -- a row of floor this narrow round a stretched ramp rides the ramp
function M.align(regions)
 for _,r in ipairs(regions)do r.floorOffset=nil end
 if regions[1]then regions[1].floorOffset=0 end
 local function difference(a,b)
  local counts={}
  local function sample(ax,ay,bx,by)
   local u=a.floorField and a.floorField.cells[key(ax,ay)]
   local v=b.floorField and b.floorField.cells[key(bx,by)]
   if u and v and u.floor and v.floor and (u.kind=='water')==(v.kind=='water')then
    local d=(u.height or 0)-(v.height or 0);counts[d]=(counts[d]or 0)+1
   end
  end
  if a.x+a.w==b.x or b.x+b.w==a.x then
   for y=math.max(a.y,b.y),math.min(a.y+a.h,b.y+b.h)-1 do
    sample(a.x<b.x and a.w-1 or 0,y-a.y,a.x<b.x and 0 or b.w-1,y-b.y)
   end
  elseif a.y+a.h==b.y or b.y+b.h==a.y then
   for x=math.max(a.x,b.x),math.min(a.x+a.w,b.x+b.w)-1 do
    sample(x-a.x,a.y<b.y and a.h-1 or 0,x-b.x,a.y<b.y and 0 or b.h-1)
   end
  end
  local best,count
  -- (ties between +d and -d go to the lower: pairs() order made a map's seam offset differ by visit)
  for d,n in pairs(counts)do if not count or n>count or n==count and (math.abs(d)<math.abs(best) or math.abs(d)==math.abs(best) and d<best)then best,count=d,n end end
  return best
 end
 for _=1,#regions do
  local changed=false
  for _,a in ipairs(regions)do if a.floorOffset~=nil then for _,b in ipairs(regions)do if b.floorOffset==nil then
   local d=difference(a,b)
   if d then b.floorOffset=a.floorOffset+d;changed=true end
  end end end end
  if not changed then break end
 end
 for _,r in ipairs(regions)do r.floorOffset=r.floorOffset or 0 end
end
function M.at(f,x,z)
 local c=f and f.cells[key(math.floor(x/16),math.floor(z/16))]
 if not c then return 0 end
 -- a stair flight's own cell stands on the tread under the point: N treads (Gen3Elevation) rising evenly
 -- from its base c.low to c.high, depth counted from the lower edge as Gen3Scene's flightTreads draws them
 if c.step and c.high then
  local N=c.treads or 4
  local k=math.min(N-1,math.floor((16-z%16)*N/16))
  return c.low+(c.high-c.low)*(k+1)/N
 end
 if c.high then return c.high-(c.high-c.low)*math.min(3,math.max(0,math.floor(z%16/4)))/4 end
 -- a floor the ledge relief bends (Gen3Scene sets slope={nw,ne,se,sw}, offsets from c.height at the
 -- cell's corners): stand on its sloped top, not on the block it was
 local sl=c.slope
 if sl and c.height then
  local u,w=(x%16)/16,(z%16)/16
  return c.height+(sl[1]*(1-u)+sl[2]*u)*(1-w)+(sl[4]*(1-u)+sl[3]*u)*w
 end
 return c.height or 0
end
return M
