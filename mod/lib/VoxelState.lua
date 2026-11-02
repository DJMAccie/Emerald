-- Voxel world mode



local Voxel = {}

Voxel.ANGLES_DEG = { 0, 35, 15, 35, 50, 75, 75, 75 }
Voxel.ANGLE_LABELS = { "OFF", "FULL", "15", "35", "50", "75",
                       "1ST", "3RD (EXPERIMENTAL)" }
Voxel.MAX_LEVEL = #Voxel.ANGLES_DEG - 1

Voxel.FULL_LEVEL = 1

Voxel.FP_LEVEL = 6

function Voxel.isFirstPerson(level)
  return (level or Voxel.level) == Voxel.FP_LEVEL
end

Voxel.TP_LEVEL = 7

function Voxel.isThirdPerson(level)
  return (level or Voxel.level) == Voxel.TP_LEVEL
end

Voxel.ORBIT_LEVEL_COUNT = 6

Voxel.HOTKEY_ORDER = { 0, 2, 3, 4, 5, 6, 7 } -- OFF, 15, 35, 50, 75, 1ST, 3RD

Voxel.level = 0
Voxel.angle = 0
Voxel.from = 0
Voxel.goal = 0
Voxel.t = 1

Voxel.ready = true

Voxel.TWEEN_TIME = 0.25
Voxel.FOCAL = 1.0

local function ease(t)
  return t * t * (3 - 2 * t)
end

local function goalFor(level)
  return math.rad(Voxel.ANGLES_DEG[level + 1] or 0)
end

function Voxel.setLevel(level)
  level = math.floor(tonumber(level) or 0)
  if level < 0 then level = 0 end
  if level > Voxel.MAX_LEVEL then level = Voxel.MAX_LEVEL end
  local goal = goalFor(level)
  if goal ~= Voxel.goal or level ~= Voxel.level then
    Voxel.from = Voxel.angle
    Voxel.goal = goal
    Voxel.t = 0
    if Voxel.angle == 0 and goal > 0 then Voxel.ready = false end
  end
  Voxel.level = level
end

function Voxel.reset()
  Voxel.level, Voxel.angle = 0, 0
  Voxel.from, Voxel.goal, Voxel.t = 0, 0, 1
end

function Voxel.levelLabel(level)
  return Voxel.ANGLE_LABELS[(level or Voxel.level) + 1] or "OFF"
end

function Voxel.update(dt, level)
  if level ~= nil and level ~= Voxel.level then Voxel.setLevel(level) end
  if Voxel.angle == 0 and Voxel.goal > 0 and not Voxel.ready then
    return
  end
  if Voxel.t < 1 then
    Voxel.t = math.min(1, Voxel.t + dt / Voxel.TWEEN_TIME)
    Voxel.angle = Voxel.from + (Voxel.goal - Voxel.from) * ease(Voxel.t)
  else
    Voxel.angle = Voxel.goal
  end
end

function Voxel.active()
  return Voxel.level > 0 or Voxel.angle > 0
end

return Voxel
