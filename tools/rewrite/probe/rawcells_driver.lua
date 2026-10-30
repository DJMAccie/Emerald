-- RAW FIELD CELLS dump (debug, new mod only: probe.fieldCells), QA identity only.
--   EM_MAP EM_X0 EM_Y0 EM_X1 EM_Y1 EM_DUMP=<out>
return function(game)
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
 local id=assert(os.getenv('EM_MAP'),'EM_MAP')
 local x0,y0,x1,y1=tonumber(os.getenv('EM_X0')),tonumber(os.getenv('EM_Y0')),tonumber(os.getenv('EM_X1')),tonumber(os.getenv('EM_Y1'))
 Map.load(nil,game,id,{x=x0,y=y0,facing='down'});U.wait(120)
 local cells=assert(probe.fieldCells(id),'no field cells')
 local f=assert(io.open(os.getenv('EM_DUMP'),'w'))
 for y=y0,y1 do for x=x0,x1 do
  local c=cells[x..':'..y]
  if c then f:write(('CELL %d %d height=%s cls=%s kind=%s floor=%s step=%s treeLoose=%s pin=%s srcMax=%s support=%s\n'):format(x,y,tostring(c.height),tostring(c.cls),tostring(c.kind),tostring(c.floor),tostring(c.step),tostring(c.treeLoose),tostring(c.pin),tostring(c.srcMax),tostring(c.support and c.support.x and (c.support.x..':'..c.support.y) or c.support))) end
 end end
 f:close();love.event.quit()
end
