-- Voxel world mode

local B = { n = 0 }

local clock = (love and love.timer and love.timer.getTime) or os.clock

local deadline = math.huge
local buildCo = nil
local tickEvery = 32

function B.begin(co, seconds, pollEvery)
  buildCo = co
  deadline = clock() + seconds
  tickEvery = pollEvery == 4 and 4 or 32
  B.n = 0
end

function B.finish()
  buildCo = nil
  deadline = math.huge
  tickEvery = 32
end


function B.tick()
  local n = B.n + 1
  B.n = n
  if n % tickEvery ~= 0 then return end
  if buildCo and coroutine.running() == buildCo and clock() > deadline then
    coroutine.yield("budget")
  end
end

-- For slow loops: tick() only samples the clock 1 in 32 calls.
function B.check()
  if buildCo and coroutine.running() == buildCo and clock() > deadline then
    coroutine.yield("budget")
  end
end

return B
