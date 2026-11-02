-- Native General cliff masses
local V=...
local M={}
local waterPatch
M.SLOPE=8
M.NARROW=13
M.CAVE_FACE=16
local memoCells,solidMemo,heightMemo,active=false,nil,nil,false
local solidRaw
local function solid(c)
 if not c then return true end
 if active then
  local v=solidMemo[c]
  if v==nil then v=solidRaw(c) and true or false;solidMemo[c]=v end
  return v
 end
 return solidRaw(c)
end
solidRaw=function(c)
 if c.shape and (c.shape.kind=='cliff' or c.shape.kind=='caveWall') then
  if M.cells and c.mass and V.require('Gen3Rock').flat(c,M.cells) then return false end
  return true
 end
 local g=c.civic
 return g and g.custom and g.custom.geometry=='tower' and c.cy>=g.cy+(g.northRows or 0)
end
function M.narrow(cells,cx,cy)
 local c=cells[cx..':'..cy]
 if not (c and c.shape and (c.shape.kind=='cliff' or c.shape.kind=='caveWall')) then return false end
 local function rock(dx,dy)local n=cells[(cx+dx)..':'..(cy+dy)];return n==nil or solid(n) end
 return not (rock(-1,0) or rock(1,0)) or not (rock(0,-1) or rock(0,1))
end
local function thickness(cells,cx,cy)
 local function run(dx,dy)
  local n=1
  for s=-1,1,2 do local k=1
   while k<=4 do local c=cells[(cx+dx*s*k)..':'..(cy+dy*s*k)];if not (c and solid(c)) then break end;n=n+1;k=k+1 end
  end
  return n
 end
 return math.min(run(1,0),run(0,1))
end
M.thickness=thickness
local heightRaw
function M.height(cells,x,z,height,shape)
 if active and cells==memoCells then
  local k=x..':'..z..':'..tostring(height)..':'..tostring(shape and shape.slope)..(shape and shape.bank and 'b' or '')
  local v=heightMemo[k]
  if not v then v=heightRaw(cells,x,z,height,shape);heightMemo[k]=v end
  return v
 end
 return heightRaw(cells,x,z,height,shape)
end
heightRaw=function(cells,x,z,height,shape)
 local cx,cy=math.floor(x/16),math.floor(z/16)
 local slope=shape and shape.slope or M.SLOPE
 local distance,boundary=slope,0
 local low,high=math.huge,-math.huge
 for y=cy-2,cy+2 do for xx=cx-2,cx+2 do
  local c=cells[xx..':'..y]
  if c and not solid(c) then
   local h=c.floorHigh or c.base or 0
   low,high=math.min(low,h),math.max(high,h)
  end
 end end
 local top=height or 32
 if high>-math.huge then
  top=high>low and high or high+top
 end
 local reach=math.ceil(slope/16)
 for y=cy-reach,cy+reach do for xx=cx-reach,cx+reach do
  local c=cells[xx..':'..y]
  if not solid(c)then
   local dx=math.max(xx*16-x,0,x-(xx+1)*16)
   local dz=math.max(y*16-z,0,z-(y+1)*16)
   local d=math.sqrt(dx*dx+dz*dz)
   local h=c.base or 0
   if c.floor and c.floor.high then h=(c.floorHigh or c.floor.high)-(c.floor.high-c.floor.low)*math.max(0,math.min(1,(z-y*16)/16))end
   if d<distance then distance,boundary=d,h
   elseif d==distance then boundary=math.max(boundary,h)end
  end
 end end
 local px,pz=math.floor((x-.001)/16),math.floor((z-.001)/16)
 for yy=pz,math.floor((z+.001)/16) do for xx=px,math.floor((x+.001)/16) do
  local function cap(n)
   if high>-math.huge then return math.max(high>low and high or -math.huge,low+n) end
   return boundary+n
  end
  if M.narrow(cells,xx,yy) then top=math.min(top,cap(M.NARROW))
  else
   local t=thickness(cells,xx,yy)
   if t<=2 then top=math.min(top,cap(M.NARROW*t)) end
  end
 end end
 local t=math.min(1,distance/slope)
 if shape and shape.bank then t=t*t*(3-2*t) else t=math.sqrt(1-(1-t)*(1-t)) end
 return boundary+(top-boundary)*t
end
local waterCache=setmetatable({},{__mode='k'})
waterPatch=function(c,a,b)
 local ts=c.ts;if not (ts and ts.imageData) then return false end
 local t=waterCache[ts];if not t then t={};waterCache[ts]=t end
 local k=c.mid*64+a*4+b/4;if t[k]~=nil then return t[k] end
 local slot=ts.midToSlot[c.mid];if not slot then t[k]=false;return false end
 local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
 local n=0
 for y=b,b+3 do for x=a,a+3 do
  local r,g,bb=ts.imageData:getPixel(ox+x,oy+y)
  if bb>r*1.25 and bb>g*1.05 then n=n+1 end
 end end
 t[k]=n>=10;return t[k]
end
function M.newBuild()active=false;memoCells=false;solidMemo,heightMemo=nil,nil end
local appendRaw
function M.append(cells,c,emit,uvFor)
 if memoCells~=cells then memoCells=cells;solidMemo=setmetatable({},{__mode='k'});heightMemo={} end
 active=true
 local ok,err=pcall(appendRaw,cells,c,emit,uvFor)
 active=false
 if not ok then error(err,0) end
end
appendRaw=function(cells,c,emit,uvFor)
 M.cells=cells
 local x,z=c.cx*16,c.cy*16;local height=c.shape.height or 32
 if c.shape.kind=='caveWall' then height=M.CAVE_FACE end
 local cap=assert(uvFor(c.ts,c.shape.cap or 113));local cliff=assert(uvFor(c.ts,c.shape.side or 121))
 local function sub(uv,a,b,u,v)
  local l,r=uv[1][1],uv[2][1];local t,d=uv[1][2],uv[3][2]
  local function p(xx,zz)return {l+(r-l)*xx/16,t+(d-t)*zz/16}end
  return {p(a,b),p(u,b),p(u,v),p(a,v)}
 end
 for iz=0,3 do for ix=0,3 do
  local a,b=ix*4,iz*4;local u,v=a+4,b+4
  local s=c.shape
  local h1,h2=M.height(cells,x+a,z+b,height,s),M.height(cells,x+u,z+b,height,s)
  local h3,h4=M.height(cells,x+u,z+v,height,s),M.height(cells,x+a,z+v,height,s)
  if s.seaRock and waterPatch(c,a,b) then h1,h2,h3,h4=0,0,0,0 end
  local flat=h1==h2 and h2==h3 and h3==h4 and h1~=0
  local tex
  local shade=flat and 1 or .84
  if s.bank then
   tex=sub(cap,a,b,u,v)
   local steep=(math.abs(h1-h3)+math.abs(h2-h4))/(2*4*math.sqrt(2))
   shade=1-math.min(.22,steep*.12)
  elseif flat then tex=sub(cap,a,b,u,v)
  else
   local alongZ=math.abs(h1-h2)+math.abs(h4-h3)>math.abs(h1-h4)+math.abs(h2-h3)
   local function side(xx,zz,h)
    return {cliff[1][1]+((alongZ and zz or xx)/16)*(cliff[2][1]-cliff[1][1]),
     cliff[1][2]+(1-math.max(0,math.min(1,h/height)))*(cliff[3][2]-cliff[1][2])}
   end
   tex={side(a,b,h1),side(u,b,h2),side(u,v,h3),side(a,v,h4)}
  end
  emit({{x+a,h1,z+b},{x+u,h2,z+b},{x+u,h3,z+v},{x+a,h4,z+v}},tex,shade)
 end end
end
return M
