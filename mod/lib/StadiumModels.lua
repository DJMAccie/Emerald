-- Optional Stadium 2 model adapter for Battle Art's staged voxel arena

local V = ...

local Mat4 = V.require("Mat4")
local BattleSpecies = V.require("BattleSpecies")

local StadiumModels = {}
local FlyMotion = V.require("FlyMotion")
StadiumModels.log = false

local providerHandle, providerExports, models
local actors = { player = {}, enemy = {} }
local warned = {}

local function warnOnce(key, message)
  if warned[key] then return end
  warned[key] = true
  local log = V.mod and V.mod.log
  if log and log.warn then pcall(log.warn, log, "%s", tostring(message)) end
end

local function findMod(id)
  local finder = V.mod and V.mod.find
  if type(finder) ~= "function" then return nil end
  local ok, handle = pcall(finder, id)
  if ok and handle then return handle end
  ok, handle = pcall(finder, V.mod, id)
  return ok and handle or nil
end

local function connect()
  if models and type(models.newInstance) == "function" then
    return models, providerExports
  end
  local handle = findMod("STADIUM2_IMPORTER")
  local exports = handle and handle.exports or nil
  local candidate = type(exports) == "table" and exports.models or nil
  if type(candidate) ~= "table" or (tonumber(candidate.apiVersion) or 0) < 2
      or type(candidate.newInstance) ~= "function" then
    return nil
  end
  providerHandle, providerExports, models = handle, exports, candidate
  return models, providerExports
end

function StadiumModels.installed()
  return connect() ~= nil
end

local function exportEnabled(exports, name)
  local fn = exports and exports[name]
  if type(fn) ~= "function" then return nil end
  local ok, enabled = pcall(fn)
  if not ok then ok, enabled = pcall(fn, exports) end
  if ok then return enabled end
  return nil
end

function StadiumModels.active()
  local api, exports = connect()
  if not api then return false end
  if exportEnabled(exports, "modelsEnabled") ~= true then return false end
  if exportEnabled(exports, "battleEnabled") ~= true then return false end
  return true
end

local function releaseActor(actor)
  if actor.instance and type(actor.instance.release) == "function" then
    pcall(actor.instance.release, actor.instance)
  end
  for key in pairs(actor) do actor[key] = nil end
end

local function failActor(actor)
  local battler, dex, variant = actor.battler, actor.dex, actor.variant
  releaseActor(actor)
  actor.failedBattler, actor.failedDex, actor.failedVariant =
    battler, dex, variant
end

function StadiumModels.release()
  releaseActor(actors.player)
  releaseActor(actors.enemy)
  StadiumModels.animWasPlaying = false
end

local function maxDex()
  local _, exports = connect()
  local fn = exports and exports.speciesMax
  if type(fn) == "function" then
    local ok, value = pcall(fn)
    value = ok and tonumber(value) or nil
    if value and value >= 251 then return math.floor(value) end
  end
  return 251
end

local function dexFor(battle, battler)
  local species = BattleSpecies.speciesFor(battler)
  local limit = maxDex()
  if type(species) == "number" then
    local dex = math.floor(species)
    return dex >= 1 and dex <= limit and dex or nil
  end
  local pokemon = battle and battle.data and battle.data.pokemon
  local def = type(pokemon) == "table" and pokemon[species] or nil
  local dex = def and tonumber(def.dex or def.index)
  dex = dex and math.floor(dex) or nil
  return dex and dex >= 1 and dex <= limit and dex or nil
end

local function safeCall(object, name, ...)
  local fn = object and object[name]
  if type(fn) ~= "function" then return nil end
  local ok, value, extra = pcall(fn, object, ...)
  if not ok then return nil, value end
  return value, extra
end

local function playIdle(actor)
  if not actor.instance then return false end
  local ok = safeCall(actor.instance, "playContext", "idle", true)
  actor.context = ok and "idle" or actor.context
  return ok and true or false
end

local function playContext(actor, context, loop)
  if not actor.instance then return false end
  local ok = safeCall(actor.instance, "playContext", context, loop)
  if not ok and context == "attack" then
    ok = safeCall(actor.instance, "playContext", "attack_default", loop)
  end
  if not ok and context ~= "idle" then return playIdle(actor) end
  if ok then actor.context = context end
  return ok and true or false
end

local function playHit(actor)
  if not actor.instance then return false end
  local ok = safeCall(actor.instance, "playContext", "hit", false)
  if ok then actor.context = "hit" end
  return ok and true or false
end

local function isAsleep(battler)
  local status = battler and (battler.status or (battler.mon and battler.mon.status))
  status = status and tostring(status):upper()
  return status == "SLP" or status == "SLEEP"
end

local function playRest(actor, asleep)
  if asleep and actor.instance then
    local ok = safeCall(actor.instance, "playContext", "sleep", true)
    if ok then actor.context = "sleep" return true end
  end
  return playIdle(actor)
end

local function syncSide(battle, side)
  local actor = actors[side]
  local battler = battle and battle[side]
  local dex = dexFor(battle, battler)
  local variant = BattleSpecies.isShiny(battler) and "shiny" or "normal"
  if actor.instance and actor.battler == battler and actor.dex == dex
      and actor.variant == variant then return actor end
  if actor.failedBattler == battler and actor.failedDex == dex
      and actor.failedVariant == variant then return actor end

  releaseActor(actor)
  actor.battler, actor.dex, actor.variant = battler, dex, variant
  if not (battler and dex) then return actor end

  local api = connect()
  if not api then return actor end
  local called, instance, err = pcall(api.newInstance, dex, variant, {
    textureFilter = "nearest",
    anisotropy = 4,
    flipY = false,
    anchorTravel = true,
  })
  if not called then err, instance = instance, nil end
  if type(instance) ~= "table" then
    actor.failedBattler, actor.failedDex, actor.failedVariant =
      battler, dex, variant
    warnOnce(("load:%s:%d:%s"):format(side, dex, variant),
      ("Stadium 2 %s model %03d (%s) unavailable: %s; using Battle Art")
        :format(side, dex, variant, tostring(err)))
    return actor
  end

  actor.instance = instance
  actor.callbackFrame = side == "enemy" and 4 or 0
  actor.context = "idle"
  actor.lastGrow, actor.lastFainted, actor.lastPicKind = false, false, nil
  actor.lastHits, actor.lastAsleep = nil, nil
  playIdle(actor)
  return actor
end

function StadiumModels.sync(battle)
  if not StadiumModels.active() then
    StadiumModels.release()
    return false
  end
  syncSide(battle, "player")
  syncSide(battle, "enemy")
  return true
end

local function drawableMetrics(actor, side)
  if not (actor and actor.instance) then return nil end
  local metrics = safeCall(actor.instance, "metrics")
  if type(metrics) == "table" and tonumber(metrics.height)
      and tonumber(metrics.height) > 0 then
    return metrics
  end

  if side == "player" and type(actor.instance.draw) == "function" then
    return { height = 52.25, floor = 0, legendaryFallback = true }
  end
  return nil
end

local function updatePresentation(battle, side, actor)
  if not actor.instance then return end
  local battler = battle and battle[side]
  local grow = battler and safeCall(battle, "growInScale", battler) or nil
  if grow and not actor.lastGrow then playContext(actor, "entrance", false) end
  actor.lastGrow = grow and true or false

  local fainted = battler and battler.fainted and true or false
  local faintFx = battler and safeCall(battle, "fxFaintActive", battler) or false

  local hits = battle and battle.hitSerial and battle.hitSerial[side] or 0
  if actor.lastHits == nil then actor.lastHits = hits end
  if hits ~= actor.lastHits then
    actor.lastHits = hits
    local lethal = battler and battler.mon and (tonumber(battler.mon.hp) or 1) <= 0
    if fainted or faintFx or lethal then
      if StadiumModels.log then
        print(("[Battle Art] hit clip skipped %s (fainting)"):format(side))
      end
    elseif playHit(actor) and StadiumModels.log then
      print(("[Battle Art] hit clip %s"):format(side))
    end
  end

  local asleep = isAsleep(battler)
  if asleep ~= (actor.lastAsleep or false) then
    actor.lastAsleep = asleep
    if actor.context == "idle" or actor.context == "sleep" then
      playRest(actor, asleep)
      if StadiumModels.log then
        print(("[Battle Art] rest clip %s asleep=%s context=%s")
          :format(side, tostring(asleep), tostring(actor.context)))
      end
    end
  end

  if (faintFx or fainted) and not actor.lastFainted then
    playContext(actor, "faint", false)
    if StadiumModels.log then
      print(("[Battle Art] faint clip %s context=%s"):format(side, tostring(actor.context)))
    end
  end
  actor.lastFainted = fainted or faintFx or false

  local picFx = battler and battle.picFx and battle.picFx[battler] or nil
  local kind = picFx and picFx.kind or nil
  if kind == "blink" and actor.lastPicKind ~= "blink" then actor.flash = 0.12 end
  actor.lastPicKind = kind
end

function StadiumModels.update(battle, dt)
  FlyMotion.update(battle, dt)
  if not StadiumModels.sync(battle) then return false end

  for _, side in ipairs({ "player", "enemy" }) do
    updatePresentation(battle, side, actors[side])
  end

  local playing = battle and battle.animPlaying and true or false
  if playing and not StadiumModels.animWasPlaying then
    local def = battle.data and battle.data.moves and battle.data.moves[battle.animName]
    local side = battle.animAttackerIsPlayer and "player" or "enemy"
    local actor = actors[side]
    local move = def and tonumber(def.index or def.number)
    actor.lastMove = move
    local ok = actor.instance and move
      and safeCall(actor.instance, "playMove", move, false)
    actor.lastMoveOk = ok and true or false
    if actor.instance and not ok then
      playContext(actor, "attack", false)
    end
    if ok then actor.context = "attack" end
  end
  StadiumModels.animWasPlaying = playing

  dt = math.max(0, tonumber(dt) or 0)
  for _, side in ipairs({ "player", "enemy" }) do
    local actor = actors[side]
    if actor.instance then
      actor.flash = math.max(0, (actor.flash or 0) - dt)
      actor.callbackFrame = (actor.callbackFrame or 0) + dt * 30
      local updated, err = safeCall(actor.instance, "update", dt, {
        callbackFrame = math.floor(actor.callbackFrame),
        species = actor.dex,
        dynamicObjectEnabled = true,
        dynamicObjectUpdateEnabled = true,
      })
      if updated == nil and err then
        warnOnce("update:" .. side,
          ("Stadium 2 %s model update failed: %s; using Battle Art")
            :format(side, tostring(err)))
        failActor(actor)
      elseif safeCall(actor.instance, "isFinished")
          and actor.context ~= "idle" and actor.context ~= "faint"
          and actor.context ~= "sleep" then
        playRest(actor, isAsleep(battle and battle[side]))
      end
    end
  end
  return true
end

local function atan2(y, x)
  if math.atan2 then return math.atan2(y, x) end
  if x > 0 then return math.atan(y / x) end
  if x < 0 then return math.atan(y / x) + (y >= 0 and math.pi or -math.pi) end
  if y > 0 then return math.pi / 2 end
  if y < 0 then return -math.pi / 2 end
  return 0
end

local LEGENDARY = {}
for _, dex in ipairs({144,145,146,150,151, 243,244,245,249,250,251,
                      377,378,379,380,381,382,383,384,385,386}) do LEGENDARY[dex] = 1.35 end
for _, dex in ipairs({149, 248, 373, 376}) do LEGENDARY[dex] = 1.2 end -- pseudo-legendaries
function StadiumModels.presenceBoost(dex)
  return LEGENDARY[math.floor(tonumber(dex) or 0)] or 1
end

local function modelMatrix(arena, groundY, battle, side, actor, metrics)
  local point = arena and arena[side]
  local target = arena and arena[side == "player" and "enemy" or "player"]
  if not (point and target and actor.instance) then return nil end
  metrics = metrics or drawableMetrics(actor, side)
  if not metrics then return nil end

  local worldHeight = math.max(5, math.min(18,
    14 * math.sqrt(metrics.height / 52.25)))
  local boost = StadiumModels.presenceBoost(actor.dex)
  if boost > 1 then worldHeight = math.min(26, worldHeight * boost) end
  local battler = battle and battle[side]
  local grow = battler and safeCall(battle, "growInScale", battler) or 1
  grow = tonumber(grow) or 1
  local plasma=battle and battle.legendaryQ57 and battle.legendaryQ57[side]
  if plasma and plasma.subjectDone then plasma=nil end
  local release = battle and ((side=="enemy" and battle.legendaryBreakoutPose)
    or (battle.legendaryReleasePose and battle.legendaryReleasePose[side]))
  if release then grow=release.scale end
  if plasma then grow=1 end
  local k = worldHeight / metrics.height * math.max(0, math.min(1, grow))
  local floor = tonumber(metrics.floor) or 0
  local hover = math.min(math.max(floor, 0), metrics.height * 0.5)
  local yaw = atan2(target[1] - point[1], target[2] - point[2])
  if plasma then
    plasma.source={point[1],groundY+worldHeight*0.5,point[2]}
    plasma.height=worldHeight
    plasma.width=math.max(4,math.min(64,worldHeight*(tonumber(metrics.width) or metrics.height)/metrics.height))
    plasma.yaw=yaw;plasma.rx=math.cos(yaw);plasma.rz=-math.sin(yaw)
    plasma.fx=math.sin(yaw);plasma.fz=math.cos(yaw)
  end
  local flight = FlyMotion.pose(battle, side)
  local fx,fy,fz=point[1],groundY,point[2]
  if flight then
    fx=fx+(target[1]-point[1])*flight.advance
    fz=fz+(target[2]-point[2])*flight.advance
    fy=fy+flight.height
  end
  local model = Mat4.mul(Mat4.translate(fx, fy, fz),
    Mat4.mul(Mat4.rotateY(yaw),
      Mat4.mul(Mat4.scale(k, k, k), Mat4.translate(0, -(floor - hover), 0))))

  local intake = side == "enemy" and battle
    and battle.dramaticShape3DBallIntake or nil
  if not plasma and type(intake) == "table" and intake.active then
    local shrinkK = math.max(0.03, math.min(1, tonumber(intake.scale) or 1))
    local pull = math.max(0, math.min(1, tonumber(intake.pull) or 0))
    local ax, ay, az = point[1], groundY + worldHeight * 0.55, point[2]
    local bx = tonumber(intake.ballX) or ax
    local by = tonumber(intake.ballY) or ay
    local bz = tonumber(intake.ballZ) or az
    local shrink = Mat4.mul(Mat4.translate(ax, ay, az),
      Mat4.mul(Mat4.scale(shrinkK, shrinkK, shrinkK),
               Mat4.translate(-ax, -ay, -az)))
    model = Mat4.mul(Mat4.translate((bx - ax) * pull,
                                    (by - ay) * pull,
                                    (bz - az) * pull),
                     Mat4.mul(shrink, model))
  end

  local fainting = battler and (battler.fainted or safeCall(battle, "fxFaintActive", battler))
  local contact
  if not plasma and grow > 0.02 and not fainting then
    local radius = tonumber(metrics.radius) or metrics.height * 0.35
    contact = { x = fx, z = fz, y = groundY, radius = math.max(0.4, radius * k * 0.85) }
  end
  return model, contact
end

function StadiumModels.placements(arena, groundY, textures, battle)
  if not StadiumModels.sync(battle) then return {} end
  local out = {}
  for _, side in ipairs({ "enemy", "player" }) do
    local texture = textures and textures[side]
    local actor = actors[side]
    local metrics = drawableMetrics(actor, side)
    local captured = side == "enemy" and battle
      and battle.dramaticShape3DBallHide == true
    local flight = FlyMotion.pose(battle, side)
    if captured then texture = nil; flight=nil end
    if metrics and ((texture and not texture.trainer) or (flight and not captured)) then
      local matrix, contact = modelMatrix(arena, groundY, battle, side, actor, metrics)
      if matrix then
        out[side] = { side = side, actor = actor, instance = actor.instance,
                      flightHidden = flight and flight.hidden,
                      modelMatrix = matrix, contact = contact,
                      plasma=battle and battle.legendaryQ57 and battle.legendaryQ57[side],
                      release = battle and ((side=="enemy" and battle.legendaryBreakoutPose)
                        or (battle.legendaryReleasePose and battle.legendaryReleasePose[side])),
                      intake = side == "enemy" and battle
                        and battle.dramaticShape3DBallIntake or nil }
      end
    end
  end
  return out
end

function StadiumModels.draw(placement, context, pass)
  if placement and placement.flightHidden then return true end
  if not (placement and placement.instance and context) then return false end
  local actor = placement.actor
  local tint = context.tint or { 1, 1, 1 }
  local intake = placement.intake
  local absorbing = type(intake) == "table" and intake.active
  if placement.plasma and placement.plasma.subjectDone then placement.plasma=nil end
  local captureAmount = absorbing and (tonumber(intake.colorAmount) or 1) or 0
  local shadow
  if context.shadowMap and context.shadowVP then
    shadow = {
      map = context.shadowMap,
      viewProjection = context.shadowVP,
      darkness = context.shadowDark,
      bias = context.shadowBias,
      texel = context.shadowTexel,
    }
  end
  local called, ok, err = pcall(placement.instance.draw, placement.instance, {
    pass = pass,
    modelMatrix = placement.modelMatrix,
    camera = { view = context.view, viewProjection = context.viewProjection },
    light = context.light,
    shadow = shadow,
    tint = { tint[1] or 1, tint[2] or 1, tint[3] or 1, tint[4] or 1 },
    q57Pose = placement.plasma,
    flashAmount = placement.plasma and 0 or absorbing and captureAmount
      or (placement.release and placement.release.amount)
      or ((context.flashing or (actor.flash or 0) > 0) and 0.5 or 0),
    flashColor = absorbing and (intake.color or {1,0.08,0.30}) or {1,1,1},
    flipWinding = true,
    disableCulling = true,
    skipHandlers = pass == "additive",
  })
  if not called then err, ok = ok, false end
  if not ok then
    warnOnce("draw:" .. placement.side,
      ("Stadium 2 %s model draw failed: %s; using Battle Art")
        :format(placement.side, tostring(err)))
    failActor(actor)
  end
  return ok and true or false
end

function StadiumModels.status()
  local function side(actor)
    return actor.instance and {
      context = actor.context,
      dex = actor.dex,
      lastMove = actor.lastMove,
      lastMoveOk = actor.lastMoveOk,
    } or nil
  end
  return {
    apiVersion = 1,
    installed = StadiumModels.installed(),
    active = StadiumModels.active(),
    providerId = providerHandle and "STADIUM2_IMPORTER" or nil,
    sides = {
      player = actors.player.instance and true or false,
      enemy = actors.enemy.instance and true or false,
    },
    detail = { player = side(actors.player), enemy = side(actors.enemy) },
  }
end

return StadiumModels
