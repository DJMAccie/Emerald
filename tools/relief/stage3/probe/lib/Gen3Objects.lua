-- Generic standing objects for Emerald's outdoor maps.
--
-- Benches, lamp posts, boulders, planters, mailboxes, boats: blocked art that
-- no table names. Rather than guess a hull per metatile, every small connected
-- group of blocked, unclassified cells is cut out of the ground its walkable
-- neighbours use (pixel by pixel: a pixel identical to the ground tile at the
-- same position is ground) and stood up as a slab of its own pixels. The walk-
-- behind row above it (art on the layer over the player) joins the drawing.
--
-- Guards: only outdoor maps; only small groups (large blocked masses are
-- terrain: mountain tops, crater rock, forest); never a group touching cliff,
-- cave wall or reviewed blocked ground (those are fragments of a cliff rim);
-- never a cell some other recipe (building, prop, stairs, boundary) owns.
-- Presentation only: collision and behaviour are untouched.
local V=...
local M={}

M.MAX_CELLS=12
M.MAX_SPAN=4      -- cells, each axis
M.MIN_INK=.06     -- share of the group's pixels that must be object, not ground
M.log=false

local function blocked(c)return c and c.collision and c.collision~=0 and c.collision~=0xff end
local function unknown(c)
 return c and not c.boundary and not c.prop and not c.civic and not c.column and not c.stairs and not c.gym
  and c.shape and c.shape.kind=='flat' and (c.shape.seaRock or not c.shape.reviewedSurface)
end
local FRAGMENT={cliff=true,caveWall=true,rock=true}
local function rim(c)
 -- a neighbour that marks this group as part of a cliff or rock mass
 if not c then return false end
 if FRAGMENT[c.shape and c.shape.kind] then return true end
 return blocked(c) and c.shape and c.shape.kind=='flat' and c.shape.reviewedSurface
end
local function walkableGround(c)
 return c and not blocked(c) and not c.boundary and c.shape and (c.shape.kind=='flat' or c.shape.kind=='grass')
end

local function key(x,y)return x..':'..y end

-- Pixel access through the provider's composited art (bottom+middle in
-- imageData, the above-player layer in overImageData).
local function livePixel(ts,x,y)
 local r,g,b,a=ts.imageData:getPixel(x,y)
 if ts.overImageData then local rr,gg,bb,aa=ts.overImageData:getPixel(x,y)
  if aa>0 then r,g,b,a=rr*aa+r*(1-aa),gg*aa+g*(1-aa),bb*aa+b*(1-aa),math.max(a,aa) end
 end
 return r,g,b,a
end
-- Everything this file asks of the tileset's pixels (rock or ground, how an object is cut from its ground)
-- is asked of the art as it was drawn, before src/core/game3/tileset_anim.lua repaints any of it: the
-- animation frame on screen when a map is built must not decide whether a boulder is rock. Gen3Objects wraps
-- TilesetAnim.bindPair (called as each atlas arrives, before its first repaint) to keep a copy of the atlas
-- pixels. An atlas bound before this module loaded is copied on first use if no animation bank has run on it
-- yet; otherwise it is read live. (Drawing still uses the live atlas.)
local okAnim,Anim=pcall(require,'src.core.game3.tileset_anim')
if not okAnim then Anim=nil end
local still
if Anim then
 still=Anim._stillAtlas
 if not still then
  still=setmetatable({},{__mode='k'});Anim._stillAtlas=still
  local bind=Anim.bindPair
  if bind then Anim.bindPair=function(pair,atlas,...)
   if atlas and atlas.imageData and still[atlas]==nil then
    still[atlas]={under=atlas.imageData:clone(),over=atlas.overImageData and atlas.overImageData:clone() or nil}
   end
   return bind(pair,atlas,...)
  end end
 end
end
local function pristine(ts)
 local entry=Anim and Anim._pairs and Anim._pairs[ts.pair]
 if not entry then return true end
 if entry.rse then for _,b in ipairs(entry.banks)do if b and b.frame~=nil then return false end end return true end
 return next(entry.frames or {})==nil
end
local function stillOf(ts)
 if not still then return nil end
 local s=still[ts]
 if s==nil then
  if ts.imageData and pristine(ts) then
   s={under=ts.imageData:clone(),over=ts.overImageData and ts.overImageData:clone() or nil}
  else s=false end
  still[ts]=s
 end
 return s or nil
end
local function overData(ts)
 local s=stillOf(ts)
 return s and s.over or ts.overImageData
end
local function pixel(ts,x,y)
 local s=stillOf(ts)
 if not s then return livePixel(ts,x,y) end
 local r,g,b,a=s.under:getPixel(x,y)
 if s.over then local rr,gg,bb,aa=s.over:getPixel(x,y)
  if aa>0 then r,g,b,a=rr*aa+r*(1-aa),gg*aa+g*(1-aa),bb*aa+b*(1-aa),math.max(a,aa) end
 end
 return r,g,b,a
end
local function underPixel(ts,x,y)
 local s=stillOf(ts)
 local r,g,b=(s and s.under or ts.imageData):getPixel(x,y)
 return r,g,b
end
local function origin(ts,mid)
 local slot=ts.midToSlot[mid];if not slot then return end
 return slot%ts.cols*16,math.floor(slot/ts.cols)*16
end
local function same(r1,g1,b1,r2,g2,b2)
 return math.abs(r1-r2)<.002 and math.abs(g1-g2)<.002 and math.abs(b1-b2)<.002
end
-- A drop shadow the artist painted on the ground: the ground pixel at the
-- same spot, darkened by one factor on every channel. It belongs to the
-- ground, not to the object standing up.
local function shade(r,g,b,R,G,B)
 if R<.08 or G<.08 or B<.08 then return false end
 local a,c,d=r/R,g/G,b/B
 local k=(a+c+d)/3
 return k>=.45 and k<=.9 and math.abs(a-k)<.07 and math.abs(c-k)<.07 and math.abs(d-k)<.07
end
-- 16x16 boolean mask: true where the cell's drawing is object, not ground.
-- grounds: every walkable tile around the group. A pixel identical to any of
-- them at the same position is ground (a lamp half in a building's shadow
-- stands on two paving tiles).
-- (one answer per tile, ground list and colour set within a build: a field of planters or trees asks
-- the same question cell after cell, and without the JIT those asks were the largest share of Battle
-- Frontier West's first view. Gen3Scene clears it as each build starts - animated tiles change.)
local cutMemo=setmetatable({},{__mode='k'})
local cutTag=setmetatable({},{__mode='k'})
local cutTags=0
local waterSets=setmetatable({},{__mode='k'})
function M.newBuild()cutMemo=setmetatable({},{__mode='k'});waterSets=setmetatable({},{__mode='k'})end
local cutRaw
function M.cut(ts,mid,grounds,noPeel,byColour)
 if not (ts and ts.imageData) then return end
 local tag=''
 if byColour then
  tag=cutTag[byColour]
  if not tag then cutTags=cutTags+1;tag='#'..cutTags;cutTag[byColour]=tag end
 end
 local k=mid..'|'..table.concat(grounds,',')..'|'..(noPeel and 1 or 0)..tag
 local byTs=cutMemo[ts];if not byTs then byTs={};cutMemo[ts]=byTs end
 local e=byTs[k]
 if not e then e={cutRaw(ts,mid,grounds,noPeel,byColour)};byTs[k]=e end
 return e[1],e[2]
end
cutRaw=function(ts,mid,grounds,noPeel,byColour)
 if not (ts and ts.imageData) then return end
 local ox,oy=origin(ts,mid);if not ox then return end
 local refs={}
 for _,g in ipairs(grounds)do local gx,gy=origin(ts,g);if gx then refs[#refs+1]={gx,gy}end end
 if #refs==0 then return end
 local mask,n={},0
 for y=0,15 do for x=0,15 do
  local r,g,b,a=pixel(ts,ox+x,oy+y)
  local ink=a>.5
  if ink and byColour and (byColour[math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)]
   or (b>r*1.25 and b>g*1.05)) then ink=false end   -- water and the shading drawn around a rock in it
  if ink then for _,ref in ipairs(refs)do
   -- the ground is what lies UNDER things: a ground tile that carries canopy on the over-player layer (a
   -- Dewford crown tile) must not erase an identical crown drawn on the cell above or below it
   local R,G,B=underPixel(ts,ref[1]+x,ref[2]+y)
   if same(r,g,b,R,G,B) or (not noPeel and shade(r,g,b,R,G,B))then ink=false;break end
  end end
  mask[y*16+x]=ink or nil
 end end
 -- Edge clean-up: the ground under an object is often a variant of its
 -- neighbours' tile (another grass pattern). Peel inward from the cut edge,
 -- at most two pixels, through pixels whose colour the main ground uses.
 -- Only the main ground's colours: a secondary neighbour (a pond's rim, a
 -- path edge) shares outline colours with the object and would hollow it.
 if noPeel then local n=0;for _ in pairs(mask)do n=n+1 end;return mask,n end
 local palette={}
 for _,ref in ipairs({refs[1]})do for y=0,15 do for x=0,15 do
  local R,G,B=underPixel(ts,ref[1]+x,ref[2]+y)
  palette[math.floor(R*255+.5)*65536+math.floor(G*255+.5)*256+math.floor(B*255+.5)]=true
 end end end
 local function groundColour(x,y)
  local r,g,b=pixel(ts,ox+x,oy+y)
  return palette[math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)]
 end
 local stack={}
 for y=0,15 do for x=0,15 do
  if mask[y*16+x] and (x==0 or y==0 or x==15 or y==15 or not mask[y*16+x-1] or not mask[y*16+x+1]
   or not mask[(y-1)*16+x] or not mask[(y+1)*16+x]) and groundColour(x,y) then
   mask[y*16+x]=nil;stack[#stack+1]={x,y,1}
  end
 end end
 while #stack>0 do
  local p=table.remove(stack)
  -- at most two pixels deep: a fringe, never a way into the drawing
  if p[3]<2 then for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
   local x,y=p[1]+d[1],p[2]+d[2]
   if x>=0 and y>=0 and x<16 and y<16 and mask[y*16+x] and groundColour(x,y) then
    mask[y*16+x]=nil;stack[#stack+1]={x,y,p[3]+1}
   end
  end end
 end
 local n=0;for _ in pairs(mask)do n=n+1 end
 return mask,n
end
-- Over-layer pixels of a walkable cell (the part of an object drawn above the
-- player), cut against the same ground.
local function overInk(ts,mid)
 if not (ts and ts.overImageData) then return 0 end
 local ox,oy=origin(ts,mid);if not ox then return 0 end
 local n=0
 for y=0,15 do for x=0,15 do
  local _,_,_,a=overData(ts):getPixel(ox+x,oy+y);if a>.5 then n=n+1 end
 end end
 return n
end

-- Rock rims. A blocked, unclassified cell touching a cliff is usually the
-- rim of that same mass (a corner, an edge the tables do not list). It joins
-- the cliff when its drawing is made of the cliff's own colours: a sign or a
-- fence beside a rock face shares too little of its palette to be taken.
M.MATERIAL=.6
local palettes=setmetatable({},{__mode='k'})
local function colourKey(r,g,b)return math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)end
local function paletteOf(ts,mid)
 local t=palettes[ts];if not t then t={};palettes[ts]=t end
 if t[mid]~=nil then return t[mid] end
 local ox,oy=origin(ts,mid);if not ox then t[mid]=false;return false end
 local set={}
 for y=0,15 do for x=0,15 do local r,g,b,a=pixel(ts,ox+x,oy+y);if a>.5 then set[colourKey(r,g,b)]=true end end end
 t[mid]=set;return set
end
local function share(ts,mid,sets)
 local ox,oy=origin(ts,mid);if not ox then return 0 end
 local hit,n=0,0
 for y=0,15 do for x=0,15 do
  local r,g,b,a=pixel(ts,ox+x,oy+y)
  if a>.5 then n=n+1;local k=colourKey(r,g,b)
   for _,set in ipairs(sets)do if set[k] then hit=hit+1;break end end
  end
 end end
 return n>0 and hit/n or 0
end
function M.joinRock(cells,outdoor)
 if not outdoor then return 0 end
 local joined=0
 for _=1,8 do
  local add={}
  for _,c in pairs(cells)do
   -- a boulder in the sea is its own stone: a cliff beside it must not swallow it
   if blocked(c) and unknown(c) and not c.shape.seaRock and c.ts and c.ts.imageData then
    local sets,like={},nil
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local n=cells[key(c.cx+d[1],c.cy+d[2])]
     if n and n.pair==c.pair and n.shape and n.shape.kind=='cliff' then
      local set=paletteOf(c.ts,n.mid);if set then sets[#sets+1]=set end
      like=like or n.shape
     end
    end
    if #sets>0 and share(c.ts,c.mid,sets)>=M.MATERIAL then add[#add+1]={c,like} end
   end
  end
  if #add==0 then break end
  for _,a in ipairs(add)do local c,like=a[1],a[2]
   -- the rim takes the profile of the mass it joins (cliff or bank)
   c.shape={kind='cliff',height=like.height or 32,bank=like.bank,slope=like.slope,
    ground=like.ground or c.shape.ground,cap=c.mid,side=c.mid,joined=true}
  end
  joined=joined+#add
 end
 return joined
end

-- Rock drawn as texture. Crater walls, sea-stack islands and rock fields are
-- painted with a few tiles repeated over and over; a building, a pyramid or
-- a shop front is a drawing of one-off tiles. A blocked, unclassified cell is
-- rock when its tile repeats (M.REPEAT or more times in view), its pixels are
-- neither foliage-green nor water-blue, and it sits in a thick mass (not a
-- fence line). A mass sharing an original group with a door is a building
-- unless rock makes up most of it. Rock becomes a bank: a mound draped with
-- its own drawing (Gen3Terrain).
M.REPEAT=6
M.BANK_HEIGHT=24
M.BANK_SLOPE=14
local DOOR={[0x60]=true,[0x69]=true}
local tones=setmetatable({},{__mode='k'})
local function tone(ts,mid)
 local t=tones[ts];if not t then t={};tones[ts]=t end
 if t[mid] then return t[mid][1],t[mid][2] end
 local ox,oy=origin(ts,mid);if not ox then t[mid]={1,1};return 1,1 end
 local green,blue,n=0,0,0
 for y=0,15 do for x=0,15 do
  local r,g,b,a=pixel(ts,ox+x,oy+y)
  if a>.5 then n=n+1
   if g>r*1.1 and g>b*1.05 then green=green+1 end
   if b>r*1.15 and b>=g then blue=blue+1 end
  end
 end end
 t[mid]={green/math.max(n,1),blue/math.max(n,1)}
 return t[mid][1],t[mid][2]
end
local function flood(set,start,same)
 local list,stack={}, {start};local seen={[start]=true}
 while #stack>0 do
  local c=table.remove(stack);list[#list+1]=c
  for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
   local n=set[key(c.cx+d[1],c.cy+d[2])]
   if n and not seen[n] and n.pair==c.pair then seen[n]=true;stack[#stack+1]=n end
  end
 end
 return list,seen
end
function M.bank(cells,outdoor)
 if not outdoor then return 0 end
 local U,freq={}, {}
 for k,c in pairs(cells)do
  if blocked(c) and unknown(c) and c.ts and c.ts.imageData then
   U[k]=c;local f=freq[c.pair] or {};freq[c.pair]=f;f[c.mid]=(f[c.mid] or 0)+1
  end
 end
 local cand={}
 for k,c in pairs(U)do
  if freq[c.pair][c.mid]>=M.REPEAT then
   local green,blue=tone(c.ts,c.mid)
   if green<.2 and blue<.25 then cand[k]=c end
  end
 end
 local rock,done={}, {}
 for k,c in pairs(cand)do if not done[c] then
  local list,seen=flood(cand,c)
  for n in pairs(seen)do done[n]=true end
  local inner=0
  for _,m in ipairs(list)do
   local around=0
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do if seen[cand[key(m.cx+d[1],m.cy+d[2])] or false] then around=around+1 end end
   if around>=3 then inner=inner+1 end
  end
  if #list>=4 and inner>=.15*#list then for _,m in ipairs(list)do rock[m]=true end end
 end end
 -- buildings: an original group touching a door that is mostly drawing
 local checked={}
 for k,c in pairs(U)do if rock[c] and not checked[c] then
  local list,seen=flood(U,c)
  for n in pairs(seen)do checked[n]=true end
  local door,share=false,0
  for _,m in ipairs(list)do
   if rock[m] then share=share+1 end
   if DOOR[m.behavior] then door=true end
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    local n=cells[key(m.cx+d[1],m.cy+d[2])]
    if n and DOOR[n.behavior] then door=true end
   end
  end
  if door and share<.6*#list then for _,m in ipairs(list)do rock[m]=nil end end
 end end
 local count=0
 for c in pairs(rock)do
  c.shape={kind='cliff',bank=true,height=M.BANK_HEIGHT,slope=M.BANK_SLOPE,ground=c.shape.ground,cap=c.mid,side=c.mid}
  count=count+1
 end
 return count
end

-- A walkable neighbour votes for the ground an object is cut from. A tile
-- carrying art on the layer above the player (a canopy's overhang, a roof
-- edge) is not plain ground: it only counts when nothing else borders.
local function vote(votes,n)
 local w=(n.ts and n.ts.overImageData and overInk(n.ts,n.mid)>=8) and .01 or 1
 votes[n.mid]=(votes[n.mid] or 0)+w
end

-- Group the scene's cells. Returns the list of objects; each blocked member
-- gets c.object, each walk-behind member c.objectTop, the owner c.objectOwner.
-- Without pixel data (the offline audit) the ink tests are skipped.
M.RUN=4          -- cells per piece of a long fence line
M.GROVE=.45      -- mean foliage share that makes a large group a grove
M.GROVE_HEIGHT=22
M.GROVE_SLOPE=10
function M.prepare(cells,outdoor)
 local objects={}
 if not outdoor then return objects end
 -- One object from a list of blocked cells: ground vote, cut, walk-behind
 -- tops. orient='v' marks a north-south fence piece (drawn from above).
 local function build(list,orient,opts)
  opts=opts or {}
  local start=list[1]
  local x0,y0,x1,y1=start.cx,start.cy,start.cx,start.cy
  local member={};for _,c in ipairs(list)do member[c]=true
   x0,y0,x1,y1=math.min(x0,c.cx),math.min(y0,c.cy),math.max(x1,c.cx),math.max(y1,c.cy) end
  local votes={}
  for _,c in ipairs(list)do
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    local n=cells[key(c.cx+d[1],c.cy+d[2])]
    if n and not member[n] and n.pair==c.pair then
     if rim(n) and not opts.grove and not start.shape.seaRock then return end
     if start.shape.seaRock then
      if n.shape and n.shape.kind=='water' then vote(votes,n);votes[n.mid]=(votes[n.mid] or 0)+100 end
     elseif walkableGround(n) then
      vote(votes,n)
     end
    end
   end
  end
  if opts.ground then votes[opts.ground]=(votes[opts.ground] or 0)+100 end
  local ground,best=nil,0
  for mid,n in pairs(votes)do if n>best or (n==best and mid<ground) then ground,best=mid,n end end
  if start.shape.seaRock and not ground then
   for _,c in ipairs(list)do
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1},{2,0},{-2,0},{0,2},{0,-2}})do
     local n=cells[key(c.cx+d[1],c.cy+d[2])]
     if n and n.shape and n.shape.kind=='water' then ground=n.mid;votes[ground]=1000;break end
    end
    if ground then break end
   end
   ground=ground or 0x170
   votes[ground]=votes[ground] or 1
  end
  if not ground then return end
  local order={}
  for mid in pairs(votes)do order[#order+1]=mid end
  table.sort(order,function(a,b)if votes[a]~=votes[b] then return votes[a]>votes[b] end return a<b end)
  while #order>6 do order[#order]=nil end
  local ts=start.ts
  local gc;for _,c in ipairs(list)do for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do local n=cells[key(c.cx+d[1],c.cy+d[2])];if n and n.mid==ground then gc=n end end end
  local isWater=(gc and gc.shape and gc.shape.kind=='water') or (start.shape.seaRock and true) or false
  local o={cells=list,tops={},ground=ground,grounds=order,water=isWater,x0=x0,y0=y0,x1=x1,y1=y1,ts=ts,pair=start.pair,masks={},orient=orient}
  if ts and ts.imageData then
   local ink=0
   -- animated water: its frames never match the rock tile's water pixel for
   -- pixel, so in the sea every colour the water uses is water
   local byColour
   if o.water then
    local wk=table.concat(o.grounds,',')
    waterSets[ts]=waterSets[ts] or {}
    byColour=waterSets[ts][wk]
    if not byColour then
     byColour={}
     for _,g in ipairs(o.grounds)do local gx,gy=origin(ts,g)
      if gx then for yy=0,15 do for xx=0,15 do local r,g2,b=pixel(ts,gx+xx,gy+yy)
       byColour[math.floor(r*255+.5)*65536+math.floor(g2*255+.5)*256+math.floor(b*255+.5)]=true end end end
     end
     waterSets[ts][wk]=byColour
    end
   end
   for _,c in ipairs(list)do
    local mask,n=M.cut(ts,c.mid,o.grounds,nil,byColour);o.masks[c]=mask;ink=ink+(n or 0)
   end
   if ink<M.MIN_INK*256*#list then return end
   o.grove=opts.grove
   o.ink=ink/(256*#list)
  end
  -- walk-behind rows above: walkable, unclassified, carrying over-layer art
  -- (rising from every member cell: a cluster of trees keeps each tree's own crown row, not only the top row's)
  local top=y0
  local frontier=list
  for _=1,orient=='v' and 0 or M.TOP_ROWS do
   local row={}
   for _,below in ipairs(frontier)do
    local c=cells[key(below.cx,below.cy-1)]
    if c and c.pair==start.pair
     and not blocked(c) and unknown(c) and not c.object and not c.objectTop
     and (not (ts and ts.overImageData) or overInk(ts,c.mid)>=8) then
     row[#row+1]=c
     c.objectTop=o     -- claimed now so a second member below it does not add it twice
    end
   end
   if #row==0 then break end
   for _,c in ipairs(row)do
    o.tops[#o.tops+1]=c
    top=math.min(top,c.cy)
    local own={}
    -- never the top's own tile: it borders the group and was voted a ground
    for _,g in ipairs(o.grounds)do if g~=c.mid then own[#own+1]=g end end
    for _,d in ipairs({{1,0},{-1,0},{0,-1}})do
     local n=cells[key(c.cx+d[1],c.cy+d[2])]
     if n and n.pair==c.pair and walkableGround(n) and n.mid~=c.mid then own[#own+1]=n.mid end
    end
    -- a walk-behind top is over-layer art drawn on purpose: no fringe peel
    if ts and ts.imageData then o.masks[c]=M.cut(ts,c.mid,own,true) end
   end
   frontier=row
  end
  o.top=top
  for _,c in ipairs(list)do c.object=o end
  local owner=list[1]
  for _,c in ipairs(list)do if c.cy>owner.cy or (c.cy==owner.cy and c.cx<owner.cx) then owner=c end end
  owner.objectOwner=true;o.owner=owner
  objects[#objects+1]=o
  if M.log then
   local ids={};for _,c in ipairs(list)do ids[#ids+1]=string.format('%03X',c.mid)end
   print(('[EM obj] %s %d,%d-%d,%d %s tops=%d ink=%.2f ground=%03X %s'):format(start.pair,x0,y0,x1,y1,orient or '-',#o.tops,o.ink or -1,ground,table.concat(ids,'+')))
  end
  return o
 end
 -- Ash pines (Mt. Chimney, Jagged Pass): vertical runs of ash-tree cells, each tree closed by its base (0x2CC)
 do
  local starts={}
  for _,c in pairs(cells)do
   if c.shape and c.shape.ash and blocked(c) then
    local up=cells[key(c.cx,c.cy-1)]
    if not (up and up.pair==c.pair and up.shape and up.shape.ash and blocked(up)) then starts[#starts+1]=c end
   end
  end
  table.sort(starts,function(a,b)if a.cx~=b.cx then return a.cx<b.cx end return a.cy<b.cy end)
  for _,top in ipairs(starts)do
   local run,c={}, top
   while c and c.pair==top.pair and c.shape and c.shape.ash and blocked(c) do run[#run+1]=c;c=cells[key(c.cx,c.cy+1)] end
   local tree={}
   local function close()
    if #tree>0 then
     -- the floor the tree stands on: the commonest walkable ground within three cells
     local votes={}
     for dy=-3,3 do for dx=-3,3 do
      local n=cells[key(tree[1].cx+dx,tree[1].cy+dy)]
      if n and n.pair==tree[1].pair and walkableGround(n) and not (n.shape and n.shape.ash) then votes[n.mid]=(votes[n.mid] or 0)+1 end
     end end
     local ground,best=0x271,0
     for mid,k in pairs(votes)do if k>best or (k==best and mid<ground) then ground,best=mid,k end end
     local o=build(tree,nil,{grove=true,ground=ground,ash=true})
     if o then o.ashTree=true end
    end
    tree={}
   end
   for _,cell in ipairs(run)do
    tree[#tree+1]=cell
    if cell.mid==0x2CC or #tree>=M.ASH_TREE_CELLS then close() end
   end
   close()
  end
 end
 local seen={}
 local order={}
 local freq={}
 for k,c in pairs(cells)do if blocked(c) and unknown(c) and not c.object then
  order[#order+1]=c;freq[c.pair..':'..c.mid]=(freq[c.pair..':'..c.mid] or 0)+1
 end end
 table.sort(order,function(a,b)if a.cy~=b.cy then return a.cy<b.cy end return a.cx<b.cx end)
 for _,start in ipairs(order)do if not seen[start] then
  local list,stack={}, {start};seen[start]=true
  local set={}
  local x0,y0,x1,y1=start.cx,start.cy,start.cx,start.cy
  while #stack>0 do
   local c=table.remove(stack);list[#list+1]=c;set[key(c.cx,c.cy)]=c
   x0,y0,x1,y1=math.min(x0,c.cx),math.min(y0,c.cy),math.max(x1,c.cx),math.max(y1,c.cy)
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    local n=cells[key(c.cx+d[1],c.cy+d[2])]
    local seaMatch=(not not (start.shape and start.shape.seaRock))==(not not (n and n.shape and n.shape.seaRock))
    if n and not seen[n] and not n.object and blocked(n) and unknown(n) and n.pair==c.pair and seaMatch then seen[n]=true;stack[#stack+1]=n end
   end
  end
  local sea=true;for _,c in ipairs(list)do if not c.shape.seaRock then sea=false;break end end
  -- touching boulders in the sea form chains: let a chain stand as one object
  -- a long thin group (a fence with a post or two where it turns: Route 117's field fence) is a fence, not a boulder
  local span=math.max(x1-x0,y1-y0)+1
  local thin=not sea and span>=M.FENCE_SPAN and #list<=span*2
  if not sea and not thin then
   local all=true
   for _,c in ipairs(list)do if not (c.shape and c.shape.fenceLine) then all=false;break end end
   thin=all
  end
  local small=not thin and (sea and (#list<=64 and x1-x0<32 and y1-y0<12)
   or (#list<=M.MAX_CELLS and x1-x0<M.MAX_SPAN and y1-y0<M.MAX_SPAN))
  local built=small and build(list)
  if small and not built and not sea and start.ts and start.ts.imageData then
   -- A tree standing against a cliff (Mossdeep's lone trees on the rim): the rock beside it made the
   -- 'is this a fence post on a ledge' test refuse the group, leaving the trunk flat and its crown a floating
   -- slab. A group that is mostly leaf-green is a tree wherever it stands.
   local f=0
   for _,c in ipairs(list)do f=f+tone(c.ts,c.mid) end
   if f/#list>=M.GROVE then built=build(list,nil,{grove=true}) end
  end
  if not built then
   -- sea rock that cannot be one object (a long ridge, a rock wall in the
   -- sea): the rounded bank it has always been
   for _,c in ipairs(list)do if c.shape.seaRock then
    c.shape={kind='cliff',bank=true,sea=true,height=14,slope=16,ground=c.shape.ground,cap=c.mid,side=c.mid}
   end end
  end
  if small then
  else
   -- A long line (a fence: no cell with three neighbours in the group) is
   -- split into straight runs, and each run into pieces of M.RUN cells.
   local line=true
   for _,c in ipairs(list)do
    local around=0
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do if set[key(c.cx+d[1],c.cy+d[2])] then around=around+1 end end
    if around>=3 then line=false;break end
   end
   if thin then line=true end
   local foliage=0
   if not line and start.ts and start.ts.imageData then
    for _,c in ipairs(list)do foliage=foliage+tone(c.ts,c.mid) end
    foliage=foliage/#list
   end
   if not line and foliage>=M.GROVE then
    -- A grove the tables do not name (Dewford's packed trees, Route 113's
    -- ash-covered rows, Mossdeep's clustered trees).
    local votes={}
    for _,c in ipairs(list)do for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local n=cells[key(c.cx+d[1],c.cy+d[2])]
     if n and n.pair==c.pair and walkableGround(n) then vote(votes,n) end
    end end
    local ground,best=nil,0
    for mid,n in pairs(votes)do if n>best or (n==best and mid<ground) then ground,best=mid,n end end
    -- Seen from above a packed grove is one canopy: it rises as a bank (a
    -- rounded mass draped with the cartridge's own canopy drawing, see
    -- Gen3Terrain), the trunks along its edge at the foot of the mass.
    -- Trees standing on open ground (Mossdeep: trunks on grass, crowns in
    -- the walk-behind row) are separate trees: each cell a slab of its own
    -- pixels with its crown. A packed canopy (Dewford: tiles solid foliage,
    -- no ground left after the cut) is one mass.
    -- A big grove of stacked round trees on a lattice (Mossdeep's rocky grove) stands as one object cut per tree.
    local stacked
    if ground and (#list>M.CLUSTER_CELLS or x1-x0>=M.CLUSTER_SPAN or y1-y0>=M.CLUSTER_SPAN) then
     table.sort(list,function(a,b)if a.cy~=b.cy then return a.cy<b.cy end return a.cx<b.cx end)
     local whole=build(list,nil,{grove=true,ground=ground})
     if whole then
      local trees=M.segmentTrees(whole)
      if M.log then print(('[EM stacked] %s %d cells -> %s trees'):format(start.pair,#list,trees and #trees or 'no'))end
      if trees then
       whole.trees=trees;stacked=true
       -- the grove steps up and down terraces (a pocket of grass above a lavender shore): each cell keeps the ground
       -- its own neighbours stand on, not the one the whole object voted for
       for _,c in ipairs(whole.cells)do
        local v={}
        for dy=-2,2 do for dx=-2,2 do
         local n=cells[key(c.cx+dx,c.cy+dy)]
         if n and n.pair==c.pair and walkableGround(n) then v[n.mid]=(v[n.mid] or 0)+1/(1+math.abs(dx)+math.abs(dy)) end
        end end
        local best,bn=nil,0
        for mid,k in pairs(v)do if k>bn or (k==bn and mid<best) then best,bn=mid,k end end
        c.objGround=best
       end
      end
      if not trees then
       for _,c in ipairs(whole.cells)do c.object=nil;c.objectOwner=nil end
       for _,c in ipairs(whole.tops)do c.objectTop=nil end
       objects[#objects]=nil
      end
     end
    end
    if ground and not stacked then
     local solid=0
     for _,c in ipairs(list)do local _,n=M.cut(c.ts,c.mid,{ground});if (n or 0)>=.75*256 then solid=solid+1 end end
     if M.log then print(('[EM grove] %s %d cells solid=%d ground=%03X'):format(start.pair,#list,solid,ground))end
     if solid>=.5*#list then
      for _,c in ipairs(list)do
       c.shape={kind='cliff',bank=true,grove=true,height=M.GROVE_HEIGHT,slope=M.GROVE_SLOPE,ground=ground,cap=c.mid,side=c.mid}
      end
     else
      table.sort(list,function(a,b)if a.cy~=b.cy then return a.cy<b.cy end return a.cx<b.cx end)
      -- a tight cluster of trees is ONE drawing (each tree is two tiles wide; cutting it per cell halved every
      -- tree). Only a large grove stays one cell per object.
      if #list<=M.CLUSTER_CELLS and x1-x0<M.CLUSTER_SPAN and y1-y0<M.CLUSTER_SPAN and build(list,nil,{grove=true,ground=ground}) then
      else
       for _,c in ipairs(list)do build({c},nil,{grove=true,ground=ground}) end
      end
     end
    end
    if M.log then print(('[EM grove] %s %d cells ground=%s'):format(start.pair,#list,tostring(ground)))end
   elseif line then
    local used={}
    local function runs(horizontal)
     table.sort(list,function(a,b)
      if horizontal then if a.cy~=b.cy then return a.cy<b.cy end return a.cx<b.cx end
      if a.cx~=b.cx then return a.cx<b.cx end return a.cy<b.cy end)
     for _,c in ipairs(list)do
      local dx,dy=horizontal and 1 or 0,horizontal and 0 or 1
      local prev=set[key(c.cx-dx,c.cy-dy)]
      local nextc=set[key(c.cx+dx,c.cy+dy)]
      if not used[c] and (not prev or used[prev]) and (nextc or not horizontal) then
       local run,cur={},c
       while cur and not used[cur] do run[#run+1]=cur;used[cur]=true;cur=set[key(cur.cx+dx,cur.cy+dy)] end
       -- a fence repeats its tiles along the line; a building's unlisted
       -- outline is a run of one-off drawings and stays flat
       -- (one odd post in a long run of a repeated tile is part of the fence)
       local odd=0
       for _,m in ipairs(run)do if (freq[m.pair..':'..m.mid] or 0)<3 then odd=odd+1 end end
       local repeated=odd==0 or (#run>=4 and odd<=math.max(1,math.floor(#run*.2)))
       if repeated then for a=1,#run,M.RUN do
        local piece={};for b=a,math.min(#run,a+M.RUN-1)do piece[#piece+1]=run[b] end
        local o=build(piece,not horizontal and #piece>1 and 'v' or nil)
        if o then o.line=true end
       end end
      end
     end
    end
    runs(true);runs(false)
   end
  end
 end end
 return objects
end

-- Emit the object's slab: every cut pixel becomes a voxel column whose depth
-- follows the row's width (rounded like the drawing's own silhouette), capped
-- so a post stays thin and a boulder stays within its footprint.
M.FENCE_SPAN=5         -- a blocked group this long and thin is a fence
M.ASH_DEPTH=20         -- widest an ash pine is front to back (voxels)
M.ASH_TAPER=.45        -- depth of its tip as a share of its foot: a pine narrows toward the top
M.ASH_TREE_CELLS=6     -- tallest ash pine, in cells (the card is at most 7 cells with the crown row above)
M.CLUSTER_CELLS=30     -- trunk cells of a tree cluster built as one object
M.CLUSTER_SPAN=6       -- widest/tallest such cluster, in cells
M.TOP_ROWS=4          -- walk-behind rows above a blocked object that join its drawing (a tall tree has up to 3)
M.TREE_GREEN=.4       -- share of an object's pixels that are leaf-green for it to count as a tree
-- A standing object that is a tree (Dewford's sand trees, Mossdeep's, Fallarbor's ash trees...): one cell
-- wide, a crown in the walk-behind row over a trunk, mostly foliage.
local function treeLike(o,member)
 if o.treeLike~=nil then return o.treeLike end
 o.treeLike=false
 if o.ashTree then o.treeLike=true;return true end
 if o.line or o.orient or (o.x1-o.x0)>6 or (#o.tops==0 and not o.grove) then return false end
 local ts=o.ts;if not (ts and ts.imageData) then return false end
 local n,green=0,0
 for _,c in ipairs(o.cells)do local mask=o.masks[c];if mask then
  local ox,oy=origin(ts,c.mid)
  for ly=0,15 do for lx=0,15 do if mask[ly*16+lx] then
   local r,g,b=pixel(ts,ox+lx,oy+ly);n=n+1
   if g>r*1.1 and g>b*1.05 then green=green+1 end
  end end end
 end end
 for _,c in ipairs(o.tops)do local mask=o.masks[c];if mask then
  local ox,oy=origin(ts,c.mid)
  for ly=0,15 do for lx=0,15 do if mask[ly*16+lx] then
   local r,g,b=pixel(ts,ox+lx,oy+ly);n=n+1
   if g>r*1.1 and g>b*1.05 then green=green+1 end
  end end end
 end end
 local overGreen,overN=0,0
 for _,c in ipairs(o.tops)do
  local ox,oy=origin(ts,c.mid)
  if ox and ts.overImageData then for ly=0,15 do for lx=0,15 do
   local r,g,b,a=overData(ts):getPixel(ox+lx,oy+ly)
   if a>.5 then overN=overN+1;if g>r*1.1 and g>b*1.05 then overGreen=overGreen+1 end end
  end end end
 end
 o.treeLike=(n>=120 and green/n>=M.TREE_GREEN) or (overN>=60 and overGreen/overN>=.6)
 return o.treeLike
end
-- The pixels of an object as the tree path sees them: the crown is whatever the cartridge draws on the
-- over-player layer (exact, no colour guessing); the trunk is the bottom-layer pixels the object cut kept.
-- (Cutting crowns by "differs from the ground" removed every leaf darker than the grass: ragged holes.)
local function memberOf(o)
 local member={}
 for _,c in ipairs(o.cells)do member[key(c.cx,c.cy)]=c end
 for _,c in ipairs(o.tops)do member[key(c.cx,c.cy)]=c end
 return member
end
local function sampler(o,member)
 local ts=o.ts
 return function(px,py)
  local c=member[key(o.x0+math.floor(px/16),o.top+math.floor(py/16))]
  if not c then return 0,0,0,0 end
  local lx,ly=px%16,py%16
  local mask=o.masks[c]
  if not (mask and mask[ly*16+lx]) then return 0,0,0,0 end
  local ox,oy=origin(ts,c.mid)
  local r,g,b=pixel(ts,ox+lx,oy+ly)
  return r,g,b,1,(ox+lx+.5)/(ts.cols*16),(oy+ly+.5)/(ts.rows*16)
 end
end
local function treePixels(o,member,sample)
 local ts=o.ts
 local function crownPixel(px,py)
  local c=member[key(o.x0+math.floor(px/16),o.top+math.floor(py/16))]
  if not c or not ts.overImageData then return end
  local ox,oy=origin(ts,c.mid);if not ox then return end
  local r,g,b,a=ts.overImageData:getPixel(ox+px%16,oy+py%16)
  if a>.5 then return r,g,b end
 end
 return function(px,py)
  local r,g,b=crownPixel(px,py)
  if r then return r,g,b,1 end
  local r2,g2,b2,a2=sample(px,py)
  return r2,g2,b2,a2
 end
end

-- A stacked grove: round trees of one 32-px drawing standing on a half-cell lattice, each in front of the one
-- above (Mossdeep's rocky grove). No cell or tile holds one tree, so the drawing is cut per tree: every
-- crown's lightest highlight marks its apex; trees claim their pixels front (lowest) first, inside their own
-- rounded outline, so a tree keeps its crown top where a neighbour overlaps it.
M.TREE_W=32
M.STACK_DEPTH=16       -- stacked trees stand a lattice step (16 px) apart: no deeper, or neighbours cut into each other
M.TREE_H=40            -- crown, underside and root fringe
M.APEX=6.2             -- the highlight's centre below the apex row
-- The same lamp post, railing piece or sign stands many times in a town: its solid is built once per
-- drawing (the same tiles in the same arrangement, on the same tileset image) and reused. Building
-- each one again was most of a city's build time.
local hulls,hullCount={},0
local function hull(o,ts,w,h,sample,depth,tag)
 local ids={}
 for _,list in ipairs({o.cells,o.tops})do for _,c in ipairs(list)do ids[#ids+1]=(c.cx-o.x0)..','..(c.cy-o.top)..':'..tostring(c.pair)..':'..tostring(c.mid) end end
 table.sort(ids)
 local g=o.owner and o.owner.shape and (o.owner.shape.ground or o.owner.shape.groundMid) or ''
 local id=tag..':'..w..'x'..h..':'..depth..':'..tostring(ts.imageData)..':'..tostring(g)..':'..(o.line and 'l' or '')..':'..table.concat(ids,'|')
 local faces=hulls[id]
 if not faces then
  if hullCount>600 then hulls,hullCount={},0 end
  faces=V.require('VoxelHull').build(w,h,sample,1,0,depth);hulls[id]=faces;hullCount=hullCount+1
 end
 return faces
end
function M.segmentTrees(o)
 local member=memberOf(o)
 local pix=treePixels(o,member,sampler(o,member))
 local w=(o.x1-o.x0+1)*16
 local h=(o.y1-o.top+1)*16
 local col,alpha={}, {}
 local best,bestG,bestRB=nil,-1,-1
 local count={}
 for py=0,h-1 do for px=0,w-1 do
  local r,g,b,a=pix(px,py)
  if a and a>.5 then
   local R,G,B=math.floor(r*255+.5),math.floor(g*255+.5),math.floor(b*255+.5)
   local k=R*65536+G*256+B
   if not (R>140 and R>G*1.2) then   -- salmon cliff stone beside the grove is none of the trees' pixels
    col[py*w+px]=k;alpha[#alpha+1]=py*w+px
   end
   if G>R*1.1 and G>B*1.05 then
    count[k]=(count[k] or 0)+1
    if G>bestG or (G==bestG and R+B>bestRB) then best,bestG,bestRB=k,G,R+B end
   end
  end
 end end
 if not best or count[best]<150 then return end
 -- highlight pieces, 8-connected
 local seen,blobs={}, {}
 for k,c in pairs(col)do if c==best and not seen[k] then
  local stack,n,sx,sy={k},0,0,0;seen[k]=true
  while #stack>0 do
   local q=table.remove(stack);n=n+1
   local x,y=q%w,math.floor(q/w);sx=sx+x+.5;sy=sy+y+.5
   for dy=-1,1 do for dx=-1,1 do
    local nx,ny=x+dx,y+dy
    if nx>=0 and ny>=0 and nx<w and ny<h then
     local nk=ny*w+nx
     if col[nk]==best and not seen[nk] then seen[nk]=true;stack[#stack+1]=nk end
    end
   end end
  end
  if n>=4 then blobs[#blobs+1]={x=sx/n,y=sy/n,n=n} end
 end end
 -- pieces of one highlight lie within 9 px of each other
 local joined,groups={}, {}
 for i,b in ipairs(blobs)do if not joined[i] then
  joined[i]=true;local grp={i};local k=1
  while k<=#grp do
   for j,c in ipairs(blobs)do
    if not joined[j] and math.abs(c.x-blobs[grp[k]].x)<=9 and math.abs(c.y-blobs[grp[k]].y)<=9 then joined[j]=true;grp[#grp+1]=j end
   end
   k=k+1
  end
  local n,sx,sy=0,0,0
  for _,j in ipairs(grp)do n=n+blobs[j].n;sx=sx+blobs[j].x*blobs[j].n;sy=sy+blobs[j].y*blobs[j].n end
  if n>=60 then groups[#groups+1]={x=sx/n,y=sy/n} end
 end end
 local trees,have={}, {}
 for _,g in ipairs(groups)do
  local cx=math.floor(g.x/16+.5)*16
  local ay=math.floor((g.y-M.APEX)/16+.5)*16
  if math.abs(g.x-cx)>3 or math.abs(g.y-M.APEX-ay)>3 then
   -- not on the lattice: not this kind of grove. Except a highlight at the drawing's own edge: the half of a tree
   -- the group is cut through (by the build window: the near and upgrade builds end a row or two before the full one
   -- does, and must find the same trees) is no evidence against the lattice, and it is no tree of the group.
   if not (g.x<=9 or g.x>=w-9 or g.y<=9 or g.y>=h-9) then return end
  else
   local id=cx..':'..ay
   if not have[id] then have[id]=true;trees[#trees+1]={cx=cx,ay=ay,px={}} end
  end
 end
 if #trees<2 then return end
 table.sort(trees,function(a,b)if a.ay~=b.ay then return a.ay>b.ay end return a.cx<b.cx end)
 local owner={}
 local function inside(t,x,y)
  local dx=math.abs(x+.5-t.cx)/16.5;local dy=math.abs(y+.5-(t.ay+17))/19.5
  return dx^2.6+dy^2.6<=1
 end
 for ti,t in ipairs(trees)do
  for y=math.max(0,t.ay),math.min(h-1,t.ay+M.TREE_H-1)do for x=math.max(0,t.cx-17),math.min(w-1,t.cx+16)do
   local k=y*w+x
   if col[k] and not owner[k] and inside(t,x,y)then owner[k]=ti end
  end end
 end
 -- what no outline claimed belongs to the nearest tree (root fringe, outline pixels), unless it is none's
 for _,k in ipairs(alpha)do if not owner[k] then
  local x,y=k%w,math.floor(k/w)
  local bt,bd=nil,2.4
  for ti,t in ipairs(trees)do
   local dx=(x+.5-t.cx)/16.5;local dy=(y+.5-t.ay-17)/19.5
   local d=dx*dx+dy*dy
   if d<bd then bt,bd=ti,d end
  end
  if bt then owner[k]=bt end
 end end
 local owned=0
 for _,k in ipairs(alpha)do if owner[k] then owned=owned+1 end end
 for k,ti in pairs(owner)do local t=trees[ti];t.px[k]=true end
 if owned<.6*#alpha then return end
 return trees,w,h
end
-- emitLeaf: receives the quads of a tree model (its atlas is NativeTreeArt's, not the tileset's)
function M.append(o,emit,emitLeaf)
 local ts=o.ts;if not (ts and ts.imageData) then return 0 end
 local w=(o.x1-o.x0+1)*16
 local h=(o.y1-o.top+1)*16
 local member=memberOf(o)
 local sample=sampler(o,member)
 local rows,cols=o.y1-o.y0+1,o.x1-o.x0+1
 -- A tree: the round model of the sprite's own cut pixels (NativeTreeArt.lathe), at the art's true size
 if emitLeaf and V.require('TreePresentation').round() and (o.trees or treeLike(o,member)) then
  local N=V.require('NativeTreeArt')
  local ids={};for _,c in ipairs(o.cells)do ids[#ids+1]=c.pair..':'..c.mid end
  for _,c in ipairs(o.tops)do ids[#ids+1]=c.pair..':'..c.mid end
  local id='obj:'..table.concat(ids,',')..':'..tostring(ts.imageData)
  local treePixel=treePixels(o,member,sample)
  -- the same closed solid the scene's trees use; vertices are {x,y,z,u,v,shade,...} around the card's centre
  local function emitCard(card,cx,zFoot,lift)
   if not card then return 0 end
   lift=lift or 0
   local verts,idx={}, {}
   -- (on entering a map the first area stands an unbuilt round tree as its drawing on a card: the
   -- game runs without the JIT, and Mossdeep's five groves alone held the flat map two seconds; the
   -- full build a moment later makes them whole)
   local name='solid'..N.variantAt(cx,zFoot-(card.bottom or 0))
   if V.require('Gen3Scene').firstArea() and not (card.models and card.models[name]) then
    N.append(card,verts,idx,0,cx,0,zFoot-(card.bottom or 0),true)
   else
    N.appendModel(card,verts,idx,0,cx,0,zFoot-(card.bottom or 0))
   end
   local count=0
   for k=1,#idx,6 do
    local a,b,c2,d=verts[idx[k]],verts[idx[k+1]],verts[idx[k+2]],verts[idx[k+5]]
    emitLeaf({{a[1],a[2]+lift,a[3]},{b[1],b[2]+lift,b[3]},{c2[1],c2[2]+lift,c2[3]},{d[1],d[2]+lift,d[3]}},{{a[4],a[5]},{b[4],b[5]},{c2[4],c2[5]},{d[4],d[5]}},a[6]);count=count+1
   end
   return count
  end
  if o.trees then
   -- a stacked grove: one round tree per crown, each from its own pixels, standing at its own terrace height
   -- (the object is emitted once, at its owner cell's height)
   local total=0
   local ownerBase=(o.owner and o.owner.base) or 0
   for i,t in ipairs(o.trees)do
    local tc=member[key(o.x0+math.floor(t.cx/16),o.top+math.floor(math.min(h-1,t.ay+M.TREE_H-1)/16))]
    local lift=((tc and tc.base) or ownerBase)-ownerBase
    local card=N.cardFrom(id..':t'..t.cx..'/'..t.ay,M.TREE_W+2,M.TREE_H,function(px,py)
     local x,y=t.cx-M.TREE_W/2-1+px,t.ay+py
     if x<0 or y<0 or x>=w or y>=h or not t.px[y*w+x] then return 0,0,0,0 end
     return treePixel(x,y)
    end)
    if card then card.treeDepth=M.STACK_DEPTH end
    total=total+emitCard(card,o.x0*16+t.cx,o.top*16+t.ay+M.TREE_H,lift)
   end
   if total>0 then return total end
  else
   local card=N.cardFrom(id,w,h,treePixel)
   if card and o.ashTree then card.treeDepth=M.ASH_DEPTH;card.taper=M.ASH_TAPER end
   local count=emitCard(card,(o.x0+o.x1+1)*8,o.top*16+h)
   if count>0 then return count end
  end
 end
 if o.orient=='v' then
  -- A north-south fence is drawn from above: its cut pixels rise as a low
  -- wall along the run (the hull's depth becomes the height).
  local H=10
  local faces=hull(o,ts,w,h,sample,H,'v')
  local cx,zTop=(o.x0+o.x1+1)*8,o.top*16
  for _,q in ipairs(faces)do
   local p={};for _,v in ipairs(q)do p[#p+1]={cx+v[1],v[3]+H/2,zTop+h-v[2]}end
   local t={q.u,q.v};emit(p,{t,t,t,t},q.shade)
  end
  return #faces
 end
 -- Art that stays inside its blocked footprint (nothing drawn over the walk-
 -- behind row) is a low thing seen from above: a boulder, a planter, a
 -- bench. It stands at half its drawn height. Art reaching into the row
 -- above (lamp posts, tall signs) is tall and stands at full height.
 local scale=(#o.tops==0 and not o.grove) and .5 or 1
 -- A low thing (boulder, planter, bench) is rebuilt from its drawing by
 -- inverting the oblique view (Gen3Mass): as high as it is deep, nothing squashed.
 if scale==.5 and not o.line then
  local n=V.require('Gen3Mass').appendObject(o,emit)
  if n and n>0 then return n end
 end
 -- A one-row strip two or more cells wide with gaps in its drawing is a
 -- fence or a rail: thin. A solid one (a long rock) keeps its round depth.
 -- A piece of a long fence line is thin whatever its ink.
 local depth=((rows==1 and cols>=2 and (o.ink or 1)<.6) or o.line) and 3 or math.min(w,rows*16)*.8
 -- A tall thing one cell wide (lamp post, tall sign) is a post, not a barrel: the
 -- round hull made its lamp head and shaft fat and blobby. A thin plank of its
 -- own pixels stands upright, front face = the drawing.
 if cols==1 and #o.tops>0 and not o.grove then depth=4 end
 local faces=hull(o,ts,w,h,sample,depth,'h')
 local cx=(o.x0+o.x1+1)*8
 local cz=(o.y0+o.y1+1)*8
 for _,q in ipairs(faces)do
  local p={};for _,v in ipairs(q)do p[#p+1]={cx+v[1],v[2]*scale,cz+v[3]}end
  local t={q.u,q.v};emit(p,{t,t,t,t},q.shade)
 end
 return #faces
end

-- debug: M.prof={} collects seconds per kind of object
do local append=M.append
 M.append=function(o,emit,emitLeaf)
  if not M.prof then return append(o,emit,emitLeaf) end
  local t=os.clock();local n=append(o,emit,emitLeaf)
  local k=(o.trees and 'grove ' or '')..(o.orient or '-')..' tops'..#o.tops..' '..(o.x1-o.x0+1)..'x'..(o.y1-o.top+1)..(o.line and ' line' or '')
  local e=M.prof[k] or {0,0,0};M.prof[k]=e;e[1]=e[1]+os.clock()-t;e[2]=e[2]+1;e[3]=e[3]+(n or 0)
  return n
 end
end
return M
