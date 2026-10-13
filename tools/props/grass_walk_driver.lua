-- driver (EM_DRIVER; case = {map,x,y,facing,direction}): walk (default down) through the grass at the first EM_CASES entry and capture the player in it.
-- Frames: standing above the grass, mid first step, standing in the grass, mid second step, standing again; each
-- at every level in EM_LEVELS (EM_YAW applies). Files: SHOT_DIR/gw_<level>_<n>.png
return function(game)
 local U=dofile('tests/drivers/util.lua')
 local dir=assert(os.getenv('SHOT_DIR'))
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local export=game.mods and game.mods.exports and game.mods.exports.BATTLE_ART_VOXEL_FORK
 local ns=export and (export.gen3 or export.firered)
 local C=ns and ns.camera
 local Map=require('src.core.game3.map');local Player=require('src.core.game3.player')
 local case=dofile(os.getenv('EM_CASES'))[1]
 assert(Map.load(nil,game,case[1],{x=case[2],y=case[3],facing=case[4] or 'down'}))
 pcall(Player.reset,case[2],case[3],case[4] or 'down')
 U.wait(60)
 for _,level in ipairs(os.getenv('EM_LEVELS') and dofile(os.getenv('EM_LEVELS')) or {4}) do
  if C then C.setLevel(level,game);C.yaw=tonumber(os.getenv('EM_YAW')) or 0
   if os.getenv('EM_PITCH') then C.pitch=tonumber(os.getenv('EM_PITCH')) end end
  pcall(Player.reset,case[2],case[3],case[4] or 'down')
  U.wait(60)
  local n=0
  local function shot()n=n+1;U.shot(game,string.format('%s/gw_%d_%d.png',dir,level,n))end
  shot()
  for step=1,2 do
   U.hold(game,case[5] or 'down',5);shot()      -- inside the first frames of a step
   U.hold(game,case[5] or 'down',9);shot()      -- landed in the next cell
  end
  U.wait(30);shot()
 end
 print('[EM gw] done')
 love.event.quit()
end
