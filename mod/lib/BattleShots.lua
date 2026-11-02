-- The battle's own cutting
local V = ...

local ModSetting = V.require("ModSetting")
local BattleCam = V.require("BattleCam")

local BattleShots = {}

BattleShots.setting = ModSetting.new("battleCamera", "BATTLE CAMERA",
  { "ON", "CINEMATIC", "OFF" }, { "ON", "CINEMATIC", "OFF" }, 1)

function BattleShots.enabled()
  return BattleShots.setting:get() ~= "OFF"
end

function BattleShots.gain()
  return BattleShots.setting:get() == "CINEMATIC" and 1.35 or 1
end

local function scaled(base, gain, orbit, pitch, zoom)
  local b = base or {}
  return {
    orbit = (b.orbit or 0) + (orbit or 0) * gain,
    pitch = (b.pitch or 0) + (pitch or 0) * gain,
    zoom  = (zoom or 1),
  }
end

BattleShots.OFFSET = {
  -- the wide one the fight opens and settles on
  wide     = { orbit = 0, pitch = 0, zoom = 1 },
  -- behind the attacker, low, looking along its own charge
  attacker = { orbit = 0.22, pitch = -0.10, zoom = 1 },
  reverse  = { orbit = -0.26, pitch = 0.06, zoom = 1 },
  target   = { orbit = -0.10, pitch = 0.34, zoom = 1.08 },
  settle   = { orbit = 0.04, pitch = 0.14, zoom = 1.12 },
}

BattleShots.SCENE = {
  wide     = { yaw = 0,   pitch = 0 },
  attacker = { yaw = 34,  pitch = -9 },
  reverse  = { yaw = -30, pitch = 6 },
  target   = { yaw = -16, pitch = 22 },
  settle   = { yaw = 7,   pitch = 10 },
}

-- Not zero: at zero the eye, the aim and both actors share one line.
BattleShots.SCENE_RAKE = math.rad(-45)

function BattleShots.scene(name, gain)
  local offset = BattleShots.SCENE[name] or BattleShots.SCENE.wide
  local k = gain or BattleShots.gain()
  return BattleShots.SCENE_RAKE + math.rad((offset.yaw or 0) * k),
         math.rad((offset.pitch or 0) * k)
end

BattleShots.ANTICIPATE = 0.55 -- from the animation's start to the cut in
BattleShots.IMPACT = 0.85 -- the attacker's angle, held at least this long
BattleShots.SETTLE = 1.10 -- ... and this long before the wide shot
BattleShots.FAINT_HOLD = 2.20
BattleShots.ANIM_SPAN = 1.2

local shot  = "wide" -- which angle is live
local timer = 0 -- seconds into it
local cutIn = nil -- seconds until the next cue, nil = nothing pending
local attackerPlayer = true
local wasAnim, wasDrain, wasFaint = false, false, false
local wasShake = false
local announced = false
local animTimer = 0 -- seconds left in the move window opened by a launch

local function base()
  return {
    orbit = BattleCam.OPEN_ORBIT or 0,
    pitch = BattleCam.OPEN_PITCH or 0,
  }
end

local sink = nil


-- The scene's sink re-enters this function, so `scene` (not the sink) picks the path.
local sceneSink = nil
local function requireScene() return sceneSink end

local function take(name, cut, scene)
  local ok
  if scene then
    local okScene, result = pcall(function()
      return requireScene()
    end)
    if not okScene or type(result) ~= "function" then return false end
    ok = result(name, cut) and true or false
  else
    local offset = BattleShots.OFFSET[name]
    if not offset then return false end
    local aim = scaled(base(), BattleShots.gain(), offset.orbit, offset.pitch,
                       offset.zoom)
    if sink then
      ok = sink(name, cut, aim) and true or false
    else
      ok = BattleCam.direct{
        name = name, cut = cut,
        orbit = aim.orbit, pitch = aim.pitch, zoom = aim.zoom,
      }
    end
  end
  if ok then shot, timer = name, 0 end
  return ok
end

function BattleShots.setSceneSink(fn)
  sceneSink = type(fn) == "function" and fn or nil
  BattleShots.sceneSinkSet = sceneSink ~= nil
end

BattleShots.take = take

local function held()
  if sink then return true end
  return BattleCam.shotHeld()
end

function BattleShots.state()
  return { shot = shot, timer = timer, cutIn = cutIn,
           attackerPlayer = attackerPlayer,
           held = held(), enabled = BattleShots.enabled() }
end

function BattleShots.reset()
  shot, timer, cutIn = "wide", 0, nil
  wasAnim, wasDrain, wasFaint, wasShake = false, false, false, false
  announced = false
  BattleCam.releaseShot()
end

local function fx(battle, key)
  local layer = battle and battle.fx
  return type(layer) == "table" and layer[key] or nil
end

local function anyFaint(battle)
  if not battle then return false end
  local player, enemy = battle.player, battle.enemy
  return (player and player.fainted) or (enemy and enemy.fainted) or false
end

local function attackerIsPlayer(battle)
  if battle.animAttackerIsPlayer ~= nil then
    return battle.animAttackerIsPlayer and true or false
  end
  return true
end

function BattleShots.update(battle, dt, shotSink, sig)
  dt = math.max(0, tonumber(dt) or 0)
  timer = timer + dt
  if type(shotSink) == "function" then sink = shotSink end

  if not BattleShots.enabled() or not battle then
    cutIn = nil
    return false
  end
  if not held() and shot ~= "wide" then
    cutIn = nil
  end

  local anim, drain, faint, shake
  if sig then
    if sig.launch then
      animTimer = BattleShots.ANIM_SPAN
      attackerPlayer = sig.attackerPlayer ~= false
    end
    if animTimer > 0 then animTimer = animTimer - dt end
    anim = animTimer > 0
    drain = sig.hit and true or false
    shake = false
    faint = sig.faint and true or false
  else
    anim = battle.animPlaying and true or false
    drain = battle.draining and true or false
    faint = anyFaint(battle)
    shake = fx(battle, "shake") ~= nil and true or false
  end

  if anim and not wasAnim then
    if not sig then attackerPlayer = attackerIsPlayer(battle) end
    cutIn = BattleShots.ANTICIPATE
    announced = true
    if shot ~= "wide" then take("wide", true) end
  end

  if (drain and not wasDrain) or (shake and not wasShake) then
    if take(attackerPlayer and "target" or "target", true) then
      cutIn = BattleShots.IMPACT
    end
  end
  if wasAnim and not anim then
    if shot == "wide" or shot == "attacker" or shot == "reverse" then
      if take("settle", false) then cutIn = BattleShots.SETTLE end
    end
    announced = false
  end

  if faint and not wasFaint then
    take("wide", true)
    cutIn = BattleShots.FAINT_HOLD
  end

  if cutIn then
    cutIn = cutIn - dt
    if cutIn <= 0 then
      cutIn = nil
      if announced then
        take(attackerPlayer and "attacker" or "reverse", true)
      elseif shot == "settle" or shot == "target" then
        take("wide", false)
      end
    end
  end

  if not cutIn and shot == "target" and timer > BattleShots.IMPACT then
    if take("settle", false) then cutIn = BattleShots.SETTLE end
  end

  wasAnim, wasDrain, wasFaint, wasShake = anim, drain, faint, shake
  return true
end

return BattleShots
