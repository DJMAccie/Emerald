-- Overworld rocks that are actors
local V=...
local R=V.require('Voxel3D')
local M={}

M.GIDS={[86]=true,[87]=true,[59]=true,[88]=true}
M.BALL_LIFT=1.15
M.BALL={[59]=true}
M.BULGE=.9 -- depth as a share of a row's half-width
M.DEPTH=.7
M.FOOT=2

M.BOAT={[88]=true}
M.BOAT_STEM=-26.5
M.BOAT_STERN=1.5
M.BOAT_FLOOR=2.2 -- cockpit sole above the waterline
M.BOAT_RIM=1.5
M.BOAT_FLARE=.45 -- how far the topsides lean out at the gunwale
M.BOAT_WELL=-24.5
M.BOAT_HB={
 {-26.5,.55},{-26,1.5},{-25,2.9},{-24,4.1},{-23,5.2},{-22,6.1},{-21,6.9},{-20,7.6},
 {-18.5,8.4},{-17,9.0},{-15,9.5},{-12,9.85},{-8,10},{-4,10},{-1,9.8},{.5,9.2},{1.5,8.4}}
M.BOAT_SHEER={
 {-26.5,7.0},{-24,6.6},{-21,6.15},{-17,5.75},{-12,5.4},{-6,5.2},{0,5.1},{1.5,5.15}}
M.BOAT_CAB={z0=-20.0,z1=-10.0,half=6.6,top=10.4,win0=7.1,win1=9.9}
M.BOAT_MAST={z0=-12.2,z1=-11.4,top=17.0}
M.BOAT_BENCH={{-21.8,-20.8},{-2.4,1.05}} -- thwarts, north edge to south edge
local built={}

local function solid(data,qx,qy,qw,qh,x,y)
 if x<0 or y<0 or x>=qw or y>=qh then return false end
 local ok,_,_,_,a=pcall(data.getPixel,data,qx+x,qy+y)
 return ok and (a or 0)>.5
end

local function curve(t,v)
 if v<=t[1][1] then return t[1][2] end
 for n=2,#t do
  local a,b=t[n-1],t[n]
  if v<=b[1] then local f=(v-a[1])/(b[1]-a[1]);f=f*f*(3-2*f);return a[2]+(b[2]-a[2])*f end
 end
 return t[#t][2]
end

function M.boat(spr)
 if not (spr and spr.image and spr.imageData and spr.quads and spr.quads[0]) then return nil end
 local _,_,qw,qh=spr.quads[0]:getViewport()
 local iw,ih=spr.image:getDimensions()
 local data=spr.imageData
 local pts={}
 local function scan(y0,y1)
  for y=y0,y1 do for x=0,iw-1 do
   local ok,r,g,b,a=pcall(data.getPixel,data,x,y)
   if ok and (a or 0)>.5 then pts[#pts+1]={x,y,r*255,g*255,b*255} end
  end end
 end
 scan(0,math.min(ih,3*(qh or ih))-1)
 if #pts==0 then scan(0,ih-1) end
 local found={}
 local function tex(r,g,b)
  local k=r..','..g..','..b
  local hit=found[k]
  if hit then return hit[1],hit[2] end
  local best,bd
  for _,c in ipairs(pts) do
   local d=(c[3]-r)^2+(c[4]-g)^2+(c[5]-b)^2
   if not bd or d<bd then best,bd=c,d end
  end
  if not best then return .5,.5 end
  local u,v=(best[1]+.5)/iw,(best[2]+.5)/ih
  found[k]={u,v}
  return u,v
 end
 local function col(r,g,b) local u,v=tex(r,g,b) return {u,v} end
 local C={
  boot=col(0,0,0),        bottom=col(148,58,41),   hull=col(206,206,222), rail=col(74,74,123),
  rim=col(255,255,255),   inner=col(206,206,222),  deck=col(255,255,255), hullBot=col(82,16,0),
  wood1=col(255,197,148), wood2=col(222,148,115),  bench=col(148,58,41),  benchHi=col(206,99,74),
  dark=col(82,16,0),      wall=col(255,255,255),   roof=col(206,206,222), pane=col(156,156,189),
  mull=col(74,74,123),    mast=col(74,74,123)}
 local v,i={},{}
 local function flat(p,c,sh)
  local base=#v
  for k=1,4 do v[#v+1]={p[k][1],p[k][2],p[k][3],c[1],c[2],sh} end
  for _,k in ipairs({1,2,3,1,3,4}) do i[#i+1]=base+k end
 end
 local stem,stern=M.BOAT_STEM,M.BOAT_STERN
 local FLOOR,RIM,FL=M.BOAT_FLOOR,M.BOAT_RIM,M.BOAT_FLARE
 local function HB(z) return curve(M.BOAT_HB,z) end
 local function SH(z) return curve(M.BOAT_SHEER,z) end
 local SHADE={top=1,south=.95,north=.78,east=.90,west=.86}
 local function wall(z0,z1,xb0,xb1,xt0,xt1,yb0,yb1,yt0,yt1,c,sh)
  flat({{xb0,yb0,z0},{xb1,yb1,z1},{xt1,yt1,z1},{xt0,yt0,z0}},c,sh)
 end
 for z=stem,stern-1 do
  local z0,z1=z,z+1
  local b0,b1,s0,s1=HB(z0),HB(z1),SH(z0),SH(z1)
  local t0,t1=b0+FL,b1+FL -- half beam at the gunwale (the topsides flare)
  local m0,m1=b0+FL*.35,b1+FL*.35 -- where the topsides meet the bottom paint
  local i0,i1=t0-RIM,t1-RIM -- the inside of the hull
  local open=z>=M.BOAT_WELL-1e-6
  for _,sg in ipairs({1,-1}) do
   local sh=sg>0 and SHADE.east or SHADE.west
   wall(z0,z1,sg*b0,sg*b1, sg*b0,sg*b1, -1.0,-1.0, .55,.55, C.boot,sh)
   wall(z0,z1,sg*b0,sg*b1, sg*m0,sg*m1, .55,.55, 2.0,2.0, C.bottom,sh)
   wall(z0,z1,sg*m0,sg*m1, sg*t0,sg*t1, 2.0,2.0, s0-1.0,s1-1.0, C.hull,sh)
   wall(z0,z1,sg*t0,sg*t1, sg*t0,sg*t1, s0-1.0,s1-1.0, s0,s1, C.rail,sh)
   if open then
    flat({{sg*t0,s0,z0},{sg*i0,s0,z0},{sg*i1,s1,z1},{sg*t1,s1,z1}},C.rim,1)
    wall(z0,z1,sg*i0,sg*i1, sg*i0,sg*i1, FLOOR,FLOOR, s0,s1, C.inner,sh)
   end
  end
  if open then
   local half=(i0+i1)/2
   if half>.25 then
    for x=math.ceil(-half),math.floor(half)-1 do
     local xa,xb=math.max(x,-half),math.min(x+1,half)
     if xb-xa>.02 then
      flat({{xa,FLOOR,z0},{xb,FLOOR,z0},{xb,FLOOR,z1},{xa,FLOOR,z1}},x%2==0 and C.wood1 or C.wood2,1)
     end
    end
   end
  else
   flat({{-t0,s0,z0},{t0,s0,z0},{t1,s1,z1},{-t1,s1,z1}},C.deck,1)
  end
  flat({{-b0,-1.0,z0},{b0,-1.0,z0},{b1,-1.0,z1},{-b1,-1.0,z1}},C.hullBot,.6)
 end
 do
  local bW,sW=HB(M.BOAT_WELL)+FL-RIM,SH(M.BOAT_WELL)
  flat({{-bW,FLOOR,M.BOAT_WELL},{bW,FLOOR,M.BOAT_WELL},{bW,sW,M.BOAT_WELL},{-bW,sW,M.BOAT_WELL}},C.inner,.8)
 end
 do
  local bs,ss=HB(stern),SH(stern)
  local ts,ms=bs+FL,bs+FL*.35
  wall(stern,stern,-bs,bs, -bs,bs, 0,0, .55,.55, C.boot,SHADE.south)
  wall(stern,stern,-bs,bs, -ms,ms, .55,.55, 2.0,2.0, C.bottom,SHADE.south)
  wall(stern,stern,-ms,ms, -ts,ts, 2.0,2.0, ss-1.0,ss-1.0, C.hull,SHADE.south)
  wall(stern,stern,-ts,ts, -ts,ts, ss-1.0,ss-1.0, ss,ss, C.rail,SHADE.south)
  local bi=ts-RIM
  flat({{bi,FLOOR,stern-.45},{-bi,FLOOR,stern-.45},{-bi,ss,stern-.45},{bi,ss,stern-.45}},C.inner,.85)
  flat({{-bi,ss,stern-.45},{bi,ss,stern-.45},{ts,ss,stern},{-ts,ss,stern}},C.rim,1)
  for n=-1,1 do
   local x0=n*3.4-.85
   flat({{x0,.85,stern+.05},{x0+1.7,.85,stern+.05},{x0+1.7,1.55,stern+.05},{x0,1.55,stern+.05}},C.dark,.75)
  end
 end
 do
  local z0,z1,half,top=M.BOAT_CAB.z0,M.BOAT_CAB.z1,M.BOAT_CAB.half,M.BOAT_CAB.top
  local w0,w1=M.BOAT_CAB.win0,M.BOAT_CAB.win1
  local f=.8
  local function band(a0,a1,emit)
   local s0,s1=a0+f,a1-f
   local m1=s0+(s1-s0)/3-.14
   local m2=s0+(s1-s0)*2/3-.14
   emit(a0,a0+f,C.wall)
   emit(s0,m1,C.pane);emit(m1,m1+.28,C.mull)
   emit(m1+.28,m2,C.pane);emit(m2,m2+.28,C.mull)
   emit(m2+.28,s1,C.pane)
   emit(a1-f,a1,C.wall)
  end
  for _,sg in ipairs({1,-1}) do
   local x=sg*half
   local sh=sg>0 and SHADE.east or SHADE.west
   flat({{x,FLOOR,z0},{x,FLOOR,z1},{x,w0,z1},{x,w0,z0}},C.wall,sh)
   band(z0,z1,function(a,b,c) flat({{x,w0,a},{x,w0,b},{x,w1,b},{x,w1,a}},c,sh) end)
   flat({{x,w1,z0},{x,w1,z1},{x,top-.3,z1},{x,top-.3,z0}},C.wall,sh)
   flat({{x,top-.3,z0},{x,top-.3,z1},{x,top,z1},{x,top,z0}},C.mull,sh)
  end
  for _,zf in ipairs({z0,z1}) do
   local sh=zf==z1 and SHADE.south or SHADE.north
   flat({{-half,FLOOR,zf},{half,FLOOR,zf},{half,w0,zf},{-half,w0,zf}},C.wall,sh)
   band(-half,half,function(a,b,c) flat({{a,w0,zf},{b,w0,zf},{b,w1,zf},{a,w1,zf}},c,sh) end)
   flat({{-half,w1,zf},{half,w1,zf},{half,top-.3,zf},{-half,top-.3,zf}},C.wall,sh)
   flat({{-half,top-.3,zf},{half,top-.3,zf},{half,top,zf},{-half,top,zf}},C.mull,sh)
  end
  local ov=.35
  local ry=top+.3
  flat({{-half-ov,ry,z0-ov},{half+ov,ry,z0-ov},{half+ov,ry,z1+ov},{-half-ov,ry,z1+ov}},C.roof,1)
  flat({{-half-ov,top,z0-ov},{half+ov,top,z0-ov},{half+ov,ry,z0-ov},{-half-ov,ry,z0-ov}},C.wall,SHADE.north)
  flat({{half+ov,top,z1+ov},{-half-ov,top,z1+ov},{-half-ov,ry,z1+ov},{half+ov,ry,z1+ov}},C.wall,SHADE.south)
  flat({{half+ov,top,z0-ov},{half+ov,top,z1+ov},{half+ov,ry,z1+ov},{half+ov,ry,z0-ov}},C.wall,SHADE.east)
  flat({{-half-ov,top,z1+ov},{-half-ov,top,z0-ov},{-half-ov,ry,z0-ov},{-half-ov,ry,z1+ov}},C.wall,SHADE.west)
 end
 do -- the mast, stepped on the roof, with its yard
  local z0,z1,top=M.BOAT_MAST.z0,M.BOAT_MAST.z1,M.BOAT_MAST.top
  local base=M.BOAT_CAB.top+.3 -- the wheelhouse roof slab's top
  local mx=.5
  flat({{-mx,base,z0},{mx,base,z0},{mx,top,z0},{-mx,top,z0}},C.mast,SHADE.north)
  flat({{mx,base,z1},{-mx,base,z1},{-mx,top,z1},{mx,top,z1}},C.mast,SHADE.south)
  flat({{mx,base,z0},{mx,base,z1},{mx,top,z1},{mx,top,z0}},C.mast,SHADE.east)
  flat({{-mx,base,z1},{-mx,base,z0},{-mx,top,z0},{-mx,top,z1}},C.mast,SHADE.west)
  flat({{-mx,top,z0},{mx,top,z0},{mx,top,z1},{-mx,top,z1}},C.mast,SHADE.top)
  local y0,y1=top-1.0,top-.5
  flat({{-1.5,y0,z0},{1.5,y0,z0},{1.5,y1,z0},{-1.5,y1,z0}},C.mast,SHADE.north)
  flat({{1.5,y0,z1},{-1.5,y0,z1},{-1.5,y1,z1},{1.5,y1,z1}},C.mast,SHADE.south)
  flat({{-1.5,y1,z0},{1.5,y1,z0},{1.5,y1,z1},{-1.5,y1,z1}},C.mast,SHADE.top)
  flat({{-1.5,y0,z1},{1.5,y0,z1},{1.5,y0,z0},{-1.5,y0,z0}},C.mast,.8)
  flat({{1.5,y0,z0},{1.5,y0,z1},{1.5,y1,z1},{1.5,y1,z0}},C.mast,SHADE.east)
  flat({{-1.5,y0,z1},{-1.5,y0,z0},{-1.5,y1,z0},{-1.5,y1,z1}},C.mast,SHADE.west)
 end
 for _,bn in ipairs(M.BOAT_BENCH) do -- the thwarts: a dark red seat with a lit edge
  local za,zb=bn[1],bn[2]
  local bw=math.min(HB(za),HB(zb))+FL-RIM-.15
  local yt=FLOOR+1.5
  flat({{-bw,yt,za},{bw,yt,za},{bw,yt,zb},{-bw,yt,zb}},C.bench,1)
  flat({{-bw,yt,za},{bw,yt,za},{bw,FLOOR,za},{-bw,FLOOR,za}},C.bench,SHADE.north)
  flat({{bw,yt,zb},{-bw,yt,zb},{-bw,FLOOR,zb},{bw,FLOOR,zb}},C.benchHi,SHADE.south)
  flat({{-bw,yt,zb},{-bw,yt,za},{-bw,FLOOR,za},{-bw,FLOOR,zb}},C.bench,.72)
  flat({{bw,yt,za},{bw,yt,zb},{bw,FLOOR,zb},{bw,FLOOR,za}},C.bench,.82)
 end
 local mesh=#v>0 and R.newMesh(v,i) or nil
 built[spr]=mesh or false
 return mesh
end

M.SEG=28
M.BAND=.16 -- half-height of the black band, as a share of R
M.SUB=3
M.BALL_Z=.2 -- share of R the centre stands behind the card plane
function M.sphere(spr,qx,qy,qw,qh,top,low,x0,x1)
 local data,iw,ih=spr.imageData,spr.image:getDimensions()
 local W,H=x1-x0,low-top+1
 local Rr=(W+H)/4
 local v,i={},{}
 local function pt(h,a)
  local c=math.max(-1,math.min(1,(h-Rr)/Rr))
  local ring=math.sqrt(1-c*c)
  return {Rr*ring*math.sin(a),h,-Rr*M.BALL_Z+Rr*ring*math.cos(a)},{ring*math.sin(a),c,ring*math.cos(a)}
 end
 local function find(rf,gf,bf)
  for y=top,low do for x=x0,x1-1 do
   local ok,cr,cg,cb=pcall(data.getPixel,data,qx+x,qy+y)
   if ok and solid(data,qx,qy,qw,qh,x,y) and rf(cr*255) and gf(cg*255) and bf(cb*255) then return x,y end
  end end
 end
 local rx,ry=find(function(r)return r>130 and r<170 end,function(g)return g>40 and g<75 end,function(b)return b>25 and b<60 end)
 local wx,wy=find(function(r)return r>250 end,function(g)return g>250 end,function(b)return b>250 end)
 local kx,ky=find(function(r)return r<8 end,function(g)return g<8 end,function(b)return b<8 end)
 local gx,gy=find(function(r)return r>140 and r<170 end,function(g)return g>140 and g<170 end,function(b)return b>170 end)
 local function uv(x,y)return (qx+x+.5)/iw,(qy+y+.5)/ih end
 local steps=H*M.SUB
 for st=0,steps-1 do
  local h0,h1=st*2*Rr/steps,(st+1)*2*Rr/steps
  local hm=(h0+h1)/2
  local c=(hm-Rr)/Rr
  local px,py
  if c>M.BAND then px,py=rx,ry elseif c<-M.BAND then px,py=wx,wy else px,py=kx,ky end
  for s=0,M.SEG-1 do
   local a0,a1=s*2*math.pi/M.SEG,(s+1)*2*math.pi/M.SEG
   local am=(a0+a1)/2
   local qx_,qy_=px,py
   if math.cos(am)>0 then
    local bx,by=Rr*math.sin(am)*math.sqrt(1-c*c),hm-Rr
    local d=math.sqrt(bx*bx+by*by)
    if d<Rr*.13 then qx_,qy_=gx,gy elseif d<Rr*.25 then qx_,qy_=kx,ky end
   end
   local P={pt(h0,a0),pt(h0,a1),pt(h1,a1),pt(h1,a0)}
   local _,n=pt(hm,am)
   local sh=(1.04+.1*n[2]+.05*n[3])*(c>M.BAND and 1.25 or 1)
   local u,t=uv(qx_,qy_)
   local base=#v
   for q=1,4 do v[#v+1]={P[q][1],P[q][2],P[q][3],u,t,sh} end
   for _,k in ipairs({1,2,3,1,3,4})do i[#i+1]=base+k end
  end
 end
 return #v>0 and R.newMesh(v,i) or nil
end
function M.mesh(gid,spr)
 local n=tonumber(gid)
 if not (n and M.GIDS[n] and spr and spr.imageData and spr.image and spr.quads and spr.quads[0]) then return nil end
 local hit=built[spr]
 if hit~=nil then return hit or nil end
 if M.BOAT[n] then return M.boat(spr) end
 local qx,qy,qw,qh=spr.quads[0]:getViewport()
 local iw,ih=spr.image:getDimensions()
 local data=spr.imageData
 local top,low=qh,-1
 for y=0,qh-1 do for x=0,qw-1 do if solid(data,qx,qy,qw,qh,x,y) then if y<top then top=y end;if y>low then low=y end end end end
 if low<0 then built[spr]=false;return nil end
 local height=low-top+1
 local rows={}
 for y=top,low do
  local l,r
  for x=0,qw-1 do if solid(data,qx,qy,qw,qh,x,y) then l=l or x;r=x end end
  if l then rows[y]={l=l,r=r+1,cx=(l+r+1)/2,rad=(r-l+1)/2} end
 end
 local ball=M.BALL[n]
 if ball then
  local x0,x1=qw,-1
  for y=top,low do local sp=rows[y];if sp then if sp.l<x0 then x0=sp.l end;if sp.r>x1 then x1=sp.r end end end
  local m=M.sphere(spr,qx,qy,qw,qh,top,low,x0,x1)
  built[spr]=m or false
  return m
 end
 local cap=height*(ball and 1 or M.DEPTH)
 local bulge=ball and 1 or M.BULGE
 local function depth(k,px)
  local sum,cnt=0,0
  for _,row in ipairs({k-1,k})do
   local sp=rows[row]
   if sp and px>=sp.l and px<=sp.r then
    local t=(px-sp.cx)/sp.rad
    sum=sum+math.min(cap,sp.rad*bulge*math.sqrt(math.max(0,1-t*t)));cnt=cnt+1
   elseif sp then cnt=cnt+1 end
  end
  if cnt==0 then return 0 end
  local up=low+1-k
  return sum/cnt*math.min(1,up/(ball and 2 or M.FOOT))
 end
 local sphere
 if ball then
  local x0,x1=qw,-1
  for y=top,low do local sp=rows[y];if sp then if sp.l<x0 then x0=sp.l end;if sp.r>x1 then x1=sp.r end end end
  local a=(x1-x0)/2
  local B=height/(2*math.sqrt(2))
  local yc=B*M.BALL_LIFT
  sphere={cx=(x0+x1)/2,a=a,B=B,yc=yc}
 end
 local function ballPoint(px,k,sign)
  local up=low+1-k
  local u=px-sphere.cx
  local Q=sphere.B^2*(1-math.min(1,(u/sphere.a)^2))
  local w=up-sphere.yc
  local disc=2*Q-w*w
  local z=-w/2
  if disc>0 then z=z+sign*math.sqrt(disc)/2 end
  local y=up+z
  if y<0 then y=0 end
  return px-qw/2,y,z
 end
 local v,i={},{}
 local function quad(p,uv,shade)
  local base=#v
  for k,a in ipairs(p)do v[#v+1]={a[1],a[2],a[3],uv[k][1],uv[k][2],shade} end
  for _,k in ipairs({1,2,3,1,3,4})do i[#i+1]=base+k end
 end
 local function point(px,k,sign)
  if sphere then return ballPoint(px,k,sign) end
  local d=depth(k,px)
  local up=low+1-k
  local y=up+sign*d
  if y<0 then y=0 end
  return px-qw/2,y,sign*d
 end
 for y=top,low do
  local sp=rows[y]
  local x=sp.l
  while x<sp.r do
   if solid(data,qx,qy,qw,qh,x,y) then
    local e=x+1
    while e<sp.r and e-x<(ball and 1 or 2) and solid(data,qx,qy,qw,qh,e,y) do e=e+1 end
    local u0,u1=(qx+x)/iw,(qx+e)/iw
    local t0,t1=(qy+y)/ih,(qy+y+1)/ih
    local uv={{u0,t0},{u1,t0},{u1,t1},{u0,t1}}
    for _,sign in ipairs({1,-1})do
     local ax,ay,az=point(x,y,sign);local bx,by,bz=point(e,y,sign)
     local cx,cy,cz=point(e,y+1,sign);local dx,dy,dz=point(x,y+1,sign)
     quad({{ax,ay,az},{bx,by,bz},{cx,cy,cz},{dx,dy,dz}},uv,sign>0 and 1 or .7)
    end
    if not solid(data,qx,qy,qw,qh,x,y-1) or not solid(data,qx,qy,qw,qh,e-1,y-1) then
     local ax,ay,az=point(x,y,1);local bx,by,bz=point(e,y,1)
     local cx,cy,cz=point(e,y,-1);local dx,dy,dz=point(x,y,-1)
     local tu,tv=(qx+x+.5)/iw,(qy+y+.5)/ih
     quad({{ax,ay,az},{bx,by,bz},{cx,cy,cz},{dx,dy,dz}},{{tu,tv},{tu,tv},{tu,tv},{tu,tv}},.95)
    end
    x=e
   else x=x+1 end
  end
 end
 local mesh=#v>0 and R.newMesh(v,i) or nil
 built[spr]=mesh or false
 return mesh
end
return M
