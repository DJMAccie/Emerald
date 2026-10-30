-- Overworld rocks that are actors (map objects), not tiles: the smashable rock (Rock Smash) and the
-- Strength boulder. Drawn as cards they lean and read as paper. Here each one is a body built from its
-- own sprite, one art pixel = one voxel, by the same view-direction placement as Gen3Mass domes and
-- the round trees (NativeTreeArt.lathe):
--   * screen row = depth - height, one pixel per unit, so a point lifted by d and pushed d toward the
--     camera lands on its own sprite row;
--   * a row's depth is a half-disc of that row's own width, capped by the rock's height;
--   * the front shell is the drawing pixel for pixel from the player's camera, the rear shell mirrors it
--     behind, so a turned or low camera sees a solid rock.
-- Frame 0 only (the rock before it breaks); a breaking rock is a field effect and keeps the native path.
local V=...
local R=V.require('Voxel3D')
local M={}

M.GIDS={[86]=true,[87]=true,[59]=true,[88]=true}      -- Emerald graphics ids: smashable rock, strength boulder, item ball
M.BALL_LIFT=1.15                 -- the ball's centre height as a multiple of its radius (the foot is cropped by the oblique rule)
M.BALL={[59]=true}               -- a sphere: as deep as it is wide (round from every side)
M.BULGE=.9                        -- depth as a share of a row's half-width
M.DEPTH=.7                        -- deepest a body may be, as a share of its own height
M.FOOT=2                          -- rows above the ground over which the body grows from nothing

M.FLAT={[88]=true}                -- Mr. Briney's boat: drawn from above, it lies on the water (M.flat), it does not stand
M.FLAT_MIN=3                      -- height of its gunwale (px)
M.FLAT_MAX=11                     -- and of its highest part (the cabin roof)
M.FLAT_RISE=1.3                   -- px of height per px in from the outline
local built={}

local function solid(data,qx,qy,qw,qh,x,y)
 if x<0 or y<0 or x>=qw or y>=qh then return false end
 local ok,_,_,_,a=pcall(data.getPixel,data,qx+x,qy+y)
 return ok and (a or 0)>.5
end

-- A thing drawn from above that lies low and long (a boat): every sprite pixel is a column whose top
-- is that pixel, as high as the pixel is far in from the outline (gunwale low, cabin high), standing
-- where the oblique drawing puts it (screen row = depth - height), so the player's camera sees the
-- drawing and every other camera sees a hull with a deckhouse, not a card.
function M.flat(spr)
 local qx,qy,qw,qh=spr.quads[0]:getViewport()
 local iw,ih=spr.image:getDimensions()
 local data=spr.imageData
 local function on(x,y)return solid(data,qx,qy,qw,qh,x,y) end
 local dist,low={},-1
 for y=0,qh-1 do for x=0,qw-1 do if on(x,y) then dist[y*qw+x]=1e9;if y>low then low=y end else dist[y*qw+x]=0 end end end
 if low<0 then built[spr]=false;return nil end
 local function at(x,y)if x<0 or y<0 or x>=qw or y>=qh then return 0 end;return dist[y*qw+x] end
 for y=0,qh-1 do for x=0,qw-1 do local k=y*qw+x
  if dist[k]>0 then dist[k]=math.min(dist[k],at(x-1,y)+1,at(x,y-1)+1,at(x-1,y-1)+1.4,at(x+1,y-1)+1.4) end
 end end
 for y=qh-1,0,-1 do for x=qw-1,0,-1 do local k=y*qw+x
  if dist[k]>0 then dist[k]=math.min(dist[k],at(x+1,y)+1,at(x,y+1)+1,at(x+1,y+1)+1.4,at(x-1,y+1)+1.4) end
 end end
 local function hgt(x,y)
  local d=at(x,y);if d<=0 then return 0 end
  return math.floor(math.min(M.FLAT_MAX,M.FLAT_MIN+(d-1)*M.FLAT_RISE))
 end
 local v,i={},{}
 local function quad(p,uv,shade)
  local base=#v
  for k,a in ipairs(p)do v[#v+1]={a[1],a[2],a[3],uv[k][1],uv[k][2],shade} end
  for _,k in ipairs({1,2,3,1,3,4})do i[#i+1]=base+k end
 end
 for y=0,qh-1 do for x=0,qw-1 do
  local h=hgt(x,y)
  if h>0 then
   local tu,tv=(qx+x+.5)/iw,(qy+y+.5)/ih
   local t={{tu,tv},{tu,tv},{tu,tv},{tu,tv}}
   -- the pixel's own ground position: rows up from the lowest row, pushed south by its height
   local x0,x1=x-qw/2,x+1-qw/2
   local z1=h-(low-y);local z0=z1-1
   -- (a higher pixel to the south stands further south: this top runs on under its foot)
   local sh=hgt(x,y+1);local ze=sh>h and sh-(low-y) or z1
   quad({{x0,h,z0},{x1,h,z0},{x1,h,ze},{x0,h,ze}},t,1)
   local function side(nx,ny,p,shade)
    local nh=hgt(nx,ny)
    if nh<h then for _,c in ipairs(p)do if c[2]==0 then c[2]=nh end end;quad(p,t,shade) end
   end
   side(x,y+1,{{x0,h,z1},{x1,h,z1},{x1,0,z1},{x0,0,z1}},.85)
   side(x,y-1,{{x1,h,z0},{x0,h,z0},{x0,0,z0},{x1,0,z0}},.6)
   side(x-1,y,{{x0,h,z0},{x0,h,z1},{x0,0,z1},{x0,0,z0}},.7)
   side(x+1,y,{{x1,h,z1},{x1,h,z0},{x1,0,z0},{x1,0,z1}},.78)
  end
 end end
 local mesh=#v>0 and R.newMesh(v,i) or nil
 built[spr]=mesh or false
 return mesh
end

-- An item ball is a true sphere, a body of revolution: R from the drawing's size, resting on the ground,
-- touching the card plane in front. Its bands are the sprite's rows (colour read down a column at the
-- ball's side, clear of the outline and the button); the button's own pixels are kept on the face that
-- looks at the player's camera. Round from every yaw and from the low camera.
M.SEG=28
M.BAND=.16            -- half-height of the black band, as a share of R
M.SUB=3             -- latitude steps per drawing row (the body bends smoothly, the colour stays the row's)
M.BALL_Z=.2         -- share of R the centre stands behind the card plane
function M.sphere(spr,qx,qy,qw,qh,top,low,x0,x1)
 local data,iw,ih=spr.imageData,spr.image:getDimensions()
 local W,H=x1-x0,low-top+1
 local Rr=(W+H)/4
 local cxs=(x0+x1)/2
 local v,i={},{}
 local function rowSpan(row)
  local l,r
  for x=x0,x1-1 do if solid(data,qx,qy,qw,qh,x,row) then l=l or x;r=x end end
  return l,r
 end
 local function pt(h,a)
  local c=math.max(-1,math.min(1,(h-Rr)/Rr))
  local ring=math.sqrt(1-c*c)
  return {Rr*ring*math.sin(a),h,-Rr*M.BALL_Z+Rr*ring*math.cos(a)},{ring*math.sin(a),c,ring*math.cos(a)}
 end
 -- three flat colours read from the drawing (red top, white bottom, black band), whatever the row
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
   local sn=math.sin(am)
   local qx_,qy_=px,py
   if math.cos(am)>0 then   -- the button: a black ring round a grey centre, on the face that looks at the camera
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
 if M.FLAT[n] then return M.flat(spr) end
 local qx,qy,qw,qh=spr.quads[0]:getViewport()
 local iw,ih=spr.image:getDimensions()
 local data=spr.imageData
 -- the lowest and highest opaque rows: the rock stands on its lowest row
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
 local function depth(k,px)       -- depth of the body at boundary k (above row k) and pixel position px
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
 -- An item ball is a sphere, not a rock: both shells lie on one ellipsoid, found per sprite pixel on the plane
 -- y-z=up (the oblique rule), so every pixel still lands on its own row from the player's camera; the
 -- ellipsoid is as wide as the ball is, as high as deep.
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
    -- one strip per run of pixels, kept short so the body bends smoothly
    while e<sp.r and e-x<(ball and 1 or 2) and solid(data,qx,qy,qw,qh,e,y) do e=e+1 end
    local u0,u1=(qx+x)/iw,(qx+e)/iw
    local t0,t1=(qy+y)/ih,(qy+y+1)/ih
    local uv={{u0,t0},{u1,t0},{u1,t1},{u0,t1}}
    for _,sign in ipairs({1,-1})do
     local ax,ay,az=point(x,y,sign);local bx,by,bz=point(e,y,sign)
     local cx,cy,cz=point(e,y+1,sign);local dx,dy,dz=point(x,y+1,sign)
     quad({{ax,ay,az},{bx,by,bz},{cx,cy,cz},{dx,dy,dz}},uv,sign>0 and 1 or .7)
    end
    -- nothing above: close the top between the shells with the pixel's own colour
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
function M.release()
 for _,m in pairs(built)do if m and m.release then pcall(m.release,m) end end
 built={}
end
return M
