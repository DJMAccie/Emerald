-- One live scene, up to capacity-1 retained scenes for return visits, one cooperative candidate,
-- and one scene of another map warmed ahead of a crossing (only while nothing else builds)
local V=...
local Budget=V.require('BuildBudget')
local clock=(love and love.timer and love.timer.getTime) or os.clock
local M={}
function M.new(release,capacity)
 local self={capacity=math.max(1,capacity or 1),kept={},maxWarmSlices=600,
  stats={started=0,completed=0,cancelled=0,hits=0,reused=0,kept=0,evicted=0,slices=0,maxSlice=0,maxStreamSlice=0,maxColdSlice=0}}
 function self:cancel()
  if self.pending then
   release(self.pending.value);self.pending=nil
   self.stats.cancelled=self.stats.cancelled+1
  end
 end
 function self:cancelWarm()
  if self.warming then release(self.warming.value);self.warming=nil end
 end
 function self:has(context)
  if self.active and self.context==context then return true end
  for _,e in ipairs(self.kept)do if e.context==context then return true end end
  return self.failed and self.failed[context] or false
 end
 -- One slice of a scene for another map; `hooks.enter/leave` bracket every resume (the build reads global map state).
 function self:warm(key,context,build,seconds,hooks)
  if self.pending or not(key and context) or self:has(context)then return end
  local w=self.warming
  if w and w.context~=context then self:cancelWarm();w=nil end
  if not w then
   w={key=key,context=context,value={},hooks=hooks,slices=0}
   w.co=coroutine.create(function()return build(w.value)end)
   self.warming=w
  end
  w.slices=w.slices+1
  local start=clock()
  Budget.begin(w.co,seconds,4)
  hooks.enter(w)
  local ok,result=coroutine.resume(w.co)
  hooks.leave(w)
  Budget.finish()
  local spent=clock()-start
  self.stats.buildMs=(self.stats.buildMs or 0)+spent*1000
  self.stats.maxWarmSlice=math.max(self.stats.maxWarmSlice or 0,spent)
  if coroutine.status(w.co)~='dead' then return end
  self.warming=nil
  if not ok then
   release(w.value);print('[emerald 3d] warm scene failed: '..tostring(result))
   self.failed=self.failed or {};self.failed[context]=true;return
  end
  result=result or w.value
  if result~=w.value then release(w.value)end
  self:retire(result,w.key,w.context)
  self.stats.warmed=(self.stats.warmed or 0)+1
 end
 function self:clear()
  self:cancel();self:cancelWarm();self.failed=nil
  if self.active then release(self.active);self.active=nil end
  for _,e in ipairs(self.kept)do release(e.value)end
  self.kept={};self.stats.kept=0
  self.key,self.context=nil,nil
 end
 function self:retire(value,key,context)
  if not(key and context)then release(value);return end
  table.insert(self.kept,1,{key=key,context=context,value=value})
  while #self.kept>self.capacity-1 do
   local old=table.remove(self.kept);release(old.value);self.stats.evicted=self.stats.evicted+1
  end
  self.stats.kept=#self.kept
 end
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
   -- Same map layout, another window (a scene warmed ahead): it shows while the window under the player builds.
   if not(self.active and self.context==context)then
    for i,e in ipairs(self.kept)do
     if e.context==context then
      table.remove(self.kept,i);self.stats.reused=self.stats.reused+1;self.stats.kept=#self.kept
      self:cancel()
      if self.active then self:retire(self.active,self.key,self.context)end
      self.active,self.key,self.context=e.value,e.key,e.context
      break
     end
    end
   end
  end
 if self.pending and (self.pending.context~=context or (self.pending.key~=key and not (self.keepStale and context and self.active)))then self:cancel()end
  local immediate=not context or not key
  local same=self.active~=nil and context~=nil and context==self.context
  local w=self.warming
  if w and not self.pending then
   if w.context==context and key then self.pending,self.warming=w,nil;w.adopted=true;self.stats.adopted=(self.stats.adopted or 0)+1
   elseif same and w.slices<self.maxWarmSlices then return self.active -- the warm scene finishes first
   else self:cancelWarm()end
  end
  if not self.pending then
   local p={key=key,context=context,value={}}
   p.co=coroutine.create(function()return build(p.value,self.active)end)
   self.pending=p;self.stats.started=self.stats.started+1
  end
  local p=self.pending
  local budget=(not immediate) and (same and seconds or cold or seconds) or nil
  local start=clock()
  if budget then Budget.begin(p.co,budget,4)end
  if p.hooks then p.hooks.enter(p)end
  local ok,result=coroutine.resume(p.co)
  if p.hooks then p.hooks.leave(p)end
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
  if same then return self.active end
  return nil
 end
 return self
end
return M
