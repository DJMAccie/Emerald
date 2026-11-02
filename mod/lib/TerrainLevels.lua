-- Presentation-only floor topology
local M={}
M.LEDGE_AT_TOP=true
M.CROWN_POCKET=8
M.CROWN_REACH=6
M.logPockets=false
M.POCKET=2
M.LEDGE_RELIEF=true
M.RELIEF_SLOPE=3
M.RELIEF_MAX=48 -- most a cell is lifted
M.RELIEF_MOVES=200000
M.logRelief=false
M.CONNECTOR_KINDS={flat=true,grass=true,flowers=true,sand=true} -- a stair drawn as this ground may be a connector
M.LEDGE_DROP=8
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
    local above={} -- cell landed on -> the cells jumped from
    for _,p in ipairs(ledges)do local l=above[p[2]] or {};l[#l+1]=p[1];above[p[2]]=l end
    local base,queue,head,moves={}, {},1,0
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
     if c.x==0 or c.y==0 or c.x==w-1 or c.y==h-1 or c.kind=='water' or c.anchor then return true end
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
    for c in pairs(conn)do if c.relief then c.connector=true;c.step=false;c.floor=true end end
    if M.logRelief then local top,n=0,0;for c,b0 in pairs(base)do n=n+1;if c.height-b0>top then top=c.height-b0 end end
     bad=0;for _,p in ipairs(ledges)do if p[1].height-p[2].height<4 then bad=bad+1 end end
     print('[EM relief]',M.mapId,#ledges,n,top,moves,bad,os.clock()-t0) end
   end
  end
  for y=0,h-1 do for x=0,w-1 do local c=cells[key(x,y)]
   if c.drop then
    local a,b=cells[key(x-c.drop[1],y-c.drop[2])],cells[key(x+c.drop[1],y+c.drop[2])]
    local high,low=a and a.group,b and b.group
    if high and low and a.height~=nil and b.height~=nil and a.height>b.height then
     if M.LEDGE_AT_TOP then c.height=a.height;c.ledgeLow=b.height else c.height=b.height end
    end
   end
  end end
 end
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
 for _,g in ipairs(f.groups)do
  if #g.cells<=M.POCKET and not g.anchored and g.height~=nil and g.cells[1].kind~='water' then
   local inG={};for _,c in ipairs(g.cells)do inG[c]=true end
   local hh,n,one=nil,0,true
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
  local bottom=s.bottom
  if s.low and M.stretch~=false and (high-low)/((bottom-s.top)*16)>M.STEEP then
   local want=math.ceil((high-low)/(16*M.GENTLE)-1e-6)
   while bottom-s.top<want do
    local c=cells[key(s.x,bottom)]
    if c and c.group==s.low and not c.step and c.kind~='water' then bottom=bottom+1 else break end
   end
  end
  for y=s.top,bottom-1 do local c=cells[key(s.x,y)]
   if c.connector then goto connector end
   do
   local fraction=(y-s.top)/(bottom-s.top)
   c.high=high-(high-low)*fraction;c.low=high-(high-low)*(fraction+1/(bottom-s.top));c.height=c.low
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
 for y=0,h-1 do
  local x=0
  while x<w do
   local c=cells[key(x,y)]
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
M.STEEP=.9
M.GENTLE=.7 -- the slope it is stretched to
M.CORRIDOR=4
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
  -- Ties go to the lower: pairs() order made seams differ per visit.
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
 if c.step and c.high then
  local N=c.treads or 4
  local u=c.stairUp
  local t=16-z%16
  if u then if u[2]>0 then t=z%16 elseif u[1]>0 then t=x%16 elseif u[1]<0 then t=16-x%16 end end
  local k=math.min(N-1,math.floor(t*N/16))
  return c.low+(c.high-c.low)*(k+1)/N
 end
 if c.high then return c.high-(c.high-c.low)*math.min(3,math.max(0,math.floor(z%16/4)))/4 end
 local sl=c.slope
 if sl and c.height then
  local u,w=(x%16)/16,(z%16)/16
  return c.height+(sl[1]*(1-u)+sl[2]*u)*(1-w)+(sl[4]*(1-u)+sl[3]*u)*w
 end
 return c.height or 0
end
return M
