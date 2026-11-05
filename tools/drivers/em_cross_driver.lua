-- POKEPORT_DRIVER script: walk over a map connection and count the frames until the 3D scene is drawn again.
-- EM_CROSS="MAP,x,y,dir;MAP,x,y,dir" (x,y = last cell before the edge). Shots (frame 1, 8, 30 after crossing) go to SHOT_DIR.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 local dir=assert(os.getenv('SHOT_DIR'))
 assert(love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa'),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local export=game.mods.exports.emerald_3d_voxel_mod
 local C=(export.gen3 or export.firered).camera
 local Scene=export.lib.require('Gen3Scene')
 local Map=require('src.core.game3.map');local Player=require('src.core.game3.player');local Collision=require('src.core.game3.collision')
 C.setLevel(tonumber(os.getenv('EM_LEVEL')) or 4,game)
 if os.getenv('EM_TOUR') then export.lib.require('Gen3SceneOptions').tour:setIndex(2,game) end -- TOUR: walk through walls and over any edge
 for spec in (os.getenv('EM_CROSS') or 'EM_LITTLEROOT_TOWN,10,0,up'):gmatch('[^;]+') do
  local id,x,y,d=spec:match('([^,]+),(%d+),(%d+),(%a+)')
  x,y=tonumber(x),tonumber(y)
  assert(Map.load(nil,game,id,{x=x,y=y,facing=d}))
  pcall(Player.reset,x,y,d)
  U.wait(60)
  for _=1,900 do if C.active then break end;U.wait(1) end
  U.wait(tonumber(os.getenv('EM_SETTLE')) or 300)
  local s=Scene.streaming
  print('[EM cross] before',id,'active',C.active,'builds',s.completed,'buildMs',math.floor(s.buildMs or 0),'warmed',s.warmed)
  C.yaw=({up=0,right=math.pi/2,down=math.pi,left=math.pi*1.5})[d] or 0 -- look the way the player crosses (free camera levels)
  U.shot(game,string.format('%s/%s_before.png',dir,id))
  if os.getenv('EM_COLD') then -- tilesets only the destination's world needs are not resident yet, as on a first visit
   local Tiles=require('src.core.game3.tileset_native');local maps=game.data.maps
   local function pairOf(def)return def and (def.pair or (def.midLayout and def.midLayout.pair))end
   local keep={}
   keep[pairOf(Map.currentDef())]=true
   if os.getenv('EM_COLD')~='all' then for _,e in ipairs(Map.world)do keep[pairOf(e.def)]=true end end
   local evicted={}
   for _,n in ipairs(Map.neighborList or {})do
    for _,e in ipairs(Map.computeWorld(maps,n.map,Map.WORLD_HOPS,0,0))do
     local p=pairOf(e.def);if p and not keep[p] and Tiles._pairs[p] then Tiles._pairs[p]=nil;evicted[#evicted+1]=p;keep[p]=true end
    end
    local p=pairOf(maps[n.map]);if p and not keep[p] and Tiles._pairs[p] then Tiles._pairs[p]=nil;evicted[#evicted+1]=p;keep[p]=true end
   end
   print('[EM cross] evicted',table.concat(evicted,' '))
  end
  local log,t0={},love.timer.getTime()
  local drawn=Scene.draw
  Scene.draw=function(...)
   local t=love.timer.getTime();local r=drawn(...)
   log[#log+1]=string.format('%.0fms%s',(love.timer.getTime()-t)*1000,r and '' or ' FLAT');return r
  end
  if os.getenv('EM_WALK') then -- walk toward the edge, counting frames a scene build is in flight
   local busy,n=0,0
   for i=1,tonumber(os.getenv('EM_WALK')) do -- jump one block (6 cells) every 90 frames
    if i%90==1 then x=x-6;Player.reset(x,y,d) end
    U.wait(1);n=n+1
    if s.started>s.completed+s.cancelled then busy=busy+1 end
   end
   print('[EM walk] frames',n,'busy',busy,'map',Map.current,'cell',Player.cellX,Player.cellY,'started',s.started,'completed',s.completed)
   break
  end
  local ok=Collision.tryConnection(game,x,y,d,false)
  local flat,first=0,nil
  for f=1,600 do
   U.wait(1)
   if C.active then first=first or f else flat=flat+1 end
   if f==1 or f==8 or f==30 then U.shot(game,string.format('%s/%s_f%02d%s.png',dir,id,f,C.active and '' or '_FLAT')) end
  end
  Scene.draw=drawn
  print('[EM cross] draws',table.concat(log,' ',1,math.min(#log,40)))
  print('[EM cross] after',id,'crossed',ok,'map',Map.current,'flatFrames',flat,'firstActive',first,'builds',s.completed,'buildMs',math.floor(s.buildMs or 0),'reused',s.reused,'warmed',s.warmed,'adopted',s.adopted)
 end
 print('[EM QA] done')
 love.event.quit()
end
