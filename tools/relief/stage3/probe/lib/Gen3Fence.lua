-- Little white fences drawn on the ground stand up as fences (Opus; user:
-- "the little white fences haven't been built").
--
-- The cartridge draws a fence running east-west as seen from the front: posts
-- with their caps and two rails over a shadow line, in rows top..foot of the
-- cell. Each of those pixels becomes a voxel standing at the fence's line, at
-- the height that puts it where it is drawn at the player camera (screen row
-- = depth - height): height = foot - row. Posts (columns drawn in every fence
-- row) are POST deep, the rails RAIL deep. A fence running north-south is
-- drawn from above as a line of posts: it stands as a rail as tall as the
-- east-west fence's rails along the drawn line, with a post wherever a cap is
-- drawn. The cell keeps its ground tile under it; the drawn fence and its
-- shadow no longer lie on the ground.
local V=...
local M={}
M.SPECS={
 -- Mt. Chimney's cable car station, Route 112 (general__lavaridge)
 general__lavaridge={ground=0x271,foot=12,shadow={0x296,0,13},
  across={[0x296]=true,[0x293]=true,[0x287]=true,[0x285]=true,[0x294]=true,[0x28E]=true},
  along={[0x28F]=true},cap={0x296,4,3}},
 -- the Battle Frontier's grey stake fence along the west cliff top
 general__battle_frontier_outside_west={ground=0x001,foot=12,shadow={0x149,0,13},
  across={[0x149]=true,[0x148]=true,[0x13A]=true},along={[0x142]=true,[0x140]=true}},
 -- the grey stake fences round Route 117's fields (same art)
 general__mauville={ground=0x001,foot=12,shadow={0x149,0,13},
  across={[0x149]=true,[0x148]=true,[0x13A]=true,[0x138]=true,[0x14A]=true},along={[0x142]=true,[0x140]=true,[0x139]=true}},
 -- Slateport's grey stake fences (the same drawing as Route 117's): stood up as
 -- a picture (extrude) the north-south runs came out as tall splayed planks
 general__slateport={ground=0x001,foot=12,shadow={0x149,0,13},
  across={[0x149]=true,[0x148]=true,[0x13A]=true,[0x14A]=true,[0x133]=true},along={[0x142]=true,[0x141]=true}},
 -- the island harbours' white balustrades (Birth Island, Navel Rock): the
 -- rail and its kerb, 16 rows, drawn from the front over the quay or the sea
 general__island_harbor={foot=15,grounds={0x3A1,0x3A0,0x170,0x189,0x181,0x180,0x19A,0x198},
  across={[0x21F]=true,[0x3C1]=true,[0x3C5]=true,[0x22A]=true,[0x22B]=true,[0x22E]=true,[0x3C2]=true,[0x3C3]=true},along={},
  deep={[0x3C1]={2,7},[0x22A]={2,7},[0x3C5]={8,13},[0x22E]={8,13}}},
 -- Rustboro's navy iron railings round the lawns (looped rail east-west, a plain line north-south)
 general__rustboro={foot=12,grounds={0x2BB,0x001,0x2EA,0x2E1},ink=.5,
  across={[0x2FC]=true,[0x2A7]=true,[0x2BE]=true,[0x2BF]=true,[0x2B7]=true,[0x2D5]=true,[0x33F]=true,[0x2D7]=true,
   [0x2E9]=true,[0x2E7]=true,[0x2E6]=true,[0x2CD]=true,[0x352]=true,[0x337]=true,[0x33E]=true},
  along={[0x2DE]=true,[0x2DF]=true,[0x2EC]=true,[0x318]=true,[0x319]=true,[0x32C]=true,[0x2DC]=true,
   [0x31A]=true,[0x315]=true,[0x320]=true,[0x31D]=true,[0x2C6]=true,[0x2C7]=true,[0x321]=true,[0x31B]=true,[0x32D]=true},
  -- (the looped pieces on the south lawn edge: their rings stood as a lattice of pixel tops and sides
  -- at close range; drawn as one panel, each rail pixel a front and back face only)
  flat={[0x2B7]=true,[0x2E7]=true,[0x2E6]=true,[0x337]=true,[0x33E]=true},
  -- the north-south runs are the same looped rail turned side-on (this tile's drawing), as tall as the
  -- east-west runs: as two thin bars 7 px up they met the 13 px rails at every corner as a broken gate
  -- (user: "lets do the rustboro railings")
  alongPanel=0x2FC},
 -- Lilycove's blue iron fences in front of the houses and the Center
 general__lilycove={ground=0x001,foot=12,shadow={0x251,1,14},
  across={[0x250]=true,[0x251]=true,[0x252]=true},along={}},
}
-- low concrete curbs drawn obliquely (Route 110's channels): per tile, the
-- top band (rows t0..t1 east-west, or columns t0..t1 north-south) lies flat
-- at height h, the face rows f0..f1 below it stand at the curb's front
M.CURB={
 general__mauville={
  [0x04E]={dir='ew',t0=8,t1=12,f0=13,f1=15,h=3},[0x04D]={dir='ew',t0=8,t1=12,f0=13,f1=15,h=3},
  [0x03E]={dir='ew',t0=0,t1=4,f0=5,f1=7,h=3},
  [0x045]={dir='ns',t0=0,t1=7,h=3},[0x047]={dir='ns',t0=0,t1=7,h=3}},
}
M.STAKES={ground=0x001,foot=12,shadow={0x149,0,13},
 across={[0x149]=true,[0x148]=true,[0x13A]=true,[0x138]=true,[0x14A]=true},along={[0x142]=true,[0x140]=true,[0x139]=true}}
M.POST=3
M.RAIL=1.2
M.RAIL_H=7

-- A fence of logs driven into the ground (the Day Care's on Route 117): each log is drawn from above
-- as a pale cut end over its bark. Every cut end found in the tile is one post: a square log as wide
-- as its end, POST_H tall, the end on top (1:1, its first and last rows carried to the edges), the
-- bark rows under the end round its sides. Returns the number of posts.
M.POST_H=11
local postCache=setmetatable({},{__mode='k'})
local function postEnds(ts,mid)
 local cache=postCache[ts];if not cache then cache={};postCache[ts]=cache end
 if cache[mid]~=nil then return cache[mid] end
 local slot=ts.midToSlot[mid]
 if not slot or not ts.imageData then cache[mid]=false;return false end
 local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
 -- (under and over-player layers together: the logs you walk behind are drawn in the upper one)
 local function px(x,y)
  local r,g,b=ts.imageData:getPixel(ox+x,oy+y)
  if ts.overImageData then local rr,gg,bb,aa=ts.overImageData:getPixel(ox+x,oy+y);if aa>.5 then return rr,gg,bb end end
  return r,g,b
 end
 local pale={}
 for y=0,15 do for x=0,15 do local r,g,b=px(x,y);pale[y*16+x]=r>.8 and g>.5 and g<.9 and b>.3 and b<.7 and r>g and g>b end end
 local function bark(x,y)local r,g,b=px(x,y);return r>g*1.15 and r>b*1.1 and r<.78 end
 local seen,ends={},{}
 for y=0,15 do for x=0,15 do
  local i=y*16+x
  if pale[i] and not seen[i] then
   local stack,x0,y0,x1,y1,n={i},x,y,x,y,0;seen[i]=true
   while #stack>0 do
    local q=table.remove(stack);n=n+1
    local qx,qy=q%16,math.floor(q/16)
    x0,y0,x1,y1=math.min(x0,qx),math.min(y0,qy),math.max(x1,qx),math.max(y1,qy)
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local nx,ny=qx+d[1],qy+d[2];local j=ny*16+nx
     if nx>=0 and ny>=0 and nx<16 and ny<16 and pale[j] and not seen[j] then seen[j]=true;stack[#stack+1]=j end
    end
   end
   if n>=6 then
    -- bark rows under the end, at its middle column
    local cx=math.floor((x0+x1)/2);local rows=0
    -- (rows whose whole width is bark: lower down the grass round the foot is drawn over its edges)
    while y1+1+rows<16 and rows<M.POST_H and bark(cx,y1+1+rows) and bark(x0+1,y1+1+rows) and bark(x1-1,y1+1+rows) do rows=rows+1 end
    ends[#ends+1]={x0,y0,x1+1,y1+1,rows}
   end
  end
 end end
 -- a tile whose ends have no bark under them (cut by the tile's edge) borrows the longest bark found
 local best
 for _,e in ipairs(ends)do if not best or e[5]>best[5] then best=e end end
 for _,e in ipairs(ends)do e[6]=(e[5]>=2 and e or best) end
 cache[mid]=#ends>0 and ends or false
 return cache[mid]
end
function M.posts(c,quad,uvFor)
 local ends=postEnds(c.ts,c.mid);local uv=uvFor(c.ts,c.mid)
 if not ends or not uv then return 0 end
 local L,T,R,B=uv[1][1],uv[1][2],uv[3][1],uv[3][2]
 local function rect(x0,y0,x1,y1)local a,b,cc,d=L+(R-L)*x0/16,T+(B-T)*y0/16,L+(R-L)*x1/16,T+(B-T)*y1/16;return {{a,b},{cc,b},{cc,d},{a,d}} end
 local X,Z=c.cx*16,c.cy*16
 local H=M.POST_H
 for _,e in ipairs(ends)do
  local w,d=e[3]-e[1],e[4]-e[2]
  local x0,x1=X+e[1],X+e[3]
  local zc=Z+(e[2]+e[4])/2
  local z0,z1=zc-w/2,zc+w/2                -- as deep as it is wide
  local zt0,zt1=zc-d/2,zc+d/2
  -- the cut end, 1:1, and its edge rows out to the log's rim
  quad({{x0,H,zt0},{x1,H,zt0},{x1,H,zt1},{x0,H,zt1}},rect(e[1],e[2],e[3],e[4]),1)
  if zt0>z0+.01 then quad({{x0,H,z0},{x1,H,z0},{x1,H,zt0},{x0,H,zt0}},rect(e[1],e[2]+.1,e[3],e[2]+.9),1) end
  if z1>zt1+.01 then quad({{x0,H,zt1},{x1,H,zt1},{x1,H,z1},{x0,H,z1}},rect(e[1],e[4]-.9,e[3],e[4]-.1),1) end
  -- the bark: its drawn rows under the end, the last one carried down to the ground
  local s=e[6];local rows=math.max(1,math.min(s[5],H))
  local by=s[4]
  local function side(a,b,shade,u0,u1)
   local yb=H-rows
   quad({{a[1],H,a[2]},{b[1],H,b[2]},{b[1],yb,b[2]},{a[1],yb,a[2]}},rect(u0,by,u1,by+rows),shade)
   if yb>0 then quad({{a[1],yb,a[2]},{b[1],yb,b[2]},{b[1],0,b[2]},{a[1],0,a[2]}},rect(u0,by+rows-.9,u1,by+rows-.1),shade*.92) end
  end
  side({x0,z1},{x1,z1},.92,s[1],s[3])
  side({x1,z0},{x0,z0},.62,s[1],s[3])
  side({x0,z0},{x0,z1},.72,s[1],s[3])
  side({x1,z1},{x1,z0},.8,s[1],s[3])
 end
 return #ends
end
function M.kind(c)
 local cb=c and M.CURB[c.pair or ''];if cb and cb[c.mid] then return 'curb',cb[c.mid] end
 local s=c and M.SPECS[c.pair or '']
 -- (the grey stake fence of the shared tiles, on a map whose tileset has no entry of its own)
 if c and not (s and (s.across[c.mid] or s.along[c.mid])) and (M.STAKES.across[c.mid] or M.STAKES.along[c.mid]) then s=M.STAKES end
 if not s then return end
 if s.across[c.mid] then return 'across',s end
 if s.along[c.mid] then return 'along',s end
end

local function key(r,g,b)return math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)end
-- per tileset: colours that are not fence (the ground and the drawn shadow)
local function notFence(ts,s)
 ts.fenceNot=ts.fenceNot or {}
 local t=ts.fenceNot[s]
 if t then return t end
 t={}
 -- (ink: the fence is every pixel darker than this, whatever the ground; an iron railing's lighter
 -- navy is also a speck colour of the paving it stands on, which cut its loops to pieces)
 if s.ink then
  setmetatable(t,{__index=function(tt,k)
   local v=(.299*math.floor(k/65536)+.587*(math.floor(k/256)%256)+.114*(k%256))/255>=s.ink
   rawset(tt,k,v);return v
  end})
 end
 local function px(mid,x,y)
  local slot=ts.midToSlot[mid];if not slot then return end
  return ts.imageData:getPixel(slot%ts.cols*16+x,math.floor(slot/ts.cols)*16+y)
 end
 -- (grounds: several tiles whose colours are not fence -- quay, sea, shore)
 for _,gm in ipairs(s.ink and {} or s.grounds or {s.ground})do
  for y=0,15 do for x=0,15 do local r,g,b=px(gm,x,y);if r then t[key(r,g,b)]=true end end end
 end
 if s.shadow then local r,g,b=px(s.shadow[1],s.shadow[2],s.shadow[3]);if r then t[key(r,g,b)]=true end end
 ts.fenceNot[s]=t
 return t
end

-- Extrude: a low structure drawn from above (white curbs along the Battle
-- Frontier's cliff tops, its flower planters): every pixel of the drawing
-- that belongs to it (light pixels, or pixels not in the ground colours of
-- the walkable cells round it) stands h px up, its top the pixel, its sides
-- the run's end pixels.
local function lumOf(r,g,b)return .299*r+.587*g+.114*b end
function M.extrude(c,cells,quad,uvFor,h,light,cool)
 local ts=c.ts;local slot=ts.midToSlot[c.mid];local uv=uvFor(ts,c.mid)
 if not slot or not uv or not ts.imageData then return end
 local ground={}
 if not light then
  for dy=-1,1 do for dx=-1,1 do
   local n=cells[(c.cx+dx)..':'..(c.cy+dy)]
   if n and n~=c and (n.collision or 0)==0 and n.ts==ts and ts.midToSlot[n.mid] then
    local sl=ts.midToSlot[n.mid];local ox,oy=sl%ts.cols*16,math.floor(sl/ts.cols)*16
    for y=0,15 do for x=0,15 do local r,g,b=ts.imageData:getPixel(ox+x,oy+y);ground[key(r,g,b)]=true end end
   end
  end end
 end
 local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
 local mask={}
 for y=0,15 do for x=0,15 do
  local r,g,b=ts.imageData:getPixel(ox+x,oy+y)
  if light then mask[y*16+x]=lumOf(r,g,b)>=light else mask[y*16+x]=not ground[key(r,g,b)] end
  -- (cool: the structure is grey-blue stone on warm paving; its drawn shadow, a darker paving
  -- colour, is ground too -- it stood as pale blocks at the fountain's foot)
  if cool and r>b+.03 then mask[y*16+x]=false end
 end end
 local function on(x,y)return x>=0 and x<16 and y>=0 and y<16 and mask[y*16+x] end
 local L,T,R,B=uv[1][1],uv[1][2],uv[3][1],uv[3][2]
 local function px(x,y)local u=L+(R-L)*(x+.5)/16;local v=T+(B-T)*(y+.5)/16;return {{u,v},{u,v},{u,v},{u,v}} end
 local X,Z=c.cx*16,c.cy*16
 for y=0,15 do
  local x=0
  while x<16 do
   if on(x,y) then
    local a=x;while x<16 and on(x,y) do x=x+1 end
    local b=x
    local u0,u1=L+(R-L)*a/16,L+(R-L)*b/16;local v0,v1=T+(B-T)*y/16,T+(B-T)*(y+1)/16
    quad({{X+a,h,Z+y},{X+b,h,Z+y},{X+b,h,Z+y+1},{X+a,h,Z+y+1}},{{u0,v0},{u1,v0},{u1,v1},{u0,v1}},1)
    -- (sides take the object's body colour: the first pixel in from the
    -- edge that is not its dark outline)
    local function body(k,step)
     for i=0,3 do local q=k+i*step
      if q>=a and q<b then local r,g,bb=ts.imageData:getPixel(ox+q,oy+y);if lumOf(r,g,bb)>.42 then return px(q,y) end end
     end
     return px(k,y)
    end
    quad({{X+a,h,Z+y},{X+a,h,Z+y+1},{X+a,0,Z+y+1},{X+a,0,Z+y}},body(a,1),.74)
    quad({{X+b,h,Z+y+1},{X+b,h,Z+y},{X+b,0,Z+y},{X+b,0,Z+y+1}},body(b-1,-1),.8)
    for k=a,b-1 do
     if not on(k,y+1) then
      -- (the front takes the lightest of the edge's last rows, not its dark outline)
      local by,bl=y,-1
      for yy=y,math.max(0,y-2),-1 do if on(k,yy) then local r,g,b=ts.imageData:getPixel(ox+k,oy+yy);local l=lumOf(r,g,b);if l>bl then bl,by=l,yy end end end
      quad({{X+k,h,Z+y+1},{X+k+1,h,Z+y+1},{X+k+1,0,Z+y+1},{X+k,0,Z+y+1}},px(k,by),.88)
     end
     if not on(k,y-1) then
      local by=y
      for yy=y,math.min(15,y+3) do if on(k,yy) then local r,g,bb=ts.imageData:getPixel(ox+k,oy+yy);if lumOf(r,g,bb)>.42 then by=yy;break end end end
      quad({{X+k+1,h,Z+y},{X+k,h,Z+y},{X+k,0,Z+y},{X+k+1,0,Z+y}},px(k,by),.64)
     end
    end
   else x=x+1 end
  end
 end
end

-- whether the fence in this cell is drawn in the layer above the player
function M.overInk(c)
 local ts=c.ts;local slot=ts.midToSlot[c.mid]
 if not slot or not ts.overImageData then return false end
 local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
 local n=0
 for y=0,15,2 do for x=0,15,2 do local _,_,_,a=ts.overImageData:getPixel(ox+x,oy+y);if a>.5 then n=n+1 end end end
 return n>=6
end
-- quad(points,uv,shade)
function M.append(c,quad,uvFor)
 local kind,s=M.kind(c);if not kind then return end
 local ts=c.ts
 local slot=ts.midToSlot[c.mid];local uv=uvFor(ts,c.mid)
 if not slot or not uv or not ts.imageData then return end
 local no=kind~='curb' and notFence(ts,s) or {}
 local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
 -- (the rail may be drawn in the layer above the player: both layers count)
 local function pix(x,y)
  local r,g,b=ts.imageData:getPixel(ox+x,oy+y)
  if ts.overImageData then local rr,gg,bb,aa=ts.overImageData:getPixel(ox+x,oy+y)
   if aa>.5 then return rr,gg,bb end end
  return r,g,b
 end
 local function fence(x,y)
  if x<0 or x>15 or y<0 or y>15 then return false end
  local r,g,b=pix(x,y)
  return not no[key(r,g,b)]
 end
 local function swatch(x,y)
  local u=uv[1][1]+(uv[2][1]-uv[1][1])*(x+.5)/16
  local v=uv[1][2]+(uv[3][2]-uv[1][2])*(y+.5)/16
  return {{u,v},{u,v},{u,v},{u,v}}
 end
 local function box(x0,y0,z0,x1,y1,z1,t)
  quad({{x0,y1,z0},{x1,y1,z0},{x1,y1,z1},{x0,y1,z1}},t,1)
  quad({{x0,y1,z1},{x1,y1,z1},{x1,y0,z1},{x0,y0,z1}},t,.88)
  quad({{x1,y1,z0},{x0,y1,z0},{x0,y0,z0},{x1,y0,z0}},t,.66)
  quad({{x0,y1,z0},{x0,y1,z1},{x0,y0,z1},{x0,y0,z0}},t,.76)
  quad({{x1,y1,z1},{x1,y1,z0},{x1,y0,z0},{x1,y0,z1}},t,.8)
 end
 local X,Z=c.cx*16,c.cy*16
 if kind=='curb' then
  local h=s.h
  local function sub(x0,y0,x1,y1)
   local L,T,R,B=uv[1][1],uv[1][2],uv[3][1],uv[3][2]
   return {{L+(R-L)*x0/16,T+(B-T)*y0/16},{L+(R-L)*x1/16,T+(B-T)*y0/16},{L+(R-L)*x1/16,T+(B-T)*y1/16},{L+(R-L)*x0/16,T+(B-T)*y1/16}}
  end
  if s.dir=='ew' then
   local z0,z1=Z+s.t0,Z+s.t1+1
   quad({{X,h,z0},{X+16,h,z0},{X+16,h,z1},{X,h,z1}},sub(0,s.t0,16,s.t1+1),1)
   quad({{X,h,z1},{X+16,h,z1},{X+16,0,z1},{X,0,z1}},sub(0,s.f0,16,s.f1+1),.86)
   quad({{X+16,h,z0},{X,h,z0},{X,0,z0},{X+16,0,z0}},sub(0,s.f0,16,s.f1+1),.66)
  else
   local x0,x1=X+s.t0,X+s.t1+1
   quad({{x0,h,Z},{x1,h,Z},{x1,h,Z+16},{x0,h,Z+16}},sub(s.t0,0,s.t1+1,16),1)
   local edge=swatch(s.t0,1)
   quad({{x0,h,Z},{x0,h,Z+16},{x0,0,Z+16},{x0,0,Z}},edge,.74)
   quad({{x1,h,Z+16},{x1,h,Z},{x1,0,Z},{x1,0,Z+16}},edge,.8)
  end
  return
 end
 if kind=='across' then
  -- the fence line: the foot row's depth
  local zf=Z+s.foot+1
  local flat=s.flat and s.flat[c.mid]
  -- the fence's body colour: its commonest pixel that is not dark outline
  local bodySw
  do local votes,bn={},0
   for y=0,s.foot do for x=0,15 do if fence(x,y) then
    local r,g,b=pix(x,y)
    if lumOf(r,g,b)>.42 then local k=key(r,g,b);votes[k]=(votes[k] or 0)+1
     if votes[k]>bn then bn=votes[k];bodySw=swatch(x,y) end end
   end end end
  end
  -- a column drawn in (nearly) every row from its top to the foot is a post
  for x=0,15 do
   local top
   for y=0,s.foot do if fence(x,y) then top=top or y end end
   if top then
    local rows=0
    for y=top,s.foot do if fence(x,y) then rows=rows+1 end end
    local post=rows>=(s.foot-top+1)-1
    for y=top,s.foot do if fence(x,y) then
     local h1=s.foot-y+1
     local d=post and M.POST or M.RAIL
     -- (deep: a stretch of the rail running north-south, drawn end-on in
     -- these columns, runs back through the whole cell)
     local dp=s.deep and s.deep[c.mid]
     local deepCol=dp and x>=dp[1] and x<=dp[2]
     if deepCol then
      -- a run seen end-on: its long sides and top are the body colour, its
      -- end shows the drawn cross-section
      d=16
      box(X+x,h1-1,zf-d,X+x+1,h1,zf,bodySw or swatch(x,y))
      quad({{X+x,h1,zf+.02},{X+x+1,h1,zf+.02},{X+x+1,h1-1,zf+.02},{X+x,h1-1,zf+.02}},swatch(x,y),.88)
     elseif flat and d==M.RAIL then
      -- a rail pixel of a flat panel: its front and back faces, no top or sides
      quad({{X+x,h1,zf},{X+x+1,h1,zf},{X+x+1,h1-1,zf},{X+x,h1-1,zf}},swatch(x,y),.88)
      quad({{X+x+1,h1,zf-d},{X+x,h1,zf-d},{X+x,h1-1,zf-d},{X+x+1,h1-1,zf-d}},swatch(x,y),.66)
     else
      box(X+x,h1-1,zf-d,X+x+1,h1,zf,swatch(x,y))
      -- the column's top shows its body colour, not the drawing's dark outline
      if y==top then
       local lit
       for yy=top,math.min(s.foot,top+3) do
        if fence(x,yy) then local r,g,b=pix(x,yy)
         if lumOf(r,g,b)>.42 then lit=swatch(x,yy);break end
        end
       end
       lit=lit or bodySw
       if lit then quad({{X+x,h1+.02,zf-d},{X+x+1,h1+.02,zf-d},{X+x+1,h1+.02,zf},{X+x,h1+.02,zf}},lit,1) end
      end
     end
    end end
   end
  end
 else
  -- along: the drawn line of posts seen from above (its fence columns)
  local cols={}
  for x=0,15 do
   local n=0
   for y=0,15 do if fence(x,y) then n=n+1 end end
   if n>=10 then cols[#cols+1]=x end
  end
  if #cols==0 then return end
  local xa,xb=X+cols[1],X+cols[#cols]+1
  local cx=(xa+xb)/2
  local ref=s.alongPanel and ts.midToSlot[s.alongPanel]
  if ref then
   -- the looped rail of the reference tile turned side-on: its column k stands at depth Z+k, its row r
   -- at the height an east-west rail puts it (foot-r+1); posts (columns drawn top to foot) POST thick,
   -- rail pixels a panel RAIL thick with only its two broad faces (no lattice of pixel sides)
   local rox,roy=ref%ts.cols*16,math.floor(ref/ts.cols)*16
   local ruv=uvFor(ts,s.alongPanel)
   local function rfence(x,y)
    local r,g,b=ts.imageData:getPixel(rox+x,roy+y)
    return not no[key(r,g,b)]
   end
   local function rsw(x,y)
    local u=ruv[1][1]+(ruv[2][1]-ruv[1][1])*(x+.5)/16
    local v=ruv[1][2]+(ruv[3][2]-ruv[1][2])*(y+.5)/16
    return {{u,v},{u,v},{u,v},{u,v}}
   end
   -- rows of this cell the drawn line runs through
   local onRow={}
   for y=0,15 do for _,x in ipairs(cols)do if fence(x,y) then onRow[y]=true;break end end end
   for k=0,15 do if onRow[k] then
    local top,rows
    for y=0,s.foot do if rfence(k,y) then top=top or y end end
    if top then
     rows=0;for y=top,s.foot do if rfence(k,y) then rows=rows+1 end end
     local post=rows>=(s.foot-top+1)-1
     for y=top,s.foot do if rfence(k,y) then
      local h1=s.foot-y+1
      local t=rsw(k,y)
      if post then
       local d=M.POST/2
       box(cx-d,h1-1,Z+k,cx+d,h1,Z+k+1,t)
      else
       local d=M.RAIL/2
       quad({{cx-d,h1,Z+k+1},{cx-d,h1,Z+k},{cx-d,h1-1,Z+k},{cx-d,h1-1,Z+k+1}},t,.76)
       quad({{cx+d,h1,Z+k},{cx+d,h1,Z+k+1},{cx+d,h1-1,Z+k+1},{cx+d,h1-1,Z+k}},t,.8)
       -- (ends of the rail where the next row along has none: closed)
       if not (onRow[k-1] and rfence(math.max(0,k-1),y)) then quad({{cx+d,h1,Z+k},{cx-d,h1,Z+k},{cx-d,h1-1,Z+k},{cx+d,h1-1,Z+k}},t,.66) end
       if not (onRow[k+1] and rfence(math.min(15,k+1),y)) then quad({{cx-d,h1,Z+k+1},{cx+d,h1,Z+k+1},{cx+d,h1-1,Z+k+1},{cx-d,h1-1,Z+k+1}},t,.88) end
       if y==top or not rfence(k,y-1) then quad({{cx-d,h1,Z+k},{cx+d,h1,Z+k},{cx+d,h1,Z+k+1},{cx-d,h1,Z+k+1}},t,1) end
      end
     end end
    end
   end end
   return
  end
  local rail=swatch(cols[1],8)
  for y=0,15 do
   -- a cap (a row whose colour differs from the rail's) is a post
   local r1,g1,b1=ts.imageData:getPixel(ox+cols[1],oy+y)
   local r2,g2,b2=ts.imageData:getPixel(ox+cols[1],oy+8)
   local capRow=key(r1,g1,b1)~=key(r2,g2,b2)
   if capRow then
    box(cx-M.POST/2,0,Z+y,cx+M.POST/2,M.RAIL_H+3,Z+y+1,swatch(cols[1],y))
   else
    box(cx-M.RAIL/2,M.RAIL_H-2,Z+y,cx+M.RAIL/2,M.RAIL_H,Z+y+1,rail)
    box(cx-M.RAIL/2,M.RAIL_H-6,Z+y,cx+M.RAIL/2,M.RAIL_H-4,Z+y+1,rail)
   end
  end
 end
end
return M
