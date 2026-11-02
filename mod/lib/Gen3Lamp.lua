-- Rustboro's street lamps as slender standing lamps that light up at night
local V=...
local M={}
M.PAIR='general__rustboro'
M.FOOT=0x21A
M.HEAD={[0x212]=true,[0x213]=true}
M.GROUND=0x2BB -- the lawn under the foot
M.AXIS_X=8.5 -- the post's middle in its cell (columns 7..9)
M.D_MAX=5
M.SHADOW={132,132,140} -- the grey the lamp's cast shadow is painted in
M.SHADOW_FROM=11 -- the foot rows from which a trailing grey is shadow
M.PALE=.6
M.GLASS={1,.749,.42} -- 255,191,107
M.GLASS_ALPHA=220/255
M.POOL_R=28 -- 1.75 cells, in world pixels
M.POOL={1,.58,.24}
M.POOL_ALPHA=.34
M.LIFT=.12

local function origin(ts,mid)
 local slot=ts.midToSlot[mid];if not slot then return end
 return slot%ts.cols*16,math.floor(slot/ts.cols)*16
end
local function px(data,ox,oy,x,y)
 local r,g,b,a=data:getPixel(ox+x,oy+y)
 return math.floor(r*255+.5),math.floor(g*255+.5),math.floor(b*255+.5),a
end

local function outline(ts,headMid)
 ts.lampArt=ts.lampArt or {}
 local hit=ts.lampArt[headMid]
 if hit~=nil then return hit end
 local art=false
 local hx,hy=origin(ts,headMid)
 local fx,fy=origin(ts,M.FOOT)
 local gx,gy=origin(ts,M.GROUND)
 if ts.imageData and ts.overImageData and hx and fx and gx then
  local rows={}
  for y=0,15 do
   local l,r,gl,gr,run
   for x=0,15 do
    local cr,cg,cb,a=px(ts.overImageData,hx,hy,x,y)
    if a>.5 then
     l=l or x;r=x
     if y>=6 and y<=10 and (cr+cg+cb)/765>M.PALE then
      if run and run[2]==x-1 then run[2]=x else run={x,x} end
      if run[2]-run[1]>=1 and (not gl or run[2]-run[1]>gr-gl) then gl,gr=run[1],run[2] end
     end
    end
   end
   if l then rows[#rows+1]={mid=headMid,y=y,l=l,r=r,gl=gl,gr=gr,foot=false} end
  end
  local lawn={}
  for _,t in ipairs({{gx,gy},{hx,hy}})do for y=0,15 do for x=0,15 do
   local cr,cg,cb=px(ts.imageData,t[1],t[2],x,y);lawn[cr*65536+cg*256+cb]=true
  end end end
  local SH=M.SHADOW[1]*65536+M.SHADOW[2]*256+M.SHADOW[3]
  for y=0,15 do
   local cols={}
   for x=0,15 do
    local cr,cg,cb=px(ts.imageData,fx,fy,x,y)
    local k=cr*65536+cg*256+cb
    if not lawn[k] then cols[x]=k end
   end
   if y>=M.SHADOW_FROM then
    for x=15,0,-1 do if cols[x] then if cols[x]==SH then cols[x]=nil else break end end end
   end
   local l,r
   for x=0,15 do if cols[x] then l=l or x;r=x end end
   if l then rows[#rows+1]={mid=M.FOOT,y=y,l=l,r=r,foot=true} end
  end
  if #rows>0 and rows[#rows].foot then art={rows=rows} end
 end
 ts.lampArt[headMid]=art
 return art
end

local function headOf(c,cells)
 local n=cells[c.cx..':'..(c.cy-1)]
 return n and M.HEAD[n.mid] and n.mid or nil
end
function M.is(c,cells)
 if not (c and cells and c.pair==M.PAIR and c.mid==M.FOOT and (c.collision or 0)~=0 and c.ts) then return false end
 local hm=headOf(c,cells)
 return hm~=nil and outline(c.ts,hm)~=false
end
function M.isTop(c,cells)
 if not (c and cells and c.pair==M.PAIR and M.HEAD[c.mid] and c.ts) then return false end
 local s=cells[c.cx..':'..(c.cy+1)]
 return s~=nil and s.mid==M.FOOT and M.is(s,cells)
end

local function runsOf(art)
 local out={}
 for _,row in ipairs(art.rows)do
  local last=out[#out]
  if last and last.mid==row.mid and last.foot==row.foot and last.l==row.l and last.r==row.r
   and last.gl==row.gl and last.gr==row.gr and last.y1+1==row.y then last.y1=row.y
  else out[#out+1]={mid=row.mid,foot=row.foot,y0=row.y,y1=row.y,l=row.l,r=row.r,gl=row.gl,gr=row.gr} end
 end
 return out
end

local function lit(n,c)
 if not (n and n.shape) then return false end
 local k=n.shape.kind
 if not (k=='flat' or k=='fence' or k=='grass') then return false end
 if n.civic or n.bldModel or n.prop or n.column or n.stairs or n.boundary then return false end
 return math.abs((n.base or 0)-(c.base or 0))<=.5
end

function M.append(c,quad,uvFor,cells,sinks)
 local hm=headOf(c,cells)
 local art=hm and outline(c.ts,hm)
 if not art then return end
 local runs=runsOf(art)
 local x0=c.cx*16
 local last=runs[#runs]
 local function depth(w)return math.min(w,M.D_MAX)end
 local zf=c.cy*16+last.y1+1
 local zc=zf-2
 local base=c.base or 0
 local night
 if sinks and sinks.lamps then
  night={x=c.cx*16+M.AXIS_X,y=base,z=zf-2,glass={v={},i={}},pool={v={},i={}}}
  sinks.lamps[#sinks.lamps+1]=night
 end
 local function tileUv(mid)
  local t=uvFor(c.ts,mid);if not t then return end
  return t[1][1],t[1][2],t[3][1],t[3][2]
 end
 for k,run in ipairs(runs)do
  local L,T,R,B=tileUv(run.mid)
  if L then
   local w=run.r-run.l+1
   local d=depth(w)
   local zb,za=zf,zf-d
   local baseY=(run.foot and c.cy or c.cy-1)*16
   local n=run.y1-run.y0+1
   local h1=zf-(baseY+run.y0);local h0=h1-n
   local xa,xb=x0+run.l,x0+run.r+1
   local u0,u1=L+(R-L)*run.l/16,L+(R-L)*(run.r+1)/16
   local v0,v1=T+(B-T)*run.y0/16,T+(B-T)*(run.y1+1)/16
   local cut=(w>7 and not run.gl) and 1 or 0
   local function U(x)return u0+(u1-u0)*(x-xa)/w end
   local function band(xL,zL,xR,zR,uL,uR,shade)
    quad({{xL,h1,zL},{xR,h1,zR},{xR,h0,zR},{xL,h0,zL}},{{uL,v0},{uR,v0},{uR,v1},{uL,v1}},shade)
   end
   if cut>0 then band(xa,zb-cut,xa+cut,zb,U(xa),U(xa+cut),.8) end
   band(xa+cut,zb,xb-cut,zb,U(xa+cut),U(xb-cut),.9)
   if cut>0 then band(xb-cut,zb,xb,zb-cut,U(xb-cut),U(xb),.84) end
   band(xb,zb-cut,xb,za+cut,U(xb-.5),U(xb-.5),.76)
   if cut>0 then band(xb,za+cut,xb-cut,za,U(xb),U(xb-cut),.7) end
   band(xb-cut,za,xa+cut,za,U(xb-cut),U(xa+cut),.64)
   if cut>0 then band(xa+cut,za,xa,za+cut,U(xa+cut),U(xa),.68) end
   band(xa,za+cut,xa,zb-cut,U(xa+.5),U(xa+.5),.72)
   local vt=T+(B-T)*(run.y0+.5)/16
   local function cap(pts)
    local uv={}
    for i,p in ipairs(pts)do uv[i]={U(math.max(xa,math.min(xb,p[1]))),vt} end
    quad(pts,uv,1)
   end
   if cut>0 then
    cap({{xa+cut,h1,za},{xb-cut,h1,za},{xb-cut,h1,zb},{xa+cut,h1,zb}})
    cap({{xa,h1,za+cut},{xa+cut,h1,za},{xa+cut,h1,zb},{xa,h1,zb-cut}})
    cap({{xb-cut,h1,za},{xb,h1,za+cut},{xb,h1,zb-cut},{xb-cut,h1,zb}})
   else
    cap({{xa,h1,za},{xb,h1,za},{xb,h1,zb},{xa,h1,zb}})
   end
   local nxt=runs[k+1]
   if nxt then
    local nw=nxt.r-nxt.l+1
    if nw<w or depth(nw)<d then
     local vb=T+(B-T)*(run.y1+.5)/16
     local uv={}
     for i,xx in ipairs({xa,xb,xb,xa})do uv[i]={U(xx),vb} end
     quad({{xa,h0,zb},{xb,h0,zb},{xb,h0,za},{xa,h0,za}},uv,.5)
    end
   end
   if run.gl and night then
    local ga,gb=x0+run.gl,x0+run.gr+1
    local y0,y1=h0+base,h1+base
    local z1,z2=zb+M.LIFT,za-M.LIFT
    local t={{0,0},{1,0},{1,1},{0,1}}
    sinks.quad(night.glass.v,night.glass.i,{{ga,y1,z1},{gb,y1,z1},{gb,y0,z1},{ga,y0,z1}},t,1)
    sinks.quad(night.glass.v,night.glass.i,{{gb,y1,z2},{ga,y1,z2},{ga,y0,z2},{gb,y0,z2}},t,1)
   end
  end
 end
 if night then
  local cx,cz=x0+M.AXIS_X,zc
  local r=M.POOL_R
  local y=base+M.LIFT
  local function uvOf(x,z)return {.5+(x-cx)/(2*r),.5+(z-cz)/(2*r)} end
  for gy=math.floor((cz-r)/16),math.floor((cz+r)/16)do
   for gx=math.floor((cx-r)/16),math.floor((cx+r)/16)do
    local n=cells[gx..':'..gy]
    if lit(n,c) then
     local ax,bx=math.max(gx*16,cx-r),math.min(gx*16+16,cx+r)
     local az,bz=math.max(gy*16,cz-r),math.min(gy*16+16,cz+r)
     if bx>ax and bz>az then
      sinks.quad(night.pool.v,night.pool.i,{{ax,y,az},{bx,y,az},{bx,y,bz},{ax,y,bz}},{uvOf(ax,az),uvOf(bx,az),uvOf(bx,bz),uvOf(ax,bz)},1)
     end
    end
   end
  end
 end
end

function M.finish(cache,sinks)
 local R=V.require('Voxel3D')
 local out={}
 for _,l in ipairs(sinks.lamps)do
  local lamp={x=l.x,y=l.y,z=l.z}
  if #l.glass.v>0 then lamp.glass=R.newMesh(l.glass.v,l.glass.i) end
  if #l.pool.v>0 then lamp.pool=R.newMesh(l.pool.v,l.pool.i) end
  if lamp.glass or lamp.pool then out[#out+1]=lamp end
 end
 if #out>0 then cache.lamps=out end
end
function M.release(cache)
 for _,l in ipairs(cache and cache.lamps or {})do
  if l.glass then l.glass:release() end
  if l.pool then l.pool:release() end
 end
 if cache then cache.lamps=nil end
end

local poolImage,whiteImage
local function images()
 if not poolImage then
  local n=64
  local data=love.image.newImageData(n,n)
  for y=0,n-1 do for x=0,n-1 do
   local dx,dy=(x+.5)/(n/2)-1,(y+.5)/(n/2)-1
   local w=1-(dx*dx+dy*dy)
   data:setPixel(x,y,1,1,1,w>0 and w*w or 0)
  end end
  poolImage=love.graphics.newImage(data);poolImage:setFilter('linear','linear');poolImage:setWrap('clamp','clamp');data:release()
  local one=love.image.newImageData(1,1);one:setPixel(0,0,1,1,1,1)
  whiteImage=love.graphics.newImage(one);one:release()
 end
 return poolImage,whiteImage
end
function M.invalidate()
 if poolImage then poolImage:release();poolImage=nil end
 if whiteImage then whiteImage:release();whiteImage=nil end
end

local function haze(R,x,y,z)
 local f=R.fog
 if not (f and (f.density or 0)>0) then return 0 end
 local o,run=f.origin
 if f.bounds and o then
  local b=f.bounds
  local sx=x<o[1] and o[1]-b[1] or b[3]-o[1]
  local sz=z<o[3] and o[3]-b[2] or b[4]-o[3]
  run=math.max(math.abs(x-o[1])/math.max(sx,1),math.abs(z-o[3])/math.max(sz,1))
 elseif o then run=math.sqrt((x-o[1])^2+(z-o[3])^2)
 elseif R.eye then run=math.sqrt((x-R.eye[1])^2+(y-R.eye[2])^2+(z-R.eye[3])^2)
 else return 0 end
 return (1-math.exp(-f.density*math.max(0,run-(f.start or 0))))*math.exp(-math.max(y,0)*(f.heightK or 0))
end

function M.draw(cache,R,strength)
 local list=cache and cache.lamps
 if not list or not strength or strength<=.003 then return end
 local pool,white=images()
 R.withEffect('alpha',function()
  for _,l in ipairs(list)do
   local k=strength*(1-haze(R,l.x,l.y+16,l.z))
   if k>.01 then
    if l.pool then
     love.graphics.setColor(M.POOL[1],M.POOL[2],M.POOL[3],k*M.POOL_ALPHA)
     R.draw(l.pool,pool)
    end
    if l.glass then
     love.graphics.setColor(M.GLASS[1],M.GLASS[2],M.GLASS[3],k*M.GLASS_ALPHA)
     R.draw(l.glass,white)
    end
   end
  end
 end)
end
return M
