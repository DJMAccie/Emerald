-- Overworld battles

local BattleCam = {}

BattleCam.RIGS = {
  tele = {
    side = 78.79, back = 144.96, height = 37.88,
    lookX = -0.26, lookY = 0.34, frameH = 34.11,
  },
  wide = {
    side = 41.98, back = 41.16, height = 28.48,
    lookX = -3.24, lookY = -1.35, frameH = 55.62,
  },
}

BattleCam.DEFAULT_RIG = "tele"

BattleCam.PAN_YAW = math.rad(2) -- half-angle of the orbit
BattleCam.PAN_PERIOD = 26 -- seconds for one there-and-back
BattleCam.PAN_DOLLY = 0.02 -- how far the eye breathes, as a fraction
BattleCam.DOLLY_PERIOD = 37

BattleCam.ORBIT_TIME = 0.22 -- seconds for the eye to catch its goal
BattleCam.ORBIT_DRAG = 1.15 -- fraction of the range per screen width
BattleCam.ORBIT_STICK = 0.9 -- fraction of the range per second, full tilt
BattleCam.ORBIT_MOUSE = 0.0011 -- fraction of the range per mouse count
BattleCam.STICK_DEAD = 0.2

BattleCam.PITCH_RANGE = math.rad(45)
BattleCam.PITCH_TIME = 0.22
BattleCam.PITCH_DRAG = 1.6 -- fraction of the range per screen HEIGHT
BattleCam.PITCH_STICK = 0.9
BattleCam.PITCH_MOUSE = 0.0016

BattleCam.ZOOM_MIN = 0.45 -- the pair filling the frame
BattleCam.ZOOM_MAX = 2.0 -- the fight in its own landscape
BattleCam.ZOOM_STEP = 1.15
BattleCam.ZOOM_TIME = 0.18

BattleCam.orbit = 0
BattleCam.orbitGoal = 0
BattleCam.pitch = 0
BattleCam.pitchGoal = 0
BattleCam.zoom = 1
BattleCam.zoomGoal = 1

BattleCam.shotName = nil
BattleCam.snapShots = false

BattleCam.cutAt = nil
BattleCam.CUT_SETTLE = 0.5

local shotGoals = nil

function BattleCam.direct(options)
  if not BattleCam.steerable or BattleCam.still or BattleCam.poseLocked then
    return false
  end
  local o = type(options) == "table" and options or {}
  local goal = {
    orbit = math.max(-1, math.min(1,
                                 tonumber(o.orbit) or BattleCam.orbitGoal)),
    pitch = math.max(0, math.min(BattleCam.pitchLimit,
                                 tonumber(o.pitch) or BattleCam.pitchGoal)),
    zoom  = math.max(BattleCam.ZOOM_MIN,
                     math.min(BattleCam.ZOOM_MAX,
                              tonumber(o.zoom) or BattleCam.zoomGoal)),
  }
  BattleCam.orbitGoal, BattleCam.pitchGoal, BattleCam.zoomGoal =
    goal.orbit, goal.pitch, goal.zoom
  shotGoals = goal
  BattleCam.shotName = o.name
  if o.cut then BattleCam.snapShots = true end
  return true
end

function BattleCam.releaseShot()
  shotGoals = nil
  BattleCam.shotName = nil
end

function BattleCam.shotHeld()
  if not shotGoals then return false end
  return BattleCam.orbitGoal == shotGoals.orbit
     and BattleCam.pitchGoal == shotGoals.pitch
     and BattleCam.zoomGoal == shotGoals.zoom
end

BattleCam.steerable = true

BattleCam.still = false

BattleCam.poseLocked = false

BattleCam.pitchLimit = 1

BattleCam.t = 0

BattleCam.OPEN_ORBIT = 0.18
BattleCam.OPEN_PITCH = 0.16

-- Real frame time: a fast-forwarded battle must not spin the camera.

return BattleCam
