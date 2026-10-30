-- Battle Frontier flower planters: one raised bed built from the composed art of all its cells. The rim is a kerb
-- 5 px high (its top the rim art, its faces the rim's edge colour); the soil inside stands 3 px up; every flower
-- pixel stands 6 px above the soil (its blossom colour on top and on its sides), so from a low camera the bed
-- is a kerbed planter full of standing flowers, closed on every side. One art pixel = one voxel column.
-- Claimed by Gen3Scene's extrude branch through M.owns (planter cells keep their paving under them).
local V=...
local M={}

M.PAIR='general__battle_frontier_outside_west'
M.RIM={[0x208]=true,[0x209]=true,[0x20A]=true,[0x218]=true,[0x219]=true,[0x21A]=true}
M.SOIL={[0x210]=true,[0x211]=true,[0x212]=true}
M.RIM_H=5                -- the kerb
M.SOIL_H=3               -- the soil inside
M.FLOWER_H=6             -- a flower stands this far above the soil
local info=setmetatable({},{__mode='k'})

local function planterMid(c)return c.pair==M.PAIR and (M.RIM[c.mid] or M.SOIL[c.mid]) and true or false end
M.owns=function(c)return planterMid(c)end

-- the planter group of a cell: every planter cell connected to it (8-neighbours), with its canvas
local function group(c,cells,pred,cache)
 pred=pred or planterMid;cache=cache or info
 local t=cache[cells];if not t then t={};cache[cells]=t end
 local key=c.cx..':'..c.cy
 if t[key] then return t[key] end
 local g={cells={},minx=c.cx,maxx=c.cx,miny=c.cy,maxy=c.cy}
 local todo={c}
 local seen={[key]=true}
 while #todo>0 do
  local n=table.remove(todo)
  g.cells[#g.cells+1]=n
  if n.cx<g.minx then g.minx=n.cx end
  if n.cx>g.maxx then g.maxx=n.cx end
  if n.cy<g.miny then g.miny=n.cy end
  if n.cy>g.maxy then g.maxy=n.cy end
  for dy=-1,1 do for dx=-1,1 do
   local k=(n.cx+dx)..':'..(n.cy+dy)
   local m=cells[k]
   if not seen[k] and m and m.ts==c.ts and pred(m) then seen[k]=true;todo[#todo+1]=m end
  end end
 end
 for _,n in ipairs(g.cells) do t[n.cx..':'..n.cy]=g end
 return g
end

-- the composed pixel of a group at (x,y) of its canvas: the cell, its height and whether the over layer draws it
-- (a tile's pixels classed once per tileset - (h, over) or false - and a bed's pixels sampled one cell
-- at a time as they are first asked for: without the JIT, sampling every pixel of the Battle Frontier's
-- long beds, most of them outside the first view, was a large share of its first view)
local classMemo=setmetatable({},{__mode='k'})
function M.newBuild()classMemo=setmetatable({},{__mode='k'})end   -- (Gen3Scene, as each build starts: animated tiles change)
local function classed(ts,kind,mid,classify)
 local t=classMemo[ts];if not t then t={};classMemo[ts]=t end
 local k=kind..mid
 local e=t[k]
 if not e then e={};for i=0,255 do e[i]=classify(i%16,math.floor(i/16)) or false end;t[k]=e end
 return e
end
local sampleRaw
local function sample(c,cells,g,x,y)
 local cx,cy=g.minx+math.floor(x/16),g.miny+math.floor(y/16)
 local n=cells[cx..':'..cy]
 if not n or n.ts~=c.ts or not planterMid(n) then return nil end
 local lx,ly=x%16,y%16
 local e=classed(c.ts,'p',n.mid,function(px,py)return sampleRaw(c.ts,n,px,py)end)[ly*16+lx]
 if not e then return nil end
 return {cell=n,h=e[1],over=e[2],lx=lx,ly=ly}
end
sampleRaw=function(ts,n,lx,ly)
 local slot=ts.midToSlot[n.mid];if not slot then return nil end
 local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
 local ar,ag,ab,aa=0,0,0,0
 local orr,og,ob,oa=0,0,0,0
 if ts.overImageData then orr,og,ob,oa=ts.overImageData:getPixel(ox+lx,oy+ly) end
 local mr,mg,mb,ma=ts.imageData:getPixel(ox+lx,oy+ly)
 local over=oa>.5
 local opaque=over or ma>.5
 if not opaque then return nil end
 local r,gg,b=mr,mg,mb
 if over then r,gg,b=orr,og,ob end
 local green=gg>r*1.1 and gg>b*1.05
 -- a flower is a white or red blossom (the orange wall and the dark outline are not)
 local flower=(math.min(r,gg,b)>.9) or (r>.7 and gg<.47 and r-gg>.35)
 local h
 if M.RIM[n.mid] then h=M.RIM_H
 elseif green then h=M.SOIL_H
 elseif flower then h=M.SOIL_H+M.FLOWER_H
 else h=M.RIM_H end
 return {h,over}
end

-- emit(vertices,uv,shade) for the floor atlas, emitOver for the over-layer atlas
function M.append(c,emit,emitOver,uvFor,cells)
 local g=group(c,cells)
 local W,H=(g.maxx-g.minx+1)*16,(g.maxy-g.miny+1)*16
 local ox,oz=g.minx*16,g.miny*16
 -- the group's pixels are sampled once; each cell emits only its own columns
 local px=g.px
 if not px then px={};g.px=px;g.pxDone={} end
 local done=g.pxDone
 local function at(x,y)
  if x<0 or y<0 or x>=W or y>=H then return nil end
  local b=math.floor(y/16)*4096+math.floor(x/16)
  if not done[b] then
   done[b]=true
   local x0,y0=x-x%16,y-y%16
   for yy=y0,y0+15 do for xx=x0,x0+15 do px[yy*W+xx]=sample(c,cells,g,xx,yy) end end
  end
  return px[y*W+x]
 end
 local function hgt(x,y)local s=at(x,y);return s and s.h or 0 end
 local function sub(uv,l,t,r,b)
  local function p(x,y)return {uv[1][1]+(uv[2][1]-uv[1][1])*x/16,uv[1][2]+(uv[3][2]-uv[1][2])*y/16}end
  return {p(l,t),p(r,t),p(r,b),p(l,b)}
 end
 -- (only this cell's own 16x16 pixels can be its: scanning the whole bed for every cell of it was most
 -- of the Battle Frontier's first view without the JIT)
 local cx0,cy0=(c.cx-g.minx)*16,(c.cy-g.miny)*16
 for y=math.max(0,cy0),math.min(H-1,cy0+15) do
  local x=math.max(0,cx0)
  while x<math.min(W,cx0+16) do
   local s=at(x,y)
   if not s or s.cell~=c then x=x+1 else
    -- the tops of a run of pixels of one cell, one height and one layer: one quad
    local e=x+1
    while e<W and (e%16)~=0 do
     local t=at(e,y)
     if not t or t.cell~=c or t.h~=s.h or t.over~=s.over then break end
     e=e+1
    end
    local uv=uvFor(c.ts,s.cell.mid)
    if uv then
     local out=s.over and emitOver or emit
     local wx,wz=ox+x,oz+y
     local lx,ly=s.lx,s.ly
     out({{wx,s.h,wz},{wx+(e-x),s.h,wz},{wx+(e-x),s.h,wz+1},{wx,s.h,wz+1}},sub(uv,lx,ly,lx+(e-x),ly+1),1)
    end
    for xx=x,e-1 do
     local q=at(xx,y)
     local uvq=uvFor(c.ts,c.mid)
     if uvq then
      local out=q.over and emitOver or emit
      local wx,wz=ox+xx,oz+y
      local t=sub(uvq,q.lx,q.ly,q.lx+1,q.ly+1)
      local hn=hgt(xx,y-1)
      if hn<q.h then out({{wx+1,q.h,wz},{wx,q.h,wz},{wx,hn,wz},{wx+1,hn,wz}},t,.55) end
      hn=hgt(xx,y+1)
      if hn<q.h then out({{wx,q.h,wz+1},{wx+1,q.h,wz+1},{wx+1,hn,wz+1},{wx,hn,wz+1}},t,.62) end
      hn=hgt(xx-1,y)
      if hn<q.h then out({{wx,q.h,wz},{wx,q.h,wz+1},{wx,hn,wz+1},{wx,hn,wz}},t,.78) end
      hn=hgt(xx+1,y)
      if hn<q.h then out({{wx+1,q.h,wz+1},{wx+1,q.h,wz},{wx+1,hn,wz},{wx+1,hn,wz+1}},t,.84) end
     end
    end
    x=e
   end
  end
 end
 return true
end

-- The Battle Frontier West's south flower beds (rows 52-55 of general__battle_frontier_outside_west, x 14-22 and
-- 30-39): each bed is one planter 16 px high. Its brown walls and green soil lie on top at that height, every flower
-- stands 6 px above the soil, the south wall's art stands 1:1 as its face down to the ground, and the other faces
-- take their pixel's colour. Owned by tile AND box AND adjacency to a flower: other 0x004 flowers are not touched.
M.BED_MAP='EM_BATTLE_FRONTIER_OUTSIDE_WEST'
M.BED_FLOWER={[0x004]=true}
M.BED_WALL={[0x074]=true,[0x078]=true,[0x079]=true,[0x07A]=true,[0x07C]=true,[0x089]=true,[0x09F]=true,[0x0A9]=true}
M.BED_BOX={{14,22},{30,39}}      -- the two beds' columns (cx); rows 52-55 below
M.BED_ROWS={52,55}
M.BED_H=16                       -- the walls and the soil: one cell of art
M.BED_FLOWER_H=6                 -- a flower stands this far above the soil
local bedInfo=setmetatable({},{__mode='k'})

local function inBed(c)
 if c.cy<M.BED_ROWS[1] or c.cy>M.BED_ROWS[2] then return false end
 for _,b in ipairs(M.BED_BOX) do if c.cx>=b[1] and c.cx<=b[2] then return true end end
 return false
end
local function bedMid(c)
 if c.pair~=M.PAIR or not inBed(c) then return false end
 return ((M.BED_FLOWER[c.mid] and (c.collision or 0)==0) or (M.BED_WALL[c.mid] and c.collision==7)) and true or false
end
local function bedCell(m)return m.bedPlanter==true end

-- Claims the bed cells for this planter (Gen3Scene calls it before Mass reads the cells). Each group of bed cells
-- that touches a flower is hidden from the rock masses (its shape is 'bedPlanter' until restore) and marked
-- bedPlanter. Returns the saved shapes for restore.
function M.prepare(cells,def)
 if not def or def.id~=M.BED_MAP then return nil end
 local cand={}
 for _,c in pairs(cells)do
  if c.mid and c.ts and c.ts.midToSlot[c.mid] and bedMid(c) then cand[c.cx..':'..c.cy]=c end
 end
 local saved,seen={},{}
 for k,c0 in pairs(cand)do
  if not seen[k] then
   local todo,list,flower={c0},{},false
   seen[k]=true
   while #todo>0 do
    local n=table.remove(todo)
    list[#list+1]=n
    if M.BED_FLOWER[n.mid] then flower=true end
    for dy=-1,1 do for dx=-1,1 do
     local kk=(n.cx+dx)..':'..(n.cy+dy)
     local m=cand[kk]
     if m and not seen[kk] and m.ts==n.ts then seen[kk]=true;todo[#todo+1]=m end
    end end
   end
   if flower then for _,n in ipairs(list)do
    saved[#saved+1]={c=n,shape=n.shape}
    n.shape={kind='bedPlanter'};n.bedPlanter=true
   end end
  end
 end
 return saved
end
function M.restore(saved)
 for _,s in ipairs(saved or {})do s.c.shape=s.shape end
end

-- the composed pixel of a bed group at (x,y) of its canvas: the cell, its height, its layer and whether it is a wall
local bedRaw
local function bedSample(c,cells,g,x,y)
 local cx,cy=g.minx+math.floor(x/16),g.miny+math.floor(y/16)
 local n=cells[cx..':'..cy]
 if not n or n.ts~=c.ts or not n.bedPlanter then return nil end
 local lx,ly=x%16,y%16
 local e=classed(c.ts,'b',n.mid,function(px,py)return bedRaw(c.ts,n,px,py)end)[ly*16+lx]
 if not e then return nil end
 return {cell=n,h=e[1],over=e[2],lx=lx,ly=ly,wall=e[3]}
end
bedRaw=function(ts,n,lx,ly)
 local slot=ts.midToSlot[n.mid];if not slot then return nil end
 local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
 local orr,og,ob,oa=0,0,0,0
 if ts.overImageData then orr,og,ob,oa=ts.overImageData:getPixel(ox+lx,oy+ly) end
 local mr,mg,mb,ma=ts.imageData:getPixel(ox+lx,oy+ly)
 local over=oa>.5
 if not (over or ma>.5) then return nil end
 local r,gg,b=mr,mg,mb
 if over then r,gg,b=orr,og,ob end
 local wall=M.BED_WALL[n.mid] and true or false
 -- a blossom is warm (red or peach); the soil and the leaves are green or teal
 local blossom=(not wall) and r>gg*1.1 and r>b
 local h=M.BED_H+(blossom and M.BED_FLOWER_H or 0)
 return {h,over,wall}
end

-- emit(vertices,uv,shade) for the floor atlas, emitOver for the over-layer atlas (Gen3Scene's bed branch)
function M.appendBed(c,emit,emitOver,uvFor,cells)
 local g=group(c,cells,bedCell,bedInfo)
 local W,H=(g.maxx-g.minx+1)*16,(g.maxy-g.miny+1)*16
 local ox,oz=g.minx*16,g.miny*16
 local px=g.bedPx
 if not px then px={};g.bedPx=px;g.bedDone={} end
 local done=g.bedDone
 local function at(x,y)
  if x<0 or y<0 or x>=W or y>=H then return nil end
  local b=math.floor(y/16)*4096+math.floor(x/16)
  if not done[b] then
   done[b]=true
   local x0,y0=x-x%16,y-y%16
   for yy=y0,y0+15 do for xx=x0,x0+15 do px[yy*W+xx]=bedSample(c,cells,g,xx,yy) end end
  end
  return px[y*W+x]
 end
 local function hgt(x,y)local s=at(x,y);return s and s.h or 0 end
 local function sub(uv,l,t,r,b)
  local function p(x,y)return {uv[1][1]+(uv[2][1]-uv[1][1])*x/16,uv[1][2]+(uv[3][2]-uv[1][2])*y/16}end
  return {p(l,t),p(r,t),p(r,b),p(l,b)}
 end
 local uv=uvFor(c.ts,c.mid)
 if not uv then return true end
 -- (only this cell's own 16x16 pixels can be its: scanning the whole bed for every cell of it was most
 -- of the Battle Frontier's first view without the JIT)
 local cx0,cy0=(c.cx-g.minx)*16,(c.cy-g.miny)*16
 for y=math.max(0,cy0),math.min(H-1,cy0+15) do
  local x=math.max(0,cx0)
  while x<math.min(W,cx0+16) do
   local s=at(x,y)
   if not s or s.cell~=c then x=x+1 else
    -- the tops of a run of pixels of one cell, one height and one layer: one quad
    local e=x+1
    while e<W and (e%16)~=0 do
     local t=at(e,y)
     if not t or t.cell~=c or t.h~=s.h or t.over~=s.over then break end
     e=e+1
    end
    local out=s.over and emitOver or emit
    local wx,wz=ox+x,oz+y
    out({{wx,s.h,wz},{wx+(e-x),s.h,wz},{wx+(e-x),s.h,wz+1},{wx,s.h,wz+1}},sub(uv,s.lx,s.ly,s.lx+(e-x),s.ly+1),1)
    for xx=x,e-1 do
     local q=at(xx,y)
     local outq=q.over and emitOver or emit
     local wxq,wzq=ox+xx,oz+y
     local t=sub(uv,q.lx,q.ly,q.lx+1,q.ly+1)
     -- a side: the pixel's own colour on a low step; a taller one (a bed's 16 px edge) shows the tile's own
     -- column stood up 1:1, its rows from the top down, a tile's height at a time - one pixel stretched
     -- down the whole wall stood as streaks in first person
     local T,B=uv[1][2],uv[3][2]
     local u0=uv[1][1]+(uv[2][1]-uv[1][1])*q.lx/16
     local u1=uv[1][1]+(uv[2][1]-uv[1][1])*(q.lx+1)/16
     local function side(hn,shade,mk)
      if not q.wall and q.h-hn<=2 then outq(mk(q.h,hn),t,shade);return end
      local yy=q.h
      while yy>hn do
       local hb=math.min(16,yy-hn);local bp=T+(B-T)*hb/16
       outq(mk(yy,yy-hb),{{u0,T},{u1,T},{u1,bp},{u0,bp}},shade);yy=yy-hb
      end
     end
     local hn=hgt(xx,y-1)
     if hn<q.h then side(hn,.55,function(a,b)return {{wxq+1,a,wzq},{wxq,a,wzq},{wxq,b,wzq},{wxq+1,b,wzq}}end) end
     hn=hgt(xx,y+1)
     if hn<q.h then side(hn,.62,function(a,b)return {{wxq,a,wzq+1},{wxq+1,a,wzq+1},{wxq+1,b,wzq+1},{wxq,b,wzq+1}}end) end
     hn=hgt(xx-1,y)
     if hn<q.h then side(hn,.78,function(a,b)return {{wxq,a,wzq},{wxq,a,wzq+1},{wxq,b,wzq+1},{wxq,b,wzq}}end) end
     hn=hgt(xx+1,y)
     if hn<q.h then side(hn,.84,function(a,b)return {{wxq+1,a,wzq+1},{wxq+1,a,wzq},{wxq+1,b,wzq},{wxq+1,b,wzq+1}}end) end
    end
    x=e
   end
  end
 end
 return true
end
return M
