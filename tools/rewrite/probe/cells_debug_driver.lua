-- CELL DEBUG dump (new mod only: probe.fieldCells + the map layout): print every field flag the passes use,
-- plus the raw metatile/collision/elevation/behaviour of the cell. QA identity only.
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
 local def=Map.currentDef()
 local l=def and def.midLayout
 local behaviours={}
 local okS,Scripts=pcall(require,'src.core.game3.scripting.interaction_scripts')
 if okS and type(Scripts)=='table' and type(Scripts.behaviors)=='table' then behaviours=Scripts.behaviors[l.pair] or {} end
 local function f2(v) if type(v)=='number' then return ('%.2f'):format(v) end return tostring(v) end
 local f=assert(io.open(os.getenv('EM_DUMP'),'w'))
 f:write(('# %s pair=%s size=%dx%d\n'):format(id,tostring(l and l.pair),l and l.width or -1,l and l.height or -1))
 for y=y0,y1 do for x=x0,x1 do
  local c=cells[x..':'..y]
  local raw=l and l:cellAt(x,y)
  local beh=raw and behaviours[raw.mid]
  f:write(('CELL %d %d h=%s cls=%s kind=%s floor=%s step=%s drop=%s ledgeLow=%s ledge=%s bareDrop=%s relief=%s high=%s low=%s pin=%s srcMax=%s connector=%s mid=%s coll=%s elev=%s beh=%s\n'):format(
   x,y,f2(c and c.height),tostring(c and c.cls),tostring(c and c.kind),tostring(c and c.floor),tostring(c and c.step),
   c and c.drop and ('%d,%d'):format(c.drop[1],c.drop[2]) or 'nil',f2(c and c.ledgeLow),
   c and c.ledge and table.concat({f2(c.ledge[1]),f2(c.ledge[2]),f2(c.ledge[3]),f2(c.ledge[4])},',') or 'nil',
   tostring(c and c.bareDrop),tostring(c and c.relief),
   f2(c and c.high),f2(c and c.low),tostring(c and c.pin),f2(c and c.srcMax),tostring(c and c.connector),
   raw and ('0x%03X'):format(raw.mid) or 'nil',tostring(raw and raw.coll),tostring(raw and raw.elev),tostring(beh)))
 end end
 f:close();love.event.quit()
end
