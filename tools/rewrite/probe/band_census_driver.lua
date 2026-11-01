-- POKEPORT_DRIVER: field-cell dump over MANY maps for the P3a band census (rewrite mod only, QA identity only).
-- For every map in EM_MAPS ("MAP x y" lines) it loads the map, runs the field (probe.fieldCells) and writes
-- EM_DUMP_DIR/<MAP>.cells: one line per cell with the fields the band classifier reads:
--   CELL x y h=<height> cls=<cls> kind=<kind> floor=<0|1> layer=<n> step=<0|1> coll=<n> mid=0xNNN elev=<n>
--        shape=<shape.kind> sea=<0|1> tree=<0|1> bare=<0|1> ledge=<nw,ne,se,sw|nil> relief=<0|1>
--   EM_MAPS=<file> EM_DUMP_DIR=<absolute dir>
return function(game)
 io.stdout:setvbuf('no')
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 require('src.core.game3.rng').Random=function()return 0 end
 require('src.core.game3.tileset_anim')._enabled=false
 local Map=require('src.core.game3.map')
 local probe
 for _,ex in pairs(game.mods.exports or {})do
  if type(ex)=='table' and type(ex.gen3)=='table' and type(ex.gen3.probe)=='table' and type(ex.gen3.probe.fieldCells)=='function' then probe=ex.gen3.probe end
 end
 assert(probe,'no probe.fieldCells')
 local DIR=assert(os.getenv('EM_DUMP_DIR'),'EM_DUMP_DIR')
 local maps={}
 local MAPS=os.getenv('EM_MAPS');assert(MAPS,'EM_MAPS')
 for l in io.lines(MAPS)do local m,x,y=l:match('^(%S+)%s+(%d+)%s+(%d+)');if m then maps[#maps+1]={m,tonumber(x),tonumber(y)} end end
 local function f2(v) if type(v)=='number' then return ('%.2f'):format(v) end return tostring(v) end
 for _,m in ipairs(maps)do
  local id=m[1]
  local ok,err=pcall(Map.load,nil,game,id,{x=m[2],y=m[3],facing='down'})
  if not ok then print(('[CENSUS] %s load failed: %s'):format(id,tostring(err)))
  else
   U.wait(45)
   local okC,cells=pcall(probe.fieldCells,id)
   local def=Map.currentDef()
   local l=def and def.midLayout
   if not (okC and cells and l) then print(('[CENSUS] %s no cells (%s)'):format(id,tostring(cells)))
   else
    local f=assert(io.open(DIR..'/'..id..'.cells','w'))
    f:write(('# %s pair=%s size=%dx%d type=%s\n'):format(id,tostring(l.pair),l.width,l.height,tostring(def.mapType or def.type)))
    local n=0
    for y=0,l.height-1 do for x=0,l.width-1 do
     local c=cells[x..':'..y]
     local raw=l:cellAt(x,y)
     if c then
      n=n+1
      local sh=c.shape
      f:write(('CELL %d %d h=%s cls=%s kind=%s floor=%d layer=%s step=%d coll=%s mid=%s elev=%s shape=%s sea=%d tree=%d bare=%d ledge=%s relief=%d tall=%s\n'):format(
       x,y,f2(c.height),tostring(c.cls),tostring(c.kind),c.floor and 1 or 0,tostring(c.layer),c.step and 1 or 0,
       tostring(raw and raw.coll),raw and ('0x%03X'):format(raw.mid) or 'nil',tostring(raw and raw.elev),
       tostring(sh and sh.kind),(sh and sh.seaRock) and 1 or 0,c.treeLoose and 1 or 0,c.bareDrop and 1 or 0,
       c.ledge and table.concat({f2(c.ledge[1]),f2(c.ledge[2]),f2(c.ledge[3]),f2(c.ledge[4])},',') or 'nil',c.relief and 1 or 0,c.tallDrop and (c.tallDrop.need..'/'..c.tallDrop.reach..'/'..c.tallDrop.dx..','..c.tallDrop.dy) or 'nil'))
     end
    end end
    f:close()
    print(('[CENSUS] %s %dx%d cells %d'):format(id,l.width,l.height,n))
   end
  end
 end
 print('[CENSUS] done')
 love.event.quit()
end
