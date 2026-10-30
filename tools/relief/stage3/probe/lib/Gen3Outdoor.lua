-- Reviewed General outdoor metatiles. Geometry changes presentation only;
-- native map collision, ledge jumps and field interactions remain untouched.
local V=...
local M={}
M.LONG_H=14   -- long grass blade height (px)
M.SOLID_PLANTS=false   -- flowers and tall grass as solid pixel-voxels instead of flat cards
local Mask=V and V.require("SceneryMask") or assert(loadfile("lib/SceneryMask.lua"))()
-- Each cutout keeps the palette of its actual ground. Saffron's board
-- spans shaded paving and pale paving, rather than the General grass swatch.
local plants={[4]=1,[5]=1,[0xD]=1,[0x160]=1,[0x168]=1,[0x304]=0x2E5,[0x30C]=0x2E9}
-- Plant cells discovered while a scene is built (Emerald's grass, flowers
-- and shrubs are behaviour-driven, not a fixed FireRed metatile list). Each
-- entry is mid -> ground so the cutout keeps only the drawn plant.
local registered={}
local images={}
function M.registerPlant(pair,mid,ground)
 local t=registered[pair];if not t then t={};registered[pair]=t end
 if t[mid]~=ground then
  t[mid]=ground
  local old=images[pair];if old then old.image:release();images[pair]=nil end
 end
end
local tuftInfo,tufts
local function sub(uv,l,t,r,b)
 local function p(x,y)return {uv[1][1]+(uv[2][1]-uv[1][1])*x/16,uv[1][2]+(uv[3][2]-uv[1][2])*y/16}end
 return {p(l,t),p(r,t),p(r,b),p(l,b)}
end
local function pixel(ts,x,y)
 local r,g,b,a=ts.imageData:getPixel(x,y)
 if ts.overImageData then local rr,gg,bb,aa=ts.overImageData:getPixel(x,y)
  r,g,b,a=rr*aa+r*(1-aa),gg*aa+g*(1-aa),bb*aa+b*(1-aa),aa+a*(1-aa)
 end
 return r,g,b,a
end
local function colorKey(r,g,b)return math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)end
function M.mask(ts,mid,ground)
 -- ground: one floor tile, or a list of them (a pool rim drawn over water,
 -- sand and the cliff behind: all of those are not the rock)
 local floor={}
 local any=false
 for _,g in ipairs(type(ground)=='table' and ground or {ground})do
  local slot=ts.midToSlot[g]
  if slot then
   any=true
   for y=0,15 do for x=0,15 do
    floor[colorKey(pixel(ts,slot%ts.cols*16+x,math.floor(slot/ts.cols)*16+y))]=true
   end end
  end
 end
 if not any then return end
 local at=ts.midToSlot[mid];if not at then return end
 return Mask.mask(16,function(x,y)
  local r,g,b,a=pixel(ts,at%ts.cols*16+x,math.floor(at/ts.cols)*16+y)
  return a==0 or floor[colorKey(r,g,b)]
 end)
end
M.HEDGE_HULL_MIN=100   -- floor-art pixels a hedge tile needs before its own hull is built
-- Solid flower or tall-grass cell: every opaque pixel of the tile's own drawing
-- becomes voxel, merged into boxes: a run of columns sharing the same rows is one box,
-- 4 units deep, with the front and back showing the pixels' own texels 1:1. Sides and tops
-- sample a quarter-texel band, so depth never stretches a pixel. A tuft keeps the lower 12 rows
-- of its tile (10-12 px tall). Returns the number of quads emitted.
local function solidPlant(c,emit,uv,anchor)
 local ts=c.ts
 local at=ts.midToSlot[c.mid];if not at then return 0 end
 local mask=M.mask(ts,c.mid,c.shape.ground)
 local ox,oy=at%ts.cols*16,math.floor(at/ts.cols)*16
 local tuft=c.shape.kind=='grass'
 local r0min=tuft and 4 or 0
 local g={}
 for r=0,15 do g[r]={};for px=0,15 do
  local _,_,_,a=pixel(ts,ox+px,oy+r)
  g[r][px]=(r>=r0min and a>.5 and (not mask or mask[r*16+px])) and true or false
 end end
 local function on(px,r)
  return px>=0 and px<=15 and r>=r0min and r<=15 and g[r][px]
 end
 -- per column, its runs of opaque rows; adjacent columns with the same rows join one box
 local runs,active={},{}
 for px=0,15 do
  local segs,r={},r0min
  while r<=15 do
   if g[r][px] then
    local r1=r
    while r1+1<=15 and g[r1+1][px] do r1=r1+1 end
    segs[#segs+1]={r0=r,r1=r1};r=r1+1
   else r=r+1 end
  end
  local nxt={}
  for _,s in ipairs(segs)do
   local key=s.r0..':'..s.r1
   local run=active[key]
   if run and run.px1==px then run.px1=px+1 else run={px0=px,px1=px+1,r0=s.r0,r1=s.r1};runs[#runs+1]=run end
   nxt[key]=run
  end
  active=nxt
 end
 local x,zc=c.cx*16,c.cy*16+8
 local z0,z1=zc-2,zc+2
 local n=0
 local function quad(p,t,shade)n=n+1;emit(p,t,shade,anchor)end
 for _,run in ipairs(runs)do
  local a,b,t,u=run.px0,run.px1,run.r0,run.r1+1
  local x0,x1=x+a,x+b
  local y0,y1=15-run.r1,16-run.r0
  quad({{x0,y1,z1},{x1,y1,z1},{x1,y0,z1},{x0,y0,z1}},sub(uv,a,t,b,u),1)          -- front
  quad({{x1,y1,z0},{x0,y1,z0},{x0,y0,z0},{x1,y0,z0}},sub(uv,b,t,a,u),.72)        -- back, mirrored
  quad({{x0,y1,z0},{x0,y1,z1},{x0,y0,z1},{x0,y0,z0}},sub(uv,a+.25,t,a+.75,u),.78) -- left side
  quad({{x1,y1,z1},{x1,y1,z0},{x1,y0,z0},{x1,y0,z1}},sub(uv,b-.75,t,b-.25,u),.9)  -- right side
  -- top: only where the row above is not part of the box (same texel row across the depth)
  local px=a
  while px<b do
   if on(px,t-1) then px=px+1 else
    local e=px
    while e<b and not on(e,t-1) do e=e+1 end
    quad({{x+px,y1,z0},{x+e,y1,z0},{x+e,y1,z1},{x+px,y1,z1}},sub(uv,px,t+.25,e,t+.75),1)
    px=e
   end
  end
 end
 return n
end
function M.plant(c,emit,uv,uvFor)
 -- One complete, flat native drawing. Shared canopy anchors preserve the
 -- authored angle in static views and face free/battle cameras without
 -- bending, inflating, or duplicating the artwork.
 local x,z=c.cx*16,c.cy*16
 if c.shape.kind=='shrub' and V.require('TreePresentation').props:get()=='modeled' then
  local mask=M.mask(c.ts,c.mid,c.shape.ground);local slot=c.ts.midToSlot[c.mid]
  -- a hedge tile whose floor art is only a few edge pixels (0x24C, 0x246, 0x266: grass with a dark rim) is drawn by
  -- its over-layer strip (Gen3Canopy bar); a hull of the rim alone is a grey ghost under the bar
  if mask and c.shape.hedge then
   -- (the floor layer alone: pixel() above is the floor with the over layer composited on it)
   local floor,slotG={},c.ts.midToSlot[c.shape.ground]
   local img=c.ts.imageData
   if slotG then for y=0,15 do for x=0,15 do
    local r,g,b=img:getPixel(slotG%c.ts.cols*16+x,math.floor(slotG/c.ts.cols)*16+y);floor[colorKey(r,g,b)]=true
   end end end
   local n,at=0,c.ts.midToSlot[c.mid]
   if at then for y=0,15 do for x=0,15 do
    local r,g,b,a=img:getPixel(at%c.ts.cols*16+x,math.floor(at/c.ts.cols)*16+y)
    if a>.5 and not floor[colorKey(r,g,b)] then n=n+1 end
   end end end
   if n<M.HEDGE_HULL_MIN and V.require('Gen3Canopy').applies(c) then return true end
  end
  if mask and slot then
   -- A hedge is a straight wall of leaf: the drawing's own pixels in front and
   -- a bounded row hull behind it, never the round bush of the lone shrub.
   local hedge=c.shape.hedge
   local faces=V.require('VoxelHull').build(16,16,function(px,py)
    local r,g,b,a=pixel(c.ts,slot%c.ts.cols*16+px,math.floor(slot/c.ts.cols)*16+py)
    local t=sub(uv,px+.5,py+.5,px+.5,py+.5)[1]
    return r,g,b,mask[py*16+px] and a or 0,t[1],t[2]
   end,1,0,hedge and 10 or nil,(not hedge) and 'bush' or nil)
   for _,q in ipairs(faces)do
    local p={};for _,v in ipairs(q)do p[#p+1]={x+8+v[1],v[2],z+8+v[3]}end
    local t={q.u,q.v};emit(p,{t,t,t,t},q.shade)
   end
   return true
  end
 end
 -- Long grass (Routes 119/120 round Fortree, the player wades through it):
 -- a field of upright blades, not two cut-out cards (its tile is all grass
 -- colours, so the cut-out left it flat). Four rows of one-pixel blades per
 -- cell, each blade a column of the tile's own drawing, at uneven heights
 -- (deterministic per cell), opaque in the tile's colours (Opus; user: "the
 -- tall grass ... around fortree, those long paths").
 if c.shape.kind=='grass' and (c.shape.height or 4)>=8 then
  emit({{x,.025,z},{x+16,.025,z},{x+16,.025,z+16},{x,.025,z+16}},uv,1)
  local L,T,R,B=uv[1][1],uv[1][2],uv[3][1],uv[3][2]
  for k,zz in ipairs({3,7,11,15})do
   for px=0,15 do
    local hash=(c.cx*73+c.cy*151+px*37+k*19)%7
    local h=M.LONG_H-4+hash*.9-(k==1 and 0 or 0)
    local r0=math.max(0,16-h)
    local u0,u1=L+(R-L)*px/16,L+(R-L)*(px+1)/16
    local v0,v1=T+(B-T)*r0/16,B
    local xa=x+px+(k%2)*.5
    emit({{xa,h,z+zz},{xa+1,h,z+zz},{xa+1,0,z+zz},{xa,0,z+zz}},{{u0,v0},{u1,v0},{u1,v1},{u0,v1}},.78+.06*k)
   end
  end
  return true
 end
 M.registerPlant(c.ts.pair,c.mid,c.shape.ground)
 local h=c.shape.kind=='grass' and (c.shape.height or 4)*1.5 or 16
 local groundUv=((c.shape.ownGround or c.shape.kind=='grass') and uv) or (c.shape.groundMid and uvFor(c.ts,c.shape.groundMid)) or uvFor(c.ts,c.shape.ground) or uv
 local bladeUv=(not c.shape.ownGround and c.shape.groundMid and uvFor(c.ts,0x00D)) or uv
 if M.TUFTS and (c.shape.kind=='flowers' or c.shape.kind=='grass') and c.ts.midToSlot[c.mid] and c.ts.imageData then
  local info=tuftInfo(c.ts,c.mid,c.shape.ground)
  if info and tufts(c,emit,uv,groundUv,info) then return true end
 end
 if M.SOLID_PLANTS and (c.shape.kind=='flowers' or c.shape.kind=='grass') and c.ts.midToSlot[c.mid] then
  -- the flower's own ground is the cell's floor (drawn by the scene); a tuft keeps its flat ground quad
  if c.shape.kind=='grass' then emit({{x,.025,z},{x+16,.025,z},{x+16,.025,z+16},{x,.025,z+16}},groundUv,1) end
  solidPlant(c,emit,uv,{x+8,z+8,.001})
  return true
 end
 if c.shape.kind=='grass' then
  -- Keep the original patch spread across its full ground area; lowering
  -- only the upright card collapses a meadow into separated green stripes.
  emit({{x,.025,z},{x+16,.025,z},{x+16,.025,z+16},{x,.025,z+16}},groundUv,1)
  -- Two crossed blades per patch read as a tuft from every camera yaw
  -- instead of a single strip that vanishes edge-on.
  emit({{x+8,h,z},{x+8,h,z+16},{x+8,.001,z+16},{x+8,.001,z}},bladeUv,.92,{x+8,z+8,.001})
 end
 emit({{x,h,z+8},{x+16,h,z+8},{x+16,.001,z+8},{x,.001,z+8}},bladeUv,1,{x+8,z+8,.001})
 return true
end
-- A prop's ground defaults to its tileset's floor (or grass), but a sign in a
-- paved street stands on paving: take the
-- ground the walkable cells around it share (most common wins, same tileset
-- only). Props with no walkable neighbour borrow the ground their prop
-- neighbours already resolved.
local STANDS={sign=true,awning=true}
-- A market stall is one hip roof drawn from above: the cells of a stall form a
-- rectangle, and its cloth rises to a ridge along the middle (see append).
local function groupAwnings(cells)
 local seen={}
 for _,c in pairs(cells)do
  if c.shape and c.shape.kind=='awning' and not seen[c] then
   local members,stack={}, {c};seen[c]=true
   while #stack>0 do
    local p=table.remove(stack);members[#members+1]=p
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local n=cells[(p.cx+d[1])..':'..(p.cy+d[2])]
     if n and not seen[n] and n.pair==c.pair and n.shape and n.shape.kind=='awning' then seen[n]=true;stack[#stack+1]=n end
    end
   end
   local x0,y0,x1,y1=c.cx,c.cy,c.cx,c.cy
   for _,m in ipairs(members)do x0=math.min(x0,m.cx);y0=math.min(y0,m.cy);x1=math.max(x1,m.cx);y1=math.max(y1,m.cy) end
   local set={}
   for _,m in ipairs(members)do set[m.cx..':'..m.cy]=true end
   local comp={x0=x0*16,z0=y0*16,x1=(x1+1)*16,z1=(y1+1)*16,set=set}
   for _,m in ipairs(members)do m.awn=comp end
  end
 end
end
M.SIGN_POST_REPEAT=3   -- how many times a sign's post rows are stacked (taller than the flat drawing)
M.RISE=.5     -- height gained per unit of run toward the ridge
function M.groundProps(cells)
 groupAwnings(cells)
 local function vote(c,pass)
  local votes,best,top={},nil,0
  for dy=-1,1 do for dx=-1,1 do
   local n=(dx~=0 or dy~=0) and cells[(c.cx+dx)..':'..(c.cy+dy)]
   if n and n.pair==c.pair and n.shape and c.ts.midToSlot[n.mid] then
    local mid
    if pass==1 then
     if n.shape.kind=='flat' and n.collision==0 and not n.boundary then mid=n.mid end
    elseif n.shape.grounded then mid=n.shape.ground end
    if mid and c.ts.midToSlot[mid] then
     local v=(votes[mid] or 0)+((dx==0 or dy==0) and 2 or 1)
     votes[mid]=v
     if v>top then top,best=v,mid end
    end
   end
  end end
  return best
 end
 local pending={}
 for _,c in pairs(cells)do
  if c.shape and STANDS[c.shape.kind] and c.ts then
   local best=vote(c,1)
   if best then c.shape.ground=best;c.shape.grounded=true else pending[#pending+1]=c end
  end
 end
 for _=1,3 do
  local rest={}
  for _,c in ipairs(pending)do
   local best=vote(c,2)
   if best then c.shape.ground=best;c.shape.grounded=true else rest[#rest+1]=c end
  end
  pending=rest
 end
end
-- One-way ledge, any south-facing tile (plain run, rounded corners, end pieces). The drawing is an
-- oblique picture, grass above and a dirt face below; each pixel column is read on its own:
--   * its face = the contiguous non-grass rows ending at its lowest non-grass row (at most FACE_MAX);
--   * grass rows below the face are the ground in front of it (a rounded corner has some);
--   * rows above the face are the flat top.
-- The face stands as a vertical wall of its own pixel rows, one face row repeated M.LEDGE_EXTRA times so the
-- step is taller than the flat art; the top is laid in plan behind it; the ground rows lie flat in front.
-- Neighbouring columns with the same profile are one strip; where profiles differ, the taller strip's side
-- is closed in its own lip colour. A tile with no usable split returns false (the old mound).
M.LEDGE_EXTRA=3
M.FACE_MAX=9
M.RUN_F=9
local ledgeSplit=setmetatable({},{__mode='k'})
local function isGreen(ts,ox,oy,x,y)
 local r,g,b,a=pixel(ts,ox+x,oy+y)
 return a<=.5 or (g>r*1.1 and g>b*1.05)
end
local function profile(ts,mid)
 local cache=ledgeSplit[ts];if not cache then cache={};ledgeSplit[ts]=cache end
 if cache[mid]~=nil then return cache[mid] or nil end
 local slot=ts.midToSlot[mid];if not slot then cache[mid]=false;return end
 local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
 local cols,faceCols={}, 0
 for x=0,15 do
  local l=15
  while l>=0 and isGreen(ts,ox,oy,x,l) do l=l-1 end
  if l<0 then cols[x]={none=true}
  else
   local f=l
   while f-1>=0 and not isGreen(ts,ox,oy,x,f-1) and (l-f+1)<M.FACE_MAX do f=f-1 end
   cols[x]={f=f,l=l};faceCols=faceCols+1
  end
 end
 -- the lip row jitters by one pixel from column to column (shaded highlights): snap each column to the
 -- tile's most common face top and bottom unless it really differs (a rounded corner)
 local function mode(key)
  local count,best,bn={},nil,0
  for x=0,15 do local v=cols[x][key];if v then count[v]=(count[v] or 0)+1;if count[v]>bn then best,bn=v,count[v] end end end
  return best
 end
 local mf,ml=mode('f'),mode('l')
 for x=0,15 do local c=cols[x]
  if c.f then
   if mf and math.abs(c.f-mf)<=1 then c.f=mf end
   if ml and math.abs(c.l-ml)<=1 then c.l=ml end
  end
 end
 -- every full-height face stands on the plain run's lip (9:15): the corner and end tiles' 7:15 columns
 -- drew a lip two rows higher than the run beside them (teeth and stubs); the art above the lip stays the top
 for x=0,15 do local c=cols[x]
  if c.f and c.l>=14 and c.f>=5 and c.f<=9 then c.tf=c.f;c.f=M.RUN_F;c.l=15 end
 end
 -- a real ledge tile has a face in most of its columns, and a plain run's face is between 4 and 9 rows
 if faceCols<5 then cache[mid]=false;return end
 for x=0,15 do local c=cols[x];if c.f and (c.l-c.f+1)<2 then c.f=nil;c.none=true end end
 cache[mid]=cols;return cols
end
-- A side ledge (jump east or west: Route 115's 0x085) is drawn as a band of dirt running north-south
-- down the tile. Read as a south-facing lip it stood as a tall block or a thin diagonal plank; it is a
-- kerb along its band instead: the band's own pixels laid flat on top, SIDE_H px up (flush with the
-- floor above where it tops a drop), its face on the side the player jumps to, down to the floor there.
M.SIDE_H=8
local sideBand=setmetatable({},{__mode='k'})
local function sideProfile(ts,mid)
 local cache=sideBand[ts];if not cache then cache={};sideBand[ts]=cache end
 if cache[mid]~=nil then return cache[mid] or nil end
 local slot=ts.midToSlot[mid];if not slot then cache[mid]=false;return end
 local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
 local x0,x1
 for x=0,15 do
  local n=0
  for y=0,15 do if not isGreen(ts,ox,oy,x,y) then n=n+1 end end
  if n>=12 then x0=x0 or x;x1=x+1 elseif n>4 and x0 and not x1 then cache[mid]=false;return end
 end
 if not x0 or x1-x0>12 or x1-x0<2 then cache[mid]=false;return end
 -- the band's rows that are dirt across its whole width; a row with grass in it (the band's rounded ends)
 -- shows the nearest clean row on the kerb's faces, so no green panels stand in the dirt
 local clean,rowMap,least,leastN={}, {},nil,99
 for y=0,15 do
  local n=0;for x=x0,x1-1 do if isGreen(ts,ox,oy,x,y) then n=n+1 end end
  clean[y]=n==0
  if n<leastN then least,leastN=y,n end
 end
 for y=0,15 do
  local best;for d=0,15 do if clean[y-d] then best=y-d;break elseif clean[y+d] then best=y+d;break end end
  rowMap[y]=best or least
 end
 cache[mid]={x0=x0,x1=x1,rowMap=rowMap};return cache[mid]
end
local function sideLedge(c,emit,uv)
 local east=c.behavior==0x38
 if not (east or c.behavior==0x39) then return false end
 local b=sideProfile(c.ts,c.mid);if not b then return false end
 local x,z=c.cx*16,c.cy*16
 local drop=c.floor and c.floor.ledgeLow and c.base and c.base-c.floor.ledgeLow
 local top=(drop and drop>.5) and 0 or M.SIDE_H
 local foot=(drop and drop>.5) and -drop or 0
 local a,e=x+b.x0,x+b.x1
 -- the ground either side of the band, flat (on the floor below on the jump side)
 if b.x0>0 then emit({{x,.01+(east and 0 or foot),z},{a,.01+(east and 0 or foot),z},{a,.01+(east and 0 or foot),z+16},{x,.01+(east and 0 or foot),z+16}},sub(uv,0,0,b.x0,16),1) end
 if b.x1<16 then emit({{e,.01+(east and foot or 0),z},{x+16,.01+(east and foot or 0),z},{x+16,.01+(east and foot or 0),z+16},{e,.01+(east and foot or 0),z+16}},sub(uv,b.x1,0,16,16),1) end
 -- top: the band's own pixels
 emit({{a,top,z},{e,top,z},{e,top,z+16},{a,top,z+16}},sub(uv,b.x0,0,b.x1,16),1)
 -- the face on the jump side, down to the floor there; the back face down to this cell's floor
 local col=sub(uv,b.x0,0,b.x1,16)
 local function face(xx,y0,y1,shade,westward)
  if y1-y0<.01 then return end
  -- the band's art turned on its side: along the face runs the tile's rows (one strip each, the clean
  -- row standing in for a row with grass), up the face its columns
  for r=0,15 do
   local cs=sub(uv,b.x0,b.rowMap[r],b.x1,b.rowMap[r]+1)
   local q={{cs[1][1],cs[1][2]},{cs[1][1],cs[4][2]},{cs[2][1],cs[3][2]},{cs[2][1],cs[2][2]}}
   local zs,ze=z+r,z+r+1
   if westward then emit({{xx,y1,zs},{xx,y1,ze},{xx,y0,ze},{xx,y0,zs}},{q[1],q[2],q[3],q[4]},shade)
   else emit({{xx,y1,ze},{xx,y1,zs},{xx,y0,zs},{xx,y0,ze}},{q[2],q[1],q[4],q[3]},shade) end
  end
 end
 if east then face(e,foot,top,.74,false);face(a,0,top,.7,true)
 else face(a,foot,top,.7,true);face(e,0,top,.74,false) end
 -- ends: closed where the next cell north or south is no ledge
 local band=sub(uv,b.x0,0,b.x1,1)
 emit({{a,top,z+16},{e,top,z+16},{e,math.min(0,foot),z+16},{a,math.min(0,foot),z+16}},band,.84)
 emit({{e,top,z},{a,top,z},{a,math.min(0,foot),z},{e,math.min(0,foot),z}},band,.62)
 return true
end
-- The cell's ground under a ledge at the top of a drop (Gen3Scene lays it before M.append). Such a
-- ledge's lip lies flush with the floor, so a full ground plane under it lay in the same plane as the
-- lip: a flickering khaki streak in first person. Emits the ground only where the ledge draws none of
-- its own (the grass rows behind a front ledge's lip; nothing for a side ledge) and returns true;
-- false when the cell is no drop ledge (the full plane stays, under the raised wall).
-- A drop ledge draws its own faces down to the floor below (the kerb's, the front wall's): the scene's
-- terrace skirt of the ledge tile's art (half grass) beside it stood as green panels in the dirt.
function M.ownsFaces(c)
 local drop=c.floor and c.floor.ledgeLow and c.base and c.base-c.floor.ledgeLow
 if not (drop and drop>.5) or c.stageHidden then return false end
 if c.shape and c.shape.side then
  return (c.behavior==0x38 or c.behavior==0x39) and sideProfile(c.ts,c.mid) and true or false
 end
 return profile(c.ts,c.mid) and true or false
end
function M.ledgeFloor(c,emit,ground)
 local drop=c.floor and c.floor.ledgeLow and c.base and c.base-c.floor.ledgeLow
 if not (drop and drop>.5) or c.stageHidden then return false end
 if c.shape and c.shape.side then
  return (c.behavior==0x38 or c.behavior==0x39) and sideProfile(c.ts,c.mid) and true or false
 end
 local cols=profile(c.ts,c.mid);if not cols then return false end
 local x,z=c.cx*16,c.cy*16
 -- (columns with the same depth behind the lip in one quad)
 local x0,d0
 for cx=0,16 do
  local p=cols[cx]
  local d=p and not p.none and p.l+1-math.max(p.f,1) or 0
  if d~=d0 then
   if d0 and d0>0 then emit({{x+x0,0,z},{x+cx,0,z},{x+cx,0,z+d0},{x+x0,0,z+d0}},sub(ground,x0,0,cx,d0),1) end
   x0,d0=cx,d
  end
 end
 return true
end
function M.ledge(c,emit,uv)
 if c.shape and c.shape.side then
  if not sideLedge(c,emit,uv) then local x,z=c.cx*16,c.cy*16;emit({{x,.01,z},{x+16,.01,z},{x+16,.01,z+16},{x,.01,z+16}},uv,1) end
  return true
 end
 local cols=profile(c.ts,c.mid);if not cols then return false end
 local x,z=c.cx*16,c.cy*16
 local E=M.LEDGE_EXTRA
 -- group consecutive columns with the same profile into strips
 local strips={}
 for cx=0,15 do
  local p=cols[cx]
  local key=p.none and 'none' or (p.f..':'..p.l..':'..(p.tf or p.f))
  local last=strips[#strips]
  if last and last.key==key then last.x1=cx+1 else strips[#strips+1]={key=key,x0=cx,x1=cx+1,p=p} end
 end
 local function band(x0,x1,zz,y0,y1,r0,r1,shade,flip)
  local q=sub(uv,x0,r0,x1,r1)
  if flip then emit({{x+x1,y1,zz},{x+x0,y1,zz},{x+x0,y0,zz},{x+x1,y0,zz}},q,shade)
  else emit({{x+x0,y1,zz},{x+x1,y1,zz},{x+x1,y0,zz},{x+x0,y0,zz}},q,shade) end
 end
 for _,st in ipairs(strips)do
  local p=st.p
  if p.none then
   -- plain ground: the tile's own rows, flat
   emit({{x+st.x0,.01,z},{x+st.x1,.01,z},{x+st.x1,.01,z+16},{x+st.x0,.01,z+16}},sub(uv,st.x0,0,st.x1,16),1)
  else
   local rows=p.l-p.f+1
   local H=rows+E
   local zf=z+p.l+1               -- front of the wall
   local zb=zf-math.max(p.f,1)    -- back of the top
   -- ground rows in front of the face (a rounded corner), flat (on the floor below a drop)
   local dropF=c.floor and c.floor.ledgeLow and c.base and c.base-c.floor.ledgeLow
   local gy=(dropF and dropF>.5) and .01-dropF or .01
   if p.l<15 then emit({{x+st.x0,gy,zf},{x+st.x1,gy,zf},{x+st.x1,gy,z+16},{x+st.x0,gy,z+16}},sub(uv,st.x0,p.l+1,st.x1,16),1) end
   -- a ground strip behind the wall too, so the ledge stands on the cell's floor (rows above the top are grass)
   local rep=p.f+1
   if rep>p.l then rep=p.l end
   -- (a ledge at the top of a drop runs on down to the floor below)
   local drop=c.floor and c.floor.ledgeLow and c.base and c.base-c.floor.ledgeLow
   local r0=math.min(p.f+2,p.l)
   if drop and drop>.5 then
    -- the ledge IS the step (user: "route 115 doesnt even have a double ledge"): its lip is flush
    -- with the floor above, one face of its own rows runs down to the floor below -- lip rows on top,
    -- the face's own earth 1:1 in blocks, its shadow row at the foot. (It stood its full height on top
    -- of the raised floor with the drop under it: two ledges, one over the other.)
    H=0
    local lip=r0-p.f
    if drop>=lip+3 and p.l-r0>=2 then
     band(st.x0,st.x1,zf,-lip,0,math.min(r0+1,p.l-lip+1),math.min(r0+1,p.l-lip+1)+lip,1,false)
     band(st.x0,st.x1,zf,-drop,-drop+1,p.l,p.l+1,.9,false)
     local y=-lip
     while y>-drop+1.01 do
      local h=math.min(p.l-r0,y-(-drop+1))
      band(st.x0,st.x1,zf,y-h,y,r0,r0+h,1,false)
      y=y-h
     end
    else
     band(st.x0,st.x1,zf,-drop,0,r0,p.l+1,1,false)
    end
   else
   -- wall, bottom to top: rows below the repeated one, the repeated row, then the lip row
   if rep<p.l then band(st.x0,st.x1,zf,0,p.l-rep,rep+1,p.l+1,1,false);band(st.x0,st.x1,zb,0,p.l-rep,rep+1,p.l+1,.7,true) end
   band(st.x0,st.x1,zf,p.l-rep,p.l-rep+E,rep,rep+1,1,false);band(st.x0,st.x1,zb,p.l-rep,p.l-rep+E,rep,rep+1,.7,true)
   band(st.x0,st.x1,zf,p.l-rep+E,H,r0,r0+1,1,false);band(st.x0,st.x1,zb,p.l-rep+E,H,r0,r0+1,.7,true)
   end
   -- flat top: the rows above the face, in plan from the back edge to the wall
   local tx0,tx1=st.x0,st.x1
   if c.shape and c.shape.right and tx1>8 then tx0,tx1=0,math.min(8,tx1-st.x0)
   elseif c.shape and c.shape.left and tx0<8 then tx0,tx1=math.max(8,16-(tx1-st.x0)),16 end
   if p.f>0 then emit({{x+st.x0,H,zb},{x+st.x1,H,zb},{x+st.x1,H,zf},{x+st.x0,H,zf}},sub(uv,tx0,0,tx1,math.min(p.tf or p.f,6)),1) end
   -- sides: close this strip's prism where a neighbour is lower or absent
   local cap=sub(uv,st.x0,p.f,st.x0+1,p.f+1)
   local yb=(drop and drop>.5) and -drop or 0
   local z0=(drop and drop>.5) and z or zb
   local sideTex=(drop and drop>.5) and sub(uv,0,r0,16,p.l+1) or cap
   emit({{x+st.x0,H,z0},{x+st.x0,H,zf},{x+st.x0,yb,zf},{x+st.x0,yb,z0}},sideTex,.8)
   emit({{x+st.x1,H,zf},{x+st.x1,H,z0},{x+st.x1,yb,z0},{x+st.x1,yb,zf}},sideTex,.9)
  end
 end
 return true
end
-- Tall grass and flowers as plants (M.TUFTS), not as the tile stood up on two crossed cards:
--   * grass: five tufts a cell, each a fan of pointed blades leaning outward, dark at the foot and
--     light at the tip (two colours of the tile's own blades, taken where the drawing puts a light
--     pixel over a dark one); the drawn patch stays on the ground under them;
--   * flowers: each blossom of the drawing (a patch of petal colours) stands on a stem, facing up and
--     to every side, over low leaves in the tile's own leaf colours.
-- Everything sways about its own foot like the cards did.
M.TUFTS=true
M.TUFT_H=2          -- blade height per unit of shape.height (4 -> 8 px, uneven)
local tuftCache=setmetatable({},{__mode='k'})
local function hsh(a,b,c)local n=math.sin(a*12.9898+b*78.233+c*37.719)*43758.5453;return n-math.floor(n)end
function tuftInfo(ts,mid,ground)
 local cache=tuftCache[ts];if not cache then cache={};tuftCache[ts]=cache end
 local k=mid..':'..tostring(ground)
 if cache[k]~=nil then return cache[k] end
 local mask=M.mask(ts,mid,ground)
 local at=ts.midToSlot[mid]
 if not mask or not at then cache[k]=false;return false end
 local ox,oy=at%ts.cols*16,math.floor(at/ts.cols)*16
 local px,green={}, {}
 for y=0,15 do for x=0,15 do
  if mask[y*16+x] then
   local r,g,b=pixel(ts,ox+x,oy+y)
   px[y*16+x]={r,g,b,.3*r+.59*g+.11*b}
   -- (leaf: a saturated green; the pale specks of the ground's own highlight are not)
   green[y*16+x]=g>r*1.05 and g>b*1.05 and g-math.min(r,b)>.22 and .3*r+.59*g+.11*b<.66
  end
 end end
 -- a light leaf pixel directly over a darker one: the blade's tip and foot
 local best,bd
 for y=0,14 do for x=0,15 do
  local a,b=px[y*16+x],px[(y+1)*16+x]
  -- (both with leaf either side: flower tiles are animated a pixel left and right)
  local steady=x>0 and x<15 and green[y*16+x-1] and green[y*16+x+1] and green[(y+1)*16+x-1] and green[(y+1)*16+x+1]
  if a and b and green[y*16+x] and green[(y+1)*16+x] and a[4]-b[4]>.04 and (steady or not bd or bd<0) then
   if steady then a={a[1],a[2],a[3],a[4]+1} end
   local d=a[4]-b[4];if not bd or d>bd then best,bd={x,y},d end
  end
 end end
 local any
 if not best then for y=0,15 do for x=0,15 do if green[y*16+x] and not any then any={x,y} end end end end
 -- blossoms: patches of colours that are not leaf
 local seen,flowers={}, {}
 for y=0,15 do for x=0,15 do
  local i=y*16+x
  if px[i] and not green[i] and not seen[i] then
   local stack,n,x0,y0,x1,y1={i},0,x,y,x,y;seen[i]=true
   while #stack>0 do
    local q=table.remove(stack);n=n+1
    local qx,qy=q%16,math.floor(q/16)
    x0,y0,x1,y1=math.min(x0,qx),math.min(y0,qy),math.max(x1,qx),math.max(y1,qy)
    for dy=-1,1 do for dx=-1,1 do
     local nx,ny=qx+dx,qy+dy;local j=ny*16+nx
     if nx>=0 and ny>=0 and nx<16 and ny<16 and px[j] and not green[j] and not seen[j] then seen[j]=true;stack[#stack+1]=j end
    end end
   end
   if n>=6 and x1-x0<10 and y1-y0<10 then flowers[#flowers+1]={math.max(0,x0-1),y0,math.min(16,x1+2),y1+1} end
  end
 end end
 local info={blade=best,plain=any,flowers=flowers}
 if not (best or any) then info=false end
 cache[k]=info;return info
end
local function blades(emit,uv,info,bx,bz,n,H,W,seed)
 local t
 if info.blade then t=sub(uv,info.blade[1]+.2,info.blade[2]+.1,info.blade[1]+.8,info.blade[2]+1.9)
 else t=sub(uv,info.plain[1]+.2,info.plain[2]+.2,info.plain[1]+.8,info.plain[2]+.8) end
 for i=1,n do
  local a=(i+hsh(seed,i,1))*2*math.pi/n
  local dx,dz=math.cos(a),math.sin(a)
  local lean=(i==1 and .4 or 1.4+2.2*hsh(seed,i,2))*H/8
  local h=H*(i==1 and 1.15 or .65+.45*hsh(seed,i,3))
  local w=W*(.8+.4*hsh(seed,i,4))
  local fx,fz=bx+dx*.6,bz+dz*.6
  local tx,tz=fx+dx*lean,fz+dz*lean
  emit({{tx+dz*.25,h,tz-dx*.25},{tx-dz*.25,h,tz+dx*.25},{fx-dz*w/2,.03,fz+dx*w/2},{fx+dz*w/2,.03,fz-dx*w/2}},t,.82+.18*hsh(seed,i,5),{bx,bz,.001})
 end
end
function tufts(c,emit,uv,groundUv,info)
 local x,z=c.cx*16,c.cy*16
 if c.shape.kind=='grass' then
  if (c.shape.height or 4)>=8 then return false end
  emit({{x,.025,z},{x+16,.025,z},{x+16,.025,z+16},{x,.025,z+16}},groundUv,1)
  local H=(c.shape.height or 4)*M.TUFT_H
  for k,p in ipairs({{3,3},{11,4},{7,8.5},{3,13},{12,12.5}})do
   local seed=c.cx*73+c.cy*139+k*17
   blades(emit,uv,info,x+p[1]+3*hsh(seed,1,9)-1.5,z+p[2]+3*hsh(seed,2,9)-1.5,5,H,2.6,seed)
  end
  return true
 end
 if #info.flowers==0 then return false end
 for k,p in ipairs({{4,5},{12,6},{8,12}})do
  blades(emit,uv,info,x+p[1],z+p[2],4,4.5,3.2,c.cx*31+c.cy*57+k*13)
 end
 local stem=info.blade and sub(uv,info.blade[1]+.3,info.blade[2]+1.2,info.blade[1]+.7,info.blade[2]+1.8) or sub(uv,info.plain[1]+.3,info.plain[2]+.3,info.plain[1]+.7,info.plain[2]+.7)
 for k,f in ipairs(info.flowers)do
  local w,d=f[3]-f[1],f[4]-f[2]
  local xc,zc=x+(f[1]+f[3])/2,z+(f[2]+f[4])/2
  local hs=5+2.5*hsh(c.cx,c.cy,k)
  local t=sub(uv,f[1],f[2],f[3],f[4])
  local an={xc,zc,.001}
  emit({{xc-.5,hs,zc},{xc+.5,hs,zc},{xc+.5,.03,zc},{xc-.5,.03,zc}},stem,.8,an)
  emit({{xc,hs,zc-.5},{xc,hs,zc+.5},{xc,.03,zc+.5},{xc,.03,zc-.5}},stem,.7,an)
  -- the blossom: open to the sky (tipped a little to the south) and to both sides
  emit({{xc-w/2,hs+1.5,zc-d/2},{xc+w/2,hs+1.5,zc-d/2},{xc+w/2,hs-.5,zc+d/2},{xc-w/2,hs-.5,zc+d/2}},t,1,an)
  emit({{xc-w/2,hs+d/2,zc},{xc+w/2,hs+d/2,zc},{xc+w/2,hs-d/2,zc},{xc-w/2,hs-d/2,zc}},t,.95,an)
  emit({{xc,hs+d/2,zc-w/2},{xc,hs+d/2,zc+w/2},{xc,hs-d/2,zc+w/2},{xc,hs-d/2,zc-w/2}},t,.88,an)
 end
 return true
end
function M.append(c,emit,uvFor)
 local s,x,z=c.shape,c.cx*16,c.cy*16
 local uv=assert(uvFor(c.ts,c.mid))
 local function box(x0,y0,z0,x1,y1,z1,tex,frontTex)
  emit({{x0,y1,z0},{x1,y1,z0},{x1,y1,z1},{x0,y1,z1}},tex,1)
  emit({{x0,y1,z1},{x1,y1,z1},{x1,y0,z1},{x0,y0,z1}},frontTex or tex,frontTex and 1 or .85)
  emit({{x1,y1,z0},{x0,y1,z0},{x0,y0,z0},{x1,y0,z0}},tex,.72)
  emit({{x0,y1,z0},{x0,y1,z1},{x0,y0,z1},{x0,y0,z0}},tex,.78)
  emit({{x1,y1,z1},{x1,y1,z0},{x1,y0,z0},{x1,y0,z1}},tex,.9)
 end
 if s.kind=='sign' then
  -- Signs are stacks of 1:1 bands cut from the tile: every visible face shows whole art pixels
  -- and nothing is stretched. Posts get taller by repeating their own rows (M.SIGN_POST_REPEAT),
  -- boards are thicker than the flat drawing and show the same art on both faces.
  local function R(l,t,r,b)return sub(uv,l,t,r,b)end
  local function sbox(x0,y0,z0,x1,y1,z1,front,back,side,top)
   emit({{x0,y1,z1},{x1,y1,z1},{x1,y0,z1},{x0,y0,z1}},front,1)                 -- south: the drawing
   emit({{x1,y1,z0},{x0,y1,z0},{x0,y0,z0},{x1,y0,z0}},back or front,.72)         -- north: same art
   emit({{x0,y1,z0},{x0,y1,z1},{x0,y0,z1},{x0,y0,z0}},side,.78)
   emit({{x1,y1,z1},{x1,y1,z0},{x1,y0,z0},{x1,y0,z1}},side,.9)
   if top then emit({{x0,y1,z0},{x1,y1,z0},{x1,y1,z1},{x0,y1,z1}},top,1) end
  end
  -- a band of art rows [t,b] (inclusive), columns [l,r), stacked `times` over, 1 row = 1 unit
  local function stack(x0,x1,z0,z1,y,l,t,r,b,times,side,top)
   for i=0,times-1 do
    local y0=y+i*(b-t+1);local y1=y0+(b-t+1)
    sbox(x0,y0,z0,x1,y1,z1,R(l,t,r,b+1),nil,side,i==times-1 and top or nil)
   end
   return y+times*(b-t+1)
  end
  local mid=c.mid
  local n=M.SIGN_POST_REPEAT
  if mid==0x01B then
   -- route sign: foot rows 13-15, post rows 11-12, board rows 1-10 (row 0 is the post's peg)
   local y=stack(x+3,x+12,z+5.5,z+10.5,0,3,13,12,15,1,R(4,14,5,15))
   y=stack(x+6,x+9,z+6.5,z+9.5,y,6,11,9,12,n,R(6,11,7,12))
   sbox(x+0,y,z+6,x+15,y+10,z+10,R(0,1,15,11),nil,R(0,5,1,6),R(2,2,3,3))
  elseif mid==0x131 then
   -- gym sign: base rows 12-15, neck row 11 stacked, board rows 0-10
   local y=stack(x+3,x+14,z+5.5,z+10.5,0,3,12,14,15,1,R(5,13,6,14))
   y=stack(x+5,x+12,z+6,z+10,y,5,11,12,11,n*2,R(6,11,7,12))
   sbox(x+1,y,z+6,x+16,y+11,z+10,R(1,0,16,11),nil,R(1,4,2,5),R(3,0,4,1))
  else
   -- town sign (0x003): the tile is one whole panel with its base drawn on it (16 x 15)
   sbox(x+0,0,z+6,x+16,15,z+10,R(0,0,16,15),nil,R(15,6,16,7),R(1,1,2,2))
  end
 elseif s.kind=='fence' then
  local vertical=s.axis and not s.turn
  local post=uvFor(c.ts,s.material or (s.wood and 0xE6 or 0xE7)) or uv
  local face,cap=sub(post,3,6,6,14),sub(post,3,3,6,6)
  local rail=sub(post,3,9,5,11)
  local function stake(px,pz)
   box(px-1.4,0,pz-1.4,px+1.4,10,pz+1.4,face)
   box(px-1.5,10,pz-1.5,px+1.5,10.6,pz+1.5,cap)
  end
  if vertical then
   for _,dz in ipairs(s.stop and {8} or {4,12})do stake(x+s.axis,z+dz)end
   for _,h in ipairs({3,7})do box(x+s.axis-.6,h,z,x+s.axis+.6,h+1,z+(s.stop and 8 or 16),rail)end
  else
   for _,dx in ipairs({4,12})do stake(x+dx,z+8)end
   for _,h in ipairs({3,7})do
    box(x,h,z+7.4,x+16,h+1,z+8.6,rail)
    if s.turn then box(x+s.axis-.6,h,z+(s.turn=='north' and 0 or 8),x+s.axis+.6,h+1,z+(s.turn=='north' and 8 or 16),rail)end
   end
  end
 elseif s.kind=='ledge' then
  if not M.ledge(c,emit,uv) then
  -- A low turf mound with a thin exposed dirt edge, never a tall block.
  -- The sand/grass transition is painted into each native cap. C0/C1
  -- and C8/C9 are material transitions along a continuous ledge, not ends.
  -- Keep those pixels on both the approach and the raised cap.
  emit({{x,.01,z},{x+16,.01,z},{x+16,.01,z+6},{x,.01,z+6}},sub(uv,0,0,16,4),1)
  -- Ridge height: a readable step (a jump is a real drop), still shorter
  -- than a fence post so the map keeps its natural proportions.
  local RIDGE=5
  local function height(u,v)
   local endScale=(s.left and math.min(1,u/5) or s.right and math.min(1,(16-u)/5) or 1)
   return RIDGE*math.sin(math.min(1,math.max(0,(v-6)/10))*math.pi*.5)*endScale
  end
  for ix=0,3 do for iz=0,3 do
   local a,b=ix*4,(ix+1)*4;local p,q=6+iz*2.5,6+(iz+1)*2.5
   -- ramp rows 4..10 of the drawing (turf into the lip), face rows 10..16
   emit({{x+a,height(a,p),z+p},{x+b,height(b,p),z+p},{x+b,height(b,q),z+q},{x+a,height(a,q),z+q}},sub(uv,a,4+(p-6)*.6,b,4+(q-6)*.6),1)
  end end
  for ix=0,3 do local a,b=ix*4,(ix+1)*4
   emit({{x+a,height(a,16),z+16},{x+b,height(b,16),z+16},{x+b,0,z+16},{x+a,0,z+16}},sub(uv,a,10,b,16),.85)
  end
  for _,u in ipairs({0,16})do
   emit({{x+u,0,z+6},{x+u,height(u,16),z+16},{x+u,0,z+16},{x+u,0,z+6}},sub(uv,2,10,5,16),.8)
  end
  end
 elseif s.kind=='awning' then
  -- A market stall's cloth: the drawing lifted onto a slab with a valance
  -- hanging from its south and north edges.
  local h=s.height or 12
  local a=c.awn
  if a then
   -- Hip roof, the drawing seen from above laid over it: every pixel keeps its
   -- footprint (planar mapping), the cloth rises to a ridge along the middle.
   -- a stall's cloth is a shallow canopy, not a hip roof: cap the rise (a steep tent read as a sail
   -- over the market, tested 2026-10-20)
   local cap=math.min(M.RISE*math.min(a.x1-a.x0,a.z1-a.z0)/2,2.5)
   local function H(px,pz)
    local run=math.min(px-a.x0,a.x1-px,pz-a.z0,a.z1-pz)
    return h+math.min(cap,M.RISE*run)
   end
   for iz=0,3 do for ix=0,3 do
    local l,t=ix*4,iz*4;local r,b=l+4,t+4
    local h1,h2,h3,h4=H(x+l,z+t),H(x+r,z+t),H(x+r,z+b),H(x+l,z+b)
    -- the drawing already carries the light on each slope: no extra shading
    emit({{x+l,h1,z+t},{x+r,h2,z+t},{x+r,h3,z+b},{x+l,h4,z+b}},sub(uv,l,t,r,b),1)
   end end
   local south=not a.set[c.cx..':'..(c.cy+1)]
   local north=not a.set[c.cx..':'..(c.cy-1)]
   if south then emit({{x,h,z+16},{x+16,h,z+16},{x+16,h-3,z+16},{x,h-3,z+16}},sub(uv,0,13,16,16),.82) end
   if north then emit({{x+16,h,z},{x,h,z},{x,h-3,z},{x+16,h-3,z}},sub(uv,0,0,16,3),.7) end
   -- the frame: four posts carry the cloth (the drawing's dark frame colour). Without them the awning
   -- was a slab floating over the market floor (user: "the little stands are too low").
   if c.cx*16==a.x0 and c.cy*16==a.z0 then
    local f=sub(uv,1,1,2,2)
    local t={f[1],f[1],f[1],f[1]}
    local function post(px,pz)
     local e=2
     emit({{px,h-1,pz},{px+e,h-1,pz},{px+e,h-1,pz+e},{px,h-1,pz+e}},t,1)
     emit({{px,0,pz+e},{px+e,0,pz+e},{px+e,h-1,pz+e},{px,h-1,pz+e}},t,.88)
     emit({{px+e,0,pz},{px,0,pz},{px,h-1,pz},{px+e,h-1,pz}},t,.66)
     emit({{px+e,0,pz+e},{px+e,0,pz},{px+e,h-1,pz},{px+e,h-1,pz+e}},t,.8)
     emit({{px,0,pz},{px,0,pz+e},{px,h-1,pz+e},{px,h-1,pz}},t,.74)
    end
    post(a.x0+2,a.z0+2);post(a.x1-4,a.z0+2)
    post(a.x0+2,a.z1-4);post(a.x1-4,a.z1-4)
   end
  else
   emit({{x,h,z},{x+16,h,z},{x+16,h,z+16},{x,h,z+16}},uv,1)
   emit({{x,h,z+16},{x+16,h,z+16},{x+16,h-3,z+16},{x,h-3,z+16}},sub(uv,0,13,16,16),.82)
   emit({{x+16,h,z},{x,h,z},{x,h-3,z},{x+16,h-3,z}},sub(uv,0,0,16,3),.7)
  end
 elseif s.kind=='flowers' or s.kind=='grass' or s.kind=='shrub' then
  M.plant(c,emit,uv,uvFor)
 end
end
-- Derive cutouts from the provider's composited art, removing exact colours
-- from its reviewed ground swatch. Never ship or read private imported pixels.
function M.image(ts,frame)
 local old=images[ts.pair];if old and old.ts==ts and old.frame==frame then return old.image end
 if not ts.imageData then return end
 local data=ts.imageData:clone()
 local masks={}
 local artPair=V.require('Gen3Tilesets').canonical(ts.pair)
 masks=V.require('Gen3Furniture').cutouts(artPair)
 if not next(masks)then local copy={};for k,v in pairs(plants)do copy[k]=v end;masks=copy end
 for mid,ground in pairs(registered[ts.pair] or {})do masks[mid]=ground end
 for mid,ground in pairs(masks)do
  local mask=M.mask(ts,mid,ground)
  local at=ts.midToSlot[mid]
  if mask and at then for y=0,15 do for x=0,15 do
   local px,py=at%ts.cols*16+x,math.floor(at/ts.cols)*16+y
   local r,g,b,a=pixel(ts,px,py)
   if not mask[y*16+x]then a=0 end
   data:setPixel(px,py,r,g,b,a)
  end end end
 end
 local img=love.graphics.newImage(data);img:setFilter('nearest','nearest');data:release()
 if old then old.image:release()end;images[ts.pair]={ts=ts,image=img,frame=frame};return img
end
function M.release()
 for _,p in pairs(images)do p.image:release()end;images={}
end
return M
