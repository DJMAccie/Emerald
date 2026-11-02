-- TOUR

local V = ...

local M = {}

local DebugWalk = V.require("DebugWalk")

local on = false
local inMove = false -- inside Player.tryMove: the player's own step
local quiet = false
local frame = 0

local function engine(name)
  local m = package.loaded[name]
  if m == nil then
    local ok, got = pcall(require, name)
    if ok then m = got end
  end
  return type(m) == "table" and m or nil
end

local function bikeRse()
  local Bike = engine("src.core.game3.bike")
  if not (Bike and Bike.rse) then return nil end
  local ok, rse = pcall(Bike.rse)
  return ok and type(rse) == "table" and rse or nil
end

local function refuse() return false end
local function nothing() return nil end

local DELTA = { up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 } }
local function crossEdge(Collision, game, fromX, fromY, dir, run)
  local d = DELTA[dir]
  if not d then return false end
  local Map = engine("src.core.game3.map")
  local P = engine("src.core.game3.player")
  if not (Map and P and Map.load and Map.world) then return false end
  local gx, gy = fromX + d[1], fromY + d[2]
  local dest, lx, ly
  for _, e in ipairs(Map.world) do
    local L = e.def and e.def.midLayout
    if L then
      local x, y = gx - (e.ox or 0), gy - (e.oy or 0)
      if x >= 0 and y >= 0 and x < L.width and y < L.height then dest, lx, ly = e, x, y; break end
    end
  end
  if not dest then return false end
  local Runtime = package.loaded["src.core.game3.runtime"]
  local mod = Runtime and Runtime._mod
  local g = game or (Runtime and Runtime._game)
  if not Map.load(mod, g, dest.id, { x = lx, y = ly, facing = dir, seamless = true, depth1Connections = true }) then
    return false
  end
  local CELL, WALK_FRAMES, RUN_FRAMES = 16, 16, 8
  local landingWater = Collision.isWaterOn and Collision.isWaterOn(dest.def, lx, ly) or false
  P.cellX, P.cellY = lx - d[1], ly - d[2]
  P.px, P.py = P.cellX * CELL, P.cellY * CELL
  P.facing = dir
  P.targetX, P.targetY = lx, ly
  P.moving = true
  P.progress = 0
  P.animClock = 0
  P.running = run and true or false
  P.jumping = false
  P.dismounting = P.surfing and not landingWater or false
  if P.dismounting then
    local Audio = engine("src.core.game3.audio")
    if Audio then Audio.stopSurfMusic() end
  end
  P.spriteYOffset = 0
  P.stepFrames = run and RUN_FRAMES or WALK_FRAMES
  P.syncSavePosition(g)
  return true
end

local SPECS = {
  -- walls: the player's step is allowed onto any cell
  { name = "Collision.canEnter", tbl = "src.core.game3.collision", key = "canEnter",
    make = function(orig)
      return function(game, tx, ty, opts)
        local ok, why = orig(game, tx, ty, opts)
        if ok or not inMove or why == "bounds" then return ok, why end
        return true, nil
      end
    end },
  -- ledges: no hop over the ledge (that would start a jumping state)
  { name = "Collision.ledgeLanding", tbl = "src.core.game3.collision", key = "ledgeLanding",
    make = function(orig)
      return function(game, fx, fy, dir)
        if inMove then return nil end
        return orig(game, fx, fy, dir)
      end
    end },
  -- marks the player's own step, so NPC and scripted movement stay as they are
  { name = "Player.tryMove", tbl = "src.core.game3.player", key = "tryMove",
    make = function(orig)
      return function(dir, game, run)
        local was = inMove
        inMove = true
        local ok, a, b = pcall(orig, dir, game, run)
        inMove = was
        if not ok then error(a, 0) end
        return a, b
      end
    end },
  { name = "Collision.tryConnection", tbl = "src.core.game3.collision", key = "tryConnection",
    make = function(orig, tbl)
      return function(game, fromX, fromY, dir, run)
        local ok = orig(game, fromX, fromY, dir, run)
        if ok or not inMove or not DebugWalk.on() then return ok end
        return crossEdge(tbl, game, fromX, fromY, dir, run)
      end
    end },
  { name = "RotatingGate.checkCollision", tbl = "src.core.game3.rotating_gate", key = "checkCollision",
    make = function(orig)
      return function(...)
        if inMove then return false end
        return orig(...)
      end
    end },
  { name = "BikeRse.acroCollision", tbl = bikeRse, key = "acroCollision",
    make = function(orig)
      return function(beh)
        if inMove then return 0 end
        return orig(beh)
      end
    end },
  { name = "TrainerSight.check", tbl = "src.core.game3.trainer_sight", key = "check",
    make = function() return refuse end },
  { name = "TrainerSight.checkLineOfSight", tbl = "src.core.game3.trainer_sight", key = "checkLineOfSight",
    make = function() return refuse end },
  { name = "Encounters.onStep", tbl = "src.core.game3.encounters", key = "onStep",
    make = function() return nothing end },
  -- forced tile movement and per-step callbacks
  { name = "ForcedMovement.onStepFinished", tbl = "src.core.game3.forced_movement", key = "onStepFinished",
    make = function() return refuse end },
  { name = "ForcedMovement.runStepCallback", tbl = "src.core.game3.forced_movement", key = "runStepCallback",
    make = function() return refuse end },
  -- coord events and walk-into signs
  { name = "Field.tryCoordEvents", tbl = "src.core.game3.field", key = "tryCoordEvents",
    make = function() return refuse end },
  { name = "Field.tryWalkIntoSign", tbl = "src.core.game3.field", key = "tryWalkIntoSign",
    make = function() return nothing end },
  { name = "Space.runOnFrame", tbl = "src.core.game3.scripting.space", key = "runOnFrame",
    make = function() return refuse end },
  { name = "Space.runOnLoad", tbl = "src.core.game3.scripting.space", key = "runOnLoad",
    make = function() return refuse end },
  { name = "Space.runOnWarpIntoMap", tbl = "src.core.game3.scripting.space", key = "runOnWarpIntoMap",
    make = function() return refuse end },
  { name = "Space.runOnResume", tbl = "src.core.game3.scripting.space", key = "runOnResume",
    make = function() return refuse end },
  { name = "Space.runOnReturnToField", tbl = "src.core.game3.scripting.space", key = "runOnReturnToField",
    make = function() return refuse end },
  { name = "Space.runOnDiveWarp", tbl = "src.core.game3.scripting.space", key = "runOnDiveWarp",
    make = function() return refuse end },
  -- while a step's own events are read, no script may start from it
  { name = "Space.startScript", tbl = "src.core.game3.scripting.space", key = "startScript",
    make = function(orig)
      return function(...)
        if quiet then return false end
        return orig(...)
      end
    end },
  { name = "StepEvents.onStepTaken", tbl = "src.core.game3.step_events", key = "onStepTaken",
    make = function(orig)
      return function(session, game)
        quiet = true
        local ok, err = pcall(orig, session, game)
        quiet = false
        if not ok then error(err, 0) end
      end
    end },
  -- queued step events (white-out, VS Seeker, repel, match call) are dropped
  { name = "StepEvents.update", tbl = "src.core.game3.step_events", key = "update",
    make = function(orig, tbl)
      return function(dt, game)
        local q = tbl._queue
        if q then for i = #q, 1, -1 do q[i] = nil end end
        tbl._activeEvent = nil
        return orig(dt, game)
      end
    end },
  -- saving: the in-game save entry point and the file writer for game3 saves
  { name = "Game3.saveGame", tbl = "src.core.Game3", key = "saveGame",
    make = function()
      return function()
        print("[tour] TOUR: saving is off (save refused)")
        return false
      end
    end },
  { name = "SaveData.save", tbl = "src.core.SaveData", key = "save",
    make = function(orig)
      return function(data, ...)
        if type(data) == "table" and data.engine == "game3" then
          print("[tour] TOUR: saving is off (save file not written)")
          return false
        end
        return orig(data, ...)
      end
    end },
}

for _, s in ipairs(SPECS) do s.done = false end

local function tableOf(spec)
  if type(spec.tbl) == "function" then return spec.tbl() end
  return engine(spec.tbl)
end

local function ensure()
  for _, s in ipairs(SPECS) do
    if not s.done then
      local tbl = tableOf(s)
      if tbl and type(tbl[s.key]) == "function" then
        s.tbl_ = tbl
        s.orig = tbl[s.key]
        s.new = s.make(s.orig, tbl)
        tbl[s.key] = s.new
        s.done = true
      end
    end
  end
end

local function restore()
  for i = #SPECS, 1, -1 do
    local s = SPECS[i]
    if s.done then
      if s.tbl_[s.key] == s.new then s.tbl_[s.key] = s.orig end
      s.tbl_, s.orig, s.new, s.done = nil, nil, nil, false
    end
  end
  inMove, quiet = false, false
end

function M.update(want)
  want = want and true or false
  if want ~= on then
    on = want
    if on then
      frame = 0
      print("[tour] TOUR ON: walls, quiet scenes, save refused")
    else
      restore()
      print("[tour] TOUR OFF: engine restored")
    end
  end
  if not on then return end
  frame = frame + 1
  if frame % 30 == 1 then ensure() end
end

function M.overlay(canvas, w, h)
  if not (on and canvas and w and h and h > 0) then return end
  local Battle = package.loaded["src.core.game3.battle"]
  if Battle and Battle.isActive and Battle.isActive() then return end

  local cam = (V.mod and V.mod.exports and V.mod.exports.gen3Camera) or {}
  local Map = engine("src.core.game3.map")
  local P = engine("src.core.game3.player")
  local text = "?"
  if P then
    local ground = 0
    local okG, g = pcall(function() return V.require("Gen3Scene").groundAt(P.px + 8, P.py + 16 - .001) end)
    if okG and tonumber(g) then ground = tonumber(g) end
    local deg = math.floor(math.deg(tonumber(cam.yaw) or 0) + .5) % 360
    text = string.format("%s  %d,%d  h%d  cam%d/%d",
      (Map and Map.current) or "?", math.floor(P.cellX or 0), math.floor(P.cellY or 0),
      math.floor(ground + .5), math.floor(tonumber(cam.level) or 0), deg)
  end

  local Font = require("src.ui.game3.frlg_font")
  local opts = { colors = Font.COLOR.WHITE }
  local tw = Font.measure(text, opts)
  local s = h / 360
  local right = w / s -- the canvas edge in native pixels
  local x0 = right - tw - 3

  local prev = love.graphics.getCanvas()
  love.graphics.setCanvas(canvas)
  love.graphics.push()
  love.graphics.origin()
  love.graphics.scale(s, s)
  love.graphics.setShader()
  love.graphics.setColor(.06, .07, .08, .82)
  love.graphics.rectangle("fill", x0 - 2, 0, tw + 4, 12)
  love.graphics.setColor(1, 1, 1, 1)
  Font.draw(text, x0, 2, opts)
  love.graphics.pop()
  if prev then love.graphics.setCanvas(prev) else love.graphics.setCanvas() end
end

return M
