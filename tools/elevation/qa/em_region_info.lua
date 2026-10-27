return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert(love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa'),'QA only')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 require('src.core.game3.rng').Random=function()return 0 end
 require('src.core.game3.tileset_anim')._enabled=false
 local lib=game.mods.exports.BATTLE_ART_VOXEL_FORK.lib
 local Scene=lib.require('Gen3Scene');local Boundary=lib.require('Gen3Boundary')
 local Map=require('src.core.game3.map')
 local f=assert(io.open(os.getenv('EM_DUMP'),'w'))
 Map.load(nil,game,'EM_ROUTE120',{x=36,y=80,facing='down'});U.wait(300)
 local def=Map.currentDef()
 for _,r in ipairs(Boundary.regions(def,Map.world))do f:write(('REGION %s x=%d y=%d w=%d h=%d\n'):format(tostring(r.def.id),r.x,r.y,r.w,r.h))end
 for cy=74,84 do for cx=36,44 do
  local c=Scene.debugRaw(cx,cy)
  if c then f:write(('%d %d mid=%03X kind=%s boundary=%s base=%s floor=%s cls=%s coll=%s\n'):format(cx,cy,c.mid or 0,tostring(c.shape and c.shape.kind),tostring(c.boundary),tostring(c.base),tostring(c.floor and c.floor.height),tostring(c.floor and c.floor.cls),tostring(c.collision)))end
 end end
 f:close();love.event.quit()
end
