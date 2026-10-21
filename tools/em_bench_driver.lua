-- Renderer benchmark: frame interval, CPU time inside the world draw and
-- LÖVE draw-call counts, with the mod's 3D pipeline ON and OFF.
--
--   EM_W/EM_H      window pixels (default 1280x720)
--   EM_VSYNC=1     keep vsync (default off for a headless headroom read)
--   EM_CAP         FrameCap ceiling (default 160)
--   EM_LEVELS      levels to test (default {0,4,7})
--   EM_CASES       mod map cases (default Route 112 / 115 / 111 spots)
--   EM_WARM        settle frames after the scene is ready (default 60)
--   EM_FRAMES      sampled frames per case/level (default 180)
--   EM_WALK=up|down hold a direction during the sample (traversal hitches)
--
-- Run from the engine root under qa_tryp.sh with this file as EM_DRIVER.
-- Prints one [BENCH] line per case/level; a line with active=false means the
-- 3D scene never settled and the numbers describe the flat fallback.
return function(game)
  local U = dofile('tests/drivers/util.lua')
  local W = tonumber(os.getenv('EM_W') or 1280)
  local H = tonumber(os.getenv('EM_H') or 720)
  local frames = tonumber(os.getenv('EM_FRAMES') or 180)
  local vsync = os.getenv('EM_VSYNC') == '1' and 1 or 0
  if os.getenv('EM_FULLSCREEN') == '1' then
    love.window.setMode(W, H, { resizable = true, vsync = vsync })
    love.window.setFullscreen(true, 'desktop')
  else
    love.window.setMode(W, H, { resizable = true, vsync = vsync })
  end
  pcall(love.window.setVSync, vsync == 1)
  local FrameCap = require('src.core.FrameCap')
  FrameCap.apply(tonumber(os.getenv('EM_CAP') or 160))
  print(string.format('[BENCH] window %dx%d px dpi=%.2f vsync=%s cap=%d',
    love.graphics.getWidth(), love.graphics.getHeight(),
    love.window.getDPIScale() or 1, tostring(vsync == 1), FrameCap.current))

  game:_handleBootAction({ action = 'new_game', name = 'MAY', gender = 1,
    start = { map = 'EM_ROUTE101', x = 8, y = 10, facing = 'down' } })
  U.wait(120)
  local exports = game.mods and game.mods.exports or {}
  local export = exports.BATTLE_ART_VOXEL_FORK
  local ns = export and (export.gen3 or export.firered)
  local C = ns and ns.camera
  print('[BENCH] mod export:', export and 'yes' or 'NO', 'camera:', C and 'yes' or 'NO')

  -- end-of-frame stats: love.graphics.present is the last call in a frame
  local present = love.graphics.present
  local last, gpuAcc, gpuN = nil, 0, 0
  love.graphics.present = function(...)
    last = love.graphics.getStats()
    local t0 = love.timer.getTime()
    local r = present(...)
    gpuAcc = gpuAcc + (love.timer.getTime() - t0)
    gpuN = gpuN + 1
    return r
  end

  local Display = require('src.core.game3.display')
  local displayPresent = Display.present
  local displayAcc, displayN = 0, 0
  Display.present = function(...)
    local t0 = love.timer.getTime()
    local r = displayPresent(...)
    displayAcc = displayAcc + (love.timer.getTime() - t0)
    displayN = displayN + 1
    return r
  end

  local FV = require('src.core.game3.field_view')
  local worldDraw = FV.draw
  local acc, accFrames = 0, 0
  FV.draw = function(...)
    local t0 = love.timer.getTime()
    local r = worldDraw(...)
    acc = acc + (love.timer.getTime() - t0)
    accFrames = accFrames + 1
    return r
  end

  local Map = require('src.core.game3.map')
  local Player = require('src.core.game3.player')
  local cases = os.getenv('EM_CASES') and dofile(os.getenv('EM_CASES')) or {
    { 'EM_ROUTE112', 27, 29 }, { 'EM_ROUTE115', 27, 46 }, { 'EM_ROUTE111', 15, 14 },
  }
  local levels = os.getenv('EM_LEVELS') and dofile(os.getenv('EM_LEVELS')) or { 0, 4, 7 }

  local function pct(sorted, p)
    return sorted[math.max(1, math.min(#sorted, math.floor(#sorted * p + 0.5)))]
  end

  for _, case in ipairs(cases) do
    local ok = pcall(function()
      assert(Map.load(nil, game, case[1], { x = case[2], y = case[3], facing = 'down' }))
      Player.reset(case[2], case[3], 'down')
    end)
    print('[BENCH] load', case[1], case[2], case[3], ok, ok and '' or 'FAILED')
    if ok then
      for _, level in ipairs(levels) do
        if C then C.setLevel(level, game); C.yaw = 0.8 else level = 0 end
        U.wait(20)
        for _ = 1, 900 do
          if not C or C.active or level == 0 then break end
          U.wait(1)
        end
        U.wait(tonumber(os.getenv('EM_WARM') or 60)) -- settle, warm shaders/mesh cache
        acc, accFrames = 0, 0
        gpuAcc, gpuN, displayAcc, displayN = 0, 0, 0, 0
        local dts, calls, canvases, shaders, texmem, modms = {}, {}, {}, {}, {}, {}
        local walk = os.getenv('EM_WALK')
        U.wait(1)
        for i = 1, frames do
          if walk then
            table.insert(game.input.pressQueue, walk)
            game.input.state[walk] = true
          end
          U.wait(1)
          local dt = love.timer.getDelta()
          dts[#dts + 1] = dt
          if accFrames > 0 then
            modms[#modms + 1] = acc / accFrames * 1000
            acc, accFrames = 0, 0
          end
          if last then
            calls[#calls + 1] = last.drawcalls or 0
            canvases[#canvases + 1] = last.canvasswitches or 0
            shaders[#shaders + 1] = last.shaderswitches or 0
            texmem[#texmem + 1] = (last.texturememory or 0) / 1048576
          end
        end
        if walk then game.input.state[walk] = false end
        table.sort(dts)
        local sum = 0 for _, d in ipairs(dts) do sum = sum + d end
        local function mean(t)
          if #t == 0 then return 0 end
          local s = 0 for _, v in ipairs(t) do s = s + v end
          return s / #t
        end
        local function max(t)
          local m = 0 for _, v in ipairs(t) do if v > m then m = v end end
          return m
        end
        local mm = mean(modms)
        local gpu = gpuN > 0 and gpuAcc / gpuN * 1000 or 0
        local disp = displayN > 0 and displayAcc / displayN * 1000 or 0
        print(string.format(
          '[BENCH] %s %d,%d level=%d active=%s frames=%d | frame mean=%.2f p50=%.2f p95=%.2f max=%.1f | world cpu mean=%.2fms | drawcalls mean=%.0f max=%d | canvas %.0f shader %.0f tex %.0fMB',
          case[1], case[2], case[3], level, tostring(C and C.active or false), #dts,
          sum / #dts * 1000, pct(dts, 0.5) * 1000, pct(dts, 0.95) * 1000, max(dts) * 1000,
          mm, mean(calls), max(calls), mean(canvases), mean(shaders), mean(texmem)))
        print(string.format('[BENCH]   present cpu=%.2fms present-gpu-wait=%.2fms', disp, gpu))
      end
    end
  end
  print('[BENCH] done')
  love.event.quit()
end
