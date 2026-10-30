-- Masonry: the terrace walls of a town are built from their own tiles, not as natural
-- rock (Gen3Rock / Gen3Mass). A blocked cliff cell whose tile is in a map's wall table is
-- masonry. TOP cells (the cream wall-top band) are a flat slab at the upper terrace's height,
-- with their own art 1:1. FACE cells (the grey-green stippled wall face) have no top: their
-- footprint is the lower terrace's ground, and the whole column of face rows collapses onto
-- ONE vertical face at the edge where the upper terrace begins, rising from the lower
-- terrace's base to the upper one, in courses of the face rows' own art (bottom row first,
-- never stretched). Every other cliff tile stays rock. Gen3Scene calls prepare before
-- Gen3Mass.prepare (which must not see a masonry cell as rock) and restore after it.
local V=...
local M={}
M.enabled=true
-- per map: the wall-top (TOP) and wall-face (FACE) tile ids, sorted by eye from the map's
-- blocked tiles at 8x (r2/SO1/cliff_ids_8x.png, SO2 ruling). Rock: only the pink-brown lake
-- banks 0x072-0x07D, 0x089, 0x2DE, 0x2DF, the pink parts of 0x228, 0x22A, 0x230, 0x232, and
-- the tiles not listed here (building pieces, doors, 0x2CE, 0x2D6).
M.MAPS={
 EM_SOOTOPOLIS_CITY={
  top={[0x220]=true,[0x222]=true,[0x239]=true,[0x23B]=true,
       [0x240]=true,[0x241]=true,[0x242]=true,[0x246]=true,[0x247]=true,[0x251]=true,[0x252]=true,[0x253]=true,
       [0x25C]=true,[0x25D]=true,[0x25E]=true,[0x262]=true,[0x263]=true,[0x26E]=true,[0x26F]=true},
  face={[0x2CD]=true,[0x2D3]=true,[0x2D4]=true,[0x2D8]=true,[0x2DA]=true,[0x2E0]=true,[0x2E1]=true,[0x2E2]=true,
        [0x2F3]=true,[0x2FB]=true,[0x2FD]=true},
  faceDefault=0x2E1,
 },
}
M.SCAN=12       -- cells searched north and south up a wall column for the terraces it stands between
M.KERB=4        -- a band with the same walkable height on every side stands up this far (a kerb)
local DIRS={{1,0},{-1,0},{0,1},{0,-1}}
local function key(x,y)return x..':'..y end
local function walk(n)return n and (n.collision or 0)==0 and n.base~=nil end

-- the walkable terrace found searching `step` cells away (north -1, south +1) through blocked cells
local function terrace(cells,c,dy)
 for k=1,M.SCAN do
  local n=cells[key(c.cx,c.cy+dy*k)]
  if not n then break end
  if walk(n) then return n.base end
 end
 return nil
end

-- the height of what stands on a cell's edge: a TOP cell's top, a FACE cell's footprint, else its base
local function surface(n)
 if not n then return 0 end
 if n.masonry=='top' then return n.mU end
 if n.masonry=='face' then return n.mL end
 return n.base or 0
end

-- Marks the masonry cells and hides them from Gen3Mass for the duration of its prepare:
-- their shape reads 'masonry' there, so no rock mass floods through them. Returns the
-- list restore() needs.
function M.prepare(cells,def)
 local map=M.enabled and def and M.MAPS[def.id or '']
 if not map then return nil end
 local saved,list={},{}
 for _,c in pairs(cells)do
  local s=c.shape
  if s and s.kind=='cliff' and (c.collision or 0)~=0 and c.mid and c.ts and c.ts.midToSlot[c.mid] then
   local kind=map.top[c.mid] and 'top' or (map.face[c.mid] and 'face') or nil
   if kind then
    c.masonry=kind;list[#list+1]=c
    saved[#saved+1]={c=c,shape=s};c.shape={kind='masonry'}
   end
  end
 end
 for _,c in ipairs(list)do
  -- the nearest walkable terrace north and south, never above (north) or below (south) the cell's
  -- own level: a wall on the crater's rim must not take its upper terrace from the ground outside
  local own=c.base or 0
  local up,down=terrace(cells,c,-1),terrace(cells,c,1)
  c.mU=up and math.max(up,own) or own         -- the upper terrace
  c.mL=down and math.min(down,own) or own     -- the lower terrace
  c.map=map
 end
 return saved
end

function M.restore(saved)
 for _,s in ipairs(saved or {})do s.c.shape=s.shape end
end

-- one 16-unit course: a quad from (a) to (b) between heights lo and hi, both faces
-- (a quad is drawn with and against its winding, so it shows from either side)
local function course(emit,a,b,lo,hi,uv)
 local l,r=uv[1][1],uv[2][1]
 local t0,t1=uv[1][2],uv[3][2]
 local f=(hi-lo)/16
 local vb=t0+(t1-t0)*f
 emit({{a[1],lo,a[2]},{b[1],lo,b[2]},{b[1],hi,b[2]},{a[1],hi,a[2]}},{{l,vb},{r,vb},{r,t0},{l,t0}},M.SHADE)
 emit({{a[1],hi,a[2]},{b[1],hi,b[2]},{b[1],lo,b[2]},{a[1],lo,a[2]}},{{l,t0},{r,t0},{r,vb},{l,vb}},M.SHADE)
end
M.SHADE=.78

-- the face rows of the column through `start`, bottom row first
local function faceColumn(cells,start)
 local n=start
 while true do local u=cells[key(n.cx,n.cy-1)]; if u and u.masonry=='face' then n=u else break end end
 local rows={}
 while n and n.masonry=='face' do rows[#rows+1]=n; n=cells[key(n.cx,n.cy+1)] end
 local out={}
 for i=#rows,1,-1 do out[#out+1]=rows[i].mid end
 return out
end

-- vertical face from lo up to hi on the edge (a)-(b), in 16-unit courses from the bottom,
-- each course the next face row's art (the cycle repeats); the top course is cropped, never stretched
local function face(emit,ts,uvFor,a,b,lo,hi,mids,fallback)
 if #mids==0 then mids={fallback} end
 local t,i=lo,0
 while t<hi-.01 do
  local h=math.min(16,hi-t)
  i=i+1
  local uv=uvFor(ts,mids[(i-1)%#mids+1]) or uvFor(ts,fallback)
  if uv then course(emit,a,b,t,t+h,uv) end
  t=t+h
 end
end

-- a band's bottom M.KERB rows as the side of a kerb: the art's own edge, 1:1 (never stretched)
local function kerbSide(emit,a,b,lo,hi,uv)
 local l,r=uv[1][1],uv[2][1]
 local t0,t1=uv[1][2],uv[3][2]
 local vt=t1-(t1-t0)*(hi-lo)/16
 emit({{a[1],lo,a[2]},{b[1],lo,b[2]},{b[1],hi,b[2]},{a[1],hi,a[2]}},{{l,t1},{r,t1},{r,vt},{l,vt}},M.SHADE)
 emit({{a[1],hi,a[2]},{b[1],hi,b[2]},{b[1],lo,b[2]},{a[1],lo,a[2]}},{{l,vt},{r,vt},{r,t1},{l,t1}},M.SHADE)
end

-- the four edges of a cell (x,z at its corner), as {a,b} pairs by direction
local function edge(d,x,z)
 if d[1]==1 then return {x+16,z},{x+16,z+16}
 elseif d[1]==-1 then return {x,z+16},{x,z}
 elseif d[2]==1 then return {x+16,z+16},{x,z+16}
 else return {x,z},{x+16,z} end
end

-- Emits one masonry cell: its slab or footprint, and the faces on its edges where the
-- height changes. Two masonry cells share an edge: the higher one draws its face.
-- A cell with no neighbour (the map's edge) drops to the ground beside it.
function M.append(c,cells,emit,uvFor)
 local ts,map=c.ts,c.map
 local x,z=c.cx*16,c.cy*16
 local sc=c.masonry=='top' and c.mU or c.mL
 local kerb=false
 if c.masonry=='top' then
  -- a band with the same walkable height on every side, beside ground rather than only beside
  -- other bands, stands up as a kerb: its own art on top, its edge down the four sides
  local uv=uvFor(ts,c.mid)
  kerb=uv~=nil
  local other=false
  for _,d in ipairs(DIRS)do
   local n=cells[key(c.cx+d[1],c.cy+d[2])]
   if not n or surface(n)~=sc then kerb=false;break end
   if not n.masonry then other=true end
  end
  kerb=kerb and other
  if kerb then
   local h=sc+M.KERB
   emit({{x,h,z},{x+16,h,z},{x+16,h,z+16},{x,h,z+16}},uv)
   for _,d in ipairs(DIRS)do
    local a,b=edge(d,x,z)
    kerbSide(emit,a,b,sc,h,uv)
   end
   return
  end
 end
 if c.masonry=='top' then
  local uv=uvFor(ts,c.mid)
  if uv then emit({{x,sc,z},{x+16,sc,z},{x+16,sc,z+16},{x,sc,z+16}},uv) end
 else
  -- the footprint shows the lower terrace's own ground tile where a walkable cell stands at
  -- that height, else the face's own art (a flat run of wall)
  local mid=c.mid
  for _,d in ipairs(DIRS)do
   local n=cells[key(c.cx+d[1],c.cy+d[2])]
   if n and not n.masonry and n.base==sc and (n.collision or 0)==0 and n.mid and n.ts==ts then mid=n.mid;break end
  end
  local uv=uvFor(ts,mid) or uvFor(ts,c.mid)
  if uv then emit({{x,sc,z},{x+16,sc,z},{x+16,sc,z+16},{x,sc,z+16}},uv) end
 end
 for _,d in ipairs(DIRS)do
  local n=cells[key(c.cx+d[1],c.cy+d[2])]
  local sn=surface(n)
  if sn~=sc and not (n and n.masonry and sc<sn) then
   local lo,hi=math.min(sc,sn),math.max(sc,sn)
   local a,b=edge(d,x,z)
   -- the face rows standing on this edge: the column of the masonry face cell on it (the
   -- lower one of the pair) or this cell's own column
   local col
   if n and n.masonry=='face' then col=faceColumn(cells,n) elseif c.masonry=='face' then col=faceColumn(cells,c) else col={} end
   face(emit,ts,uvFor,a,b,lo,hi,col,map.faceDefault)
  end
 end
end

return M
