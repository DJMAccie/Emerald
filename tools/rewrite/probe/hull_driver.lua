-- POKEPORT_DRIVER: wrap VoxelHull.build of the OLD mod (installed look) and print every call's parameters.
-- Behaviour only (no source reads): w, h, step, bottom, depthLimit, inflate, taper, seed + the quads returned,
-- so one drawing's card and model can be compared against the rewrite's.
--   EM_MAPS=<file of "MAP x y" lines>
-- QA identity only.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert(love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa'),'refusing a non-QA identity')
 require('src.core.game3.rng').Random=function()return 0 end
 require('src.core.game3.tileset_anim')._enabled=false
 love.window.setMode(1280,720,{resizable=true})
 if love.window.minimize then pcall(love.window.minimize) end
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local Map=require('src.core.game3.map')
 local calls={}
 local function hook()
  local ex
  for _,e in pairs(game.mods.exports or {})do if type(e)=='table' and type(e.lib)=='table' then ex=e end end
  if not ex then print('[EM hull] no mod exports');return end
  local ok,VH=pcall(ex.lib.require,'VoxelHull')
  if not (ok and type(VH)=='table' and type(VH.build)=='function') then print('[EM hull] no VoxelHull');return end
  local orig=VH.build
  VH.build=function(w,h,sample,step,bottom,depthLimit,organic,family,inflate,taper,seed)
   local quads=orig(w,h,sample,step,bottom,depthLimit,organic,family,inflate,taper,seed)
   local n=0
   if type(quads)=='table' then for _ in pairs(quads)do n=n+1 end end
   calls[#calls+1]=('w=%s h=%s step=%s bottom=%s depthLimit=%s inflate=%s taper=%s seed=%s organic=%s family=%s quads=%d')
    :format(tostring(w),tostring(h),tostring(step),tostring(bottom),tostring(depthLimit),tostring(inflate),tostring(taper),tostring(seed),tostring(organic),tostring(family),n)
   return quads
  end
 end
 local maps={}
 for l in io.lines(os.getenv('EM_MAPS'))do local m,x,y=l:match('^(%S+)%s+(%d+)%s+(%d+)');if m then maps[#maps+1]={m,tonumber(x),tonumber(y)} end end
 local probe=dofile(os.getenv('HOME')..'/Documents/Emerald/tools/rewrite/probe/old_adapter.lua')(game)
 local function settle()
  local b0=probe.builds()
  local n=0
  repeat U.wait(1);n=n+1 until probe.active() or n>900
  local last,stable=-1,0
  for i=1,1800 do
   local b=probe.builds()
   if b==last then stable=stable+1 else stable=0;last=b end
   if b>b0 and stable>=240 then return true end
   U.wait(1)
  end
  return false
 end
 for _,m in ipairs(maps)do
  calls={}
  hook()
  pcall(Map.load,nil,game,m[1],{x=m[2],y=m[3],facing='down'})
  settle()
  print(('[EM hull] %s calls=%d'):format(m[1],#calls))
  for i,c in ipairs(calls)do print(('[EM hull]\t%d\t%s'):format(i,c)) end
 end
 love.event.quit()
end
