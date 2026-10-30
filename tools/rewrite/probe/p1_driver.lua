-- POKEPORT_DRIVER: P1 gate for the clean rewrite mod (EMERALD_3D).
-- Per case: boot to the spot, wait for the mod's 3D field draw, capture the 3D image, then switch the mod's hook off
-- for a few frames and capture the ENGINE'S OWN 2D field at the same spot (the art reference, R-22), then back on.
--   EM_CASES=<cases.lua> EM_LEVELS=<levels.lua> EM_WAIT=<frames> SHOT_DIR=<dir>
-- Reads only the mod's public exports (mod.exports.gen3.probe, gen3hook); no mod internals.
return function(game)
  io.stdout:setvbuf('no')
  local U = dofile('tests/drivers/util.lua')
  local dir = assert(os.getenv('SHOT_DIR'))
  assert((love.filesystem.getIdentity() == 'pokemon-love2d-rseqa'
    or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')), 'refusing a non-QA identity')
  love.window.setMode(1280, 720, { resizable = true })
  game:_handleBootAction({ action = 'new_game', name = 'MAY', gender = 1,
    start = { map = 'EM_LITTLEROOT_TOWN', x = 10, y = 10, facing = 'down' } })
  U.wait(120)

  local exports = game.mods and game.mods.exports or {}
  local ex = exports.EMERALD_3D
  local P = ex and ex.gen3 and ex.gen3.probe
  local H = ex and ex.gen3hook
  print('[P1] export:', ex and 'yes' or 'NO', 'probe:', P and 'yes' or 'NO', 'hook:', H and 'yes' or 'NO')

  local Map = require('src.core.game3.map')
  local Player = require('src.core.game3.player')
  local cases = os.getenv('EM_CASES') and dofile(os.getenv('EM_CASES')) or { { 'EM_LITTLEROOT_TOWN', 10, 10 } }
  local levels = os.getenv('EM_LEVELS') and dofile(os.getenv('EM_LEVELS')) or { 4 }

  for _, case in ipairs(cases) do
    local ok, err = pcall(function()
      assert(Map.load(nil, game, case[1], { x = case[2], y = case[3], facing = 'down' }))
    end)
    print('[P1] load', case[1], case[2], case[3], ok, err or '')
    if ok then
      pcall(Player.reset, case[2], case[3], 'down')
      U.wait(tonumber(os.getenv('EM_WAIT')) or 120)
      if P then
        for _ = 1, 900 do if P.active and P.active() then break end; U.wait(1) end
        local w0, w1, w2, w3
        if P.window then w0, w1, w2, w3 = P.window() end
        print(('[P1] probe %s active=%s builds=%s started=%s window=%s'):format(
          case[1], tostring(P.active and P.active()), tostring(P.builds and P.builds()),
          tostring(P.started and P.started()),
          tostring(w0) .. ',' .. tostring(w1) .. ',' .. tostring(w2) .. ',' .. tostring(w3)))
        if w0 then
          local c = P.cell and P.cell(case[2], case[3])
          print(('[P1] cell(%d,%d) mid=%s coll=%s cls=%s base=%s'):format(case[2], case[3],
            tostring(c and c.mid), tostring(c and c.coll), tostring(c and c.cls), tostring(c and c.base)))
        end
        local pc = P.cell and P.cell(case[2] + 10, case[3])
        print('[P1] cell+10', tostring(pc and pc.mid), tostring(pc and pc.cls))
      end
      if H then
        print(('[P1] hook calls=%s ok=%s flat=%s err=%s'):format(
          tostring(H.calls), tostring(H.sceneOk), tostring(H.sceneFalse), tostring(H.lastError)))
      end
      for _, level in ipairs(levels) do
        U.wait(30)
        local path = string.format('%s/%s_L%d.png', dir, case[1], level)
        if U.shot(game, path) then print('[P1] shot3d', path) end
      end
      if H then
        -- The engine's own flat field for the same spot: the art reference the
        -- 3D image is judged against (R-22). Same identity, same options.
        H.disabled = true
        U.wait(20)
        local ref = string.format('%s/%s_2D.png', dir, case[1])
        if U.shot(game, ref) then print('[P1] shot2d', ref) end
        H.disabled = false
        U.wait(10)
      end
    end
  end
  local FV = require('src.core.game3.field_view')
  print('[P1] fieldview.draw is mod wrapper:', tostring(FV.draw == (H and H.installed and FV.draw) and 'yes' or '?'))
  print('[P1] done')
  love.event.quit()
end
