-- POKEPORT_DRIVER: dump the engine's own building structure.
--
-- Loads every map in tools/buildings/inventory.json and prints one line per
-- CELL the engine classifies as part of a building column:
--   MAP CX CY MID KIND COLL FIRST LAST ROOFS WALLS WALLTOP HEIGHT ARTROWS BASE
-- so the offline tools can read a building's real facade line, footprint and
-- elevation from the engine rather than guessing them from the tile grid.
--
-- Run from ~/Documents/gen1recomp:
--   POKEPORT_DRIVER=<this> POKEPORT_IDENTITY=pokemon-love2d-rseqa POKEPORT_GAME=emerald \
--   EM_DUMP=<abs out.txt> EM_MAPS=<abs maps.txt> \
--   /Applications/gen1recomp.app/Contents/MacOS/love .
return function(game)
 local U=dofile('tests/drivers/util.lua')
 local out=assert(os.getenv('EM_DUMP'),'EM_DUMP is required')
 local maps=assert(os.getenv('EM_MAPS'),'EM_MAPS is required')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local exports=game.mods and game.mods.exports or {}
 local export=exports.BATTLE_ART_VOXEL_FORK
 assert(export,'no battle art export')
 local Scene=export.lib.require('Gen3Scene')
 local Map=require('src.core.game3.map')
 local list={}
 for line in io.lines(maps)do
  local id=line:match('^%s*(%S+)')
  if id and id~='' then list[#list+1]=id end
 end
 local f=assert(io.open(out,'w'))
 local total,seen=0,0
 for _,id in ipairs(list)do
  local ok,err=pcall(function() assert(Map.load(nil,game,id,{x=1,y=1,facing='down'})) end)
  if not ok then print('[DUMP] load failed',id,err) f:write('FAIL '..id..'\n')
  else
   U.wait(30)
   local def=Map.currentDef()
   local W,H=def.midLayout.width,def.midLayout.height
   local n=0
   for y=0,H-1 do for x=0,W-1 do
    local c=Scene.debugCell(x,y)
    if c and c.col then
     f:write(('%s %d %d %03X %s %d %d %d %d %d %d %d %d %.2f\n'):format(
      id,x,y,c.mid or 0,c.kind or '?',c.collision or 0,
      c.col.first or 0,c.col.last or 0,c.col.roofs or 0,c.col.walls or 0,
      c.col.wallTop or -1,c.col.height or 0,c.col.artRows or 0,0))
     n=n+1
    end
   end end
   print('[DUMP]',id,n,'column cells')
   total=total+n;seen=seen+1
  end
 end
 f:close()
 print('[DUMP] done maps='..seen..' cells='..total)
 love.event.quit()
end
