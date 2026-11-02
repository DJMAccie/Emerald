-- Whole-object recipes for Emerald's Building primary art
local V=...
local M={}
local recipes={}
local profiles=V and V.require('Gen3EmeraldInteriors') or dofile((os.getenv('DS_MOD_PATH') or '.')..'/lib/Gen3EmeraldInteriors.lua')
for secondary,p in pairs(profiles)do for _,prop in ipairs(p.props)do
 recipes[#recipes+1]={name=secondary..'_prop_'..prop[1],primary='building',secondary=secondary,
  rows={{prop[1]}},kind=prop[2],h=prop[3],lo=prop[4],ground=p.floor,depth=8}
end end
local Pixel=V and V.require('Gen3PixelFurniture') or dofile((os.getenv('DS_MOD_PATH') or '.')..'/lib/Gen3PixelFurniture.lua')
for _,r in ipairs(Pixel.recipes)do recipes[#recipes+1]=r end
local Budget=V and V.require('BuildBudget') or {tick=function()end}
 table.sort(recipes,function(a,b)
  local aa,bb=#a.rows*#a.rows[1],#b.rows*#b.rows[1]
  if aa~=bb then return aa>bb end
  local as=(a.kind=='pixel' and 4 or 0)+(a.pair and 2 or 0)+(a.secondary and 1 or 0)
  local bs=(b.kind=='pixel' and 4 or 0)+(b.pair and 2 or 0)+(b.secondary and 1 or 0)
  if as~=bs then return as>bs end
  return a.name<b.name
 end)
local candidates={}
for _,r in ipairs(recipes)do
 local mid=r.rows[1][1];local list=candidates[mid] or {};candidates[mid]=list;list[#list+1]=r
end
local function choices(mid)return candidates[mid] or {}end
function M.extract(cells)
 local out,ordered={},{}
 for _,c in pairs(cells)do if (c.primary=='building' or c.primary=='general' or c.primary=='secret_base') and #choices(c.mid)>0 then ordered[#ordered+1]=c end;Budget.tick()end
 table.sort(ordered,function(a,b)return a.cy==b.cy and a.cx<b.cx or a.cy<b.cy end)
 for _,c in ipairs(ordered)do Budget.tick();if not c.prop and not c.stairs and not c.noFurniture then
  for _,r in ipairs(choices(c.mid))do
   if c.primary==(r.primary or 'building') and c.mid==r.rows[1][1] and (not r.scopeField or c[r.scopeField]) and (not r.secondary or r.secondary==c.secondary) and (not r.pair or r.pair==c.pair) then
    local match=true;local parts={}
    for dy,row in ipairs(r.rows)do for dx,mid in ipairs(row)do
     local n=cells[(c.cx+dx-1)..':'..(c.cy+dy-1)]
     if not n or n.prop or n.stairs or n.pair~=c.pair or n.mid~=mid then match=false else parts[#parts+1]=n end
    end end
    if match then
     local p={recipe=r,cx=c.cx,cy=c.cy,pair=c.pair,ts=c.ts,w=#r.rows[1]*16,d=#r.rows*16,cells=cells}
     for _,n in ipairs(parts)do n.prop=p end
     out[#out+1]=p;break
    end
   end
  end
 end end
 return out
end
function M.sig(p,tx,ty)
 local n=p.cells and p.cells[(p.cx+tx)..':'..(p.cy+ty)]
 return n and (tostring(n.mid)..(n.pair==p.pair and '+' or '-')) or false,n
end
local function outside(p,tx,ty)
 local sig,n=M.sig(p,tx,ty)
 if p.reads then p.reads[tx..':'..ty]=sig end
 return n
end
function M.append(p,emit,uvFor)
 local r,x,z=p.recipe,p.cx*16,p.cy*16
 local function source(sx,sy,sw,sh,a,b,c,d)
  local xend,yend=sx+sw,sy+sh
  local function point(u,v)
   local u1,v1=1-u,1-v
   return {(a[1]*u1+b[1]*u)*v1+(d[1]*u1+c[1]*u)*v,(a[2]*u1+b[2]*u)*v1+(d[2]*u1+c[2]*u)*v,(a[3]*u1+b[3]*u)*v1+(d[3]*u1+c[3]*u)*v}
  end
  local tx0,ty0=math.floor(sx/16),math.floor(sy/16)
  if math.ceil(xend/16)-1==tx0 and math.ceil(yend/16)-1==ty0 then
   local mid=r.rows[ty0+1] and r.rows[ty0+1][tx0+1]
   if not mid then local n=outside(p,tx0,ty0);mid=n and n.mid end
   local uv=mid and uvFor(p.ts,mid)
   if uv then
    local ul,vt=uv[1][1],uv[1][2];local du,dv=uv[2][1]-ul,uv[3][2]-vt
    local l,t,rr,bb=sx-tx0*16,sy-ty0*16,xend-tx0*16,yend-ty0*16
    local ul_,ur_,vt_,vb_=ul+du*l/16,ul+du*rr/16,vt+dv*t/16,vt+dv*bb/16
    emit({a,b,c,d},
     {{ul_,vt_},{ur_,vt_},{ur_,vb_},{ul_,vb_}},1,r.kind=='plant' and {x+p.w/2,z+p.d-6,.001} or nil)
   end
   return
  end
  for ty=math.floor(sy/16),math.ceil(yend/16)-1 do for tx=math.floor(sx/16),math.ceil(xend/16)-1 do
   local l,t=math.max(sx,tx*16),math.max(sy,ty*16)
   local rr,bb=math.min(xend,(tx+1)*16),math.min(yend,(ty+1)*16)
   local mid=r.rows[ty+1] and r.rows[ty+1][tx+1]
   if not mid then local n=outside(p,tx,ty);mid=n and n.mid end
   local uv=mid and uvFor(p.ts,mid)
   if uv then
   local function tex(px,py)return {uv[1][1]+(uv[2][1]-uv[1][1])*(px-tx*16)/16,uv[1][2]+(uv[3][2]-uv[1][2])*(py-ty*16)/16}end
   emit({point((l-sx)/sw,(t-sy)/sh),point((rr-sx)/sw,(t-sy)/sh),point((rr-sx)/sw,(bb-sy)/sh),point((l-sx)/sw,(bb-sy)/sh)},
    {tex(l,t),tex(rr,t),tex(rr,bb),tex(l,bb)},1,r.kind=='plant' and {x+p.w/2,z+p.d-6,.001} or nil)
   end
  end end
 end
 local uv=uvFor(p.ts,r.rows[1][1]);local u,v=uv[1][1]+(uv[2][1]-uv[1][1])*.08,uv[1][2]+(uv[3][2]-uv[1][2])*.1
 local solid={{u,v},{u,v},{u,v},{u,v}}
 local function box(x0,y0,z0,x1,y1,z1,material)
  material=material or solid
  emit({{x0,y1,z0},{x1,y1,z0},{x1,y1,z1},{x0,y1,z1}},material,.88)
  emit({{x0,y1,z1},{x1,y1,z1},{x1,y0,z1},{x0,y0,z1}},material,.72)
  emit({{x1,y1,z0},{x0,y1,z0},{x0,y0,z0},{x1,y0,z0}},material,.66)
  emit({{x0,y1,z0},{x0,y1,z1},{x0,y0,z1},{x0,y0,z0}},material,.7)
  emit({{x1,y1,z1},{x1,y1,z0},{x1,y0,z0},{x1,y0,z1}},material,.7)
 end
 local function sample(sx,sy)
  local row=r.rows[math.floor(sy/16)+1]
  local mid=row and row[math.floor(sx/16)+1]
  if not mid then local n=outside(p,math.floor(sx/16),math.floor(sy/16));mid=n and n.mid end
  local t=mid and uvFor(p.ts,mid)
  if not t then return solid end
  local u=t[1][1]+(t[2][1]-t[1][1])*(sx%16+.5)/16
  local v=t[1][2]+(t[3][2]-t[1][2])*(sy%16+.5)/16
  return {{u,v},{u,v},{u,v},{u,v}}
 end
 if r.kind=='flight' then
  local steps={r.h or 0,r.lo or 0}
  for k=0,1 do
   local h=steps[k+1];local x0,x1=x+k*8,x+k*8+8
   local function at(px,py)return {uv[1][1]+(uv[2][1]-uv[1][1])*px/16,uv[1][2]+(uv[3][2]-uv[1][2])*py/16}end
   local tread={at(k*8,0),at(k*8+8,0),at(k*8+8,16),at(k*8,16)}
   emit({{x0,h+.02,z},{x1,h+.02,z},{x1,h+.02,z+16},{x0,h+.02,z+16}},tread,1)
   if h>0 then
    local face=sample(k*8+4,8)
    local nextH=k==0 and steps[2] or 0
    emit({{x1,h,z},{x1,h,z+16},{x1,nextH,z+16},{x1,nextH,z}},face,.7)
    emit({{x0,h,z+16},{x1,h,z+16},{x1,0,z+16},{x0,0,z+16}},face,.8)
    emit({{x1,h,z},{x0,h,z},{x0,0,z},{x1,0,z}},face,.66)
   end
  end
  return
 end
 if r.kind=='relief' or r.kind=='bin' or r.kind=='plaque' then
  local mask=V.require('Gen3Outdoor').mask(p.ts,r.rows[1][1],r.ground)
  if not mask then return end
  local function tex(px,py)
   local u=uv[1][1]+(uv[2][1]-uv[1][1])*(px+.5)/16
   local v=uv[1][2]+(uv[3][2]-uv[1][2])*(py+.5)/16
   return {{u,v},{u,v},{u,v},{u,v}}
  end
  local first,last
  for sy=0,15 do for sx=0,15 do if mask[sy*16+sx]then first=first or sy;last=sy end end end
  if not first then return end
  local rise=r.h/(last-first+1)
  for sy=first,last do for sx=0,15 do if mask[sy*16+sx]then
   local y0,y1=(last-sy)*rise,(last-sy+1)*rise
   local depth=r.kind=='plaque' and 2 or r.kind=='bin' and 7 or 5+3*math.sin((sy-first)/(last-first+1)*math.pi)
   box(x+sx,y0,z+8-depth/2,x+sx+1,y1,z+8+depth/2,tex(sx,sy))
  end end end
 elseif r.kind=='pixel' then
  local ts=p.ts
  local function at(mid,px,py)
   local slot=ts.midToSlot[mid];if not slot then return 0,0,0,0 end
   local ax,ay=slot%ts.cols*16+px,math.floor(slot/ts.cols)*16+py
   local cr,cg,cb,ca=ts.imageData:getPixel(ax,ay)
   if ts.overImageData then local r2,g2,b2,a2=ts.overImageData:getPixel(ax,ay)
    if a2>0 then cr,cg,cb,ca=r2*a2+cr*(1-a2),g2*a2+cg*(1-a2),b2*a2+cb*(1-a2),math.max(ca,a2)end
   end
   return cr,cg,cb,ca
  end
  local cells=p.cells
  local function pixel(px,py)
   local ty,tx=math.floor(py/16),math.floor(px/16)
   local row=r.rows[ty+1]
   local mid=row and row[tx+1]
   if not mid then
    local n=outside(p,tx,ty)
    if not n or n.pair~=p.pair then return 0,0,0,0 end
    mid=n.mid
   end
   return at(mid,px%16,py%16)
  end
  local raw,memo=pixel,{}
  pixel=function(px,py)
   local k=py*4096+px
   local e=memo[k]
   if not e then e={raw(px,py)};memo[k]=e end
   return e[1],e[2],e[3],e[4]
  end
  local function colours(mid)
   local out={}
   for py=4,11 do for px=4,11 do local cr,cg,cb=at(mid,px,py);out[#out+1]={cr,cg,cb}end end
   return out
  end
  Pixel.append(p,x,z,pixel,colours,source,box,sample)
 end
end
-- Presentation only: never alter native interaction cells, scripted motion or collision.
function M.flightHeight(cells,px,pz)
 local c=cells and cells[math.floor(px/16)..':'..math.floor(pz/16)]
 local r=c and c.prop and c.prop.recipe
 if not (r and r.kind=='flight') then return 0 end
 return (px%16)<8 and (r.h or 0) or (r.lo or 0)
end
function M.support(cells,gid,px,py,stationary)
 gid=tonumber(gid)
 local c=cells and cells[math.floor(px/16)..':'..math.floor(py/16)]
 local p=c and c.prop;local r=p and p.recipe
 if r and r.kind=='pixel' and r.dais then return r.h+Pixel.lift(r.h,r)+.12,0 end
 if gid==88 and stationary~=false and r and r.seat then
  return r.seat.height-r.seat.hips,r.seat.z-16
 end
 return 0
end
M.recipes=recipes
return M
