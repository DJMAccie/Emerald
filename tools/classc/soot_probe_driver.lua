-- POKEPORT_DRIVER: Sootopolis cell probe. EM_BOX="x0,y0,x1,y1" EM_DUMP=out. One line per cell: mid kind base floorHigh mass-size mass-bbox handles
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
 local id=os.getenv('EM_MAP') or 'EM_SOOTOPOLIS_CITY'
 local px,py=tonumber(os.getenv('EM_CX') or 8),tonumber(os.getenv('EM_CY') or 54)
 Map.load(nil,game,id,{x=px,y=py,facing='down'});C.setLevel(7,game)
 local n=0;repeat U.wait(10);n=n+10 until (C.active and Scene.debugRaw(px,py)) or n>900
 U.wait(300)
 local x0,y0,x1,y1=os.getenv('EM_BOX'):match('(%d+),(%d+),(%d+),(%d+)')
 local f=assert(io.open(os.getenv('EM_DUMP'),'w'))
 for cy=tonumber(y0),tonumber(y1) do for cx=tonumber(x0),tonumber(x1) do
  local c=Scene.debugRaw(cx,cy)
  if c then
   local m=c.mass
   local h=m and Rock.handles(m,nil)
   f:write(('%d %d %03X kind=%s coll=%s base=%s fh=%s mass=%s n=%s box=%s,%s,%s,%s rockHandles=%s hill=%s sea=%s\n'):format(cx,cy,c.mid or 0,tostring(c.shape and c.shape.kind),tostring(c.collision),tostring(c.base),tostring(c.floorHigh),tostring(m~=nil),tostring(m and #m.members),tostring(m and m.x0),tostring(m and m.y0),tostring(m and m.x1),tostring(m and m.y1),tostring(h),tostring(m and m.hill),tostring(m and m.seaBoulders)))
  end
 end end
 f:close();love.event.quit()
end
