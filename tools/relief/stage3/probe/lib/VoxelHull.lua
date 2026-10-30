-- Closed, greedy-meshed voxel volumes. Organic trees/rocks use intersecting
-- solid masses and native palette samples; sculpture drawings use row hulls.
-- Only boundary faces exist; equal-colour coplanar faces are merged once per
-- template. No billboard anchors, cubes under the object, or per-frame work.
local V=...
local Trees=V and V.require('NativeTreeModels') or dofile((os.getenv('DS_MOD_PATH') or '.')..'/lib/NativeTreeModels.lua')
local Budget=V and V.require("BuildBudget") or {tick=function()end,check=function()end}
local M={}
M.BACK_RATIO=.9
M.INK=180          -- colours darker than this (r+g+b) are outline ink, not leaf body
M.TIER=.3          -- an inflated crown's dark leaf bands sit this share of the depth further in than its lightest leaves
M.LUMP=2.4         -- and its surface swells and dips by up to this many voxels (per seed: no two variants alike)
local NEIGH={{-1,0},{1,0},{0,-1},{0,1}}
function M.build(w,h,sample,step,bottom,depthLimit,organic,family,inflate,taper,seed)
 step=step or 1;bottom=bottom or 0
 local nx,ny=math.ceil(w/step),math.ceil(h/step)
 local depth=w
 local nz=math.ceil(depth/step)
 local vox,paints={},{}
 local foliage,wood,all={},{},{}
 local nativeRows={}
 local function key(x,y,z)return (y*nx+x)*nz+z end
 -- inflate: every pixel is as deep as a pillow is thick at that distance from the drawing's edge (so the
 -- crown rounds off at its top and sides, never a flat lid with a vertical wall). The foot stays flat.
 local halfDepth,relief
 local zr0,zr1,rowK={}, {}, {}
 if inflate then
  local INF=1e9
  local dist={}
  for y=0,ny-1 do local sy=h-1-y*step;for x=0,nx-1 do
   local _,_,_,a=sample(math.min(w-1,x*step+math.floor(step/2)),sy)
   dist[y*nx+x]=(a and a>.5) and INF or 0
  end end
  local function at(x,y)
   if y<0 then return INF end
   if x<0 or x>=nx or y>=ny then return 0 end
   return dist[y*nx+x]
  end
  for y=0,ny-1 do for x=0,nx-1 do local k=y*nx+x
   if dist[k]>0 then dist[k]=math.min(dist[k],at(x-1,y)+3,at(x,y-1)+3,at(x-1,y-1)+4,at(x+1,y-1)+4) end
  end end
  for y=ny-1,0,-1 do for x=nx-1,0,-1 do local k=y*nx+x
   if dist[k]>0 then dist[k]=math.min(dist[k],at(x+1,y)+3,at(x,y+1)+3,at(x+1,y+1)+4,at(x-1,y+1)+4) end
  end end
  local top=0
  for k,d in pairs(dist)do if d<INF and d>top then top=d end end
  local R=math.min(top/3,(depthLimit or 24)/2/step)
  halfDepth=function(x,y)
   local d=math.min(R,math.max(0,dist[y*nx+x]/3-.5))
   return math.sqrt(math.max(0,R*R-(R-d)^2))
  end
  if seed then
   -- A crown is tiers of leaves, not a smooth barrel with the tiers painted on: where the drawing is dark
   -- (the shade under a tier) the surface lies deeper, where it is light it stands out. Brightness is
   -- averaged over 5x5 pixels so the relief is leaf clumps, not pits.
   local lum,lo,hi={},1e9,-1e9
   for y=0,ny-1 do local sy=h-1-y*step;for x=0,nx-1 do
    local r,g,b,a=sample(math.min(w-1,x*step+math.floor(step/2)),sy)
    if a and a>.5 then local l=r+g+b;lum[y*nx+x]=l;if l*255>=M.INK then lo=math.min(lo,l);hi=math.max(hi,l) end end
   end end
   local function hash(a,b,c)local n=math.sin(a*12.9898+b*78.233+c*37.719+seed*4.137)*43758.5453;return n-math.floor(n)end
   local CELL=7
   local function noise(x,y,c)
    local gx,gy=x/CELL,y/CELL;local ix,iy=math.floor(gx),math.floor(gy);local fx,fy=gx-ix,gy-iy
    fx,fy=fx*fx*(3-2*fx),fy*fy*(3-2*fy)
    local p,q=hash(ix,iy,c)+(hash(ix+1,iy,c)-hash(ix,iy,c))*fx,hash(ix,iy+1,c)+(hash(ix+1,iy+1,c)-hash(ix,iy+1,c))*fx
    return (p+(q-p)*fy)*2-1
   end
   relief=function(x,y,depth)
    local sum,n=0,0
    for dy=-2,2 do for dx=-2,2 do
     local xx,yy=x+dx,y+dy
     local l=xx>=0 and xx<nx and yy>=0 and yy<ny and lum[yy*nx+xx]
     if l then sum=sum+math.max(lo,math.min(hi,l));n=n+1 end
    end end
    local t=(n>0 and hi>lo) and (sum/n-lo)/(hi-lo) or 1
    local edge=math.min(1,depth/5)
    return depth*(1-M.TIER*(1-t))+noise(x,y,1)*M.LUMP*edge,depth*M.BACK_RATIO+noise(x,y,2)*M.LUMP*edge
   end
  end
 end
 for y=0,ny-1 do
  Budget.check()
  local sy=math.min(h-1,h-1-y*step)
  local row,left,right={},nx,-1
  for x=0,nx-1 do
   local sx=math.min(w-1,x*step+math.floor(step/2))
   local r,g,b,a,u,v=sample(sx,sy)
   if a and a>.5 then
    local k=math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)
    paints[k]=paints[k]or{u,v};row[x]=k;left=math.min(left,x);right=math.max(right,x)
    if organic then
     all[#all+1]=k
     -- Ink outlines belong to the 2D drawing; distributing them across a
     -- solid crown makes black blocks. Lighting supplies the 3D shadows.
     if (family or sy<h*.76) and g>r*1.12 and g>b*1.08 then
      foliage[#foliage+1]=k
      local leafRow=nativeRows[y] or {};nativeRows[y]=leafRow;leafRow[x]=k
     end
     if sy>h*.65 and r>=g*.9 then wood[#wood+1]=k end
    end
   end
  end
  -- each contiguous run of pixels in the row is its own round blob (a grove of trees side by side is
  -- several crowns, not one wide ellipse); a row with a single run behaves exactly as before
  local runL,runR={}, {}
  do local x=left
   while x<=right do
    if row[x] then
     local e=x;while row[e+1] do e=e+1 end
     for k=x,e do runL[k]=x;runR[k]=e end
     x=e+1
    else x=x+1 end
   end
  end
  for x=left,right do if row[x] and not organic then
   local center=(runL[x]+runR[x]+1)/2;local radius=(runR[x]-runL[x]+1)/2
   local dx=x+.5-center
   local depth=math.sqrt(math.max(0,radius*radius-dx*dx))*.88
   if inflate then depth=math.max(.5,halfDepth(x,y)*(taper and (1-(1-taper)*y/math.max(1,ny-1)) or 1)) elseif depthLimit then depth=math.min(depth,depthLimit/(2*step)) end
   -- an inflated crown is seen from the south: the half behind the middle is only 55% as deep (its drawing is a mirror of the front and reads as streaks)
   local z0=math.max(0,math.floor(nx/2-depth*(inflate and M.BACK_RATIO or 1)));local z1=math.min(nx-1,math.ceil(nx/2+depth)-1)
   if relief then
    local front,back=relief(x,y,depth)
    z0=math.max(0,math.floor(nx/2-math.max(.5,back)));z1=math.min(nx-1,math.ceil(nx/2+math.max(.5,front))-1)
   end
   if depthLimit and not inflate then
    local cells=math.max(1,math.floor(depthLimit/step))
    local first=math.floor((nx-cells)/2)
    z0=math.max(z0,first);z1=math.min(z1,first+cells-1)
   end
   if inflate then zr0[y*nx+x]=z0;zr1[y*nx+x]=z1;rowK[y]=row
   else for z=z0,z1 do vox[key(x,y,z)]=row[x] end end
  end end
 end
 if inflate then
  -- Only the shell the camera can see keeps the drawing's own pixels (the front face and the top's front half,
  -- so the crown reads exactly as drawn); the rest of the body is the leaf colour of its row, so the back and
  -- sides are tiers of leaf instead of streaks of the front's outline pixels.
  local function dominant(row)
   local counts,bestK,bestN,anyK,anyN={}, nil,0,nil,0
   for x=0,nx-1 do local k=row[x];if k then
    counts[k]=(counts[k] or 0)+1
    local r,g,b=math.floor(k/65536),math.floor(k/256)%256,k%256
    if counts[k]>anyN then anyK,anyN=k,counts[k] end
    if r+g+b>=M.INK and counts[k]>bestN then bestK,bestN=k,counts[k] end
   end end
   return bestK or anyK
  end
  local function ink(k) return math.floor(k/65536)+math.floor(k/256)%256+k%256<M.INK end
  -- the leaf pixel of the drawing nearest column x in row yy (outline ink is
  -- skipped: it belongs to the flat drawing's edge, not to a leaf)
  local function leaf(x,yy)
   local row=rowK[yy];if not row then return nil end
   for d=0,nx do
    local k=row[x-d];if k and not ink(k) then return k end
    k=row[x+d];if k and not ink(k) then return k end
   end
  end
  local topRow=0
  for y=0,ny-1 do if rowK[y] then topRow=y end end
  -- (a tree's top is the leaves of the drawing's widest part laid flat about that row: the tip's few
  -- pixels, repeated across the whole width, lay as light and dark bands over every crown)
  local wideRow,wide=0,0
  for y=0,ny-1 do local row=rowK[y];if row then
   local n=0;for x=0,nx-1 do if row[x] and not ink(row[x]) then n=n+1 end end
   if n>wide then wide,wideRow=n,y end
  end end
  local zBack=nx
  for _,z in pairs(zr0)do if z<zBack then zBack=z end end
  local bodies={}
  -- the colour of voxel (x,y,z) of a column
  local function colourAt(x,y,z)
   local row=rowK[y]
   local z0,z1=zr0[y*nx+x],zr1[y*nx+x]
   -- The front face is the drawing itself. Behind it the drawing goes on:
   -- in the oblique art a point d deep is drawn d rows higher, so the
   -- crown's top and flanks take the leaf pixels of the rows above (the
   -- rear half mirrors the front). One flat colour per row stood as dark
   -- bands across every crown.
   if z==z1 then return row[x] end
   local d=z>=math.floor(nx/2) and z1-z or z-z0
   -- past the drawing's top row the rows run back down (a crown's far
   -- side), so the top never ends in one repeated row of dark rim leaves
   local yy=y+d
   if yy>topRow then yy=math.max(0,2*topRow-yy-3) end
   -- a voxel with nothing over it is the crown's top, seen from above:
   -- the drawing's own upper part laid flat, one row per voxel of depth
   -- from the back rim forward (rows of one repeated colour stood as a
   -- plain slab between the rows of a packed forest)
   local above=rowK[y+1]
   local covered=above and above[x] and zr0[(y+1)*nx+x]<=z and zr1[(y+1)*nx+x]>=z
   if not covered then yy=seed and math.max(0,math.min(topRow,wideRow+math.floor(nx/2)-z)) or math.max(0,topRow-2-(z-zBack)) end
   local body=bodies[y];if body==nil then body=dominant(row) or false;bodies[y]=body end
   return leaf(x,yy) or leaf(x,y) or body or nil
  end
  -- Faces straight from the columns (the game runs without the JIT: filling every voxel of a crown and
  -- slicing the whole box six times was most of a tree's build). A crown is one depth span per pixel,
  -- so its boundary is each span's front and back voxel plus the voxels of a span its four neighbours'
  -- spans do not cover; only those get a colour. The planes are then merged exactly as the box slicer
  -- did (same order, same rectangles), so the model is the same quad for quad.
  local planes={{},{},{}}
  local limits={nx,ny,nz}
  local function covers(x,y,z)
   if x<0 or y<0 or x>=nx or y>=ny then return false end
   local k=y*nx+x;local a=zr0[k];return a~=nil and a<=z and zr1[k]>=z
  end
  local function put(axis,sign,plane,u,v,colour)
   local t=planes[axis][sign*(plane+1)];if not t then t={};planes[axis][sign*(plane+1)]=t end
   t[v*limits[axis%3+1]+u]=colour
  end
  local function span(x,y)
   if x<0 or y<0 or x>=nx or y>=ny then return nil end
   local k=y*nx+x;return zr0[k],zr1[k]
  end
  for y=0,ny-1 do local row=rowK[y];if row then for x=0,nx-1 do if row[x] then
   local z0,z1=zr0[y*nx+x],zr1[y*nx+x]
   -- the depths all four neighbours cover: only the column's own ends are exposed in there
   local lo_,hi_=z0,z1
   for _,d in ipairs(NEIGH)do
    local a,b=span(x+d[1],y+d[2])
    if a==nil then lo_,hi_=z1+1,z0-1;break end
    if a>lo_ then lo_=a end;if b<hi_ then hi_=b end
   end
   local z=z0
   while z<=z1 do
    -- (inside the covered run only the ends can show: jump to its end)
    if z>z0 and z<z1 and z>=lo_ and z<=hi_ then z=math.min(hi_+1,z1) end
    local xm,xp,ym,yp=not covers(x-1,y,z),not covers(x+1,y,z),not covers(x,y-1,z),not covers(x,y+1,z)
    local zm,zp=z==z0,z==z1
    if xm or xp or ym or yp or zm or zp then
     local c=colourAt(x,y,z)
     if c then
      -- (axis 1: u=y, v=z; axis 2: u=z, v=x; axis 3: u=x, v=y)
      if xm then put(1,-1,x,y,z,c) end;if xp then put(1,1,x,y,z,c) end
      if ym then put(2,-1,y,z,x,c) end;if yp then put(2,1,y,z,x,c) end
      if zm then put(3,-1,z,x,y,c) end;if zp then put(3,1,z,x,y,c) end
     end
    end
    z=z+1
   end
   Budget.tick()
  end end end end
  local out={}
  for axis=1,3 do for _,sign in ipairs({-1,1})do
   local uaxis=axis%3+1;local vaxis=(axis+1)%3+1
   local nw,nh=limits[uaxis],limits[vaxis]
   local list={}
   for pk in pairs(planes[axis])do if (pk>0)==(sign>0) then list[#list+1]=sign*pk-1 end end
   table.sort(list)
   for _,plane in ipairs(list)do
    Budget.check()
    local grid=planes[axis][sign*(plane+1)]
    local keys={};for k in pairs(grid)do keys[#keys+1]=k end
    table.sort(keys)
    for _,k0 in ipairs(keys)do
     local colour=grid[k0]
     if colour then
      local u,v=k0%nw,math.floor(k0/nw)
      local ww,hh=1,1
      while u+ww<nw and grid[v*nw+u+ww]==colour do ww=ww+1 end
      while v+hh<nh do
       local whole=true
       for du=0,ww-1 do if grid[(v+hh)*nw+u+du]~=colour then whole=false;break end end
       if not whole then break end;hh=hh+1
      end
      for dv=0,hh-1 do for du=0,ww-1 do grid[(v+dv)*nw+u+du]=nil end end
      local q={u=paints[colour][1],v=paints[colour][2],shade=axis==2 and (sign>0 and 1 or .68) or axis==1 and .85 or .94}
      for _,uv in ipairs({{u,v},{u+ww,v},{u+ww,v+hh},{u,v+hh}})do
       local p={};p[axis]=(plane+(sign>0 and 1 or 0))*step;p[uaxis]=uv[1]*step;p[vaxis]=uv[2]*step
       p[1]=p[1]-w/2;p[2]=math.max(0,p[2]-bottom);p[3]=p[3]-nz*step/2
       q[#q+1]=p
      end
      if sign<0 then q[2],q[4]=q[4],q[2] end
      out[#out+1]=q
     end
    end
   end
  end end
  return out
 end
 if organic and #all>0 then
  if #foliage==0 then foliage=all end;if #wood==0 then wood=all end
  local nativePaint={}
  if family then for y=0,ny-1 do
   local row=nativeRows[y]
   if not row then for d=1,ny do row=nativeRows[y+d] or nativeRows[y-d];if row then break end end end
   if row then
    local paint={};nativePaint[y]=paint
    for sx=0,nx-1 do
     local color=row[sx]
     if not color then for d=1,nx do color=row[sx-d] or row[sx+d];if color then break end end end
     paint[sx]=color
    end
   end
  end end
  local height=h-bottom
  local function oval(x,y,z,cx,cy,cz,rx,ry,rz)
   return ((x-cx)/rx)^2+((y-cy)/ry)^2+((z-cz)/rz)^2<=1
  end
  for y=0,ny-1 do for x=0,nx-1 do Budget.tick();for z=0,nz-1 do
   local xx=(x+.5)*step/w-.5;local yy=((y+.5)*step-bottom)/height;local zz=(z+.5)*step/depth-.5
   local stemZ=((z+.5)*step-depth/2)/w
   local pool
   if yy>=0 then
    if organic=='tree' and family then
     local part=Trees.part(family,xx,yy,zz)
     if part then pool=part=='foliage' and foliage or wood end
    elseif organic=='tree' then
     -- Overlapping canopy lobes surround real trunk/branch volumes. The
     -- source image supplies colors only, never a front-facing solid slab.
     -- Each tree has a round footprint. Multi-row drawings are populated
     -- with separate trees by NativeTreeArt, never one elongated crown.
     -- Raise the canopy shoulders above head height on full-sized trees.
     local cy,ry=height>20 and .72 or .53,height>20 and .25 or .28
     if oval(xx,yy,zz,0,.82,0,.34,.18,.4)
      or oval(xx,yy,zz,-.12,cy,.02,.36,ry,.48)
      or oval(xx,yy,zz,.15,cy-.01,-.05,.34,ry-.01,.46)then pool=foliage
     elseif yy<.7 and xx*xx+stemZ*stemZ<(.065+.06*math.max(0,1-yy/.12))^2 then pool=wood
     elseif yy>.35 and yy<.68 and math.abs(math.abs(xx)-(yy-.35)*.65)<.055 and math.abs(stemZ)<.06 then pool=wood end
    elseif organic=='bush' then
     if oval(xx,yy,zz,-.17,.24,.06,.32,.26,.39)
      or oval(xx,yy,zz,.12,.35,-.08,.36,.36,.34)
      or oval(xx,yy,zz,.2,.2,.18,.26,.24,.25)then pool=foliage end
    elseif organic=='rock' then
     -- Three offset masses form a broad, asymmetric stone with a rounded
     -- top and real depth. Its foot is the rock itself, not a support box.
     if oval(xx,yy,zz,-.1,.34,.04,.38,.4,.39)
      or oval(xx,yy,zz,.12,.45,-.06,.34,.5,.32)
      or oval(xx,yy,zz,.22,.2,.18,.24,.27,.26)then pool=all end
    end
   end
   if pool then
    -- Native palette patches vary in all three axes; no repeated 2D bands
    -- through the middle. Coherent two-voxel patches retain greedy merging.
    local color
    if family and pool==foliage then
     -- Carry the drawing's leaf bands around the solid crown. Palette-only
     -- random noise erased the characteristic light/dark native leaf tiers.
     local row=nativePaint[y]
     if row then
      local azimuth=math.atan2(zz,xx)/(2*math.pi)+.5
      color=row[math.min(nx-1,math.floor(azimuth*nx))]
     end
    end
    if not color then
     local a,b,c=math.floor(x/2),math.floor(y/2),math.floor(z/2)
     local n=math.sin(a*12.9898+b*78.233+c*37.719)*43758.5453
     color=pool[math.floor((n-math.floor(n))*#pool)+1]
    end
    vox[key(x,y,z)]=color
   end
  end end end
 end
 local out={}
 -- Slice along each normal. Rectangle merging keeps the pixel silhouette
 -- while avoiding six independent cube faces for every solid pixel.
 -- (only the box the voxels occupy is sliced: a thin fence four cells wide is 3 voxels deep in a
 -- 64-deep grid, and walking the empty rest was most of a town's first build)
 local lo,hi={nx,ny,nz},{-1,-1,-1}
 for k in pairs(vox)do
  local z=k%nz;local r=(k-z)/nz;local x=r%nx;local y=(r-x)/nx
  if x<lo[1] then lo[1]=x end;if x>hi[1] then hi[1]=x end
  if y<lo[2] then lo[2]=y end;if y>hi[2] then hi[2]=y end
  if z<lo[3] then lo[3]=z end;if z>hi[3] then hi[3]=z end
 end
 -- (key(x,y,z) is linear: a step along x, y or z adds a fixed stride, so the slices index the voxels by
 -- arithmetic; a coordinate table per voxel visited, six passes over the box, was most of a big tree's
 -- build - Mossdeep's five groves alone held its first view on the flat map for two seconds)
 local strides={nz,nx*nz,1}
 for axis=1,3 do for _,sign in ipairs({-1,1})do
  local limits={nx,ny,nz};local uaxis=axis%3+1;local vaxis=(axis+1)%3+1
  local sa,su,sv=strides[axis],strides[uaxis],strides[vaxis]
  for plane=lo[axis],hi[axis] do
   Budget.check()
   local grid={};local nw,nh=limits[uaxis],limits[vaxis]
   local inside=plane+sign>=0 and plane+sign<limits[axis]
   local across=sign*sa
   for v=lo[vaxis],hi[vaxis] do local rowk=plane*sa+v*sv;for u=lo[uaxis],hi[uaxis] do
    local k=rowk+u*su
    local colour=vox[k]
    if colour and not (inside and vox[k+across]) then grid[v*nw+u]=colour end
   end end
   for v=lo[vaxis],hi[vaxis] do for u=lo[uaxis],hi[uaxis] do
    local colour=grid[v*nw+u]
    if colour then
     local ww,hh=1,1
     while u+ww<nw and grid[v*nw+u+ww]==colour do ww=ww+1 end
     while v+hh<nh do
      local whole=true
      for du=0,ww-1 do if grid[(v+hh)*nw+u+du]~=colour then whole=false;break end end
      if not whole then break end;hh=hh+1
     end
     for dv=0,hh-1 do for du=0,ww-1 do grid[(v+dv)*nw+u+du]=nil end end
     local q={u=paints[colour][1],v=paints[colour][2],shade=axis==2 and (sign>0 and 1 or .68) or axis==1 and .85 or .94}
     for _,uv in ipairs({{u,v},{u+ww,v},{u+ww,v+hh},{u,v+hh}})do
      local p={};p[axis]=(plane+(sign>0 and 1 or 0))*step;p[uaxis]=uv[1]*step;p[vaxis]=uv[2]*step
      p[1]=p[1]-w/2;p[2]=math.max(0,p[2]-bottom);p[3]=p[3]-nz*step/2
      q[#q+1]=p
     end
     if sign<0 then q[2],q[4]=q[4],q[2] end
     out[#out+1]=q
    end
   end end
  end
 end end
 return out
end
-- Native cutout pixels, kept on one upright plane for the optional 2.5D path.
function M.card(w,h,sample,bottom,height)
 local out={};local scale=(height or h)/h
 for y=0,h-1 do for x=0,w-1 do
  local _,_,_,a,u,v=sample(x,y)
  if a and a>.5 then
   local top=(h-y-(bottom or 0))*scale;local low=top-scale
   out[#out+1]={{x-w/2,top,0},{x+1-w/2,top,0},{x+1-w/2,low,0},{x-w/2,low,0},u=u,v=v,shade=1,card=true}
  end
 end end
 return out
end
function M.append(quads,v,i,count,x,y,z)
 for _,q in ipairs(quads)do
  Budget.tick()
  local base=#v
  for _,p in ipairs(q)do v[#v+1]={x+p[1],y+p[2],z+p[3],q.u,q.v,q.shade,0,0,0} end
  for _,k in ipairs({1,2,3,1,3,4})do i[#i+1]=base+k end
 end
 return (count or 0)+#quads
end
return M
