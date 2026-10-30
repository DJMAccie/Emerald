-- The battle's own cutting: the camera changes angle when the fight does.
--
-- BattleCam owns the rig and the player's steering; this owns the SHOTS. A
-- fight used to be one angle from the send-out to the faint -- composed
-- correctly, and then never touched again -- and the two things a Stadium or
-- Colosseum battle does that this could not were both about that: the camera
-- keeps moving between angles, and it moves ON THE FIGHT'S BEAT, not on a
-- timer.
--
-- So this is a small sequencer with the battle's own events for a clock. It
-- reads the live battle state once a frame (nothing is wrapped, nothing is
-- patched: every field it looks at is one the engine already maintains) and
-- when something happens it asks BattleCam.direct for the shot that moment
-- wants:
--
--   move announced   hold the wide shot: the attacker is composing itself
--   animation starts CUT to the attacker's side, low and hard off-axis
--   impact            CUT to the target's quarter, high and looking down
--   everything settles GLIDE back out to the wide shot
--
-- Between those it does nothing at all, which is the point: the base shot is
-- the one the fight is composed for (BattleCam.OPEN_ORBIT), so a battle with
-- no moves thrown -- a capture, a switch, a menu -- sits on it.
--
-- NOTHING HERE REACHES THE BATTLE. Every shot is written into the same three
-- goals a stick writes into, the pair stays pinned to its two anchors at
-- every angle (BattleCam.spread opens the lens by what the orbit costs), and
-- a player who steers takes the controls back for good (BattleCam.releaseShot
-- in setAxis). With the row OFF, or on a device where the camera is not the
-- player's to steer (VR's fixed seat, BACK SPRITES' pinned half), direct()
-- declines and this module is inert.
--
-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local ModSetting = V.require("ModSetting")
local BattleCam = V.require("BattleCam")

local BattleShots = {}

-- ------- the row
--
-- ON is the default: this is the feature the round is about, and a camera
-- that cuts is the whole difference between a diorama and a broadcast.
-- CINEMATIC is the same cutting with the shots pushed further off the axis,
-- for players who want the angles to read as angles; OFF releases the camera
-- and leaves the composed base shot (plus the player's own steering).
BattleShots.setting = ModSetting.new("battleCamera", "BATTLE CAMERA",
  { "ON", "CINEMATIC", "OFF" }, { "ON", "CINEMATIC", "OFF" }, 1)

function BattleShots.enabled()
  return BattleShots.setting:get() ~= "OFF"
end

-- How far the cuts push off the composed base shot. ON keeps every shot
-- close enough to the base that the pair still reads as standing on their
-- own tiles (see BattleCam.OPEN_ORBIT for why that is the limit); CINEMATIC
-- spends some of that and is meant to be looked at rather than played
-- through.
function BattleShots.gain()
  return BattleShots.setting:get() == "CINEMATIC" and 1.35 or 1
end

-- ------- the shot list
--
-- Angles, in the camera's own three axes, one entry per beat:
--
--   orbit  how far around the arena. Positive walks the eye toward SIDE-ON
--          (the far mon moves to the near side of the frame); negative looks
--          past the NEAR mon's shoulder instead, which shows the far one
--          between the two of them. Both are real shots and the reason the
--          sequence has two attack angles rather than one.
--   pitch  how far above the rig's own seat, over BattleCam.PITCH_RANGE.
--   zoom   the lens, as a multiple of the rig's reach. Only ever >= 1: below
--          it the pair close on the frame and a wide card starts to cover
--          the ground its own mon is standing on.
--
-- `base` is the composed opening shot: every other angle is expressed
-- against it, so retuning BattleCam.OPEN_* moves the whole sequence with it.
local function scaled(base, gain, orbit, pitch, zoom)
  local b = base or {}
  return {
    orbit = (b.orbit or 0) + (orbit or 0) * gain,
    pitch = (b.pitch or 0) + (pitch or 0) * gain,
    zoom  = (zoom or 1),
  }
end

-- The angles themselves, as offsets from the base shot, for the STAGED rig
-- (lib/BattleCam: orbit/pitch/zoom over the solved composition).
BattleShots.OFFSET = {
  -- the wide one the fight opens and settles on
  wide     = { orbit = 0, pitch = 0, zoom = 1 },
  -- behind the attacker, low, looking along its own charge
  attacker = { orbit = 0.22, pitch = -0.10, zoom = 1 },
  -- the mirror: past the near mon's shoulder, so the two of them bracket
  -- the frame and the blow lands between them
  reverse  = { orbit = -0.26, pitch = 0.06, zoom = 1 },
  -- over the target's shoulder, raised, so the ground it is being driven
  -- across is in shot
  target   = { orbit = -0.10, pitch = 0.34, zoom = 1.08 },
  -- the wide shot with the eye lifted: the resolution beat, everything in
  -- frame and the shadow long
  settle   = { orbit = 0.04, pitch = 0.14, zoom = 1.12 },
}

-- The same beats for the GEN 3 SCENE camera (lib/Gen3Battle, which drives
-- lib/Gen3Scene): the arena there is two actors on a line and the eye starts
-- level with them, so the axes mean something different -- `yaw` is how far
-- the eye is raked off that line, in the scene's own degrees, and `pitch` is
-- the elevation of the seat. The REST rake those are measured from is
-- SCENE_RAKE below, and its sign is the one that turns the picture
-- clockwise.
--
-- Every one of these is expressed the same way as the staged set: a change
-- from the composed rest pose, so the two paths stay recognisable as the
-- same sequence of beats even though their numbers do not match.
BattleShots.SCENE = {
  wide     = { yaw = 0,   pitch = 0 },
  attacker = { yaw = 34,  pitch = -9 },
  reverse  = { yaw = -30, pitch = 6 },
  target   = { yaw = -16, pitch = 22 },
  settle   = { yaw = 7,   pitch = 10 },
}

-- The rest pose the scene shots are measured from: the eye's heading OFF the
-- line the two actors stand on, in degrees (lib/Gen3Battle applies it once,
-- when the battle opens).
--
-- WHY NOT ZERO. At zero the eye, the aim and both actors share one bearing:
-- the far Pokemon stands exactly behind the near one and the whole frame is
-- one column (the player's model hid the foe). Raked, the foe sits high on
-- the right and the player low on the left, the layout a Stadium or Colosseum
-- battle opens on. About -45 puts the foe's feet near x 0.61 of the frame and
-- the player's near x 0.39, with the pair clear of each other and of the
-- text box.
--
-- SIGN: negative. It puts the player on the LEFT of the frame and the foe on
-- the RIGHT; a positive value would swap them. Do not flip it without a
-- captured frame to point at.
-- Radians are what the camera takes; the degree value is what a person reads.
BattleShots.SCENE_RAKE = math.rad(-45)

-- The scene's angles for `name`, relative to its rest pose. Radians.
function BattleShots.scene(name, gain)
  local offset = BattleShots.SCENE[name] or BattleShots.SCENE.wide
  local k = gain or BattleShots.gain()
  return BattleShots.SCENE_RAKE + math.rad((offset.yaw or 0) * k),
         math.rad((offset.pitch or 0) * k)
end

-- ------- the beats
--
-- Seconds, on the battle's own clock. They are the SHOT's timing, not the
-- move's: a shot lasts as long as it is interesting and then the next cue
-- takes it, and a move whose animation runs longer than IMPACT simply holds
-- the impact shot until it finishes (see `hold` below).
BattleShots.ANTICIPATE = 0.55   -- from the animation's start to the cut in
BattleShots.IMPACT = 0.85       -- the attacker's angle, held at least this long
BattleShots.SETTLE = 1.10       -- ... and this long before the wide shot
BattleShots.FAINT_HOLD = 2.20
-- How long a move animation is taken to run, from its launch. The engine does
-- not put one on the battle state (see lib/Gen3StadiumModels), so the launch
-- signal opens this window; the impact is the hit signal inside it.
BattleShots.ANIM_SPAN = 1.2

-- ------- state
local shot  = "wide"     -- which angle is live
local timer = 0          -- seconds into it
local cutIn = nil        -- seconds until the next cue, nil = nothing pending
local attackerPlayer = true
local wasAnim, wasDrain, wasFaint = false, false, false
local wasShake = false
local announced = false
local animTimer = 0      -- seconds left in the move window opened by a launch

local function base()
  return {
    orbit = BattleCam.OPEN_ORBIT or 0,
    pitch = BattleCam.OPEN_PITCH or 0,
  }
end

-- Where a shot goes: the staged rig by default, or whatever the caller
-- handed `update` (the Gen 3 scene camera, whose axes are its own).
--
-- KEPT between frames, not cleared with each update, so `take` can be called
-- on its own -- a QA driver walking the beats by hand has no battle event to
-- trigger it and must not silently fall through to the staged rig's axes.
local sink = nil

function BattleShots.useSink(fn)
  sink = type(fn) == "function" and fn or nil
end

-- `scene` selects the SCENE path (lib/Gen3Battle's camera, whose axes are
-- its own) for this call, whatever sink is installed: the scene's own sink
-- re-enters this function, so it must not be the thing that decides.
-- Set by lib/Gen3Battle at install time, so `take(name, cut, true)` works
-- from a QA driver without one and without a require cycle. Declared before
-- `take`, which closes over it.
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

-- Whether the director still owns the camera. The staged rig answers for
-- itself (a steer releases the shot); another sink says so through its own
-- return value from `take`, so this is only asked of the default path.
local function held()
  if sink then return true end
  return BattleCam.shotHeld()
end

-- Where the sequence is right now, for a shot driver's log.
function BattleShots.state()
  return { shot = shot, timer = timer, cutIn = cutIn,
           attackerPlayer = attackerPlayer,
           held = held(), enabled = BattleShots.enabled() }
end

-- Start (or restart) a battle's sequence. Called from the same reset the rig
-- gets, so a new fight opens on the composed shot with nothing pending.
function BattleShots.reset()
  shot, timer, cutIn = "wide", 0, nil
  wasAnim, wasDrain, wasFaint, wasShake = false, false, false, false
  announced = false
  BattleCam.releaseShot()
end

-- ------- reading the fight
--
-- Everything below is read off the live battle. All of it is engine state
-- that already exists for its own reasons, so nothing here can change what
-- the fight does -- the worst a missing field can do is cost this module one
-- of its cues.

local function fx(battle, key)
  local layer = battle and battle.fx
  return type(layer) == "table" and layer[key] or nil
end

local function anyFaint(battle)
  if not battle then return false end
  local player, enemy = battle.player, battle.enemy
  return (player and player.fainted) or (enemy and enemy.fainted) or false
end

-- The move being thrown right now, as the engine states it while its
-- animation runs: `animName` is the engine's own animation id (TACKLE,
-- EMBER, GROWL...), and `animAttackerIsPlayer` says which side threw it.
local function attackerIsPlayer(battle)
  if battle.animAttackerIsPlayer ~= nil then
    return battle.animAttackerIsPlayer and true or false
  end
  return true
end

-- One frame of direction. `battle` may be nil (a battle between fights, a
-- menu, a capture): nothing is cued and the camera is left alone.
function BattleShots.update(battle, dt, shotSink, sig)
  dt = math.max(0, tonumber(dt) or 0)
  timer = timer + dt
  if type(shotSink) == "function" then sink = shotSink end

  if not BattleShots.enabled() or not battle then
    cutIn = nil
    return false
  end
  -- the player owns the camera once they have steered; the sequence stops
  -- re-aiming rather than fighting them for it
  if not held() and shot ~= "wide" then
    cutIn = nil
  end

  local anim, drain, faint, shake
  if sig then
    -- the engine's own hooks (lib/Gen3Battle reads them, see signals there):
    -- a launch opens the move window, a hit is the impact pulse, a faint is
    -- the faint. battle.animPlaying / draining / fx.shake are not set on the
    -- Gen 3 engine, so they are not read on this path.
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

  -- a new move animation: the fight's own downbeat. The announcement that
  -- precedes it is where the anticipation shot starts, and the animation's
  -- first frame is where the cut lands.
  if anim and not wasAnim then
    if not sig then attackerPlayer = attackerIsPlayer(battle) end
    -- hold the wide shot through the announcement, then cut on the beat
    cutIn = BattleShots.ANTICIPATE
    announced = true
    if shot ~= "wide" then take("wide", true) end
  end

  -- the animation ended (or the hit landed, whichever the engine reports
  -- first): the target's quarter, high
  if (drain and not wasDrain) or (shake and not wasShake) then
    if take(attackerPlayer and "target" or "target", true) then
      cutIn = BattleShots.IMPACT
    end
  end
  if wasAnim and not anim then
    -- the move is over: if nothing has taken the camera yet, take it now and
    -- start the glide home
    if shot == "wide" or shot == "attacker" or shot == "reverse" then
      if take("settle", false) then cutIn = BattleShots.SETTLE end
    end
    announced = false
  end

  -- a faint is the fight's own full stop: hold wide on it, then hand the
  -- camera back so the next send-out starts clean
  if faint and not wasFaint then
    take("wide", true)
    cutIn = BattleShots.FAINT_HOLD
  end

  -- the pending cue
  if cutIn then
    cutIn = cutIn - dt
    if cutIn <= 0 then
      cutIn = nil
      if announced then
        -- looking along the attacker's charge: the far side of the arena
        -- when the player is throwing, the near side when the foe is
        take(attackerPlayer and "attacker" or "reverse", true)
      elseif shot == "settle" or shot == "target" then
        take("wide", false)
      end
    end
  end

  -- nothing pending and the sequence has run its course: make sure the wide
  -- shot is the resting state rather than whatever angle a cue left behind
  if not cutIn and shot == "target" and timer > BattleShots.IMPACT then
    if take("settle", false) then cutIn = BattleShots.SETTLE end
  end

  wasAnim, wasDrain, wasFaint, wasShake = anim, drain, faint, shake
  return true
end

return BattleShots
