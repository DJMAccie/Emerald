-- Round roofs for the flat-topped battle tent models: the 1px column model gets a domed top (quarter-circle rise from the rim).
local M={}
-- rise: dome height above the wall top; run: px from the rim to the flat crown
M.MODELS={
 b099_fallarbortown_battletentlobby={rise=18,run=30},
 b010_slateportcity_battletentlobby={rise=18,run=30},
 x_verdanturf_battletent={rise=16,run=22},
}

local function key(f,plane,a,y)return ((f*256+plane+128)*256+a+128)*64+y end

function M.build(q,p)
 local wall,top={},{}
 for i=1,#q,10 do
  local f,x0,x1,h0,h1,z0,z1=q[i],q[i+1],q[i+2],q[i+3],q[i+4],q[i+5],q[i+6]
  if f==3 then
   for x=x0,x1-1 do for z=z0,z1-1 do top[x..':'..z]={x,z,q[i+7],q[i+8],q[i+9],h0} end end
  elseif f==1 or f==2 then
   for x=x0,x1-1 do for y=h0,h1-1 do wall[key(f,z0,x,y)]={q[i+7],q[i+8],q[i+9]} end end
  else
   for z=z0,z1-1 do for y=h0,h1-1 do wall[key(f,x0,z,y)]={q[i+7],q[i+8],q[i+9]} end end
  end
 end
 local rim={}
 for k,c in pairs(top)do
  local x,z=c[1],c[2]
  if not (top[(x-1)..':'..z] and top[(x+1)..':'..z] and top[x..':'..(z-1)] and top[x..':'..(z+1)]) then rim[#rim+1]=c end
 end
 local h={}
 for k,c in pairs(top)do
  local x,z=c[1],c[2]
  local d=math.huge
  for _,r in ipairs(rim)do
   local dx,dz=r[1]-x,r[2]-z
   local e=dx*dx+dz*dz
   if e<d then d=e end
  end
  local t=math.min((math.sqrt(d)+.5)/p.run,1)
  h[k]=c[6]+math.floor(p.rise*math.sqrt(1-(1-t)*(1-t))+.5)
 end
 local out,n={},0
 local function put(f,x0,x1,h0,h1,z0,z1,px,py,sh)
  out[n+1],out[n+2],out[n+3],out[n+4],out[n+5],out[n+6],out[n+7],out[n+8],out[n+9],out[n+10]=f,x0,x1,h0,h1,z0,z1,px,py,sh
  n=n+10
 end
 -- a side with an old painted wall pixel keeps it; the rest uses the column's own roof pixel
 local function side(f,plane,a,lo,hi,c)
  for y=lo,hi-1 do
   local w=wall[key(f,plane,a,y)]
   local px,py,sh
   if w then px,py,sh=w[1],w[2],w[3] else px,py,sh=c[3],c[4],0 end
   if f==1 or f==2 then put(f,a,a+1,y,y+1,plane,plane,px,py,sh)
   else put(f,plane,plane,y,y+1,a,a+1,px,py,sh) end
  end
 end
 for k,c in pairs(top)do
  local x,z,hc=c[1],c[2],h[k]
  put(3,x,x+1,hc,hc,z,z+1,c[3],c[4],c[5])
  local function nb(nx,nz)return h[nx..':'..nz] or 0 end
  if hc>nb(x,z+1) then side(1,z+1,x,nb(x,z+1),hc,c) end
  if hc>nb(x,z-1) then side(2,z,x,nb(x,z-1),hc,c) end
  if hc>nb(x+1,z) then side(4,x+1,z,nb(x+1,z),hc,c) end
  if hc>nb(x-1,z) then side(5,x,z,nb(x-1,z),hc,c) end
 end
 return out
end

return M
