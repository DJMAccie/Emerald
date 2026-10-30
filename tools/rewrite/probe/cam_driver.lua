-- POKEPORT_DRIVER: read the 3D camera a mod ACTUALLY draws with at a spot (R-29: measure, do not guess
-- the camera from a picture). Works for either side: the installed look exports its module namespace as
-- `exports.BATTLE_ART_VOXEL_FORK.lib` (+ `gen3Camera` for level/pitch/yaw) and keeps the camera it hands
-- Voxel3D in `Voxel3D.camera`; the rewrite exports `EMERALD_3D.gen3.probe` and keeps its own inside
-- Camera3D (Probe.camera()).
--   EM_CASES=<cases.lua> EM_WAIT=<frames> SHOT_DIR=<dir>   (qa_tryp.sh / clean_try.sh pass all three)
-- Prints one `[CAM] ...` line per fact so the caller can grep them out of run.log.
--
-- 2026-10-30 (P3 slice 17): the numbers that DECIDE the diorama are printed too, because the two golden
-- captures of the play camera disagreed and the numbers had to settle it: the world view the engine hands
-- FieldView.draw (= `vw,vh` of the installed look's Voxel3D.viewProjection), the zoom scale and the fit it
-- came from, and the ENGINE TILT (Tilt.viewGrowth multiplies vw,vh before the field draw, so tilt 2 at a
-- 1280x720 window frames 1.77x the world our tilt-off capture does).
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

  -- Record the size the engine gives the field draw: that is vw,vh of the installed look's camera, and
  -- our Scene's canvasW,H (the two must be the same number for the two cameras to be comparable).
  local FV = require('src.core.game3.field_view')
  local engineDraw = FV.draw
  local viewW, viewH, viewCalls = nil, nil, 0
  FV.draw = function(g, w, h, o)
    viewW, viewH, viewCalls = w, h, viewCalls + 1
    return engineDraw(g, w, h, o)
  end

  local Map = require('src.core.game3.map')
  local Player = require('src.core.game3.player')
  local cases = os.getenv('EM_CASES') and dofile(os.getenv('EM_CASES')) or { { 'EM_LITTLEROOT_TOWN', 10, 10 } }
  for _, case in ipairs(cases) do
    local ok, err = pcall(Map.load, nil, game, case[1], { x = case[2], y = case[3], facing = 'down' })
    print('[CAM] load', case[1], case[2], case[3], ok, err or '')
    if ok then
      pcall(Player.reset, case[2], case[3], 'down')
      U.wait(tonumber(os.getenv('EM_WAIT')) or 150)

      -- the engine's own numbers: window, world view, zoom, tilt
      local ww, wh = love.window.getMode()
      local pw, ph = love.graphics.getDimensions()
      print(('[CAM] window %dx%d dpi=%.2f drawable=%dx%d'):format(ww, wh,
        love.window.getDPIScale(), pw, ph))
      local okZ, Zoom = pcall(require, 'src.render.Zoom')
      local okR, Renderer = pcall(require, 'src.render.Renderer')
      local fit = okR and Renderer.fitScale and Renderer:fitScale() or nil
      local sp = (okZ and okR and Zoom.scale) and Zoom.scale(fit) or nil
      local wvsW, wvsH
      if okR and Renderer.worldViewSize then
        local okW, a, b = pcall(function() return Renderer:worldViewSize() end)
        if okW then wvsW, wvsH = a, b end
      end
      local okT, Tilt = pcall(require, 'src.render.Tilt')
      local tiltLevel, tiltAngle, tiltActive, tiltGrow
      if okT and type(Tilt) == 'table' then
        tiltLevel, tiltAngle, tiltActive = Tilt.level, Tilt.angle, Tilt.active and Tilt.active()
        tiltGrow = Tilt.viewGrowth and Tilt.viewGrowth()
      end
      print(('[CAM] zoom offset=%s fit=%s scale=%s worldViewSize=%sx%s tilt=%s level=%s angle=%s growth=%s'):format(
        tostring(okZ and Zoom.offset), tostring(fit), tostring(sp), tostring(wvsW), tostring(wvsH),
        tostring(tiltActive), tostring(tiltLevel), tostring(tiltAngle), tostring(tiltGrow)))
      print(('[CAM] fieldDraw %sx%s calls=%s'):format(tostring(viewW), tostring(viewH), tostring(viewCalls)))

      local target = love.graphics.getCanvas()
      local cw, ch
      if target then cw, ch = target:getDimensions() else cw, ch = love.graphics.getDimensions() end
      print(('[CAM] canvas %dx%d player px=%s py=%s cell=%s,%s'):format(cw, ch,
        tostring(Player.px), tostring(Player.py), tostring(Player.cellX), tostring(Player.cellY)))

      local ex = (game.mods and game.mods.exports) or {}
      local old = ex.BATTLE_ART_VOXEL_FORK
      if old and old.lib then
        local gc = old.gen3Camera
        print(('[CAM] installed level=%s pitch=%s yaw=%s'):format(tostring(gc and gc.level),
          tostring(gc and gc.pitch), tostring(gc and gc.yaw)))
        local okV, V3 = pcall(old.lib.require, 'Voxel3D')
        if okV and type(V3) == 'table' then
          local cam = V3.camera
          if type(cam) == 'table' and cam.eye and cam.focus then
            print(('[CAM] installed camera eye=%.3f,%.3f,%.3f focus=%.3f,%.3f,%.3f fovdeg=%.3f curve=%s'):format(
              cam.eye[1], cam.eye[2], cam.eye[3], cam.focus[1], cam.focus[2], cam.focus[3],
              (tonumber(cam.fov) or 0) * 180 / math.pi, tostring(cam.curve)))
          else
            print('[CAM] installed Voxel3D.camera=' .. tostring(cam))
          end
          -- the diorama branch's own output: it sets Voxel3D.eye/focus/fovY itself
          local e, f = V3.eye, V3.focus
          if type(e) == 'table' and type(f) == 'table' then
            local dx, dy, dz = e[1] - f[1], e[2] - f[2], e[3] - f[3]
            print(('[CAM] installed diorama eye=%.3f,%.3f,%.3f focus=%.3f,%.3f,%.3f dist=%.3f fovdeg=%.3f'):format(
              e[1], e[2], e[3], f[1], f[2], f[3], math.sqrt(dx * dx + dy * dy + dz * dz),
              (tonumber(V3.fovY) or 0) * 180 / math.pi))
          end
        else
          print('[CAM] installed Voxel3D unreachable: ' .. tostring(V3))
        end
      end
      if ex.EMERALD_3D and ex.EMERALD_3D.gen3 then
        local P = ex.EMERALD_3D.gen3.probe
        local w0, w1, w2, w3
        if P and P.window then w0, w1, w2, w3 = P.window() end
        print(('[CAM] rewrite active=%s window=%s,%s,%s,%s'):format(
          tostring(P and P.active and P.active()), tostring(w0), tostring(w1), tostring(w2), tostring(w3)))
        if P and P.camera then
          local c = P.camera()
          if not c then
            print('[CAM] rewrite camera=nil cameraCalls=' ..
              tostring(P.cameraCalls and P.cameraCalls()))
          else
            local eye, tgt = c.eye, c.target
            local dx, dy, dz = eye[1] - tgt[1], eye[2] - tgt[2], eye[3] - tgt[3]
            print(('[CAM] rewrite camera eye=%.3f,%.3f,%.3f target=%.3f,%.3f,%.3f dist=%.3f fovdeg=%.3f level=%s size=%sx%s'):format(
              eye[1], eye[2], eye[3], tgt[1], tgt[2], tgt[3], math.sqrt(dx * dx + dy * dy + dz * dz),
              (tonumber(c.fov) or 0) * 180 / math.pi, tostring(c.level),
              tostring(c.width), tostring(c.height)))
          end
        end
      end
      -- Project five ground points with the camera each side actually drew with (the focus and four
      -- 4-cell offsets around it): the same world point must land on the same image pixel, so a sheet
      -- can be fitted numerically instead of by eye. Installed px are in the mod's RENDER canvas
      -- (beginScene's w,h = 1280x720 here); the rewrite's are in the world canvas the engine hands the
      -- field draw (640x360), i.e. screen = 2x these.
      local gx, gz = (tonumber(Player.px) or 0) + 8, (tonumber(Player.py) or 0) + 8
      local ground = 0
      if ex.EMERALD_3D and ex.EMERALD_3D.gen3 then
        local P = ex.EMERALD_3D.gen3.probe
        if P and P.groundAt then
          local okG, g = pcall(P.groundAt, gx, gz)
          if okG and tonumber(g) then ground = tonumber(g) end
        end
      end
      -- The GROUND the camera stands its focus on: the installed look reads it from its built
      -- window's floor regions (Gen3Scene.groundAt) and answers 0 when the player's cell is not in
      -- one, so print both sides' answer plus the elevation the engine passes.
      local oldG = ex.BATTLE_ART_VOXEL_FORK
      if oldG and oldG.lib then
        local okS, GS = pcall(oldG.lib.require, 'Gen3Scene')
        if okS and type(GS) == 'table' and GS.groundAt then
          for _ = 1, 2 do
            local okA, g1 = pcall(GS.groundAt, gx, gz - 0.001, Player.elevation)
            print(('[CAM] installed groundAt(%.1f,%.1f,elev=%s)=%s'):format(gx, gz,
              tostring(Player.elevation), tostring(okA and g1 or 'ERR')))
            if _ == 1 then U.wait(120) end
          end
        end
      end
      if ex.EMERALD_3D and ex.EMERALD_3D.gen3 then
        local P = ex.EMERALD_3D.gen3.probe
        if P and P.groundAt then
          local pc = P.cell and P.cell(math.floor(gx / 16), math.floor(gz / 16))
          print(('[CAM] rewrite groundAt(%.1f,%.1f)=%s cellBase=%s cls=%s'):format(gx, gz,
            tostring(P.groundAt(gx, gz)), tostring(pc and pc.base), tostring(pc and pc.cls)))
        end
      end
      local pts = { { 'focus', gx, gz }, { 'n64', gx, gz - 64 }, { 's64', gx, gz + 64 },
        { 'e64', gx + 64, gz }, { 'w64', gx - 64, gz } }
      local oldSide = ex.BATTLE_ART_VOXEL_FORK
      if oldSide and oldSide.lib then
        local okV, V3 = pcall(oldSide.lib.require, 'Voxel3D')
        if okV and type(V3) == 'table' and V3.project then
          for _, p in ipairs(pts) do
            local px_, py_ = V3.project(p[2], ground, p[3])
            if px_ then
              print(('[CAM] installed project %s world=%.1f,%.1f px=%.1f,%.1f'):format(
                p[1], p[2], p[3], px_, py_))
            end
          end
        end
      end
      if ex.EMERALD_3D and ex.EMERALD_3D.gen3 then
        local P = ex.EMERALD_3D.gen3.probe
        local c = P and P.camera and P.camera()
        if c and c.project then
          for _, p in ipairs(pts) do
            local px_, py_ = c.project(p[2], ground, p[3])
            if px_ then
              print(('[CAM] rewrite project %s world=%.1f,%.1f px=%.1f,%.1f'):format(
                p[1], p[2], p[3], px_, py_))
            end
          end
        end
      end
      local path = string.format('%s/%s_cam.png', dir, case[1])
      if U.shot(game, path) then print('[CAM] shot', path) end
    end
  end
  print('[CAM] done')
  love.event.quit()
end
