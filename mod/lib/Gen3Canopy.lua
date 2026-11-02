-- Walk-under canopies
local M={}

M.HEIGHT=26
M.THICK=2 -- thickness of the slab
M.TILT=math.rad(50)
M.HEIGHT_BY={['building__trainer_hill']=7}
M.MIN_INK=40
M.GREEN=.6 -- share of those that must be foliage-green
M.HEDGE_HEIGHT=13
M.HEDGE_INK=12
M.SKIP={['general__fortree']=true,
 ['general__battle_frontier']=true,['general__battle_palace']=true}

M.ARCH={['general__battle_frontier_outside_west']={[0x20B]=true,[0x20C]=true,[0x20D]=true,[0x20E]=true,[0x20F]=true,
 [0x213]=true,[0x214]=true,[0x215]=true,[0x216]=true,[0x217]=true,[0x23C]=true,[0x23D]=true,[0x23E]=true},
 -- the East gate (navy roof on four tan posts, x36-42 y36-39): its over-layer tiles
 ['general__battle_frontier_outside_east']={[0x263]=true,[0x264]=true,[0x265]=true,[0x268]=true,[0x269]=true,[0x26C]=true,
 [0x270]=true,[0x271]=true,[0x272]=true,[0x273]=true,[0x274]=true,[0x278]=true,[0x279]=true,[0x27B]=true,[0x27C]=true}}
M.ARCH_GROUPS={['general__battle_frontier_outside_west']={{top=46,x0=23},{top=51,x0=23},{top=56,x0=23}},
 ['general__battle_frontier_outside_east']={{top=36,x0=36,h=4,extra=0,H0=65,roofY=28,roofDepth=20,spanDepth=6,postDepth=6,pillars={}}}}
M.ARCH_W,M.ARCH_H=7,3
M.ARCH_SHAFT={37,38,39}
M.ARCH_EXTRA=32
M.ARCH_DEPTH=12
M.ARCH_SPAN_DEPTH=8 -- the span
M.ARCH_PILLARS={{16,32},{80,96}}
local info=setmetatable({},{__mode='k'})
local function origin(ts,mid)
 local slot=ts.midToSlot[mid];if not slot then return end
 return slot%ts.cols*16,math.floor(slot/ts.cols)*16
end
local function crown(ts,mid,hedge)
 local t=info[ts];if not t then t={};info[ts]=t end
 local ck=hedge and -mid-1 or mid
 if t[ck]~=nil then return t[ck] or nil end
 t[ck]=false
 if not ts.overImageData then return end
 local ox,oy=origin(ts,mid);if not ox then return end
 local set,n,green={},0,0
 for y=0,15 do for x=0,15 do
  local r,g,b,a=ts.overImageData:getPixel(ox+x,oy+y)
  if a>.5 then n=n+1;set[y*16+x]=true;if g>r*1.1 and g>b*1.05 then green=green+1 end end
 end end
 local arch=M.ARCH[ts.pair or ''] and M.ARCH[ts.pair][mid]
 if not arch and (n<(hedge and M.HEDGE_INK or M.MIN_INK) or green/n<M.GREEN) then return end
 if arch and n==0 then return end
 t[ck]=set
 return set
end

function M.applies(c)
 if c.shape and c.shape.hedge and not (c.boundary or c.object or c.objectTop or c.mass or c.civic or c.column or c.prop or c.stairs) then
  return crown(c.ts,c.mid,true)~=nil
 end
 if c.collision~=0 or c.boundary or c.object or c.objectTop or c.treeOwned or c.mass or c.civic or c.column or c.prop or c.stairs then return false end
 if M.SKIP[c.pair] then return false end
 local s=c.shape
 if not s or s.kind=='tree' or s.kind=='cliff' or s.kind=='water' or s.groundMid then return false end
 return crown(c.ts,c.mid)~=nil
end

local function archRows(g)
 local src={}
 local h=g.h or M.ARCH_H
 local shaft=M.ARCH_SHAFT[#M.ARCH_SHAFT]
 local extra=g.extra or M.ARCH_EXTRA
 for s=0,h*16-1 do src[#src+1]=s;if s==shaft and not g.h then for _=1,extra do src[#src+1]=M.ARCH_SHAFT[2] end end end
 return src
end
local function archDepth(g,X,Y)
 if g.roofY and Y<g.roofY then return g.roofDepth end
 for _,p in ipairs(g.pillars or M.ARCH_PILLARS) do if X>=p[1] and X<p[2] then return g.postDepth or M.ARCH_DEPTH end end
 return g.spanDepth or M.ARCH_SPAN_DEPTH
end
local function archHit(ts,cells,g,X,Y)
 if X<0 or Y<0 or X>=M.ARCH_W*16 or Y>=(g.h or M.ARCH_H)*16 then return nil end
 local n=cells[(g.x0+math.floor(X/16))..':'..(g.top+math.floor(Y/16))]
 if not n or n.ts~=ts or not M.ARCH[ts.pair or ''] or not M.ARCH[ts.pair][n.mid] then return nil end
 local set=crown(ts,n.mid)
 if set and set[(Y%16)*16+X%16] then return n end
end
function M.appendArch(c,emit,uvFor,cells)
 local g
 for _,gg in ipairs(M.ARCH_GROUPS[c.pair] or {}) do
  if c.cy>=gg.top and c.cy<gg.top+(gg.h or M.ARCH_H) and c.cx>=gg.x0 and c.cx<gg.x0+M.ARCH_W then g=gg end
 end
 local uv=uvFor(c.ts,c.mid);if not g or not uv then return false end
 local function sub(l,t,r,b)
  local function p(x,y)return {uv[1][1]+(uv[2][1]-uv[1][1])*x/16,uv[1][2]+(uv[3][2]-uv[1][2])*y/16}end
  return {p(l,t),p(r,t),p(r,b),p(l,b)}
 end
 local src=archRows(g)
 local h=g.h or M.ARCH_H
 local zc=(g.top+h)*16 -- the pillars' feet: the south edge of the base row
 local H0=g.H0 or 69 -- drawing row e (1-based) stands at height H0-e
 local x0w=g.x0*16
 local cellRow=c.cy-g.top
 local cx0=(c.cx-g.x0)*16 -- drawing column of this cell's left edge
 local ts=c.ts
 local function stone(X,Y)return archHit(ts,cells,g,X,Y)~=nil end
 for e=1,#src do
  local Y=src[e]
  if math.floor(Y/16)==cellRow then
   local yt,yb=H0-e,H0-1-e
   local ly=Y%16
   local X=cx0
   while X<cx0+16 do
    if stone(X,Y) then
     local D=archDepth(g,X,Y);local a=X;local b=X+1
     while b<cx0+16 and stone(b,Y) and archDepth(g,b,Y)==D do b=b+1 end
     local zf,zb=zc+D/2,zc-D/2
     local la,lb=a-cx0,b-cx0
     emit({{x0w+a,yt,zf},{x0w+b,yt,zf},{x0w+b,yb,zf},{x0w+a,yb,zf}},sub(la,ly,lb,ly+1),1)
     emit({{x0w+b,yt,zb},{x0w+a,yt,zb},{x0w+a,yb,zb},{x0w+b,yb,zb}},sub(la,ly,lb,ly+1),1)
     if not stone(a-1,Y) or archDepth(g,a-1,Y)~=D then
      emit({{x0w+a,yt,zb},{x0w+a,yt,zf},{x0w+a,yb,zf},{x0w+a,yb,zb}},sub(la,ly,la+1,ly+1),.78)
     end
     if not stone(b,Y) or archDepth(g,b,Y)~=D then
      emit({{x0w+b,yt,zf},{x0w+b,yt,zb},{x0w+b,yb,zb},{x0w+b,yb,zf}},sub(lb-1,ly,lb,ly+1),.84)
     end
     for x=a,b-1 do
      local lx=x-cx0
      if e==1 or not stone(x,src[e-1]) then
       emit({{x0w+x,yt,zb},{x0w+x+1,yt,zb},{x0w+x+1,yt,zf},{x0w+x,yt,zf}},sub(lx,ly,lx+1,ly+1),1)
      end
      if e==#src or not stone(x,src[e+1]) then
       emit({{x0w+x,yb,zf},{x0w+x+1,yb,zf},{x0w+x+1,yb,zb},{x0w+x,yb,zb}},sub(lx,ly,lx+1,ly+1),.58)
      end
     end
     X=b
    else X=X+1 end
   end
  end
 end
 return true
end

function M.append(c,emit,uvFor,cells)
 if M.ARCH[c.pair or ''] and M.ARCH[c.pair][c.mid] then return M.appendArch(c,emit,uvFor,cells) end
 local hedge=c.shape and c.shape.hedge
 local set=crown(c.ts,c.mid,hedge);if not set then return false end
 local uv=uvFor(c.ts,c.mid);if not uv then return false end
 local x0,z0=c.cx*16,c.cy*16
 local H,T=M.HEIGHT,M.THICK
 if M.HEIGHT_BY[c.pair or ''] then H=M.HEIGHT_BY[c.pair] end
 if hedge then H,T=0,M.HEDGE_HEIGHT end
 local function sub(l,t,r,b)
  local function p(x,y)return {uv[1][1]+(uv[2][1]-uv[1][1])*x/16,uv[1][2]+(uv[3][2]-uv[1][2])*y/16}end
  return {p(l,t),p(r,t),p(r,b),p(l,b)}
 end
 local nb={}
 local function neighbour(dx,dy)
  local k=dx..':'..dy
  if nb[k]==nil then
   nb[k]=false
   local n=cells and cells[(c.cx+dx)..':'..(c.cy+dy)]
   if n and n.pair==c.pair and M.applies(n) then nb[k]=crown(n.ts,n.mid,n.shape and n.shape.hedge) or false end
  end
  return nb[k]
 end
 local function has(x,y)
  if x>=0 and y>=0 and x<16 and y<16 then return set[y*16+x] end
  local dx=x<0 and -1 or x>15 and 1 or 0
  local dy=y<0 and -1 or y>15 and 1 or 0
  local ns=neighbour(dx,dy)
  return ns and ns[((y+16)%16)*16+((x+16)%16)]
 end
 local zs=hedge and 0 or (H+T/2)*math.tan(M.TILT)
 for y=0,15 do
  local x=0
  while x<16 do
   if has(x,y) then
    local e=x+1;while e<16 and has(e,y)do e=e+1 end
    emit({{x0+x,H+T,z0+y+zs},{x0+e,H+T,z0+y+zs},{x0+e,H+T,z0+y+1+zs},{x0+x,H+T,z0+y+1+zs}},sub(x,y,e,y+1),1)
    if not hedge then emit({{x0+x,H,z0+y+1+zs},{x0+e,H,z0+y+1+zs},{x0+e,H,z0+y+zs},{x0+x,H,z0+y+zs}},sub(x,y,e,y+1),.58) end
    for i=x,e-1 do
     if not has(i,y-1) then emit({{x0+i+1,H+T,z0+y+zs},{x0+i,H+T,z0+y+zs},{x0+i,H,z0+y+zs},{x0+i+1,H,z0+y+zs}},sub(i,y,i+1,y+1),.55) end
     if not has(i,y+1) then emit({{x0+i,H+T,z0+y+1+zs},{x0+i+1,H+T,z0+y+1+zs},{x0+i+1,H,z0+y+1+zs},{x0+i,H,z0+y+1+zs}},sub(i,y,i+1,y+1),.62) end
    end
    if not has(x-1,y) then emit({{x0+x,H+T,z0+y+zs},{x0+x,H+T,z0+y+1+zs},{x0+x,H,z0+y+1+zs},{x0+x,H,z0+y+zs}},sub(x,y,x+1,y+1),.78) end
    if not has(e,y) then emit({{x0+e,H+T,z0+y+1+zs},{x0+e,H+T,z0+y+zs},{x0+e,H,z0+y+zs},{x0+e,H,z0+y+1+zs}},sub(e-1,y,e,y+1),.84) end
    x=e
   else x=x+1 end
  end
 end
 return true
end
return M
