-- Route 110's Seaside Cycling Road as a real raised road
local M={}

M.H_FACE=32 -- slab thickness: 0x30A over 0x312
M.H_LEG=16 -- leg height: half a tile in each of two tiles

local function set(list)local t={};for _,m in ipairs(list)do t[m]=true end;return t end
M.DECK=set({0x2C5,0x2C6,0x2CE,0x2D5,0x2D6,0x2DD,0x2E5,0x2E6,0x2F5,0x2F6,0x2F7,0x2FA,0x2FB,0x2FD,0x2FE,0x2FF,0x302,
 0x3EB,0x3EC,0x3ED})
M.SEA=set({0x2E7,0x2EF,0x2F0,0x2F1,0x2F2,0x2F3,0x2F4,0x2F8,0x2FC,0x300,0x304,0x306,0x307,0x308,0x309,0x30A,0x30B,
 0x30C,0x30D,0x30E,0x30F,0x310,0x311,0x312,0x313,0x314,0x315,0x317,0x31C,0x31D,0x31E,0x31F,0x324,0x325,0x326,0x327,
 0x328,0x329,0x32A,0x32B,0x32C,0x32D,0x330,0x331,0x332,0x333,0x334,0x335,0x336,0x337,0x338,0x339,0x33A,0x33B,0x33C,
 0x33D,0x33F,0x340,0x341,0x342,0x343,0x344,0x345,0x346,0x347,0x348,0x349,0x34A,0x34B,0x34F,0x361,0x362,0x371,0x372,
 0x171})
M.LAND=set({0x34C,0x350,0x351,0x352,0x353,0x354,0x355,0x356,0x357,0x358,0x359,0x35A,0x35B,0x35C,0x35D,0x35E,
 0x35F,0x360,0x363,0x364,0x367,0x368,0x369,0x36A,0x36B,0x370,0x373,0x379,0x37B,
 0x36E,0x36F,
 0x3AA,0x3AB})
M.TREE=set({0x36C,0x36D,0x374,0x375,0x376,0x377,0x37C,0x37D,0x37E})
M.LEG={[0x308]={1,6},[0x30C]={1,14},[0x315]={2,13},[0x340]={1,6},[0x341]={9,14},[0x342]={1,6},[0x343]={9,14},
 [0x354]={2,13},[0x360]={1,6},[0x363]={9,14}}
M.SEA_MID=0x170
M.GRASS_MID=0x001
M.EDGE_MID=0x30A
M.BEAM_MID=0x312
M.RAIL_MID=0x2E5 -- deck edge cell with the rail drawn along it
M.RAIL_H=10

local function sub(uv,x0,y0,x1,y1)
 local l,t,r,b=uv[1][1],uv[1][2],uv[3][1],uv[3][2]
 local u0,u1=l+(r-l)*x0/16,l+(r-l)*x1/16
 local v0,v1=t+(b-t)*y0/16,t+(b-t)*y1/16
 return {{u0,v0},{u1,v0},{u1,v1},{u0,v1}}
end

local function road(n)return n and n.shape and n.shape.cyclingRoad end
local function isDeck(n)return n and (n.stairs or (n.shape and n.shape.cyclingRoad=='deck'))end

local function groundOf(c,cells)
 -- The abutments on either side encode the surface hidden by the three deck tiles.
 if isDeck(c) then
  for dx=-3,3 do
   local edge=cells[(c.cx+dx)..':'..c.cy]
   if edge and road(edge)=='land' then return 'grass' end
  end
 end
 local sea,grass=0,0
 for dy=-2,2 do for dx=-2,2 do local n=cells[(c.cx+dx)..':'..(c.cy+dy)]
  if n and n.shape and (not road(n) or n.mid==0x3AA or n.mid==0x3AB) then
   local rock=n.shape.seaRock or n.shape.sea or n.shape.bank or n.shape.kind=='cliff'
   if n.shape.kind=='water' or rock then sea=sea+1 elseif n.shape.kind~='tree' then grass=grass+1 end
  end
 end end
 if c.shape.cyclingRoad=='land' then return 'grass' end
 return grass>sea and 'grass' or 'sea'
end

local function ground(c,cells,ts,q,uvFor)
 local base=c.base or 0
 if groundOf(c,cells)=='sea' then
  local uv=uvFor(ts,M.SEA_MID);local h=.05-base;local x,z=c.cx*16,c.cy*16
  q.water({{x,h,z},{x+16,h,z},{x+16,h,z+16},{x,h,z+16}},uv,1)
 else
  local uv=uvFor(ts,M.GRASS_MID);local h=-base;local x,z=c.cx*16,c.cy*16
  ;(q.ground or q.solid)({{x,h,z},{x+16,h,z},{x+16,h,z+16},{x,h,z+16}},uv,1)
 end
end

local function face(q,ax,az,bx,bz,y1,edge,beam,shade)
 q.solid({{ax,y1,az},{bx,y1,bz},{bx,y1-16,bz},{ax,y1-16,az}},edge,shade)
 q.solid({{ax,y1-16,az},{bx,y1-16,bz},{bx,y1-32,bz},{ax,y1-32,az}},beam,shade)
end

local function deck(c,cells,ts,q,uvFor)
 local x,z=c.cx*16,c.cy*16;local base=c.base or 0
 q.solid({{x,0,z},{x+16,0,z},{x+16,0,z+16},{x,0,z+16}},uvFor(ts,c.mid),1)
 local edge,beam=uvFor(ts,M.EDGE_MID),uvFor(ts,M.BEAM_MID)
 local function open(dx,dz)
  local n=cells[(c.cx+dx)..':'..(c.cy+dz)]
  return not (isDeck(n) and (n.base or 0)>=base-1)
 end
 if open(0,1) then face(q,x,z+16,x+16,z+16,0,edge,beam,.82) end
 if open(0,-1) then face(q,x+16,z,x,z,0,edge,beam,.62) end
 if open(-1,0) then face(q,x,z,x,z+16,0,edge,beam,.7) end
 if open(1,0) then face(q,x+16,z+16,x+16,z,0,edge,beam,.7) end
 local function swatch(mid,px,py)
  local t=uvFor(ts,mid);if not t then return end
  local u=t[1][1]+(t[2][1]-t[1][1])*(px+.5)/16
  local v=t[1][2]+(t[3][2]-t[1][2])*(py+.5)/16
  return {{u,v},{u,v},{u,v},{u,v}}
 end
 local post=swatch(M.RAIL_MID,1,1) or edge
 local rail=swatch(M.EDGE_MID,8,1) or edge
 local function box(x0,y0,z0,x1,y1,z1,t,sh)
  q.solid({{x0,y1,z0},{x1,y1,z0},{x1,y1,z1},{x0,y1,z1}},t,1)
  q.solid({{x0,y1,z1},{x1,y1,z1},{x1,y0,z1},{x0,y0,z1}},t,.86*sh)
  q.solid({{x1,y1,z0},{x0,y1,z0},{x0,y0,z0},{x1,y0,z0}},t,.66*sh)
  q.solid({{x0,y1,z0},{x0,y1,z1},{x0,y0,z1},{x0,y0,z0}},t,.74*sh)
  q.solid({{x1,y1,z1},{x1,y1,z0},{x1,y0,z0},{x1,y0,z1}},t,.78*sh)
 end
 local R=M.RAIL_H
 local function railing(ax,az,bx,bz)
  local alongX=az==bz
  local len=alongX and math.abs(bx-ax) or math.abs(bz-az)
  local lx,lz=math.min(ax,bx),math.min(az,bz)
  for t=0,len-1,4 do
   if alongX then box(lx+t+1,0,az-.75,lx+t+2,R,az+.75,post,1)
   else box(ax-.75,0,lz+t+1,ax+.75,R,lz+t+2,post,1) end
  end
  for _,y in ipairs({R-1.5,R*.45})do
   if alongX then box(lx,y,az-.6,lx+len,y+1.5,az+.6,rail,1)
   else box(ax-.6,y,lz,ax+.6,y+1.5,lz+len,rail,1) end
  end
 end
 if open(0,1) then railing(x,z+15,x+16,z+15) end
 if open(0,-1) then railing(x,z+1,x+16,z+1) end
 if open(-1,0) then railing(x+1,z,x+1,z+16) end
 if open(1,0) then railing(x+15,z,x+15,z+16) end
 local u=-M.H_FACE
 q.solid({{x,u,z+16},{x+16,u,z+16},{x+16,u,z},{x,u,z}},beam,.5)
 ground(c,cells,ts,q,uvFor)
end

local function leg(c,cells,ts,q,uvFor)
 local cols=M.LEG[c.mid];if not cols then return end
 local base=c.base or 0
 local found,dir
 for k=1,4 do
  for _,d in ipairs({{0,-1},{-1,0},{1,0},{0,1}})do
   local n=cells[(c.cx+d[1]*k)..':'..(c.cy+d[2]*k)]
   if n and n.shape and n.shape.cyclingRoad=='deck' then found,dir=n,d;break end
  end
  if found then break end
 end
 if not found then return end
 local top=(found.base or 0)-M.H_FACE-base
 local bottom=-base
 local w=cols[2]-cols[1]+1
 local x0,x1,z0,z1
 if dir[2]~=0 then
  x0,x1=c.cx*16+cols[1],c.cx*16+cols[2]+1
  local e=dir[2]<0 and (found.cy+1)*16 or found.cy*16
  if dir[2]<0 then z0,z1=e-w,e else z0,z1=e,e+w end
 else
  local e=dir[1]<0 and (found.cx+1)*16 or found.cx*16
  if dir[1]<0 then x0,x1=e-w,e else x0,x1=e,e+w end
  local zc=c.cy*16+8;z0,z1=zc-w/2,zc+w/2
 end
 local upper=uvFor(ts,c.mid)
 local below=cells[c.cx..':'..(c.cy+1)]
 local lower=below and uvFor(ts,below.mid) or upper
 local tu=sub(upper,cols[1],8,cols[2]+1,16)
 local tl=sub(lower,cols[1],0,cols[2]+1,8)
 local mid=top-(top-bottom)/2
 local function box(y1,y0,t)
  q.solid({{x0,y1,z1},{x1,y1,z1},{x1,y0,z1},{x0,y0,z1}},t,.82)
  q.solid({{x1,y1,z0},{x0,y1,z0},{x0,y0,z0},{x1,y0,z0}},t,.62)
  q.solid({{x0,y1,z0},{x0,y1,z1},{x0,y0,z1},{x0,y0,z0}},t,.7)
  q.solid({{x1,y1,z1},{x1,y1,z0},{x1,y0,z0},{x1,y0,z1}},t,.7)
 end
 box(top,mid,tu);box(mid,bottom,tl)
end

function M.settle(cells)
 for _,c in pairs(cells)do
  local r=c.shape and c.shape.cyclingRoad
  if (r and r~='deck') or (c.shape and c.shape.roadTree) then c.base=0 end
 end
end

function M.append(c,cells,ts,q,uvFor)
 local role=c.shape.cyclingRoad
 if role=='deck' then deck(c,cells,ts,q,uvFor)
 else ground(c,cells,ts,q,uvFor);leg(c,cells,ts,q,uvFor) end
end

return M
