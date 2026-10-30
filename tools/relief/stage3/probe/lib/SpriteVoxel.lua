-- Sprite-to-voxel: stand a landmark's own sprite art up as closed geometry.
--
-- Gen 3 draws overworld objects in the same oblique "dollhouse" projection
-- as the map itself: a thing's south wall is drawn 1:1, and its top is drawn
-- directly above that wall, also 1:1, lifted by the object's depth. A 48x48
-- truck drawing therefore already contains a front elevation AND a plan
-- view, and both read straight back out of it. That is all this tool does:
-- every face of the model samples the drawing, nothing is invented.
--
-- A RECIPE describes the solid as axis-aligned boxes in sprite pixels:
--
--   { width = 48,
--     boxes = {
--       { x0=17, x1=48, y0=6, y1=24, d0=0, d1=16,
--         paint = { south={x=17,y=24,w=31,h=18}, top={x=17,y=8,w=31,h=16} } },
--       ... } }
--
--   * x runs east along the drawing, y is height above the drawing's ground
--     row, d is depth away from the viewer. A point's screen row in the
--     drawing is y+d, which is what makes the drawing's upper band the roof.
--   * paint[face] is a rect of the source image stretched over that face,
--     in the same orientation the drawing shows it. A 1x1 rect paints one
--     flat colour -- the swatch trick, taken from the sprite itself.
--   * Faces: south (+Z, toward the camera), north, east (+X), west, top
--     (+Y), bottom. A box without an entry for a face falls back to its
--     south rect, then to recipe.flat, then to the recipe's first box.
--   * scale (default 1) is world pixels per sprite pixel.
--
-- Boxes are rasterised into a voxel volume, a face is emitted only where the
-- solid actually ends (so touching boxes cannot z-fight), coplanar faces of
-- one paint are merged, and Voxel3D.FACE_SHADE is baked per face so the
-- model reads solid. A dozen-box landmark costs tens of quads.
local V=...
local R=V.require('Voxel3D')
local Budget=V.require('BuildBudget')
local M={}
M.RELIEF=0   -- deepest carve, in voxels (= art pixels); 0 = off until reviewed

local FACE={'east','west','top','bottom','south','north'}
-- Normal axis (1=x, 2=y, 3=d), which side of the voxel the face sits on,
-- and which two axes span it. Order matches Voxel3D.FACE_CORNERS/FACE_SHADE.
local SPEC={
 {axis=1,sign= 1,u=3,v=2}, -- +X east,  face at x+1
 {axis=1,sign=-1,u=3,v=2}, -- -X west,  face at x
 {axis=2,sign= 1,u=1,v=3}, -- +Y top,   face at y+1
 {axis=2,sign=-1,u=1,v=3}, -- -Y bottom,face at y
 {axis=3,sign=-1,u=1,v=2}, -- +Z south, face at d   (toward the viewer)
 {axis=3,sign= 1,u=1,v=2}, -- -Z north, face at d+1
}

-- The four corners of a face rectangle, in the winding Voxel3D already uses
-- for its own voxel meshes. cx/cy/cz pick the rectangle's extremes, and the
-- d axis is stored the way this tool thinks (away from the viewer), so a
-- corner's depth is the near plane when the engine's corner is +Z.
local function corners(dir,x0,x1,y0,y1,d0,d1)
 local out={}
 for k,c in ipairs(R.FACE_CORNERS[dir])do
  out[k]={(c[1]==1)and x1 or x0,(c[2]==1)and y1 or y0,(c[3]==1)and d0 or d1}
 end
 return out
end

local function rectFor(box,dir,recipe,iw,ih)
 local paint=box.paint or {}
 local r=paint[FACE[dir]] or paint.all or paint.south or recipe.flat
 if not r and recipe.boxes[1] then
  local first=recipe.boxes[1].paint or {}
  r=first.south or first.all or first[FACE[dir]]
 end
 if not r then return end
 local x,y,w,h=r.x or 0,r.y or 0,r.w or 1,r.h or 1
 -- Never sample outside the drawing: clamp rather than wrap, so a recipe
 -- mistake shows as a stretched edge instead of somebody else's artwork.
 if x<0 then w=w+x;x=0 end
 if y<0 then h=h+y;y=0 end
 if x+w>iw then w=iw-x end
 if y+h>ih then h=ih-y end
 if w<0 or h<0 then return end
 w=math.max(w,1);h=math.max(h,1)
 return {x=x,y=y,w=w,h=h}
end

-- Where a point of the model sits inside the box's own face, 0..1 across the
-- paint rect. This is what keeps the drawing in register: a wall's top row is
-- the rect's top row, and a roof's far edge is the rect's far edge.
local function fraction(dir,box,x,y,d)
 local function span(a,b,v)
  if b==a then return 0 end
  local f=(v-a)/(b-a)
  return f<0 and 0 or f>1 and 1 or f
 end
 if dir==5 or dir==6 then return span(box.x0,box.x1,x),span(box.y1,box.y0,y)
 elseif dir==3 or dir==4 then return span(box.x0,box.x1,x),span(box.d1,box.d0,d)
 else return span(box.d0,box.d1,d),span(box.y1,box.y0,y) end
end

local function boxPaint(box,dir,recipe,iw,ih)
 local r=rectFor(box,dir,recipe,iw,ih)
 if not r then return end
 return r
end

function M.build(spr,recipe,origin)
 if not (spr and spr.imageData and recipe and recipe.boxes)then return end
 local iw,ih=spr.imageData:getDimensions()
 local nx,ny,nd=0,0,0
 for _,b in ipairs(recipe.boxes)do
  nx=math.max(nx,b.x1 or 0);ny=math.max(ny,b.y1 or 0);nd=math.max(nd,b.d1 or 0)
 end
 if nx<1 or ny<1 or nd<1 then return end
 -- Rasterise: the last box to claim a voxel owns its faces there.
 local owner={}
 for bi,b in ipairs(recipe.boxes)do
  for y=math.max(0,b.y0),math.max(-1,b.y1-1)do
   for x=math.max(0,b.x0),math.max(-1,b.x1-1)do
    local base=(y*nx+x)*nd
    for d=math.max(0,b.d0),math.max(-1,b.d1-1)do owner[base+d]=bi end
   end
  end
  Budget.tick()
 end
 -- RELIEF. Pixel art draws depth with shading: outlines and glass sit back,
 -- the material sits in the middle, highlights (sills, ledges, roof ridges)
 -- stand forward. Each front (south) and top face is carved per pixel by its
 -- own pixel's brightness against the face's material: 0..M.RELIEF voxels.
 -- Carving only, so a model never grows past its recipe. A voxel within
 -- reach of a relieved face is painted with its own art pixel on every side,
 -- so the walls of a recess show the colours that frame it, not a smear.
 local over={}         -- voxel index -> {px,py}: per-voxel paint
 if recipe.relief~=false then
  local data=spr.imageData
  local function lum(px,py)
   local r,g,b=data:getPixel(px,py);return .3*r+.59*g+.11*b
  end
  for bi,b in ipairs(recipe.boxes)do if b.relief~=false then
   for _,dir in ipairs({5,3})do
    local r=rectFor(b,dir,recipe,iw,ih)
    local thick=dir==5 and (b.d1-b.d0) or (b.y1-b.y0)
    local reach=math.min(M.RELIEF,thick-2)
    if r and reach>=1 then
     -- the face's material: median brightness of its rect
     local ls={}
     for yy=r.y,r.y+r.h-1 do for xx=r.x,r.x+r.w-1 do ls[#ls+1]=lum(xx,yy) end end
     table.sort(ls);local mat=ls[math.ceil(#ls/2)] or .5
     local nu=b.x1-b.x0
     local nv=dir==5 and (b.y1-b.y0) or (b.d1-b.d0)
     for v=0,nv-1 do for u=0,nu-1 do
      local px=math.min(r.x+r.w-1,r.x+math.floor(u*r.w/nu))
      local py=math.min(r.y+r.h-1,r.y+math.floor(v*r.h/nv))
      local l=lum(px,py)
      local depth
      if l<mat*.45 then depth=reach                 -- outline / glass / door gap
      elseif l<mat*.8 then depth=math.max(1,reach-1) -- shadowed band
      elseif l>mat*1.12 then depth=0                -- highlight stands forward
      else depth=1 end                               -- the material plane
      depth=math.min(depth,reach)
      local x=b.x0+u
      for k=0,reach do
       local y,d
       if dir==5 then y=b.y1-1-v;d=b.d0+k else y=b.y1-1-k;d=b.d1-1-v end
       local idx=(y*nx+x)*nd+d
       if owner[idx]==bi then
        if k<depth then owner[idx]=nil
        else over[idx]=over[idx] or {px,py} end
       end
      end
     end end
    end
   end
  end end
 end
 local scale=recipe.scale or 1
 local offX=origin and (recipe.offX or 0) or ((recipe.width or nx)/2)
 local ox=origin and origin[1] or 0
 local oy=origin and origin[2] or 0
 local oz=origin and origin[3] or 0
 local verts,indices={},{}
 local function voxel(x,y,d)
  if x<0 or y<0 or d<0 or x>=nx or y>=ny or d>=nd then return nil end
  return owner[(y*nx+x)*nd+d]
 end
 local occupied,quads=0,0
 for dir=1,6 do
  local s=SPEC[dir]
  local planes=s.axis==1 and nx or s.axis==2 and ny or nd
  local nw=s.u==1 and nx or s.u==2 and ny or nd
  local nh=s.v==1 and nx or s.v==2 and ny or nd
  for plane=0,planes-1 do
   Budget.check()
   local grid={}
   for v=0,nh-1 do for u=0,nw-1 do
    local c={0,0,0}
    c[s.axis]=plane
    c[s.u]=u;c[s.v]=v
    local idx=((c[2]*nx)+c[1])*nd+c[3]
    local bi=owner[idx]
    if bi then
     local n={c[1],c[2],c[3]}
     n[s.axis]=plane+s.sign
     if not voxel(n[1],n[2],n[3])then
      local o=over[idx]
      -- the front face keeps the recipe's own mapping (it IS the pixel);
      -- every other side of a relieved voxel shows that voxel's pixel
      if o and dir~=5 and dir~=3 then grid[v*nw+u]='p'..o[1]..','..o[2]
      else grid[v*nw+u]=bi end
      occupied=occupied+1
     end
    end
   end end
   for v=0,nh-1 do for u=0,nw-1 do
    local bi=grid[v*nw+u]
    if bi then
     local ww,hh=1,1
     while u+ww<nw and grid[v*nw+u+ww]==bi do ww=ww+1 end
     while v+hh<nh do
      local whole=true
      for du=0,ww-1 do if grid[(v+hh)*nw+u+du]~=bi then whole=false;break end end
      if not whole then break end
      hh=hh+1
     end
     for dv=0,hh-1 do for du=0,ww-1 do grid[(v+dv)*nw+u+du]=nil end end
     local box,paint
     if type(bi)=='string' then
      local px,py=bi:match('^p(%d+),(%d+)$')
      paint={x=tonumber(px)+.5,y=tonumber(py)+.5,w=0,h=0};box=recipe.boxes[1]
     else
      box=recipe.boxes[bi];paint=boxPaint(box,dir,recipe,iw,ih)
     end
     if paint then
      local x0,x1,y0,y1,d0,d1
      if s.axis==1 then x0=plane+(s.sign>0 and 1 or 0);x1=x0;d0,d1=u,u+ww;y0,y1=v,v+hh
      elseif s.axis==2 then y0=plane+(s.sign>0 and 1 or 0);y1=y0;x0,x1=u,u+ww;d0,d1=v,v+hh
      else d0=plane+(s.sign>0 and 1 or 0);d1=d0;x0,x1=u,u+ww;y0,y1=v,v+hh end
      local base=#verts
      for _,p in ipairs(corners(dir,x0,x1,y0,y1,d0,d1))do
       local fu,fv=fraction(dir,box,p[1],p[2],p[3])
       verts[#verts+1]={(p[1]-offX)*scale+ox,p[2]*scale+oy,-p[3]*scale+oz,
        (paint.x+fu*paint.w)/iw,(paint.y+fv*paint.h)/ih,R.FACE_SHADE[dir]}
      end
      for _,k in ipairs({1,2,3,1,3,4})do indices[#indices+1]=base+k end
      quads=quads+1
     end
    end
   end end
  end
 end
 if quads==0 then return end
 local mesh,err=R.newMesh(verts,indices)
 if not mesh then return nil,err end
 return mesh,{quads=quads,faces=occupied,boxes=#recipe.boxes}
end

M.FACE=FACE
return M
