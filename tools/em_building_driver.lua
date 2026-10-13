-- POKEPORT_DRIVER: building capture sweep.
return function(game)
 local U = dofile('tests/drivers/util.lua')
 local dir = assert(os.getenv('SHOT_DIR'), 'SHOT_DIR is required')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')), 'refusing a non-QA identity')
 love.window.setMode(1280, 720, { resizable = true })
 game:_handleBootAction({ action = 'new_game', name = 'MAY', gender = 1, start = { map = 'EM_LITTLEROOT_TOWN', x = 10, y = 10, facing = 'down' } })
 U.wait(90)
 local exports = game.mods and game.mods.exports or {}
 local export = exports.BATTLE_ART_VOXEL_FORK
 print('[BLD_QA] battle art export:', export and 'yes' or 'NO')
 local ns = export and (export.gen3 or export.firered)
 local C = ns and ns.camera
 print('[BLD_QA] gen3 camera:', C and 'yes' or 'NO')

 local Map = require('src.core.game3.map')
 local Player = require('src.core.game3.player')
 local cases = os.getenv('EM_CASES') and dofile(os.getenv('EM_CASES')) or { { 'EM_PETALBURG_CITY', 20, 18 } }
 local levels = os.getenv('EM_LEVELS') and dofile(os.getenv('EM_LEVELS')) or { 4, 7 }
 local yaws = os.getenv('EM_YAWS') and dofile(os.getenv('EM_YAWS')) or { 0 }
 local shot = 0
 for _, case in ipairs(cases) do
  local map, x, y = case[1], case[2], case[3]
  local ok, err = pcall(function() assert(Map.load(nil, game, map, { x = x, y = y, facing = 'down' })) end)
  print('[BLD_QA] load', map, x, y, ok, err or '')
  if ok then
   pcall(Player.reset, x, y, 'down')
   for _, yaw in ipairs(yaws) do
    for _, level in ipairs(levels) do
     if C then C.setLevel(level, game); C.yaw = yaw end
     U.wait(tonumber(os.getenv('EM_WAIT')) or 120)
     shot = shot + 1
     local path = string.format('%s/%s_x%02d_y%02d_lvl%d_yaw%03d.png', dir, map, x, y, level, math.floor(yaw * 180 / math.pi + 0.5))
     U.shot(game, path)
     print(string.format('[BLD_QA] shot %d %s level %s yaw %.2f', shot, path, tostring(level), yaw))
    end
   end
  end
 end
 print('[BLD_QA] done', shot, 'shots')
 love.event.quit()
end
