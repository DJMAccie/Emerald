-- POKEPORT_DRIVER: what does walking cost now (P3 slice 20, docs/specs/WindowChunks.md)?
-- Teleports the player one cell at a time (the window is keyed on the player's
-- 6-cell bucket, so a teleport triggers the same bucket change a walk does) and
-- prints, per step: how many chunk meshes were built, what that frame's build
-- cost, and the whole draw pass's cost.
--   EM_CASES=<cases.lua> EM_WALK=<cells> EM_WAIT=<frames>
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
  print('[WALKCOST] probe:', P and 'yes' or 'NO')
  if not P then love.event.quit(); return end
  local Map = require('src.core.game3.map')
  local Player = require('src.core.game3.player')

  local cases = os.getenv('EM_CASES') and dofile(os.getenv('EM_CASES'))
    or { { 'EM_LITTLEROOT_TOWN', 10, 10 } }
  local steps = tonumber(os.getenv('EM_WALK')) or 12
  local function num(f) local ok, v = pcall(f); return ok and v or -1 end
  for _, case in ipairs(cases) do
    local map, x0, y0 = case[1], case[2], case[3]
    assert(Map.load(nil, game, map, { x = x0, y = y0, facing = 'down' }))
    U.wait(tonumber(os.getenv('EM_WAIT')) or 150)
    for _ = 1, 900 do if P.active and P.active() then break end; U.wait(1) end
    -- let an amortised window finish arriving before the walk starts
    local last, stable = -1, 0
    for _ = 1, 600 do
      local b = num(P.builds)
      if b == last then stable = stable + 1 else stable = 0; last = b end
      if stable > 10 then break end
      U.wait(1)
    end
    local u = num(P.universe)
    local c0 = num(P.chunks)
    print(('[WALKCOST] %s at (%d,%d): universe %s ms, chunks %d, window %s ms, draw %s ms')
      :format(map, x0, y0, tostring(num(P.windowMs)), c0,
        tostring(num(P.windowMs)), tostring(num(P.drawMs))))
    -- the draw pass at a standstill: 10 frames
    local dsum, dn = 0, 0
    for _ = 1, 10 do
      U.wait(1)
      local d = num(P.drawMs)
      if type(d) == 'number' and d >= 0 then dsum = dsum + d; dn = dn + 1 end
    end
    print(('[WALKCOST] %s standstill draw %.2f ms/frame over %d frames'):format(map, dn > 0 and dsum / dn or -1, dn))
    -- the whole frame, the engine's own work included: the number a player feels
    local t0, n0 = love.timer.getTime(), love.timer.getAverageDelta()
    U.wait(60)
    local dt = (love.timer.getTime() - t0) / 60
    print(('[WALKCOST] %s frame time %.2f ms (60 frames, engine delta was %.2f ms)')
      :format(map, dt * 1000, n0 * 1000))
    local b0, line, worstMs, worstChunks = num(P.builds), {}, 0, 0
    for i = 1, steps do
      Player.reset(x0 + i, y0, 'down')
      U.wait(6)
      local b = num(P.builds)
      local built = b - b0
      if built < 0 then built = 0 end
      local wm = num(P.windowMs)
      if built > 0 then
        if wm > worstMs then worstMs = wm end
        if built > worstChunks then worstChunks = built end
      end
      line[#line + 1] = ('%d:+%d/%.1f'):format(i, built, wm)
      b0 = b
    end
    local c1 = num(P.chunks)
    print(('[WALKCOST] %s %d steps: %s'):format(map, steps, table.concat(line, ' ')))
    print(('[WALKCOST] %s chunks %d -> %d, worst build frame %.1f ms (%d chunks)'):format(map, c0, c1, worstMs, worstChunks))
  end
  print('[WALKCOST] done')
  love.event.quit()
end
