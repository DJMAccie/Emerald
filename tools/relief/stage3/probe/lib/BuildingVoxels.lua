-- BuildingVoxels: buildings as pixel voxels, from geometry-only model files.
--
-- Models are designed offline (Emerald repo tools/buildings/hf.py) and
-- exported to data/buildings/<name>.lua as GEOMETRY ONLY: each quad is a
-- face of the voxel model plus the coordinates of the drawing pixel that
-- paints it. No colour is stored. At load the building's own tiles are
-- composed into its drawing (from the player's ROM, as everywhere else) and
-- each face samples its pixel, so the model is pixel-for-pixel the original
-- art with real depth -- nothing stretched.
--
-- A model applies only where its anchor (the facade row's metatile ids)
-- matches the map, so a changed map or another tileset can never pick up a
-- wrong model. Claimed cells stand down from the generic building renderer.
local V=...
local R=V.require('Voxel3D')
local Budget=V.require('BuildBudget')
local FlatMesh=V.require('FlatMesh')
local M={}
M.REPAINT_GROUND=8   -- wall faces painted with ground take a neighbour's paint if one is within this many px (see M.mesh)

M.MODELS={'frontier_gate','ferry_birth_island','ferry_navel_rock','trainer_hill_penthouse','abandoned_ship_wreck','littleroot_house_brendan','littleroot_house_may','birch_lab','devon_corp','lilycove_museum','weather_institute','fortree_treehouse','sootopolis_cone','sootopolis_box','sootopolis_box2','pacifidlog_hut','pokemon_center','poke_mart'}
-- family models (one drawing reused in every town) match their anchor pattern
-- anywhere on any map; the others only on their own map at their own place
M.FAMILY={pokemon_center=true,poke_mart=true,fortree_treehouse=true,sootopolis_cone=true,sootopolis_box=true,sootopolis_box2=true,pacifidlog_hut=true}
-- every per-building model the generator made (data/buildings/index.lua)
do
 local ok,idx=pcall(V.data,'buildings/index')
 if ok and type(idx)=='table' then for _,n in ipairs(idx)do M.MODELS[#M.MODELS+1]=n end end
end
local SHADE={0.90,0.68,1.00,0.84,0.72}   -- south, north, top, east, west

local loaded={}
-- M.mesh's vertex number lists, reused (a pool: a build that yields mid-mesh can never share one)
local pool={}
-- Models designed by hand rather than by tools/buildings/hf.py: the file's anchor, tiles and box
-- stay the generated ones (they decide where the model applies and how its drawing is composed),
-- only the geometry is replaced. The Route 108 wreck is the first: its art is a 3/4 view of a
-- ship, and the generated height field stood it up as a terraced slab.
local AUTHORED={abandoned_ship_wreck='AbandonedWreck'}
local function model(name)
 if loaded[name]==nil then
  local ok,m=pcall(V.data,'buildings/'..name)
  loaded[name]=ok and type(m)=='table' and m or false
  local authored=loaded[name] and AUTHORED[name]
  if authored then
   local okA,Q=pcall(V.require,authored)
   if okA and type(Q)=='table' and type(Q.QUADS)=='table' then loaded[name].quads=Q.QUADS end
  end
 end
 return loaded[name] or nil
end

function M.prepare(cells,def,claim)
 local out={}
 local mapId=def and def.id
 -- no building stands inside a room (indoor maps can use General tilesets
 -- whose ids collide with a family's anchor: the Bike Shop grew a Sootopolis
 -- cone)
 local indoorMap=def and tonumber(def.mapType)==8
 for _,name in ipairs(M.MODELS)do
  local m=model(name)
  -- (on an indoor map only a model built for it: the Trainer Hill penthouse)
  if indoorMap and not (m and m.indoor and m.map==mapId) then m=nil end
  -- family buildings are redrawn at their corners over each town's own
  -- ground (Sootopolis, Fallarbor, Pacifidlog Centers): match on the inner
  -- columns only
  local anchor=m and m.anchor or {}
  if m and M.FAMILY[name] then
   local lo,hi=math.huge,-math.huge
   for _,a in ipairs(anchor)do lo=math.min(lo,a[1]);hi=math.max(hi,a[1])end
   local inner={}
   for _,a in ipairs(anchor)do if a[1]>lo and a[1]<hi then inner[#inner+1]=a end end
   if #inner>=2 then anchor=inner end
  end
  local function matches(dx,dy)
   for _,a in ipairs(anchor)do
    local c=cells[(a[1]+dx)..':'..(a[2]+dy)]
    if not (c and c.mid==a[3] and not c.bldModel) then return false end
    -- the same metatile ids mean other art in another tileset (the
    -- Sootopolis cone matched a Mart's shelves indoors): families stand only
    -- on outdoor tilesets, any other model only on its own
    local pair=c.pair or (c.ts and c.ts.pair) or ''
    if M.FAMILY[name] then
     if pair:sub(1,9)~='general__' then return false end
     -- ids from 0x200 up are the town's own (secondary) tiles: the same
     -- number is other art in another town (the Pacifidlog hut's anchor is
     -- ash grass on Route 113), so those families stay in their own tileset
     if a[3]>=0x200 and m.pair and pair~=m.pair then return false end
    elseif m.pair and pair~=m.pair then return false end
   end
   return true
  end
  local function place(dx,dy)
   local bld=claim(cells,{cx=m.x0+dx,cy=m.y0+dy,width=m.x1-m.x0+1,depth=m.y1-m.y0+1,name=name,voxels=m,
    tiles=M.FAMILY[name] and m.tiles or nil})
   if bld then
    -- a tree in the box (the canopy around a Fortree hut) keeps its own model;
    -- rows above m.claimFrom are drawn by the model but stay their own cells
    -- (the sea and grass under the Space Center's rocket and gantries)
    local kept={}
    local from=bld.cy+(m.claimFrom or 0)
    for _,c in ipairs(bld.claimed)do
     -- claimBlocked: only the model's blocked cells (a wreck in the sea: the
     -- water round and under it stays water)
     if (c.shape and c.shape.kind=='tree') or c.cy<from or (m.claimBlocked and (c.collision or 0)~=7) then c.bldModel=nil;c.civic=nil else kept[#kept+1]=c end
    end
    bld.claimed=kept
    -- floor under the model: the walkable ground the building stands in
    -- (paving in Slateport/Rustboro), not the tileset's default grass
    local votes,best,bn={},nil,0
    for x=bld.cx-1,bld.cx+bld.width do for y=bld.cy,bld.cy+bld.depth do
     local n=cells[x..':'..y]
     if n and not n.bldModel and (n.collision or 0)==0 and n.shape and n.shape.kind=='flat' then
      votes[n.mid]=(votes[n.mid] or 0)+1
      if votes[n.mid]>bn then best,bn=n.mid,votes[n.mid] end
     end
    end end
    bld.groundMid=best
    out[#out+1]=bld
   end
  end
  -- a model of ANOTHER map shows here when that map is connected (Route
  -- 118's house seen from Mauville): its cells arrive at an offset, so find
  -- its full anchor pattern the way families are found
  local foreign = m and not M.FAMILY[name] and m.map ~= mapId
  if (m and M.FAMILY[name] or foreign) and anchor[1] then
   local a=anchor[1]
   for _,c in pairs(cells)do
    if c.mid==a[3] and not c.bldModel then
     local dx,dy=c.cx-a[1],c.cy-a[2]
     if matches(dx,dy) then place(dx,dy) end
    end
   end
  elseif m and m.map==mapId and matches(0,0) then
   place(0,0)
  end
 end
 return out
end

-- verts for one exported quad: face, x0,x1, h0,h1, z0,z1 (art pixels, z<=0
-- going back from the facade), painted by drawing pixel (px,py)
function M.mesh(bld,data,img)
 local m=bld.voxels
 local iw,ih=data:getDimensions()
 local ox=bld.cx*16
 local oy=bld.groundHeight or 0
 local oz=(bld.cy+bld.depth)*16
 local q=m.quads
 -- A wall face painted with a ground pixel (a corner tile is drawn over the lawn it stands on, and the
 -- bake took that for wall: a strip of grass up the edge of a house front) takes the paint of the
 -- nearest face of the same wall at its height that is not ground.
 local repaint={}
 do
  local ts=bld.ts
  local ground,any={},false
  local function key(r,g,b)return math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5)end
  for _,gm in ipairs({bld.groundMid or false,0x001})do
   local slot=gm and ts and ts.imageData and ts.midToSlot[gm]
   if slot then any=true
    local gx,gy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
    for y=0,15 do for x=0,15 do local r,g,b=ts.imageData:getPixel(gx+x,gy+y);ground[key(r,g,b)]=true end end
   end
  end
  local function isGround(px,py)
   if px<0 or py<0 or px>=iw or py>=ih then return false end
   local r,g,b,a=data:getPixel(px,py);return a>.5 and ground[key(r,g,b)] or false
  end
  if any and M.REPAINT_GROUND then
   local walls,bad={},{}
   for i=1,#q,10 do local f=q[i]
    if f~=3 and q[i+4]>q[i+3] then
     if isGround(q[i+7],q[i+8]) then bad[#bad+1]=i else walls[#walls+1]=i end
    end
   end
   -- (walls bucketed by face, plane and height row: a candidate must share the face and plane and
   -- overlap the bad face's rows, and scanning every wall of a facade for every bad face was half a
   -- town's first build without the JIT. Same rule, same choice: the nearest, the first on a tie.)
   local bucket={}
   for _,j in ipairs(walls)do
    local fj=q[j];local sj=fj~=1 and fj~=2
    local pl=sj and q[j+1] or q[j+5]
    for h=q[j+3],q[j+4]-1 do
     local k=(fj*4096+pl+2048)*4096+h+2048
     local b=bucket[k];if not b then b={};bucket[k]=b end;b[#b+1]=j
    end
   end
   for _,i in ipairs(bad)do
    local f,best,bd=q[i],nil,nil
    local side=f~=1 and f~=2
    local pl=side and q[i+1] or q[i+5]
    for h=q[i+3],q[i+4]-1 do
     for _,j in ipairs(bucket[(f*4096+pl+2048)*4096+h+2048] or {})do
      local d=side and math.abs((q[j+5]+q[j+6])-(q[i+5]+q[i+6])) or math.abs((q[j+1]+q[j+2])-(q[i+1]+q[i+2]))
      if not bd or d<bd or (d==bd and j<best) then best,bd=j,d end
     end
    end
    if best and bd<=M.REPAINT_GROUND*2 then repaint[i]=best end
   end
  end
 end
 -- (one flat list, kept and reused: 24 numbers a quad, no table per vertex - see FlatMesh)
 local F,nf=table.remove(pool) or {},0
 for i=1,#q,10 do
  local f,x0,x1,h0,h1,z0,z1,px,py=q[i],q[i+1],q[i+2],q[i+3],q[i+4],q[i+5],q[i+6],q[i+7],q[i+8]
  if repaint[i] then px,py=q[repaint[i]+7],q[repaint[i]+8] end
  local u,v=(px+.5)/iw,(py+.5)/ih
  local s=SHADE[f] or 1
  -- (a model may give a face its own shade, in percent: a chamfered corner's stair of faces is one facet)
  if (q[i+9] or 0)>0 then s=q[i+9]/100 end
  local X0,X1,H0,H1,Z0,Z1=ox+x0,ox+x1,oy+h0,oy+h1,oz+z0,oz+z1
  local n=nf
  if f==1 or f==2 then
   F[n+1],F[n+2],F[n+3],F[n+4],F[n+5],F[n+6]=X0,H0,Z0,u,v,s
   F[n+7],F[n+8],F[n+9],F[n+10],F[n+11],F[n+12]=X1,H0,Z0,u,v,s
   F[n+13],F[n+14],F[n+15],F[n+16],F[n+17],F[n+18]=X1,H1,Z0,u,v,s
   F[n+19],F[n+20],F[n+21],F[n+22],F[n+23],F[n+24]=X0,H1,Z0,u,v,s
  elseif f==3 then
   F[n+1],F[n+2],F[n+3],F[n+4],F[n+5],F[n+6]=X0,H0,Z1,u,v,s
   F[n+7],F[n+8],F[n+9],F[n+10],F[n+11],F[n+12]=X1,H0,Z1,u,v,s
   F[n+13],F[n+14],F[n+15],F[n+16],F[n+17],F[n+18]=X1,H0,Z0,u,v,s
   F[n+19],F[n+20],F[n+21],F[n+22],F[n+23],F[n+24]=X0,H0,Z0,u,v,s
  else
   F[n+1],F[n+2],F[n+3],F[n+4],F[n+5],F[n+6]=X0,H0,Z0,u,v,s
   F[n+7],F[n+8],F[n+9],F[n+10],F[n+11],F[n+12]=X0,H0,Z1,u,v,s
   F[n+13],F[n+14],F[n+15],F[n+16],F[n+17],F[n+18]=X0,H1,Z1,u,v,s
   F[n+19],F[n+20],F[n+21],F[n+22],F[n+23],F[n+24]=X0,H1,Z0,u,v,s
  end
  nf=n+24
  if i%600==1 then Budget.tick() end
 end
 local mesh=nf>0 and FlatMesh.mesh(F,nf) or nil
 pool[#pool+1]=F
 return mesh
end

return M
