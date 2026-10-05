-- the engine's own building groups (Gen3TileShape.layout) on every outdoor map
package.path="./?.lua;./?/init.lua;"..package.path
local MOD=os.getenv('HOME')..'/Documents/battle-art-notquiteog'
local GV=require('src.core.GameVersion'); pcall(GV.set,'emerald')
local cache={}
V={mod={options={get=function()end}},data=function(n)return dofile(MOD..'/data/'..n..'.lua')end}
function V.require(n) if cache[n]==nil then cache[n]=assert(loadfile(MOD..'/lib/'..n..'.lua'))(V) or true end return cache[n] end
local Shapes=V.require('Gen3TileShape')
local W=dofile(os.getenv('HOME')..'/Documents/gen1recomp-modwork/world.lua')
local out={}
TS={midToSlot=setmetatable({},{__index=function() return 0 end}),cols=1,rows=1}
for _,m in ipairs(W.maps) do if m.type==1 or m.type==2 or m.type==3 or m.type==6 then
 local prim,sec=m.pair:match('^(.-)__(.+)$');local beh=W.behaviors[m.pair] or {}
 local cells={}
 for y=0,m.h-1 do for x=0,m.w-1 do local v=m.cells[y*m.w+x+1];local mid=v%1024;local coll=math.floor(v/1024)%4~=0 and 7 or 0
  cells[x..':'..y]={ts=TS,cx=x,cy=y,mid=mid,collision=coll,pair=m.pair,secondary=sec,shape=Shapes.of(prim,sec,mid,beh[mid],coll) or {kind='flat'}} end end
 local ok,err=pcall(Shapes.layout,cells)
 if not ok then io.stderr:write(m.id..' layout failed '..tostring(err)..'\n') else
  local groups={}
  for _,c in pairs(cells) do local col=c.column
   if col and not col.indoor then local g=col.group or col
    local G=groups[g] or {x0=1e9,y0=1e9,x1=-1,y1=-1,wt={}}; groups[g]=G
    local wt=col.wallTop or ((col.first or c.cy)+(col.roofs or 0)); G.wt[wt]=(G.wt[wt] or 0)+1
    G.x0=math.min(G.x0,c.cx);G.x1=math.max(G.x1,c.cx);G.y0=math.min(G.y0,col.first or c.cy);G.y1=math.max(G.y1,col.last or c.cy) end end
  for _,G in pairs(groups) do local wt,bn=G.y1,0 for k,n in pairs(G.wt) do if n>bn then wt,bn=k,n end end
   out[#out+1]=string.format('{"map":"%s","pair":"%s","box":[%d,%d,%d,%d],"wallTop":%d}',m.id,m.pair,G.x0,G.y0,G.x1,G.y1,wt) end
 end end end
io.write('['..table.concat(out,',\n')..']')
