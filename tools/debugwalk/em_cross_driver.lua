-- QA driver: walk off a map edge with TOUR on (DEBUG WALK) and print where the
-- player ends up; the gate for TourMode's crossEdge (whole-map preload too).
--   EM_DRIVER=this QA_SRC=<probe or source> tools/qa_tryp.sh "<files>" <out> "-" 4 0.8 200
-- Expect: [EM dbg] EM_ROUTE101 10 19 after walking north off Littleroot (10,0);
-- a map edge with no neighbour in Map.world must leave the cell unchanged.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 local dir=assert(os.getenv('SHOT_DIR'))
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=0,facing='up'}})
 -- the gate under test: the loader-backed option DebugWalk.on() reads
 game.mods.modOptions=game.mods.modOptions or {}
 game.mods.modOptions.BATTLE_ART_VOXEL_FORK=game.mods.modOptions.BATTLE_ART_VOXEL_FORK or {}
 game.mods.modOptions.BATTLE_ART_VOXEL_FORK.tour=true
 U.wait(90)
 local export=game.mods.exports.BATTLE_ART_VOXEL_FORK
 local Map=require('src.core.game3.map');local Player=require('src.core.game3.player')
 local ns=export and export.gen3
 local C=ns and ns.camera
 if C then C.setLevel(4,game);C.yaw=0.8 end
 print('[EM dbg] start',Map.current,Player.cellX,Player.cellY)
 for i=1,80 do
  Player.tryMove('up',game,false)
  U.wait(2)
  if i%10==0 then print('[EM dbg] step',i,Map.current,Player.cellX,Player.cellY) end
 end
 print('[EM dbg] end',Map.current,Player.cellX,Player.cellY)
 local f=io.open(dir..'/cross.png','wb')
 U.shot(game,dir..'/cross.png')
end
