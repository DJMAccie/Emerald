-- POKEPORT_DRIVER script: dump every building and civic picture with the glass
-- mask GlassMask found in it, at night. Run through tools/qa_try.sh (QA identity
-- only, with GlassMask.lua Gen3Scene.lua DayNight.lua Gen3Outdoor.lua swapped in).
-- Output in SHOT_DIR:
--   <map>__<id>.png   three panels, each the picture at 4x (nearest):
--                     (a) the picture, (b) searched pixels only (the rest at 35%),
--                     (c) the picture with the mask painted magenta.
--   <map>__atlas_<which>_<w>x<h>.png  the same for a tileset atlas (walls drawn from
--                     tiles, not from a building picture).
--   <map>__screen.png the normal level-4 night screenshot of each case.
-- Pictures are composited over mid grey where they are transparent (display only).
-- A civic's ImageData is released by Gen3Civic.material, so its picture is rebuilt
-- from the atlas pixels the detector read (alpha 1); the log line says which.
-- Each map+id is dumped once per run. EM_CASES and EM_LEVELS come from qa_run.sh.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 local dir=assert(os.getenv('SHOT_DIR'))
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local lib=game.mods.exports.BATTLE_ART_VOXEL_FORK.lib
 -- test-only clock pin (this copy only): night
 local Day=lib.require('DayNight')
 local T=Day.T.night
 Day.time=function() return T end
 print('[GD TOD] night',T)
 local GM=lib.require('GlassMask')
 GM.log=true
 local Map=require('src.core.game3.map');local Player=require('src.core.game3.player')
 local ns=game.mods.exports.BATTLE_ART_VOXEL_FORK.gen3 or game.mods.exports.BATTLE_ART_VOXEL_FORK.firered
 local C=ns and ns.camera
 local S,GAP=4,8
 local curMap='?'
 local done={}
 local nDumped=0

 -- the picture's pixels as r,g,b,a in 0..1 (ImageData when held, else the rebuilt atlas pixels)
 local function reader(d)
  if d.pic then return function(x,y) return d.pic:getPixel(x,y) end,'picture' end
  return function(x,y)
   local r,g,b=d.px0(x,y)
   return r/255,g/255,b/255,1
  end,'rebuilt'
 end

 local function dumpOne(d)
  local w,h=d.w,d.h
  local name=curMap..'__'..(d.tag:gsub(' cell ','_c'):gsub('[^%w_%.%-]+','_'))
  -- an atlas is a whole tileset image (its tiles, not one building): size in the name
  if d.tag:sub(1,5)=='atlas' then name=name..'_'..w..'x'..h end
  if done[name] then return end
  done[name]=true
  local get,how=reader(d)
  local W,H=w*S,h*S
  local out=love.image.newImageData(3*W+2*GAP,H)
  -- the gaps between panels (the panels cover the rest)
  for y=0,H-1 do for x=W,W+GAP-1 do out:setPixel(x,y,.12,.12,.12,1) end end
  for y=0,H-1 do for x=2*W+GAP,2*W+2*GAP-1 do out:setPixel(x,y,.12,.12,.12,1) end end
  local inS,inM={},{}
  for k in pairs(d.search) do inS[k]=true end
  for _,p in ipairs(d.mask) do inM[p]=true end
  local nSearch,nMask=0,#d.mask
  for _ in pairs(inS) do nSearch=nSearch+1 end
  for y=0,h-1 do for x=0,w-1 do
   local idx=y*w+x+1
   local r,g,b,a=get(x,y)
   local cr,cg,cb=r*a+.5*(1-a),g*a+.5*(1-a),b*a+.5*(1-a)
   local dr,dg,db=cr,cg,cb
   if not inS[idx] then dr,dg,db=cr*.35,cg*.35,cb*.35 end
   local mr,mg,mb=cr,cg,cb
   if inM[idx] then mr,mg,mb=1,0,1 end
   local cols={{cr,cg,cb},{dr,dg,db},{mr,mg,mb}}
   for p=0,2 do
    local c=cols[p+1]
    local ox=p*(W+GAP)
    for j=0,S-1 do for i=0,S-1 do
     out:setPixel(ox+x*S+i,y*S+j,c[1],c[2],c[3],1)
    end end
   end
  end end
  local f=assert(io.open(dir..'/'..name..'.png','wb'))
  f:write(out:encode('png'):getString());f:close()
  nDumped=nDumped+1
  print(string.format('[GD dump] %s %s %dx%d %s searched %d mask %d boxes %d',curMap,d.tag,w,h,how,nSearch,nMask,#d.boxes))
 end

 -- Job 2 test (EM_GD_TEST=1): print the mask texture and image sizes per building;
-- EM_GD_WHITE=1 forces an all-white mask on b033 only (driver-side wrapper).
 if os.getenv('EM_GD_TEST') then
  local f0=GM.building
  GM.building=function(m,cells,bld)
   local id=tostring(bld.name or bld.kind or bld.model or '?')
   local r=f0(m,cells,bld)
   local hit=id:find('b033') or id:find('b025') or id:find('b030') or (curMap=='EM_MOSSDEEP_CITY' and id:find('house1'))
   if hit and m and m.imageData then
    local w,h=m.imageData:getDimensions()
    print(string.format('[GD test] %s map %s drawn image %dx%d mask texture %s panes-non-nil %s',id,curMap,w,h,r and (r:getWidth()..'x'..r:getHeight()) or 'nil',tostring(r~=nil)))
   end
   if os.getenv('EM_GD_WHITE') and id:find('b033') and m and m.imageData then
    local w,h=m.imageData:getDimensions()
    local d=love.image.newImageData(w,h)
    for y=0,h-1 do for x=0,w-1 do d:setPixel(x,y,1,1,1,1) end end
    r=love.graphics.newImage(d); r:setFilter('nearest','nearest')
    print('[GD test] forced all-white mask on',id,w..'x'..h)
   end
   return r
  end
 end
 GM.dump=function(d)
  local ok,err=pcall(dumpOne,d)
  if not ok then print('[GD ERROR]',curMap,d.tag,err) end
 end

 print('[EM QA] battle art export:',ns and 'yes' or 'NO')
 print('[EM QA] gen3 camera:',C and 'yes' or 'NO')
 local cases=dofile(os.getenv('EM_CASES'))
 for _,case in ipairs(cases) do
  curMap=case[1]
  local ok,err=pcall(function() assert(Map.load(nil,game,case[1],{x=case[2],y=case[3],facing='down'})) end)
  print('[EM view] load',case[1],ok,err or '')
  if ok then
   pcall(Player.reset,case[2],case[3],'down')
   for _,level in ipairs(dofile(os.getenv('EM_LEVELS'))) do
    if C then C.setLevel(level,game);C.yaw=tonumber(os.getenv('EM_YAW')) or 0 end
    U.wait(tonumber(os.getenv('EM_WAIT')) or 150)
    print('[EM view]',case[1],'level',level,'active',C and tostring(C.active),'rendered',C and C.rendered)
    U.shot(game,dir..'/'..case[1]..'__screen.png')
   end
  end
  curMap='?'
 end
 print('[GD dumped]',nDumped)
 print('[EM QA] done')
 love.event.quit()
end
