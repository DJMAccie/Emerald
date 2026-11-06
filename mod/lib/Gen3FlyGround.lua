-- Gen3FlyGround
local V=...
local R=V.require('Voxel3D')
local Mat=V.require('Mat4')
local M={
 CHUNK=64, -- cells per chunk side
 Y_MAP=-.6,
 Y_FILL=-.75,
 SEA=-3.2, -- the open sea plane
 SEA_MID=0x170,
 PLANE=26000,
 PLANE_CELL=650,
 log=true,
}
local function eng(name)return package.loaded[name] or require(name)end
local function now()return love.timer.getTime()end
local function note(fmt,...)if M.log then print('[FlyGround] '..string.format(fmt,...))end end
local floor=math.floor

local fill
function M.fill()
 if fill~=nil then return fill or nil end
 fill=false
 local ok,err=pcall(function()
  local b=assert(V.mod:read('assets/worldfill/fill.bin'))
  assert(b:sub(1,4)=='WFIL','not a world fill file')
  local ver,ox,oy,W,H,n,pos=love.data.unpack('<HhhHHH',b,5)
  assert(ver==1,'fill version '..tostring(ver))
  local pairs={}
  for i=1,n do local len=b:byte(pos);pairs[i]=b:sub(pos+1,pos+len);pos=pos+1+len end
  local cells=love.data.decompress('string','zlib',b:sub(pos))
  assert(#cells==W*H*2,'fill size')
  local src=V.mod:read('assets/worldfill/placements.lua')
  local place=src and assert((loadstring or load)(src,'@placements'))() or {}
  fill={ox=ox,oy=oy,W=W,H=H,pairs=pairs,cells=cells,place=place}
 end)
 if not ok then note('no world fill: %s',tostring(err));fill=false end
 return fill or nil
end
local dewfordTrees={0x1D4,0x1D5,0x1DC,0x1DD}
local function fillAt(F,x,y)
 local fx,fy=x-F.ox,y-F.oy
 if fx<0 or fy<0 or fx>=F.W or fy>=F.H then return nil end
 local i=(fy*F.W+fx)*2+1
 local lo,hi=F.cells:byte(i,i+1)
 local c=lo+hi*256
 if c==0 then return nil end
 local pair,mid=F.pairs[floor(c/1024)],c%1024
 if pair=='general__dewford' and mid==0x243 then mid=dewfordTrees[(y%2)*2+x%2+1] end
 return pair,mid
end
M.fillAt=fillAt
function M.placement(id)
 local F=M.fill();local p=F and F.place[id]
 if p then return p.ox,p.oy,p.overlay end
end

-- The flight atlas and the walking scene share Littleroot's coordinate origin.
local sourceMaps,origins
function M.origins(maps)
 if sourceMaps~=maps then
  local hub='EM_LITTLEROOT_TOWN'
  origins={[hub]={ox=0,oy=0}}
  for _,e in ipairs(eng('src.core.game3.map').computeWorld(maps,hub,99))do origins[e.id]=e end
  local F=M.fill()
  for id,e in pairs(F and F.place or {})do origins[id]=e end
  sourceMaps=maps
 end
 return origins
end

-- Shared index map, 0-based uint32 (1,2,3,1,3,4 per quad).
local mapData,mapQuads=nil,0
local function fullView(quads)
 if quads>mapQuads then
  local n=math.max(quads,mapQuads*2,4096)
  local parts,vals={},{}
  for q=0,n-1,50 do
   local k=0
   for j=q,math.min(n-1,q+49)do local b=j*4
    vals[k+1],vals[k+2],vals[k+3],vals[k+4],vals[k+5],vals[k+6]=b,b+1,b+2,b,b+2,b+3;k=k+6
   end
   parts[#parts+1]=love.data.pack('string',string.rep('I4',k),unpack(vals,1,k))
  end
  if mapData then mapData:release() end
  mapData=love.data.newByteData(table.concat(parts));mapQuads=n
 end
 return love.data.newDataView(mapData,0,quads*24)
end
local PACK=1200
local FMT=string.rep('f',PACK)
local function packFloats(f,n)
 local parts={}
 for s=1,n,PACK do
  local e=math.min(n,s+PACK-1)
  parts[#parts+1]=love.data.pack('string',e-s+1==PACK and FMT or string.rep('f',e-s+1),unpack(f,s,e))
 end
 return love.data.newByteData(table.concat(parts))
end

local G
function M.state()return G end
local function chunkKey(cx,cy)return cx..':'..cy end
function M.begin(game,maps)
 local F=M.fill();if not F then return false end
 if G and G.game==game then return true end
 if G then M.release() end
 local Tiles=eng('src.core.game3.tileset_native')
 local size=eng('src.core.game3.connections').sizeOf
 G={game=game,maps={},chunks={},order={},alloc={},filled={},t0=now(),quads=0,meshes=0,planMs=0,fillMs=0}
 local x0,y0,x1,y1=F.ox,F.oy,F.ox+F.W,F.oy+F.H
 for id,e in pairs(maps)do
  local def=e.def
  if def and not e.overlay then
   local w,h=size(def)
   if w>0 and h>0 then
    G.maps[#G.maps+1]={id=id,def=def,ox=e.ox,oy=e.oy,w=w,h=h}
    x0,y0,x1,y1=math.min(x0,e.ox),math.min(y0,e.oy),math.max(x1,e.ox+w),math.max(y1,e.oy+h)
   end
  end
 end
 table.sort(G.maps,function(a,b)return a.id<b.id end)
 local C=M.CHUNK
 for cy=floor(y0/C),floor((y1-1)/C)do for cx=floor(x0/C),floor((x1-1)/C)do
  local c={cx=cx,cy=cy,x0=cx*C,y0=cy*C,maps={},state='todo'}
  for _,m in ipairs(G.maps)do
   if m.ox<c.x0+C and m.ox+m.w>c.x0 and m.oy<c.y0+C and m.oy+m.h>c.y0 then c.maps[#c.maps+1]=m end
  end
  G.chunks[chunkKey(cx,cy)]=c;G.order[#G.order+1]=c
 end end
 for _,p in ipairs(F.pairs)do if not Tiles._pairs[p] then pcall(Tiles.prefetch,p,1)end end
 note('world: %d maps, %d chunks of %d cells, fill %dx%d at (%d,%d), %d fill pairs',#G.maps,#G.order,C,F.W,F.H,F.ox,F.oy,#F.pairs)
 return true
end
function M.release()
 if not G then return end
 for _,c in ipairs(G.order)do for _,p in ipairs(c.parts or {})do if p.mesh then pcall(p.mesh.release,p.mesh)end end end
 G=nil
end
function M.done()return G and G.allLive or false end

local function mapReady(m)
 local def=m.def
 if not def.midLayout then
  local Map=eng('src.core.game3.map')
  pcall(Map.ensureMidLayout,G.game,m.id,def)
 end
 local L=def.midLayout
 m.pair=m.pair or def.pair or (L and L.pair)
 if not (L and L.midAt and m.pair) then m.failed=true end
 return not m.failed
end
local want={}
local function guardRetain()
 local Tiles=eng('src.core.game3.tileset_native')
 local st=Tiles._stream
 if not st or st.flyGroundGuard then return end
 local orig=st.retain
 st.retain=function(self,wanted)
  if next(want) then
   local w={}
   for k,v in pairs(wanted or {})do w[k]=v end
   for k in pairs(want)do w[k]=true end
   return orig(self,w)
  end
  return orig(self,wanted)
 end
 st.flyGroundGuard=true
end
local function pairReady(p,priority)
 local Tiles=eng('src.core.game3.tileset_native')
 local ts=Tiles._pairs[p]
 if ts and ts.image then want[p]=nil;return ts end
 want[p]=true
 guardRetain()
 pcall(Tiles.prefetch,p,priority or 1)
 return nil
end
function M.pause()want={}end

local function planChunk(c,deadline,prio)
 local F=fill
 local C=M.CHUNK
 local SEA=M.SEA_MID
 for _,m in ipairs(c.maps)do
  if not m.failed then
   if not m.pair or not m.def.midLayout then
    if now()>deadline then return false end
    mapReady(m)
   end
   if m.pair and not m.failed and not pairReady(m.pair,prio) then return false end
  end
 end
 if not c.fillPairs then
  local need={}
  for y=c.y0,c.y0+C-1 do for x=c.x0,c.x0+C-1 do local p=fillAt(F,x,y);if p then need[p]=true end end end
  c.fillPairs=need
 end
 local ready=true
 for p in pairs(c.fillPairs)do if not pairReady(p,prio) then ready=false end end
 if not ready then return false end
 local Tiles=eng('src.core.game3.tileset_native')
 local w=c.work
 if not w then w={parts={},byPair={},row=c.y0};c.work=w end
 local parts,byPair=w.parts,w.byPair
 local function part(p)
  local q=byPair[p]
  if q then return q end
  local ts=Tiles._pairs[p]
  local iw,ih=ts.image:getDimensions()
  q={pair=p,f={},n=0,cells={},cols=ts.cols,toSlot=ts.midToSlot or {},du=16/iw,dv=16/ih,zero=(ts.midToSlot or {})[0] or 0}
  byPair[p]=q;parts[#parts+1]=q
  return q
 end
 local function quad(q,x,y,mid,Y)
  local slot=q.toSlot[mid] or q.zero
  local du,dv=q.du,q.dv
  local u0,v0=(slot%q.cols)*du,floor(slot/q.cols)*dv
  local X,Z=x*16,y*16
  local f,n=q.f,q.n*24
  f[n+1],f[n+2],f[n+3],f[n+4],f[n+5],f[n+6]=X,Y,Z,u0,v0,1
  f[n+7],f[n+8],f[n+9],f[n+10],f[n+11],f[n+12]=X+16,Y,Z,u0+du,v0,1
  f[n+13],f[n+14],f[n+15],f[n+16],f[n+17],f[n+18]=X+16,Y,Z+16,u0+du,v0+dv,1
  f[n+19],f[n+20],f[n+21],f[n+22],f[n+23],f[n+24]=X,Y,Z+16,u0,v0+dv,1
  local k=q.n*2;q.cells[k+1],q.cells[k+2]=x,y
  q.n=q.n+1
 end
 while w.row<c.y0+C do
  local y=w.row
  for _,m in ipairs(c.maps)do
   if not m.failed and y>=m.oy and y<m.oy+m.h then
    local L=m.def.midLayout
    local general=m.pair:match('^general__')~=nil
    local q=part(m.pair)
    local ax0,ax1=math.max(c.x0,m.ox),math.min(c.x0+C,m.ox+m.w)-1
    local ok,err=pcall(function()
     for x=ax0,ax1 do
      local mid=L:midAt(x-m.ox,y-m.oy) or 0
      if not (general and mid==SEA) then quad(q,x,y,mid,M.Y_MAP)end
     end
    end)
    if not ok then note('ground of %s failed: %s',m.id,tostring(err));m.failed=true end
   end
  end
  for x=c.x0,c.x0+C-1 do
   local p,mid=fillAt(F,x,y)
   if p then quad(part(p),x,y,mid,M.Y_FILL)end
  end
  w.row=y+1
  if now()>deadline and w.row<c.y0+C then return false end
 end
 local keep={}
 for _,q in ipairs(parts)do if q.n>0 then keep[#keep+1]=q end end
 c.parts=keep;c.state='planned';c.work=nil
 return true
end

function M.step(hx,hz,budget)
 if not G then return end
 local t0=now()
 local deadline=t0+(budget or .003)
 local frame=G.frame or 0;G.frame=frame+1
 local i=1
 while i<=#G.alloc do
  local c=G.alloc[i]
  if c.allocFrame<frame and now()<deadline then
   for _,p in ipairs(c.parts)do
    if p.mesh and p.f then
     local ok,err=pcall(function()
      local data=packFloats(p.f,p.n*24)
      p.mesh:setVertices(data,1)
      data:release()
     end)
     if not ok then note('chunk %d,%d %s: %s',c.cx,c.cy,p.pair,tostring(err));p.mesh:release();p.mesh=nil end
     p.f=nil
     if p.mesh then G.quads=G.quads+p.n;G.meshes=G.meshes+1 end
    end
   end
   c.state='live';c.cutKey=nil;c.liveFrame=frame
   table.remove(G.alloc,i)
  else
   i=i+1
  end
 end
 G.fillMs=G.fillMs+(now()-t0)*1000
 for _,c in ipairs(G.order)do
  if c.state=='planned' then
   for _,p in ipairs(c.parts)do
    local ok,mesh=pcall(love.graphics.newMesh,R.FORMAT,p.n*4,'triangles','static')
    p.mesh=ok and mesh or nil
    if p.mesh then
     local view=fullView(p.n)
     if not pcall(p.mesh.setVertexMap,p.mesh,view,'uint32') then p.mesh:release();p.mesh=nil end
     view:release()
    end
   end
   c.state='alloc';c.allocFrame=frame;G.alloc[#G.alloc+1]=c
  end
 end
 local t1=now()
 if not G.allLive and now()<deadline then
  if not G.sortedAt or math.abs(G.sortedAt[1]-hx)+math.abs(G.sortedAt[2]-hz)>512 then
   local C16=M.CHUNK*16
   for _,c in ipairs(G.order)do
    local cx,cz=(c.x0*16+C16/2)-hx,(c.y0*16+C16/2)-hz
    c.d=cx*cx+cz*cz
   end
   table.sort(G.order,function(a,b)return a.d<b.d end)
   G.sortedAt={hx,hz}
  end
  local todo,rank=false,0
  for _,c in ipairs(G.order)do
   if c.state=='todo' then
    todo=true;rank=rank+1
    if now()>deadline then break end
    planChunk(c,deadline,1+rank*.01)
   end
  end
  if not todo and #G.alloc==0 then
   local any=false
   for _,c in ipairs(G.order)do if c.state~='live' then any=true;break end end
   if not any then
    G.allLive=true
    note('world laid: %d quads in %d meshes, %.1f s after the first take-off (plan %.0f ms, fill %.0f ms)',
     G.quads,G.meshes,now()-G.t0,G.planMs,G.fillMs)
   end
  end
 end
 G.planMs=G.planMs+(now()-t1)*1000
end
function M.coverage(hx,hz,d)
 if not G then return 0,0 end
 local live,all=0,0
 local C16=M.CHUNK*16
 for _,c in ipairs(G.order)do
  local x0,z0=c.x0*16,c.y0*16
  local dx=hx<x0 and x0-hx or (hx>x0+C16 and hx-x0-C16 or 0)
  local dz=hz<z0 and z0-hz or (hz>z0+C16 and hz-z0-C16 or 0)
  if dx*dx+dz*dz<=d*d then all=all+1;if c.state=='live' then live=live+1 end end
 end
 return live,all
end

local function cutPart(p,rect)
 local idx,n={},0
 local cells=p.cells
 for q=0,p.n-1 do
  local x,y=cells[q*2+1],cells[q*2+2]
  if not (x>=rect[1] and x<=rect[3] and y>=rect[2] and y<=rect[4]) then
   local b=q*4
   idx[n+1],idx[n+2],idx[n+3],idx[n+4],idx[n+5],idx[n+6]=b,b+1,b+2,b,b+2,b+3;n=n+6
  end
 end
 p.hidden=n==0
 if n==0 then return end
 local parts={}
 for s=1,n,PACK do
  local e=math.min(n,s+PACK-1)
  parts[#parts+1]=love.data.pack('string',string.rep('I4',e-s+1),unpack(idx,s,e))
 end
 local data=love.data.newByteData(table.concat(parts))
 pcall(p.mesh.setVertexMap,p.mesh,data,'uint32')
 data:release()
end
function M.cut(rect)
 if not G then return end
 local key=rect and table.concat(rect,',') or '-'
 local C=M.CHUNK
 for _,c in ipairs(G.order)do
  if c.state=='live' and c.cutKey~=key and (c.liveFrame or -1)<(G.frame or 0)-1 then
   local hit=rect and not (rect[3]<c.x0 or rect[1]>c.x0+C-1 or rect[4]<c.y0 or rect[2]>c.y0+C-1)
   if hit or c.cut then
    for _,p in ipairs(c.parts)do
     if p.mesh then
      if hit then cutPart(p,rect)
      else local view=fullView(p.n);pcall(p.mesh.setVertexMap,p.mesh,view,'uint32');view:release();p.hidden=false end
     end
    end
    c.cut=hit or nil
   end
   c.cutKey=key
  end
 end
end

local sea={}
local function seaPair()
 local Tiles=eng('src.core.game3.tileset_native')
 if sea.pair and Tiles._pairs[sea.pair] and Tiles._pairs[sea.pair].image then return Tiles._pairs[sea.pair] end
 for p,ts in pairs(Tiles._pairs)do
  if type(p)=='string' and p:match('^general__') and ts.image and ts.midToSlot and ts.midToSlot[M.SEA_MID] then sea.pair=p;return ts end
 end
end
function M.refreshSea()
 local ts=seaPair();if not ts then return false end
 if not sea.canvas then
  local ok,cv=pcall(love.graphics.newCanvas,16,16,{mipmaps='manual'})
  if not ok then ok,cv=pcall(love.graphics.newCanvas,16,16) end
  if not ok then return false end
  cv:setFilter('linear','nearest');cv:setWrap('repeat','repeat')
  if cv:getMipmapCount()>1 then pcall(cv.setMipmapFilter,cv,'linear') end
  sea.canvas=cv
 end
 local slot=ts.midToSlot[M.SEA_MID]
 local iw,ih=ts.image:getDimensions()
 local sx,sy=(slot%ts.cols)*16,floor(slot/ts.cols)*16
 if not sea.quad or sea.quadFor~=ts.image then sea.quad=love.graphics.newQuad(sx,sy,16,16,iw,ih);sea.quadFor=ts.image end
 local ok=pcall(function()
  love.graphics.push('all')
  love.graphics.setCanvas(sea.canvas)
  love.graphics.clear(0,0,0,1)
  love.graphics.setShader()
  love.graphics.setBlendMode('alpha')
  love.graphics.setColor(1,1,1,1)
  love.graphics.draw(ts.image,sea.quad,0,0)
  if ts.overImage then
   local ow,oh=ts.overImage:getDimensions()
   if ow==iw and oh==ih then love.graphics.draw(ts.overImage,sea.quad,0,0)end
  end
  love.graphics.pop()
  if sea.canvas:getMipmapCount()>1 then sea.canvas:generateMipmaps() end
 end)
 return ok
end
local function seaMesh()
 if sea.mesh then return sea.mesh end
 local n=floor(M.PLANE/M.PLANE_CELL)
 local cell=M.PLANE_CELL
 local f,k={},0
 for y=0,n-1 do for x=0,n-1 do
  local X,Z=(x-n/2)*cell,(y-n/2)*cell
  local u0,v0,u1,v1=X/16,Z/16,(X+cell)/16,(Z+cell)/16
  local q={X,0,Z,u0,v0,1, X+cell,0,Z,u1,v0,1, X+cell,0,Z+cell,u1,v1,1, X,0,Z+cell,u0,v1,1}
  for j=1,24 do f[k+j]=q[j] end
  k=k+24
 end end
 local ok,mesh=pcall(love.graphics.newMesh,R.FORMAT,n*n*4,'triangles','static')
 if not ok then return nil end
 local data=packFloats(f,k);local view=fullView(n*n)
 local ok2=pcall(function()mesh:setVertices(data,1);mesh:setVertexMap(view,'uint32')end)
 data:release();view:release()
 if not ok2 then mesh:release();return nil end
 sea.mesh=mesh
 return mesh
end
function M.warm()
 seaMesh();M.refreshSea()
end

function M.draw(draw,ox,oz,fx,fz,reach)
 if not G then return 0 end
 local mesh=seaMesh()
 if mesh and sea.canvas then
  local sx,sz=floor(fx/16)*16,floor(fz/16)*16
  draw(mesh,sea.canvas,Mat.translate(sx,M.SEA,sz))
 end
 local Tiles=eng('src.core.game3.tileset_native')
 local model=Mat.translate(-ox,0,-oz)
 local hx,hz=fx+ox,fz+oz
 local C16=M.CHUNK*16
 local r2=(reach+C16)^2
 local drawn=0
 for _,c in ipairs(G.order)do
  if c.state=='live' and c.cutKey then
   local dx,dz=c.x0*16+C16/2-hx,c.y0*16+C16/2-hz
   if dx*dx+dz*dz<=r2 then
    for _,p in ipairs(c.parts)do
     if p.mesh and not p.hidden then
      local ts=Tiles._pairs[p.pair]
      if ts and ts.image then
       draw(p.mesh,ts.image,model)
       if ts.overImage then
        local ow,oh=ts.overImage:getDimensions();local iw,ih=ts.image:getDimensions()
        if ow==iw and oh==ih then draw(p.mesh,ts.overImage,model)end
       end
       drawn=drawn+1
      end
     end
    end
   end
  end
 end
 return drawn
end

return M
