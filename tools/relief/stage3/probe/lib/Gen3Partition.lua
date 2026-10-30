-- Interior partition walls drawn from above: long north-south walls one cell
-- wide whose drawing is the wall's top (Lavaridge Gym's yellow lanes), built
-- as real walls (Opus; furniture session: "the long north-south partition
-- walls are flat strips on the floor; only their south end caps stand").
--
-- As a building column they were a facade at their south end with every row
-- squeezed into it and nothing along their length. Here each cell is a
-- stretch of wall WALL px tall, the room's other walls' height:
--   top: the cell's own drawing (the band seen from above);
--   sides (where no wall is beside it): the room's east-west walls' front,
--     the top-band tile over the face tile, 16 px each, one panel per cell;
--   ends (where the wall stops): the band over the drawn end face.
local V=...
local M={}
M.WALL=32
M.INSET=1
-- per profile key: partition tiles, the side art {upper, lower} and the end face
M.ROOMS={
 lavaridge_gym={
  {mids={[0x20C]=true,[0x204]=true,[0x20B]=true},side={0x206,0x20E},endFace=0x20B,band=0x20C},   -- 1F
  {mids={[0x231]=true,[0x229]=true,[0x228]=true,[0x230]=true},side={0x22B,0x233},endFace=0x230,band=0x231}},   -- B1F
 -- Devon Corp 1F's alcove sides: the orange trim on black (0x398/0x399, the
 -- corners 0x39A/0x39B) is the alcove's side wall, in the room's wall art
 facility={
  {mids={[0x398]=true,[0x399]=true,[0x39A]=true,[0x39B]=true,[0x3A0]=true,[0x3A1]=true},side={0x388,0x390},endFace=0x390,band=0x388,
   topSwatch={0x388,8,0}},   -- (their own top is black: capped in the wall's trim colour)
  -- Aqua Hideout's white corridor walls (band 0x20A, junctions 0x209-0x211,
  -- corner 0x220), sides as its east-west walls (white top 0x2E0 over grey
  -- face 0x221). Only on the maps that name it (Gen3Scene SHAPE_BY_MAP): the
  -- tileset's other maps use these tiles otherwise.
  {mids={[0x20A]=true,[0x209]=true,[0x210]=true,[0x211]=true,[0x220]=true},side={0x2E0,0x221},endFace=0x221,band=0x20A,mapsOnly=true}},
 -- Trainer Hill: the white walls drawn from above beside the black void (the
 -- lobby's corridor, each floor's alcove). The wall is the white half of its
 -- tile (cols), capped white, its sides the lobby's wall art.
 trainer_hill={mids={[0x328]=true,[0x320]=true,[0x32F]=true,[0x327]=true},side={0x321,0x329},endFace=0x329,band=0x328,
  topSwatch={0x328,11,4},cols={[0x328]={8,16},[0x320]={8,16},[0x32F]={0,8},[0x327]={0,8}}},
}
-- the spec of this tileset that owns this tile (a tileset may hold several)
function M.spec(secondary,mid)
 local r=M.ROOMS[secondary or ''];if not r then return end
 if r.mids then return r.mids[mid] and r or nil end
 for _,s in ipairs(r)do if s.mids[mid] then return s end end
end

local function sub(uv,x0,y0,x1,y1)
 local l,t,r,b=uv[1][1],uv[1][2],uv[3][1],uv[3][2]
 local u0,u1=l+(r-l)*x0/16,l+(r-l)*x1/16
 local v0,v1=t+(b-t)*y0/16,t+(b-t)*y1/16
 return {{u0,v0},{u1,v0},{u1,v1},{u0,v1}}
end

-- quad(points,uv,shade)
function M.append(c,cells,quad,uvFor)
 local s=M.spec(c.secondary,c.mid);if not s then return end
 local ts=c.ts
 local own=uvFor(ts,c.mid);if not own then return end
 local x,z=c.cx*16,c.cy*16
 local H,I=M.WALL,M.INSET
 local x0,x1=x+I,x+16-I
 -- (cols: the wall is only part of its tile's width)
 local cw=s.cols and s.cols[c.mid]
 if cw then x0,x1=x+cw[1],x+cw[2] end
 local function wall(n)return n and n.shape and (n.shape.kind=='partition' or n.shape.kind=='roomWall') end
 -- the end piece's own top is the band; every other cell's top is its drawing
 local topUv=(c.mid==s.endFace and uvFor(ts,s.band)) or own
 local topTex=sub(topUv,I,0,16-I,16)
 if s.topSwatch then
  local t=uvFor(ts,s.topSwatch[1])
  if t then local px,py=s.topSwatch[2]+.5,s.topSwatch[3]+.5
   local u,v=t[1][1]+(t[2][1]-t[1][1])*px/16,t[1][2]+(t[3][2]-t[1][2])*py/16
   topTex={{u,v},{u,v},{u,v},{u,v}} end
 end
 quad({{x0,H,z},{x1,H,z},{x1,H,z+16},{x0,H,z+16}},topTex,1)
 local up,lo=uvFor(ts,s.side[1]),uvFor(ts,s.side[2])
 for _,d in ipairs({{-1,x0,.72},{1,x1,.78}})do
  if not wall(cells[(c.cx+d[1])..':'..c.cy]) then
   local sx=d[2]
   local function face(y0,y1,uv)
    if d[1]<0 then quad({{sx,y1,z},{sx,y1,z+16},{sx,y0,z+16},{sx,y0,z}},uv,d[3])
    else quad({{sx,y1,z+16},{sx,y1,z},{sx,y0,z},{sx,y0,z+16}},uv,d[3]) end
   end
   face(H/2,H,up);face(0,H/2,lo)
  end
 end
 -- ends: the band over the end face
 local band,endf=uvFor(ts,s.band),uvFor(ts,s.endFace)
 if not wall(cells[c.cx..':'..(c.cy+1)]) then
  local zf=z+16
  quad({{x0,H,zf},{x1,H,zf},{x1,H/2,zf},{x0,H/2,zf}},sub(band,I,0,16-I,16),.86)
  quad({{x0,H/2,zf},{x1,H/2,zf},{x1,0,zf},{x0,0,zf}},sub(endf,I,0,16-I,16),.86)
 end
 if not wall(cells[c.cx..':'..(c.cy-1)]) then
  quad({{x1,H,z},{x0,H,z},{x0,H/2,z},{x1,H/2,z}},sub(band,I,0,16-I,16),.62)
  quad({{x1,H/2,z},{x0,H/2,z},{x0,0,z},{x1,0,z}},sub(endf,I,0,16-I,16),.62)
 end
end
return M
