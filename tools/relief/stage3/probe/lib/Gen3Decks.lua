-- Stepped decks the cartridge rates flat (Opus; the Abandoned Ship's deck:
-- its hull walls and cabin fronts lay flat on one floor, the doorways holes
-- in it).
--
-- The drawing is oblique: every deck is drawn over the wall that carries it.
-- A deck h px up is drawn h px higher on screen than where it stands, so in
-- 3D (screen row = depth - height) it stands h px up AND h px further south
-- than drawn; the rows of wall, doors and stairs under its front edge are
-- one upright face on the deck below, 16 px of height per drawn row. The
-- player's camera then sees every pixel where it is drawn.
--   level(cx,cy): the height of the deck a cell belongs to (its floor, rails
--     and whatever stands on it), or nil
--   wall(cx,cy): for a cell of an upright face, the height of the deck at
--     its foot, or nil
-- Gen3Elevation pins the walkable floor to the same heights (stairs are
-- flights between them) and sets every lifted vertex back by its lift;
-- Gen3Scene sets the characters and the camera back the same way.
local V=...
local M={MAPS={}}

do
 local SEA,MAIN,MID,TOP=0,48,80,112
 local ship={w=23,h=21,side={0x35D,8,8},steps={[0x0AF]=true,[0x0CF]=true,[0x2CE]=true,[0x2CF]=true}}
 function ship.wall(x,y)
  if y>=13 and y<=15 then return SEA end                  -- the hull under the main deck, the stairs down and their posts
  if y>=8 and y<=9 and x>=3 and x<=14 then return MAIN end -- the mid deck's front: posts, doors, stairs
  if y>=6 and y<=9 and x>=14 then return MAIN end          -- the top deck's tall front with its portholes
  if y>=4 and y<=5 and x>=7 and x<=13 then return MID end  -- the bridge's front
 end
 function ship.level(x,y)
  if ship.wall(x,y) then return nil end
  if y>=16 then return SEA end
  if y>=10 or x<=2 then return MAIN end
  if x>=14 or (x>=7 and y<=3) then return TOP end
  return MID
 end
 M.MAPS.EM_ABANDONED_SHIP_DECK=ship
end

-- The Battle Pyramid's top (rated with alternating elevations 4/6 that only
-- keep its terraces apart): a stepped pyramid seen from the front. Each
-- terrace is a purple tread row with the brown riser row under it, the stairs
-- up the middle (column 17), and on both sides a wing of sunlit brick two
-- columns wide running back to the pyramid's rear edge -- the wing next to
-- the stairs belongs to the top tread, each wing further out to the next
-- tread down. The orange sky and the sun behind are an upright backdrop at
-- the rear edge (backdrop.z), each sky pixel at the height that shows it
-- where it is drawn.
do
 local C=17
 local function tread(t)return 32+8*(21-t) end           -- height of the tread drawn on (odd) row t
 local top={w=34,h=23,side={0x240,2,2},steps={[0x251]=true},noBorder=true,backdrop={z=248,sky={0x27D,0x285,0x23B,0x243,0x24B,0x253,0x25B,0x281}}}
 function top.wall(x,y)
  if y>=10 and y<=22 and y%2==0 and math.abs(x-C)<=y-9 then return tread(y+1) end
 end
 function top.level(x,y)
  if top.wall(x,y) then return nil end
  local dx=math.abs(x-C)
  if y>=11 and y<=21 and y%2==1 and dx<=y-10 then return tread(y) end
  if dx<=1 then return 128 end                            -- the summit
  local wing=x<C and math.floor((C-x)/2) or math.floor((x-C)/2)
  return math.max(0,128-16*wing)
 end
 M.MAPS.EM_BATTLE_FRONTIER_BATTLE_PYRAMID_TOP=top
end

-- (w,h: the drawn map; the engine's layout carries one more column and row)
-- The Battle Pyramid's lobby (furniture session: "a flat navy slab"): the
-- back half of the hall is a floor 48 px up. Its front wall is drawn under
-- its edge -- three rows, sandstone at the sides, deep navy in the recesses
-- beside the stairs -- and stands as one face; the stairs between the two
-- sandstone parapets are a ramp from the upper floor down to the lower one
-- (five drawn rows: 48 px of rise over 32 px of run).
do
 local H=48
 local lobby={w=15,h=18,side={0x21C,8,8},steps={[0x224]=true},ramp={x0=6,x1=8,y0=8,y1=12,h=H}}
 local function inRamp(x,y)return x>=6 and x<=8 and y>=8 and y<=12 end
 function lobby.wall(x,y)if y>=10 and y<=12 and not inRamp(x,y) then return 0 end end
 function lobby.level(x,y)
  if inRamp(x,y) or lobby.wall(x,y) then return nil end
  return y<=9 and H or 0
 end
 -- (the three walkable cells on the west wall's top row are the upper floor's edge)
 function lobby.pinAt(x,y)if y==10 and x<=2 then return H end end
 M.MAPS.EM_BATTLE_FRONTIER_BATTLE_PYRAMID_LOBBY=lobby
end

-- Trainer Hill's roof: the roof floor with everything on it stands 80 px up,
-- over the five rows of the tower's front drawn under its parapet (one
-- upright face); the tiles beyond the rails (0x36B, blocked) are the same
-- roof floor.
do
 -- The teal bands behind (0x380/0x385/0x367) are the sky and the horizon: a
 -- backdrop at the roof's rear edge. Whatever stands on the roof stands on
 -- roof tiles (ground), not on the lobby's green floor.
 local roof={w=25,h=16,side={0x39F,8,8},steps={},noBorder=true,floor={[0x36B]=true},ground=0x36B,
  -- (beside the tower's head only: its own roof is drawn with the same tiles)
  backdrop={z=144,only=true,sky={0x380,0x385,0x367,0x3BF},at=function(x,y)return y<=3 and (x<=6 or x>=18) end}}
 -- The roof's front edge is a V (the tower's two front faces meet at its
 -- middle): edge(X) is the drawn row of the edge line in pixel column X.
 -- Above it is roof floor, from it down the parapet and the tower's front
 -- standing under that point of the edge -- so the front is a V in plan too.
 roof.edgeFrom=10
 function roof.edge(X)
  if X<98 then return 160 end
  if X<192 then return 161+math.floor((X-98)/2) end
  if X<208 then return 208 end
  return math.max(160,207-math.floor((X-208)/2))
 end
 -- the seven bollards before the edge (furniture session's measurements):
 -- drawn over two cells, each a 6 px wide, 12 px tall post; its drawing on
 -- the floor is replaced by plain roof tile
 roof.posts={cols={[9]=true,[10]=true,[11]=true,[12]=true,[13]=true,[14]=true,[15]=true},
  x0=5,x1=10,top=172,r0=173,r1=184,depth=3,floorMid=0x36B,blank={4,172,11,184}}
 -- The tower's head on the roof (pixel columns 112..290, rows 0..111): a
 -- block with its corner toward the viewer and a roof over it. Per pixel
 -- column, from its drawn foot up: 25 px of wall standing at the foot, then
 -- the roof rising back at 45 degrees -- every pixel where the player's
 -- camera draws it; the two porches' fronts stand where their feet are drawn.
 roof.head={x0=112,x1=290,rows=112,wall=25,cx0=7,cx1=17,cy1=6,floorMid=0x36B}
 function roof.wall(x,y)if y>=11 then return 0 end end
 function roof.level(x,y)if y<=10 then return 80 end end
 M.MAPS.EM_TRAINER_HILL_ROOF=roof
end

local function inMap(def,x,y)
 local d=M.MAPS[def.id or '']
 return x>=0 and y>=0 and x<math.min(def.midLayout.width,d and d.w or 1e9) and y<math.min(def.midLayout.height,d and d.h or 1e9)
end

-- before props and stairs are claimed: face cells are neither
-- backdrop: how much of a tile is sky (0 none, 1 some, 2 all), per pixel
local function pixel(ts,slot,x,y)
 local X,Y=slot%ts.cols*16+x,math.floor(slot/ts.cols)*16+y
 local r,g,b=ts.imageData:getPixel(X,Y)
 if ts.overImageData then local rr,gg,bb,aa=ts.overImageData:getPixel(X,Y)
  if aa>0 then r,g,b=rr*aa+r*(1-aa),gg*aa+g*(1-aa),bb*aa+b*(1-aa) end end
 return math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)
end
local function skyOf(d,ts)
 if ts.deckSky then return ts.deckSky end
 local set={}
 if ts.imageData then
  for _,m in ipairs(d.backdrop.sky)do local s=ts.midToSlot[m]
   if s then for y=0,15 do for x=0,15 do set[pixel(ts,s,x,y)]=true end end end
  end
 end
 ts.deckSky=set;return set
end
local function skyRows(d,c)
 local ts=c.ts;ts.deckRows=ts.deckRows or {}
 local hit=ts.deckRows[c.mid]
 if hit==nil then
  hit=false
  local s=ts.midToSlot[c.mid]
  if s and ts.imageData then
   local sky=skyOf(d,ts);local n=0;local rows={}
   for y=0,15 do local row={}
    for x=0,15 do local k=sky[pixel(ts,s,x,y)] or false;row[x]=k;if k then n=n+1 end end
    rows[y]=row
   end
   hit={n=n,rows=rows}
  end
  ts.deckRows[c.mid]=hit
 end
 return hit
end
function M.prepare(cells,def)
 local d=def and M.MAPS[def.id];if not d then return end
 -- (noBorder: nothing stands round the map -- its border blocks are more sky)
 if d.noBorder then
  for k,c in pairs(cells)do if not inMap(def,c.cx,c.cy) then cells[k]=nil end end
 end
 for _,c in pairs(cells)do
  if inMap(def,c.cx,c.cy) then
   local r=d.ramp
   if r and c.cx>=r.x0 and c.cx<=r.x1 and c.cy>=r.y0 and c.cy<=r.y1 then
    c.shape={kind='deckRamp'};c.noFurniture=true
   elseif d.edge and c.cy>=d.edgeFrom then
    c.shape={kind='deckEdge'};c.noFurniture=true
   elseif d.head and c.cx>=d.head.cx0 and c.cx<=d.head.cx1 and c.cy<=d.head.cy1 and c.mid~=d.head.floorMid then
    c.shape={kind='deckHead'};c.noFurniture=true
   elseif d.wall(c.cx,c.cy) then
    c.shape={kind='deckFace',ground=c.shape and c.shape.ground};c.noFurniture=true
   elseif d.floor and d.floor[c.mid] and (c.collision or 0)~=0 then
    c.shape={kind='deckFloor'};c.noFurniture=true
   elseif d.backdrop and d.backdrop.only then
    -- (only the sky's own tiles: what stands on the deck shares their colours)
    if not d.backdrop.at or d.backdrop.at(c.cx,c.cy) then
     for _,m in ipairs(d.backdrop.sky)do if m==c.mid then c.shape={kind='deckBack'};c.noFurniture=true;break end end
    end
   elseif d.backdrop then
    local q=skyRows(d,c)
    if q and q.n==256 then c.shape={kind='deckBack'};c.noFurniture=true
    elseif q and q.n>0 then c.shape={kind='deckMixed'};c.noFurniture=true
    -- (a blocked brick cell is the same deck floor as the walkable ones)
    elseif (c.collision or 0)~=0 and not d.backdrop.only then c.shape={kind='deckFloor'};c.noFurniture=true
    elseif not d.backdrop.only then c.shape={kind='flat',reviewedSurface=true};c.noFurniture=true end
   end
  end
 end
end
-- after the heights are bound: every cell stands on its own deck
function M.settle(cells,def)
 local d=def and M.MAPS[def.id];if not d then return end
 for _,c in pairs(cells)do
  if inMap(def,c.cx,c.cy) then
   local h=d.wall(c.cx,c.cy) or d.level(c.cx,c.cy)
   -- (an edge cell is built in absolute heights)
   if c.shape and (c.shape.kind=='deckEdge' or c.shape.kind=='deckHead' or c.shape.kind=='deckRamp') then c.base=0;c.stairs=nil;c.column=nil;c.prop=nil
   elseif h then
    c.base=h
    if c.shape and c.shape.kind=='deckFace' then c.stairs=nil end
    local g=c.column and c.column.group or c.civic or c.prop
    if g then g.groundHeight=h end
    if d.ground and c.shape and c.shape.ground and c.shape.ground~=d.ground and c.shape.kind~='deckFace' then
     local copy={};for k,v in pairs(c.shape)do copy[k]=v end;copy.ground=d.ground;c.shape=copy
    end
   end
  end
 end
end

-- one cell of an upright face: its drawn row at its height over the deck at
-- the face's foot (positions relative to that deck: the scene lifts them)
-- the head's foot row per pixel column (the lowest drawn row that is not roof floor, plus one)
local headFeet=setmetatable({},{__mode='k'})
local function feet(d,cells,ts)
 local F=headFeet[cells];if F then return F end
 F={};headFeet[cells]=F
 local hd=d.head
 local floor={}
 local fs=ts.midToSlot[hd.floorMid]
 if fs and ts.imageData then for y=0,15 do for x=0,15 do floor[pixel(ts,fs,x,y)]=true end end end
 for X=hd.x0,hd.x1 do
  for r=hd.rows-1,0,-1 do
   local n=cells[math.floor(X/16)..':'..math.floor(r/16)]
   local sl=n and n.ts and n.ts.imageData and n.ts.midToSlot[n.mid]
   if not sl then break end
   if not floor[pixel(n.ts,sl,X%16,r%16)] then F[X]=r+1;break end
  end
 end
 return F
end
function M.append(def,c,quad,uvFor,cells)
 local d=M.MAPS[def.id];local uv=uvFor(c.ts,c.mid);if not (d and uv) then return end
 if c.shape.kind=='deckRamp' then
  -- (absolute: the cell's own level is 0) each drawn row of the stairs at
  -- its height on the slope, set back by that height
  local r=d.ramp
  local function at(Y)local t=(Y-r.y0*16)/((r.y1-r.y0+1)*16);local h=r.h*(1-t);return h,Y+h end
  local x=c.cx*16
  local ha,za=at(c.cy*16);local hb,zb=at(c.cy*16+16)
  quad({{x,ha,za},{x+16,ha,za},{x+16,hb,zb},{x,hb,zb}},uv,1)
  return
 end
 if c.shape.kind=='deckHead' then
  local hd=d.head
  local H=d.level(c.cx,c.cy) or 0
  local F=feet(d,cells,c.ts)
  local X0,R0=c.cx*16,c.cy*16
  -- where the drawing's row r of column X stands: height, depth
  local function at(X,r)
   local f=F[X]
   if not f or r>=f then return H,r+H end
   if r>=f-hd.wall then return H+(f-r),f+H end
   local dd=(f-hd.wall)-r
   return H+hd.wall+dd/2,f+H-dd/2
  end
  for x=0,15 do
   local X=X0+x
   local f=F[X]
   local cuts={R0,R0+16}
   -- (cut at the next column's own zone ends too, so the step between them closes without gaps)
   local fnext=F[X+1]
   for _,ff in ipairs({f or false,fnext or false})do
    if ff then for _,q in ipairs({ff-hd.wall,ff})do if q>R0 and q<R0+16 then cuts[#cuts+1]=q end end end
   end
   table.sort(cuts)
   for i=1,#cuts-1 do
    local a,b=cuts[i],cuts[i+1]         -- drawn rows a..b-1
    local u0=uv[1][1]+(uv[2][1]-uv[1][1])*x/16
    local u1=uv[1][1]+(uv[2][1]-uv[1][1])*(x+1)/16
    local v0=uv[1][2]+(uv[3][2]-uv[1][2])*(a-R0)/16
    local v1=uv[1][2]+(uv[3][2]-uv[1][2])*(b-R0)/16
    local t={{u0,v0},{u1,v0},{u1,v1},{u0,v1}}
    -- (a hair inside the zone, so each end takes its own zone's place)
    local ya,za=at(X,a+.001);local yb,zb=at(X,b-.001)
    local shade=(f and a<f and a>=f-hd.wall) and .9 or 1
    quad({{X,ya,za},{X+1,ya,za},{X+1,yb,zb},{X,yb,zb}},t,shade)
    -- the step to the next column (its foot stands elsewhere)
    local fn=F[X+1]
    if fn~=f and (f or fn) and a<math.max(f or 0,fn or 0) then
     local yc,zc=at(X+1,a+.001);local yd,zd=at(X+1,b-.001)
     -- (in the face's own shade: the drawn slant is one surface, not a comb)
     quad({{X+1,ya,za},{X+1,yc,zc},{X+1,yd,zd},{X+1,yb,zb}},t,math.abs((fn or 0)-(f or 0))<=2 and shade or .8)
    end
   end
   -- the back, at the map's top row
   if f and c.cy==0 then
    local yt,zt=at(X,0)
    local u=uv[1][1]+(uv[2][1]-uv[1][1])*(x+.5)/16;local v=uv[1][2]+(uv[3][2]-uv[1][2])*.5/16
    quad({{X+1,yt,zt},{X,yt,zt},{X,H,zt},{X+1,H,zt}},{{u,v},{u,v},{u,v},{u,v}},.62)
   end
  end
  return
 end
 if c.shape.kind=='deckEdge' then
  local H=d.level(c.cx,d.edgeFrom-1) or 0
  local X0,R0=c.cx*16,c.cy*16
  -- a strip of pixel column x, tile rows a..b, of a tile's uv
  local function strip(t,x,a,b)
   local u0=t[1][1]+(t[2][1]-t[1][1])*x/16
   local u1=t[1][1]+(t[2][1]-t[1][1])*(x+1)/16
   local v0=t[1][2]+(t[3][2]-t[1][2])*a/16
   local v1=t[1][2]+(t[3][2]-t[1][2])*(b+1)/16
   return {{u0,v0},{u1,v0},{u1,v1},{u0,v1}}
  end
  local P=d.posts
  local plain=P and uvFor(c.ts,P.floorMid)
  local post=P and P.cols[c.cx]
  local function floor(x,a,b,t)      -- drawn rows a..b of column x, flat on the roof
   if b<a then return end
   local X=X0+x
   quad({{X,H,a+H},{X+1,H,a+H},{X+1,H,b+1+H},{X,H,b+1+H}},strip(t,x,a-R0,b-R0),1)
  end
  for x=0,15 do
   local X=X0+x
   local e=d.edge(X)
   local a,b=R0,math.min(R0+15,e-1)
   if b>=a then
    if post and plain and x>=P.blank[1] and x<=P.blank[3] then
     -- (the bollard's own drawing: plain tile under the standing one)
     local m0,m1=math.max(a,P.blank[2]),math.min(b,P.blank[4])
     if m1>=m0 then floor(x,a,m0-1,uv);floor(x,m0,m1,plain);floor(x,m1+1,b,uv)
     else floor(x,a,b,uv) end
    else floor(x,a,b,uv) end
   end
   a,b=math.max(R0,e),R0+15
   if b>=a then
    local zf=e+H+.1
    local h1,h0=H-(a-e),H-(b+1-e)
    local t=strip(uv,x,a-R0,b-R0)
    quad({{X,h1,zf},{X+1,h1,zf},{X+1,h0,zf},{X,h0,zf}},t,.9)
    -- (the edge steps a pixel back or forward to the next column: close the step)
    local en=X+1<(d.w or 1e9)*16 and d.edge(X+1) or e
    if en~=e then
     local zn=en+H+.1
     quad({{X+1,h1,math.min(zf,zn)},{X+1,h1,math.max(zf,zn)},{X+1,h0,math.max(zf,zn)},{X+1,h0,math.min(zf,zn)}},t,.9)
    end
   end
  end
  -- the bollard, built by the cell its foot stands in
  if post and math.floor(P.r1/16)==c.cy then
   local function px(x,r)
    local n=cells and cells[c.cx..':'..math.floor(r/16)]
    local t=n and uvFor(n.ts,n.mid)
    return t and strip(t,x,r%16,r%16)
   end
   local xa,xb=X0+P.x0,X0+P.x1+1
   local zf=P.r1+1+H;local zb=zf-P.depth
   for r=P.r0,P.r1 do
    local h=H+(P.r1-r)
    for x=P.x0,P.x1 do
     local t=px(x,r)
     if t then
      quad({{X0+x,h+1,zf},{X0+x+1,h+1,zf},{X0+x+1,h,zf},{X0+x,h,zf}},t,.92)
      quad({{X0+x+1,h+1,zb},{X0+x,h+1,zb},{X0+x,h,zb},{X0+x+1,h,zb}},t,.64)
     end
    end
    local tl,tr=px(P.x0,r),px(P.x1,r)
    if tl then quad({{xa,h+1,zb},{xa,h+1,zf},{xa,h,zf},{xa,h,zb}},tl,.74) end
    if tr then quad({{xb,h+1,zf},{xb,h+1,zb},{xb,h,zb},{xb,h,zf}},tr,.8) end
   end
   local ht=H+(P.r1-P.r0)+1
   for x=P.x0,P.x1 do
    local t=px(x,P.top)
    if t then quad({{X0+x,ht,zb},{X0+x+1,ht,zb},{X0+x+1,ht,zf},{X0+x,ht,zf}},t,1) end
   end
  end
  return
 end
 if c.shape.kind=='deckFloor' then
  local x0,z0=c.cx*16,c.cy*16
  quad({{x0,0,z0},{x0+16,0,z0},{x0+16,0,z0+16},{x0,0,z0+16}},uv,1)
  return
 end
 if c.shape.kind=='deckBack' or c.shape.kind=='deckMixed' then
  -- sky on the backdrop, the rest flat on the cell's own deck; one strip per
  -- run of pixels in a row. (Relative to the deck: the scene lifts and sets
  -- back the cell by its height.)
  local base=d.level(c.cx,c.cy) or 0
  local Zb=d.backdrop.z
  local x0,z0=c.cx*16,c.cy*16
  local q=skyRows(d,c)
  local function strip(a,b,y,sky)
   local u0=uv[1][1]+(uv[2][1]-uv[1][1])*a/16
   local u1=uv[1][1]+(uv[2][1]-uv[1][1])*(b+1)/16
   local v0=uv[1][2]+(uv[3][2]-uv[1][2])*y/16
   local v1=uv[1][2]+(uv[3][2]-uv[1][2])*(y+1)/16
   local t={{u0,v0},{u1,v0},{u1,v1},{u0,v1}}
   local r=z0+y
   if sky and r<Zb then
    local h1=Zb-r-base
    quad({{x0+a,h1,Zb-base},{x0+b+1,h1,Zb-base},{x0+b+1,h1-1,Zb-base},{x0+a,h1-1,Zb-base}},t,1)
   elseif sky then
    quad({{x0+a,-base,r-base},{x0+b+1,-base,r-base},{x0+b+1,-base,r+1-base},{x0+a,-base,r+1-base}},t,1)
   else
    quad({{x0+a,0,r},{x0+b+1,0,r},{x0+b+1,0,r+1},{x0+a,0,r+1}},t,1)
   end
  end
  if q and q.n==256 and z0+16<=Zb then
   local h1=Zb-z0-base
   quad({{x0,h1,Zb-base},{x0+16,h1,Zb-base},{x0+16,h1-16,Zb-base},{x0,h1-16,Zb-base}},uv,1)
  elseif q then
   for y=0,15 do local row=q.rows[y];local a=0
    while a<=15 do local b=a
     while b<15 and row[b+1]==row[a] do b=b+1 end
     strip(a,b,y,row[a]);a=b+1
    end
   end
  end
  return
 end
 local low=d.wall(c.cx,c.cy)
 local y1=c.cy
 while inMap(def,c.cx,y1+1) and d.wall(c.cx,y1+1)==low do y1=y1+1 end
 local x,zf=c.cx*16,(y1+1)*16+.1
 local h0=(y1-c.cy)*16
 quad({{x,h0+16,zf},{x+16,h0+16,zf},{x+16,h0,zf},{x,h0,zf}},uv,.9)
end

-- a deck cell's sides down to a lower deck beside it (or to the sea at the
-- map's edge), in the hull's colour
function M.skirt(def,c,quad,uvFor)
 local d=M.MAPS[def.id];if not d then return end
 local h=d.level(c.cx,c.cy);if not h or h<=0 then return end
 local t=uvFor(c.ts,d.side[1]);if not t then return end
 local u=t[1][1]+(t[2][1]-t[1][1])*(d.side[2]+.5)/16
 local v=t[1][2]+(t[3][2]-t[1][2])*(d.side[3]+.5)/16
 local sw={{u,v},{u,v},{u,v},{u,v}}
 local function beside(x,y)
  if not inMap(def,x,y) then return 0 end
  return d.level(x,y) or d.wall(x,y) or 0
 end
 local x,z=c.cx*16,c.cy*16
 local n=beside(c.cx-1,c.cy)
 if n<h then quad({{x,0,z},{x,0,z+16},{x,n-h,z+16},{x,n-h,z}},sw,.74) end
 n=beside(c.cx+1,c.cy)
 if n<h then quad({{x+16,0,z+16},{x+16,0,z},{x+16,n-h,z},{x+16,n-h,z+16}},sw,.8) end
 n=beside(c.cx,c.cy-1)
 if n<h then quad({{x+16,0,z},{x,0,z},{x,n-h,z},{x+16,n-h,z}},sw,.62) end
 -- (to the south a face cell carries the drawn wall; a lower deck with no wall drawn takes a plain front)
 if inMap(def,c.cx,c.cy+1) and not d.wall(c.cx,c.cy+1) then
  n=beside(c.cx,c.cy+1)
  if n<h then quad({{x,0,z+16},{x+16,0,z+16},{x+16,n-h,z+16},{x,n-h,z+16}},sw,.88) end
 end
end
return M
