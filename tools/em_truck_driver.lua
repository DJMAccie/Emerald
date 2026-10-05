-- POKEPORT_DRIVER: is the van solid across its whole model? (QA only)
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert(love.filesystem.getIdentity()=='pokemon-love2d-rseqa','QA only')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(120)
 local C=require('src.core.game3.collision');local O=require('src.core.game3.objects')
 local P=require('src.core.game3.player');local Map=require('src.core.game3.map')
 local w=C._widthCells
 local trucks={}
 for _,lid in ipairs(O._order)do local eo=O._byId[lid]
  if eo and tonumber(eo.graphicsId)==94 then trucks[#trucks+1]=eo
   print('[TRK] truck at',eo.cellX,eo.cellY,'visible',tostring(eo.visible),'hidden',tostring(eo.hidden))
   for dx=-2,2 do print('[TRK]   grid',eo.cellX+dx,eo.cellY,C._grid[eo.cellY*w+eo.cellX+dx+1])end
  end end
 -- walk into the van from the west: stand two cells left of it, press right
 local t=trucks[1]
 if t then
  local ok,err=pcall(P.reset,t.cellX-2,t.cellY,'right');U.wait(30)
  local function pos()local q=P.state or P;return tostring(q.cellX or q.x),tostring(q.cellY or q.y)end
  print('[TRK] reset ok',ok,err or '','pos',pos())
  for i=1,3 do
   love.keypressed('right','right',false);U.wait(24);love.keyreleased('right','right');U.wait(6)
   print('[TRK] after step',i,pos())
  end
 end
 love.event.quit()
end
