-- POKEPORT_DRIVER: jump-ledge pocket census (task 34 B item 3c). Read-only.  EM_DUMP=<out.txt> [EM_MAPS=<file of map ids>]  (QA identity only)
-- For every pinned map: split the walkable floor (c.floor, not a flight, not water) into areas (4-connected cells of one zone;
-- unmarked cells = zone 0) and list, per area, how it meets its neighbours:
--   IN  = a jump ledge lands in this area (the takeoff floor is across the ledge): "IN zone@height"
--   OUT = this area is a jump ledge's takeoff side: "OUT zone@height" (the landing floor)
--   WALK = a floor cell of another area right beside it (walkable contact, the cartridge rates them differently)
--   STAIR = a flight / stair cell beside it
-- One line per area that has IN or OUT contacts:
--   AREA map zone mark(x,y=courses|-) n=cells h=min..max(px) edge=0/1 IN=... OUT=... WALK=... STAIR=n cells=x,y(first)
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 require('src.core.game3.rng').Random=function()return 0 end
 require('src.core.game3.tileset_anim')._enabled=false
 local lib=game.mods.exports.BATTLE_ART_VOXEL_FORK.lib
 local E=lib.require('Gen3Elevation');local Pin=lib.require('Gen3PinData');local Levels=lib.require('TerrainLevels')
 local Map=require('src.core.game3.map')
 local f=assert(io.open(os.getenv('EM_DUMP'),'w'))
 -- Gen3 jump behaviours: 0x38 E, 0x39 W, 0x3A N, 0x3B S, 0x3C NE, 0x3D NW, 0x3E SE, 0x3F SW (direction of the jump = high -> low)
 local JD={[0x38]={1,0},[0x39]={-1,0},[0x3A]={0,-1},[0x3B]={0,1},[0x3C]={1,-1},[0x3D]={-1,-1},[0x3E]={1,1},[0x3F]={-1,1}}
 local ids={}
 if os.getenv('EM_MAPS') then for line in io.lines(os.getenv('EM_MAPS'))do local id=line:match('^(%S+)');if id then ids[#ids+1]=id end end
 else for id in pairs(Pin.MAPS)do ids[#ids+1]=id end;table.sort(ids) end
 local dirs={{1,0},{-1,0},{0,1},{0,-1}}
 for _,id in ipairs(ids)do
  Map.load(nil,game,id,{x=5,y=5,facing='down'});U.wait(120)
  local def=Map.currentDef()
  if def and def.midLayout and def.id==id then
   local l=def.midLayout;local W,H=l.width,l.height
   local fld=E.field(def)
   local marks=Pin.MAPS[id] or {}
   local function C(x,y)if x<0 or y<0 or x>=W or y>=H then return nil end;return fld.cells[Levels.key(x,y)] end
   local function flo(c)return c and c.floor and not c.step and c.kind~='water' and c.height~=nil end
   local area={};local areas={}
   for y=0,H-1 do for x=0,W-1 do
    local c=C(x,y);local k=x..':'..y
    if flo(c) and not area[k] then
     local z=c.zone or 0
     local A={zone=z,cells={},hmin=1e9,hmax=-1e9,edge=false,IN={},OUT={},WALK={},STAIR=0}
     areas[#areas+1]=A;area[k]=A
     local q={{x,y}};local head=1
     while q[head]do local p=q[head];head=head+1;A.cells[#A.cells+1]=p
      local pc=C(p[1],p[2]);A.hmin=math.min(A.hmin,pc.height);A.hmax=math.max(A.hmax,pc.height)
      if p[1]==0 or p[2]==0 or p[1]==W-1 or p[2]==H-1 then A.edge=true end
      for _,d in ipairs(dirs)do local nx,ny=p[1]+d[1],p[2]+d[2];local nk=nx..':'..ny;local n=C(nx,ny)
       if flo(n) and not area[nk] and (n.zone or 0)==z then area[nk]=A;q[#q+1]={nx,ny} end
      end
     end
    end
   end end
   local function tag(B,c)return (B and B.zone or '?')..'@'..tostring(c and c.height) end
   for _,A in ipairs(areas)do
    for _,p in ipairs(A.cells)do
     for _,d in ipairs(dirs)do
      local nx,ny=p[1]+d[1],p[2]+d[2];local n=C(nx,ny)
      if n then
       local jd=n.behavior and JD[n.behavior]
       if jd then
        -- the ledge cell n: landing = n + jd, takeoff = n - jd
        local lx,ly,tx,ty=nx+jd[1],ny+jd[2],nx-jd[1],ny-jd[2]
        if lx==p[1] and ly==p[2] then local t=C(tx,ty);local B=area[tx..':'..ty];A.IN[tag(B,t)]=(A.IN[tag(B,t)] or 0)+1
        elseif tx==p[1] and ty==p[2] then local t=C(lx,ly);local B=area[lx..':'..ly];A.OUT[tag(B,t)]=(A.OUT[tag(B,t)] or 0)+1 end
       elseif flo(n) and area[nx..':'..ny]~=A then local B=area[nx..':'..ny];A.WALK[tag(B,n)]=(A.WALK[tag(B,n)] or 0)+1
       elseif n.step then A.STAIR=A.STAIR+1 end
      end
     end
    end
    if next(A.IN) or next(A.OUT) then
     local m=A.zone>0 and marks[A.zone];local function lst(t)local o={};for k,v in pairs(t)do o[#o+1]=k..'x'..v end;table.sort(o);return #o>0 and table.concat(o,',') or '-' end
     f:write(string.format('AREA %s zone=%d mark=%s n=%d h=%d..%d edge=%d IN=%s OUT=%s WALK=%s STAIR=%d at=%d,%d\n',id,A.zone,
      m and (m[1]..','..m[2]..'='..m[3]..(m[4] and 'top' or '')) or '-',#A.cells,A.hmin,A.hmax,A.edge and 1 or 0,lst(A.IN),lst(A.OUT),lst(A.WALK),A.STAIR,A.cells[1][1],A.cells[1][2]))
    end
   end
   f:flush()
  else f:write('SKIP '..id..'\n') end
 end
 f:close();love.event.quit()
end
