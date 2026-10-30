-- TOUR: walk the whole world and screenshot what looks wrong.
--
-- ON (the TOUR row in the Battle Art options, default OFF):
--   walls     Player.tryMove asks Collision.canEnter about the step; while the
--             player's own step is being decided, every refusal except a map
--             edge is turned into a pass. That covers solid tiles, water without
--             Surf, ledges (their hop is also skipped, so no jumping state),
--             elevation mismatches, NPCs, rotating gates and acro-bike walls.
--             Map edges and connections are unchanged.
--   quiet     trainer sight, on-frame / map-entry / resume / warp-into scripts,
--             coord events, walk-into signs, step-triggered scripts (repel, VS
--             Seeker, poison white-out, Safari, match call), wild encounters
--             started by walking, forced tile slides (ice, spin, conveyors) and
--             per-step callbacks do not run. A-button talk and door, stair,
--             escalator and arrow warps are untouched.
--   save      Game3:saveGame and SaveData.save (game3 saves) are refused, so no
--             story progress or mystery gift reaches the save file.
--   label     MAP_ID  x,y  h<ground>  cam<level>/<yaw> in the top-right corner,
--             in the overworld only.
-- OFF restores every field it swapped; nothing else is touched.
--
-- Engine code is never edited. Each wrap is a table-field swap (the same way
-- Gen3StadiumModels wraps Anim.launchMove) and is undone on OFF only if the
-- field still holds our wrapper.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local M = {}

local on = false
local inMove = false   -- inside Player.tryMove: the player's own step
local quiet = false    -- inside StepEvents.onStepTaken: scripts may not start
local frame = 0

-- the engine module table for a spec: package.loaded first, then one require
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

-- Each spec: the table holding the field, the field, and make(orig, tbl) ->
-- the replacement. Engine files named here are the only ones touched.
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
  -- trainers never spot the player (same stubs as tools/furniture/driver.lua)
  { name = "TrainerSight.check", tbl = "src.core.game3.trainer_sight", key = "check",
    make = function() return refuse end },
  { name = "TrainerSight.checkLineOfSight", tbl = "src.core.game3.trainer_sight", key = "checkLineOfSight",
    make = function() return refuse end },
  -- wild encounters started by walking (rock smash, fishing and sweet scent
  -- call BattleBridge directly and are not walking)
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
  -- map-entry and on-frame scripts (onTransition is state setup for NPC
  -- graphics and is left running)
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

-- resolve a spec's table; a function spec may return nil until its module is up
local function tableOf(spec)
  if type(spec.tbl) == "function" then return spec.tbl() end
  return engine(spec.tbl)
end

-- swap in every wrap whose table is up; a missing module is retried later
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

-- Called every frame with the TOUR setting's value. Switching ON installs the
-- wraps; switching OFF restores them, without a restart.
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
  -- modules that load late are picked up within half a second
  frame = frame + 1
  if frame % 30 == 1 then ensure() end
end

function M.active()
  return on
end

-- Draws the location label on the finished scene canvas. The label is one
-- native line of about 10 px text at 240x160 scale, right-aligned, on a dark
-- strip; it is skipped in battles.
function M.overlay(canvas, w, h)
  if not (on and canvas and w and h and h > 0) then return end
  local Battle = package.loaded["src.core.game3.battle"]
  if Battle and Battle.isActive and Battle.isActive() then return end
  local okC, CamControl = pcall(function() return V.require("CamControl") end)
  if okC and CamControl and CamControl.battleLive and CamControl.battleLive() then return end

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
  local s = h / 360                 -- small: under half a native pixel, so the label stays out of the picture
  local right = w / s               -- the canvas edge in native pixels
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

-- the names of the engine fields this module swaps (for the report)
function M.wrapNames()
  local out = {}
  for _, s in ipairs(SPECS) do out[#out + 1] = s.name end
  return out
end

return M
