-- POKEPORT_DRIVER: print each map's border block (the tiles the cartridge repeats beyond the edge).
--   EM_MAPS=<file with "MAP x y" lines> EM_DUMP=<out.txt>  (QA identity only)
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local Map=require('src.core.game3.map')
 local f=assert(io.open(os.getenv('EM_DUMP'),'w'))
 for line in io.lines(os.getenv('EM_MAPS'))do
  local id,x,y=line:match('^(%S+)%s+(%d+)%s+(%d+)')
  if id then
   Map.load(nil,game,id,{x=tonumber(x),y=tonumber(y),facing='down'});U.wait(120)
   local def=Map.currentDef();local L=def and def.midLayout
   if not L then f:write(('%s no midLayout\n'):format(id))
   else
    local t={};for _,m in ipairs(L.borderMids or {})do t[#t+1]=('%03X'):format(m)end
    f:write(('%s %dx%d border %dx%d pair=%s mids=%s\n'):format(id,L.width,L.height,L.borderWidth or 0,L.borderHeight or 0,tostring(L.pair),table.concat(t,',')))
   end
   f:flush()
  end
 end
 f:close();love.event.quit(0)
end
