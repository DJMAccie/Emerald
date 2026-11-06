-- Brown coastal ridges in the General tileset. Work in map pixels so a ridge
-- crossing a metatile edge has the same height on both sides of the seam.
local M={maps={EM_ROUTE104=true,EM_ROUTE105=true,EM_ROUTE106=true},tiles={}}
for _,id in ipairs({0x172,0x173,0x174,0x175,0x176,0x179,0x17A,0x17B,0x17C,0x17D,0x17E,
 0x180,0x181,0x182,0x184,0x188,0x189,0x18A,0x190,0x191,0x192,0x198,0x199,0x19A})do M.tiles[id]=true end
-- The same grey boulder quadrants are drawn against sea, sand and cliff.
-- Keep each tile's native background at the waterline.
local grey={}
for _,left in ipairs({0x150,0x152,0x154,0x15A,0x162,0x164,0x168})do
 grey[left],grey[left+1]=1,2
end
for _,left in ipairs({0x158,0x15C,0x160,0x16A,0x16C})do
 grey[left],grey[left+1]=3,4
end
local brown={[0x175]=1,[0x176]=2,[0x17D]=3,[0x17E]=4}
function M.join(cells)
 for _,c in pairs(cells)do
  local quadrants=grey[c.mid] and grey or brown
  if c.primary=='general' and not c.boundary and quadrants[c.mid]==1 then
   local x,y=c.cx,c.cy
   local parts={c,cells[(x+1)..':'..y],cells[x..':'..(y+1)],cells[(x+1)..':'..(y+1)]}
   local complete=true
   for i=2,4 do
    local n=parts[i]
    if not n or n.boundary or n.pair~=c.pair or quadrants[n.mid]~=i then complete=false;break end
   end
   if complete then
    for _,n in ipairs(parts)do n.shape={kind='water',reef=true,nativeReefFloor=true,level=n.shape.level or 0} end
   end
  end
 end
end
local function artwork(c)
 local ts=c.ts
 ts.reefArt=ts.reefArt or {}
 if ts.reefArt[c.mid] then return ts.reefArt[c.mid] end
 local slot=ts.midToSlot[c.mid]
 local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
 local pixels={}
 for y=0,15 do for x=0,15 do
  local r,g,b,a=ts.imageData:getPixel(ox+x,oy+y)
  -- Rock greys have almost equal red and green; the foam and sea are bluer.
  local stoneGrey=math.abs(r-g)<.035 and b>=r and b-r<.18 and r<.7
  if a>.5 and ((grey[c.mid] and stoneGrey) or (not grey[c.mid] and r>b)) then pixels[y*16+x]=r end
 end end
 ts.reefArt[c.mid]=pixels
 return pixels
end
function M.append(c,cells,uv,emit)
 local art=artwork(c)
 local function pixel(x,y)
  if x>=0 and x<16 and y>=0 and y<16 then return art[y*16+x] end
  local n=cells[(c.cx+math.floor(x/16))..':'..(c.cy+math.floor(y/16))]
  if n and n.shape.reef then return artwork(n)[y%16*16+x%16] end
 end
 local heights={}
 local function height(x,y)
  local key=(y+1)*18+x+1
  if heights[key] then return heights[key] end
  local r=pixel(x,y)
  if not r then return 0 end
  local depth=1
  while depth<8 and pixel(x-depth,y) and pixel(x+depth,y) and pixel(x,y-depth) and pixel(x,y+depth) do depth=depth+1 end
  heights[key]=math.floor(depth*(.8+r)+.5)
  return heights[key]
 end
 for y=0,15 do for x=0,15 do if art[y*16+x] then
  local h=height(x,y)
  local X,Z=c.cx*16+x,c.cy*16+y
  local t={uv[1][1]+(uv[2][1]-uv[1][1])*(x+.5)/16,uv[1][2]+(uv[4][2]-uv[1][2])*(y+.5)/16}
  local tex={t,t,t,t}
  emit({{X,h,Z},{X+1,h,Z},{X+1,h,Z+1},{X,h,Z+1}},tex,1)
  local function side(nx,ny,ax,az,bx,bz,shade)
   local low=height(nx,ny)
   if low<h then emit({{ax,low,az},{bx,low,bz},{bx,h,bz},{ax,h,az}},tex,shade) end
  end
  side(x-1,y,X,Z+1,X,Z,.84)
  side(x+1,y,X+1,Z,X+1,Z+1,.9)
  side(x,y-1,X,Z,X+1,Z,.78)
  side(x,y+1,X+1,Z+1,X,Z+1,.95)
 end end end
end
return M
