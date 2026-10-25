-- tools/searock: em_probe_driver with the map, cell and height from the environment (EM_MAP EM_CX EM_CY EM_PROBEY)
-- POKEPORT_DRIVER: which cells put geometry above a height. Edit the map/cell and Scene.probeY below.
-- Prints '[EM hit] cx,cy quads mid kind base pair collision flags' per cell (Gen3Scene quad funnel, probeHits).
-- Run: EM_DRIVER=tools/em_probe_driver.lua tools/qa_tryp.sh "Gen3Scene.lua" <out> "-" 4
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert(love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa'),'QA only')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local lib=game.mods.exports.BATTLE_ART_VOXEL_FORK.lib
 local Scene=lib.require('Gen3Scene');Scene.probeBox={tonumber(os.getenv('EM_BX0')),tonumber(os.getenv('EM_BX1')),tonumber(os.getenv('EM_BZ0')),tonumber(os.getenv('EM_BZ1'))}
 local ns=game.mods.exports.BATTLE_ART_VOXEL_FORK.gen3 or game.mods.exports.BATTLE_ART_VOXEL_FORK.firered
 local Map=require('src.core.game3.map')
 Map.load(nil,game,os.getenv('EM_MAP'),{x=tonumber(os.getenv('EM_CX')),y=tonumber(os.getenv('EM_CY')),facing='down'})
 if ns and ns.camera then ns.camera.level=7 end
 U.wait(700)
 local n=0
 for k,c in pairs(Scene.probeHits or {})do
  local x,y=k:match('(-?%d+),(-?%d+)');local r=Scene.debugRaw(tonumber(x),tonumber(y)) or {}
  print('[EM hit]',k,c,r.mid and string.format('%03X',r.mid),r.shape and r.shape.kind,r.base,r.pair,r.collision,r.mass and 'mass',r.object and 'object',r.objectTop and 'objTop',r.prop and 'prop',r.bldModel and 'bld',r.civic and 'civic',r.column and 'column')
  n=n+1
 end
 print('[EM hit] total',n)
 love.event.quit()
end
