-- Ever Grande's two gates on the way up to the Pokemon League, built as real
-- gates you walk through underneath (Opus; user: "that orange thing at ever
-- grand are arches where you walk through underneath").
--
-- The cartridge draws each gate in the over-player layer of the path cells
-- (the orange roof, 0x248..0x25F, three rows deep) and of the post tops
-- (0x260 west, 0x264 east), with the posts' feet (0x26C) in the ground layer.
-- In 3D the roof lay flat on the path as an orange slab. Here the cells keep
-- their ground (the brick path and grass under the roof, Gen3Scene skips their
-- over layer) and the gate is rebuilt from the drawing, placed so the player's
-- camera still sees it exactly as drawn (screen row = depth - height):
--   posts: the drawn posts (rows 46..79 of the gate's drawing, counted from
--     the roof's top row) stand on the posts' foot cells, 34 px tall, 12 deep;
--   roof: its front edge (rows 38..45) is a fascia 34..42 px up over the
--     posts' front; its top (rows 0..37) a lid 38 px deep at 42 px, so the
--     path runs underneath it. Transparent pixels of the over-layer art (the
--     flared ends' corners) drop out on their own.
local V=...
local M={}

M.ROOF={}
for mid=0x248,0x25F do M.ROOF[mid]=true end
M.POST_W,M.POST_E,M.FOOT=0x260,0x264,0x26C
M.GROUND=0x001        -- the grass round the posts' feet
M.POST_H=34           -- post top / roof underside
M.ROOF_H=42           -- roof top
M.ROOF_D=38           -- roof depth (its top rows 0..37)
M.POST_D=12

function M.cell(c)
 return c and c.shape and c.shape.leagueGate or false
end
-- the over layer of these cells is the gate's drawing: skipped in the flat pass
function M.overArt(mid)return M.ROOF[mid] or mid==M.POST_W or mid==M.POST_E end
function M.ground(c)
 if c.mid==M.FOOT then return M.GROUND end
 return c.mid     -- the ground layer under the roof and post tops is the path / grass
end

-- the gate whose west foot is this cell: east foot column
local function gate(c,cells)
 if c.mid~=M.FOOT then return end
 local n=cells[c.cx..':'..(c.cy-1)]
 if not (n and n.mid==M.POST_W) then return end
 for k=2,10 do
  local e=cells[(c.cx+k)..':'..c.cy]
  local en=cells[(c.cx+k)..':'..(c.cy-1)]
  if e and e.mid==M.FOOT and en and en.mid==M.POST_E then return c.cx+k end
 end
end
function M.owns(c,cells)return gate(c,cells)~=nil end

-- solid(points,uv,shade): an ordinary quad (ground + over pass);
-- over(points,uv,shade): a quad drawn only with the over-player art
function M.append(c,cells,solid,over,uvFor)
 local xr=gate(c,cells);if not xr then return end
 local xl,yf=c.cx,c.cy
 local W=(xr-xl+1)*16
 local X0,Z0=xl*16,(yf-4)*16          -- the drawing's origin (roof's top row)
 local zf=(yf+1)*16                   -- the posts' front
 -- art(sx,sy,sw,sh,a,b,cc,d,shade): drawing rect -> quad a b cc d (bilinear),
 -- split at cell edges; each piece takes its own cell's art, over-layer
 -- pieces drawn with the over art only
 local function art(sx,sy,sw,sh,a,b,cc,d,shade)
  local function point(u,v)
   local q={};for k=1,3 do q[k]=(a[k]*(1-u)+b[k]*u)*(1-v)+(d[k]*(1-u)+cc[k]*u)*v end;return q
  end
  for ty=math.floor(sy/16),math.ceil((sy+sh)/16)-1 do for tx=math.floor(sx/16),math.ceil((sx+sw)/16)-1 do
   local l,t=math.max(sx,tx*16),math.max(sy,ty*16)
   local r,bt=math.min(sx+sw,(tx+1)*16),math.min(sy+sh,(ty+1)*16)
   local n=cells[(xl+tx)..':'..(yf-4+ty)]
   local uv=n and uvFor(n.ts,n.mid)
   if uv and r>l and bt>t then
    local function tex(px,py)return {uv[1][1]+(uv[2][1]-uv[1][1])*(px-tx*16)/16,uv[1][2]+(uv[3][2]-uv[1][2])*(py-ty*16)/16}end
    local pts={point((l-sx)/sw,(t-sy)/sh),point((r-sx)/sw,(t-sy)/sh),point((r-sx)/sw,(bt-sy)/sh),point((l-sx)/sw,(bt-sy)/sh)}
    ;(M.overArt(n.mid) and over or solid)(pts,{tex(l,t),tex(r,t),tex(r,bt),tex(l,bt)},shade)
   end
  end end
 end
 local PH,RH,RD,PD=M.POST_H,M.ROOF_H,M.ROOF_D,M.POST_D
 -- posts: front, back, both sides (each side repeats the post's edge column)
 for _,p in ipairs({{2,16},{W-16,W-1}})do
  local a,b=X0+p[1],X0+p[2];local w=p[2]-p[1]
  art(p[1],46,w,34,{a,PH,zf},{b,PH,zf},{b,0,zf},{a,0,zf},.86)
  art(p[1],46,w,34,{b,PH,zf-PD},{a,PH,zf-PD},{a,0,zf-PD},{b,0,zf-PD},.62)
  art(p[1],46,1,34,{a,PH,zf-PD},{a,PH,zf},{a,0,zf},{a,0,zf-PD},.72)
  art(p[2]-1,46,1,34,{b,PH,zf},{b,PH,zf-PD},{b,0,zf-PD},{b,0,zf},.76)
 end
 -- roof: top, front fascia, back, underside, ends
 local x0,x1,zb=X0,X0+W,zf-RD
 art(0,0,W,RD,{x0,RH,zb},{x1,RH,zb},{x1,RH,zf},{x0,RH,zf},1)
 art(0,RD,W,RH-PH,{x0,RH,zf},{x1,RH,zf},{x1,PH,zf},{x0,PH,zf},.86)
 art(0,RD,W,RH-PH,{x1,RH,zb},{x0,RH,zb},{x0,PH,zb},{x1,PH,zb},.62)
 art(0,RD+6,W,1,{x0,PH,zf},{x1,PH,zf},{x1,PH,zb},{x0,PH,zb},.55)
 art(8,RD,1,RH-PH,{x0+8,RH,zb+8},{x0+8,RH,zf},{x0+8,PH,zf},{x0+8,PH,zb+8},.72)
 art(W-9,RD,1,RH-PH,{x1-8,RH,zf},{x1-8,RH,zb+8},{x1-8,PH,zb+8},{x1-8,PH,zf},.76)
end
return M
