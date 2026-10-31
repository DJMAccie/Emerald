-- POKEPORT_DRIVER: how many WINDOW REBUILDS does walking cost, and what does
-- one cost? Teleports the player one cell at a time (the window is keyed on the
-- window's own bounds, so a step and a teleport trigger the same rebuild) and
-- prints Probe.builds after each. Used by the P3 far-field slice to decide
-- whether the window needs the installed look's 6-cell bucket.
--   EM_CASES=<cases.lua> EM_WALK=<cells> EM_WAIT=<frames> SHOT_DIR=<dir>
return function(game)
  io.stdout:setvbuf('no')
  local U = dofile('tests/drivers/util.lua')
  assert((love.filesystem.getIdentity() == 'pokemon-love2d-rseqa'
    or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')), 'refusing a non-QA identity')
  love.window.setMode(1280, 720, { resizable = true })
  game:_handleBootAction({ action = 'new_game', name = 'MAY', gender = 1,
    start = { map = 'EM_LITTLEROOT_TOWN', x = 10, y = 10, facing = 'down' } })
  U.wait(120)

  local ex = (game.mods and game.mods.exports or {}).EMERALD_3D
  local P = ex and ex.gen3 and ex.gen3.probe
  print('[WALK] probe:', P and 'yes' or 'NO')
  local Map = require('src.core.game3.map')
  local Player = require('src.core.game3.player')

  local cases = os.getenv('EM_CASES') and dofile(os.getenv('EM_CASES')) or { { 'EM_LITTLEROOT_TOWN', 10, 10 } }
  local steps = tonumber(os.getenv('EM_WALK')) or 12
  for _, case in ipairs(cases) do
    local map, x0, y0 = case[1], case[2], case[3]
    assert(Map.load(nil, game, map, { x = x0, y = y0, facing = 'down' }))
    U.wait(tonumber(os.getenv('EM_WAIT')) or 150)
    for _ = 1, 900 do if P and P.active and P.active() then break end; U.wait(1) end
    local b0 = P and P.builds and P.builds() or -1
    local w0, _, _, _ = P and P.window and P.window()
    local line = {}
    for i = 1, steps do
      Player.reset(x0 + i, y0, 'down')
      U.wait(6)
      line[#line + 1] = ('%d:%d'):format(i, (P and P.builds and P.builds() or 0) - b0)
    end
    local w1 = P and P.window and P.window()
    print(('[WALK] %s start (%d,%d) builds0=%d window0=%s'):format(map, x0, y0, b0, tostring(w0)))
    print(('[WALK] %s %d steps -> rebuilds %s  window1=%s'):format(map, steps,
      table.concat(line, ' '), tostring(w1)))
  end
  print('[WALK] done')
  love.event.quit()
end
