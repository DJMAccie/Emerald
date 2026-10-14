-- POKEPORT_DRIVER: rock census. For every map in EM_MAPS (lines "MAP x y", the player is put there; use a
-- walkable cell), builds the scene at the ORBIT camera (largest build area) and writes one line per rock
-- cluster to EM_DUMP:
--   MAP cluster builder ncells x0 y0 x1 y1 standX standY mids
-- builder: rock     Gen3Rock course-built mass (cliffs, mountains, islands)
--          dome     Gen3Mass dome (sea boulders, banks, other masses Gen3Rock does not take)
--          object   Gen3Objects standing object (water=sea rock); objwater for sea ones
--          rockkind kind 'rock' cells (Gen3Cave.rock)
--          sprite   Rock Smash / Strength actors (gid 86/87)
-- stand = a walkable cell 2..4 rows south of the cluster (or nearest), for captures.
-- QA identity only.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert(love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa'),'QA only')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(120)
 local ex=game.mods.exports.BATTLE_ART_VOXEL_FORK
 local C=(ex.gen3 or ex.firered).camera
 local Scene=ex.lib.require('Gen3Scene')
 local Rock=ex.lib.require('Gen3Rock')
 local Map=require('src.core.game3.map')
 local Objects=require('src.core.game3.objects')
 local f=assert(io.open(os.getenv('EM_DUMP'),'w'))
 for line in io.lines(os.getenv('EM_MAPS'))do
  local id,px,py=line:match('^(%S+)%s+(%d+)%s+(%d+)')
  if id then
   Map.load(nil,game,id,{x=tonumber(px),y=tonumber(py),facing='down'});C.setLevel(7,game)
   local n=0;repeat U.wait(10);n=n+10 until (C.active and Scene.debugRaw(tonumber(px),tonumber(py))) or n>900
   U.wait(200)
   local def=Map.currentDef();local W,H=def.midLayout.width,def.midLayout.height
   local groups,order={},{}
   local function add(key,builder,c)
    local g=groups[key];if not g then g={builder=builder,cells={},x0=c.cx,y0=c.cy,x1=c.cx,y1=c.cy,mids={}};groups[key]=g;order[#order+1]=key end
    g.cells[#g.cells+1]=c;g.x0=math.min(g.x0,c.cx);g.y0=math.min(g.y0,c.cy);g.x1=math.max(g.x1,c.cx);g.y1=math.max(g.y1,c.cy)
    g.mids[string.format('%X',c.mid or 0)]=true
   end
   local cells={}
   for cy=0,H-1 do for cx=0,W-1 do
    local c=Scene.debugRaw(cx,cy)
    if c then cells[cx..':'..cy]=c
     local o=c.object or c.objectTop
     if c.mass then
      local b=(Rock.handles(c.mass,nil) and 'rock') or 'dome'
      add(tostring(c.mass),b,c)
     elseif o then add(tostring(o),o.water and 'objwater' or 'object',c)
     elseif c.shape and c.shape.kind=='rock' then add('rk'..cx..':'..cy,'rockkind',c) end
    end
   end end
   for _,eo in ipairs(Objects._order and (function()local t={};for _,k in ipairs(Objects._order)do t[#t+1]=Objects._byId[k]end;return t end)() or {})do
    local gid=tonumber(eo and eo.graphicsId)
    if gid==86 or gid==87 then
     local c=cells[eo.cellX..':'..eo.cellY] or {cx=eo.cellX,cy=eo.cellY,mid=0}
     add('sp'..eo.cellX..':'..eo.cellY,'sprite',c)
    end
   end
   local function walk(x,y)local c=cells[x..':'..y];return c and (c.collision or 0)==0 and c.shape and (c.shape.kind=='flat' or c.shape.kind=='grass') end
   for i,key in ipairs(order)do local g=groups[key]
    local sx,sy
    local mx=math.floor((g.x0+g.x1)/2)
    for d=1,6 do for dx=0,4 do for _,s in ipairs({dx,-dx})do
     if not sx and walk(mx+s,g.y1+d) then sx,sy=mx+s,g.y1+d end end end end
    if not sx then for r=1,8 do for dy=-r,r do for dx=-r,r do if not sx and walk(mx+dx,g.y1+dy) then sx,sy=mx+dx,g.y1+dy end end end end end
    local m={};for k in pairs(g.mids)do m[#m+1]=k end;table.sort(m)
    f:write(('%s %d %s %d %d %d %d %d %s %s %s\n'):format(id,i,g.builder,#g.cells,g.x0,g.y0,g.x1,g.y1,tostring(sx or -1),tostring(sy or -1),table.concat(m,',')))
   end
   f:flush();print('[EM census]',id,#order)
  end
 end
 f:close();love.event.quit()
end
