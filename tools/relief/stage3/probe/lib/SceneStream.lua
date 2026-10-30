-- One live scene, up to capacity-1 retained scenes for return visits, and one
-- cooperative candidate. Never expose partially uploaded geometry, keep
-- abandoned GPU resources out of the live scene, and rebuild immediately when
-- map/provider/gameplay dependencies change.
--
-- A build is sliced whenever the request has a context. Battle and replay
-- requests have none and must be camera-exact, so they build in one resume.
-- A sliced build uses `seconds` while the live scene is of the same context
-- (it keeps showing), and `cold` otherwise: then update() returns nil and the
-- caller draws its own holding picture.
local V=...
local Budget=V.require('BuildBudget')
local clock=(love and love.timer and love.timer.getTime) or os.clock
local M={}
function M.new(release,capacity)
 local self={capacity=math.max(1,capacity or 1),kept={},
  stats={started=0,completed=0,cancelled=0,hits=0,reused=0,kept=0,evicted=0,slices=0,maxSlice=0,maxStreamSlice=0,maxColdSlice=0}}
 function self:cancel()
  if self.pending then
   release(self.pending.value);self.pending=nil
   self.stats.cancelled=self.stats.cancelled+1
  end
 end
 function self:clear()
  self:cancel()
  if self.active then release(self.active);self.active=nil end
  for _,e in ipairs(self.kept)do release(e.value)end
  self.kept={};self.stats.kept=0
  self.key,self.context=nil,nil
 end
 -- Park an outgoing scene for a return visit. Only a scene with a stable
 -- identity can be found again; anything else is released at once.
 function self:retire(value,key,context)
  if not(key and context)then release(value);return end
  table.insert(self.kept,1,{key=key,context=context,value=value})
  while #self.kept>self.capacity-1 do
   local old=table.remove(self.kept);release(old.value);self.stats.evicted=self.stats.evicted+1
  end
  self.stats.kept=#self.kept
 end
 -- `settle()` returns the context and key as they stand after the build (a
 -- build may load a tileset). The next request must match them, or the scene
 -- would be built a second time.
 function self:update(key,context,build,seconds,cold,settle)
  if key and self.active and key==self.key and context==self.context then
   self:cancel();self.stats.hits=self.stats.hits+1;return self.active
  end
  if key and context then
   for i,e in ipairs(self.kept)do
    if e.key==key and e.context==context then
     table.remove(self.kept,i);self.stats.reused=self.stats.reused+1;self.stats.kept=#self.kept
     self:cancel()
     if self.active then self:retire(self.active,self.key,self.context)end
     self.active,self.key,self.context=e.value,e.key,e.context
     return self.active
    end
   end
  end
  -- (a build of the same map for an older position is finished, not thrown away: walking moved the key
 -- every few cells and restarted the full build each time, so it never completed and the first, small
 -- area stayed with the sky showing past it. The next update starts the build for the new position.)
 if self.pending and (self.pending.context~=context or (self.pending.key~=key and not (self.keepStale and context and self.active)))then self:cancel()end
  local immediate=not context or not key
  local same=self.active~=nil and context~=nil and context==self.context
  if not self.pending then
   local p={key=key,context=context,value={}}
   p.co=coroutine.create(function()return build(p.value,self.active)end)
   self.pending=p;self.stats.started=self.stats.started+1
  end
  local p=self.pending
  local budget=(not immediate) and (same and seconds or cold or seconds) or nil
  local start=clock()
  if budget then Budget.begin(p.co,budget,4)end
  local ok,result=coroutine.resume(p.co)
  Budget.finish()
  local spent=clock()-start
  self.stats.buildMs=(self.stats.buildMs or 0)+spent*1000
  self.stats.slices=self.stats.slices+1
  self.stats.maxSlice=math.max(self.stats.maxSlice,spent)
  if budget and same then self.stats.maxStreamSlice=math.max(self.stats.maxStreamSlice,spent)end
  if budget and not same then self.stats.maxColdSlice=math.max(self.stats.maxColdSlice,spent)end
  if not ok then self:cancel();error(result,0)end
  if coroutine.status(p.co)=='dead' then
   self.pending=nil
   local stale=p.key~=key
   key,context=p.key,p.context
   result=result or p.value
   if result~=p.value then release(p.value)end
   if self.active~=result then
    if self.active then self:retire(self.active,self.key,self.context)end
    self.active=result;self.stats.completed=self.stats.completed+1
   end
   self.key,self.context=key,context
   if context and settle and not stale then self.context,self.key=settle()end
   return self.active
  end
  -- Still building: only the live scene of this same context may stay on screen.
  if same then return self.active end
  return nil
 end
 return self
end
return M
