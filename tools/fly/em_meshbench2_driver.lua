-- QA driver: is the ~20 ms newMesh(format,table) stall once per frame (a sync) or once per call?
--   EM_DRIVER=<this file> tools/qa_tryp.sh "Gen3FlyOver.lua" <abs out> "-" 4 0 200
-- Each trial makes 6 meshes in ONE frame in a chosen order and prints each call's ms.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(120)
 local R=game.mods.exports.BATTLE_ART_VOXEL_FORK.lib.require('Voxel3D')
 local function verts(n)local v={};for i=1,n do v[i]={i%64*16,-.6,math.floor(i/64)*16,0,0,1}end return v end
 local function map(cells)local m={};for q=0,cells-1 do local b=q*4;local n=q*6;m[n+1],m[n+2],m[n+3],m[n+4],m[n+5],m[n+6]=b+1,b+2,b+3,b+1,b+3,b+4 end return m end
 local function t()return love.timer.getTime()*1000 end
 local N=3600
 local v=verts(N);local m=map(N/4)
 local function viaTable()local t0=t();local x=love.graphics.newMesh(R.FORMAT,v,'triangles','static');x:setVertexMap(m);return x,t()-t0 end
 local function viaCount()local t0=t();local x=love.graphics.newMesh(R.FORMAT,N,'triangles','static');x:setVertices(v);x:setVertexMap(m);return x,t()-t0 end
 local function trial(label,order)
  U.wait(3)
  local keep,ms={},{}
  for i,kind in ipairs(order)do
   local x,d=(kind=='t' and viaTable or viaCount)()
   keep[#keep+1]=x;ms[#ms+1]=string.format('%s%.1f',kind,d)
  end
  print('[bench2] '..label..': '..table.concat(ms,' '))
  for _,x in ipairs(keep)do x:release()end
 end
 for rep=1,3 do
  trial('count x6',{'c','c','c','c','c','c'})
  trial('table x6',{'t','t','t','t','t','t'})
  trial('count first, then table x3',{'c','t','t','t','c','c'})
  trial('table first, then count x3',{'t','c','c','c','t','t'})
 end
 -- one mesh per frame, either form, for 6 frames: does a sync cost accumulate per frame?
 for _,kind in ipairs({'c','t','c','t'})do
  local ms={}
  for i=1,6 do U.wait(1);local x,d=(kind=='t' and viaTable or viaCount)();ms[#ms+1]=string.format('%.1f',d);x:release()end
  print('[bench2] one per frame ('..kind..'): '..table.concat(ms,' '))
 end
 print('[bench2] done')
 love.event.quit()
end
