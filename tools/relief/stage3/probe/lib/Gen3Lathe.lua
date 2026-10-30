-- Round things drawn from the front (Slateport's lighthouse; Opus, user:
-- "please also fix the lighthouse near slateport"), turned in 3D.
--
-- Every drawn row of the object is a ring as wide as the drawing's outline in
-- that row, its front the row's own pixels, one unit per row, stacked at the
-- height that puts each row where it is drawn at the player's camera (screen
-- row = depth - height). Built per pixel column: a column stands at the
-- ring's front (and back) edge for its place across the ring, so the ring is
-- round, never a box; ledges close the steps between rings, sides close the
-- steps between columns. Nothing stretched: every face is one art pixel.
local V=...
local M={}
M.DEPTH=.85     -- ring depth as a share of its width

local function key(r,g,b)return math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)end

-- spec: {x0,y0,x1,y1 (cells), ground={mids}}; owner = the bottom-left cell
function M.owns(c,spec)return c.cx==spec.x0 and c.cy==spec.y1 end

function M.append(c,cells,spec,quad,uvFor)
 local ts=c.ts;if not ts.imageData then return end
 local W,H=(spec.x1-spec.x0+1)*16,(spec.y1-spec.y0+1)*16
 local ground={}
 for _,m in ipairs(spec.ground)do
  local s=ts.midToSlot[m]
  if s then local ox,oy=s%ts.cols*16,math.floor(s/ts.cols)*16
   for y=0,15 do for x=0,15 do local r,g,b=ts.imageData:getPixel(ox+x,oy+y);ground[key(r,g,b)]=true end end end
 end
 -- drawing pixel -> (cell, tile pixel); composite the over layer
 local function at(px,py)
  local n=cells[(spec.x0+math.floor(px/16))..':'..(spec.y0+math.floor(py/16))]
  if not n then return end
  local s=ts.midToSlot[n.mid];if not s then return end
  local X,Y=s%ts.cols*16+px%16,math.floor(s/ts.cols)*16+py%16
  local r,g,b=ts.imageData:getPixel(X,Y)
  if ts.overImageData then local rr,gg,bb,aa=ts.overImageData:getPixel(X,Y)
   if aa>0 then r,g,b=rr*aa+r*(1-aa),gg*aa+g*(1-aa),bb*aa+b*(1-aa) end end
  return n,r,g,b
 end
 local function uvpx(px,py)
  local n=cells[(spec.x0+math.floor(px/16))..':'..(spec.y0+math.floor(py/16))]
  local t=n and uvFor(ts,n.mid);if not t then return end
  local u=t[1][1]+(t[2][1]-t[1][1])*(px%16+.5)/16
  local v=t[1][2]+(t[3][2]-t[1][2])*(py%16+.5)/16
  return {{u,v},{u,v},{u,v},{u,v}}
 end
 -- outline per row
 local span={}
 local foot
 for py=0,H-1 do
  local l,r
  for px=0,W-1 do local n,cr,cg,cb=at(px,py);if n and not ground[key(cr,cg,cb)] then l=l or px;r=px end end
  if l then span[py]={l,r};foot=py end
 end
 if not foot then return end
 local maxW=0
 for _,s in pairs(span)do maxW=math.max(maxW,s[2]-s[1]+1) end
 local X0=spec.x0*16
 local zf=spec.y0*16+foot+1                 -- the front of the bottom row
 local zc=zf-maxW*M.DEPTH/2
 -- spec.axis: one vertical axis for the whole body (the median of the rows'
 -- centres), each row's radius reaching its own outline from that axis and
 -- changing at most 1 px from the row below: a tower drawn with its top a
 -- little off-centre stands straight, with no shoulder
 local AX,RAD
 if spec.axis then
  local cs={}
  for _,s2 in pairs(span)do cs[#cs+1]=(s2[1]+s2[2]+1)/2 end
  table.sort(cs);AX=cs[math.ceil(#cs/2)]
  RAD={}
  -- (the base stands straight on the ground: the lowest rows -- the rounded
  -- bottom of the drawing -- keep the widest radius among them)
  local baseR=0
  for py=foot,math.max(0,foot-5),-1 do local s2=span[py]
   if s2 then baseR=math.max(baseR,AX-s2[1],s2[2]+1-AX) end end
  local prev
  for py=foot,0,-1 do local s2=span[py]
   if s2 then
    local r=math.max(AX-s2[1],s2[2]+1-AX)
    if py>=foot-5 then r=baseR
    elseif prev then r=math.max(prev-1,math.min(prev+1,r)) end
    RAD[py]=r;prev=r
   end
  end
 end
 local function dzOf(py,px)
  local s=span[py];if not s or px<s[1] or px>s[2] then return nil end
  local cx,rx=(s[1]+s[2]+1)/2,(s[2]-s[1]+1)/2
  if AX then cx,rx=AX,math.max(RAD[py],math.abs(px+.5-AX)+.01) end
  local t=(px+.5-cx)/rx
  return rx*M.DEPTH*math.sqrt(math.max(.05,1-t*t))
 end
 for py=0,foot do local s=span[py]
  if s then
   local h0=foot-py;local h1=h0+1
   for px=s[1],s[2] do
    local t=uvpx(px,py)
    if t then
     local d=dzOf(py,px);local a,b=X0+px,X0+px+1
     quad({{a,h1,zc+d},{b,h1,zc+d},{b,h0,zc+d},{a,h0,zc+d}},t,.9)
     quad({{b,h1,zc-d},{a,h1,zc-d},{a,h0,zc-d},{b,h0,zc-d}},t,.62)
     -- the ledge above (where the row above is narrower here, or absent)
     local du=dzOf(py-1,px) or 0
     if du<d then
      quad({{a,h1,zc+du},{b,h1,zc+du},{b,h1,zc+d},{a,h1,zc+d}},t,1)
      quad({{a,h1,zc-d},{b,h1,zc-d},{b,h1,zc-du},{a,h1,zc-du}},t,1)
     end
     -- sides: between this column and the next, and at the ring's ends
     local dn=dzOf(py,px+1)
     if px==s[2] then dn=0 end
     if dn<d then
      quad({{b,h1,zc+d},{b,h1,zc+dn},{b,h0,zc+dn},{b,h0,zc+d}},t,.78)
      quad({{b,h1,zc-dn},{b,h1,zc-d},{b,h0,zc-d},{b,h0,zc-dn}},t,.7)
     end
     local dp=dzOf(py,px-1)
     if px==s[1] then dp=0 end
     if dp<d then
      quad({{a,h1,zc+dp},{a,h1,zc+d},{a,h0,zc+d},{a,h0,zc+dp}},t,.74)
      quad({{a,h1,zc-d},{a,h1,zc-dp},{a,h0,zc-dp},{a,h0,zc-d}},t,.68)
     end
    end
   end
  end
 end
end

-- A real tower (user: "its a weird ball shape at the bottom. make it a real
-- tower"). Slateport's lighthouse is drawn from steeply above, so turning its
-- rows gave two squat balls. Here it is built as a lighthouse: a tall round
-- drum with the drawn door at its foot, a gallery ledge, the lantern room with
-- its dark window band, and the domed roof -- every face one pixel of the
-- drawing (the drum's extra height repeats its plain wall row).
-- spec.tower = {cx (art column of the axis), sections bottom-up:
--   {r=radius, h=height, rows=function(y) -> art row for height y above the section's foot}
--   {disc=radius, row=art row}  a flat ledge at the current height}
M.SEG=20
function M.tower(c,cells,spec,quad,uvFor)
 local ts=c.ts
 local function uvpx(px,py)
  px=math.max(0,math.min((spec.x1-spec.x0+1)*16-1,math.floor(px)))
  local n=cells[(spec.x0+math.floor(px/16))..':'..(spec.y0+math.floor(py/16))]
  local t=n and uvFor(ts,n.mid);if not t then return end
  local u=t[1][1]+(t[2][1]-t[1][1])*(px%16+.5)/16
  local v=t[1][2]+(t[3][2]-t[1][2])*(py%16+.5)/16
  return {{u,v},{u,v},{u,v},{u,v}}
 end
 local T=spec.tower
 local CX=spec.x0*16+T.cx
 local CZ=(spec.y1+1)*16-T.base      -- the axis: the drawn foot minus the base radius
 local N=M.SEG
 local y=0
 local function ring(r,y0,y1,row)
  for k=0,N-1 do
   local a0,a1=(k/N)*2*math.pi,((k+1)/N)*2*math.pi
   local am=(a0+a1)/2
   -- angle 0 faces south (the camera); art column by the segment's place across the drum
   -- (kept inside the drawing's dark outline columns at the drum's edges)
   local col=T.cx+math.max(1,r-3)*math.sin(am)*(math.cos(am)>=0 and 1 or -1)
   local t=uvpx(col,row)
   if t then
    local x0,z0=CX+r*math.sin(a0),CZ+r*math.cos(a0)
    local x1,z1=CX+r*math.sin(a1),CZ+r*math.cos(a1)
    local shade=.72+.2*math.cos(am)+.06*math.sin(am)
    quad({{x0,y1,z0},{x1,y1,z1},{x1,y0,z1},{x0,y0,z0}},t,shade)
   end
  end
 end
 local function disc(r,yy,row)
  for dz=-r,r-1 do
   local w=math.sqrt(math.max(0,r*r-(dz+.5)^2))
   local t=uvpx(T.cx,row)
   if t and w>0 then quad({{CX-w,yy,CZ+dz},{CX+w,yy,CZ+dz},{CX+w,yy,CZ+dz+1},{CX-w,yy,CZ+dz+1}},t,1) end
  end
 end
 for _,sec in ipairs(T.sections)do
  if sec.disc then disc(sec.disc,y,sec.row)
  else
   for k=0,sec.h-1 do ring(sec.r,y+k,y+k+1,sec.rows(k)) end
   y=y+sec.h
  end
 end
end
return M
