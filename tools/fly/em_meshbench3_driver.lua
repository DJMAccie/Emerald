-- QA driver: can a pool of meshes allocated once be refilled cheaply (no per-frame sync)?
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
 -- a pool: allocate 20 meshes in one frame, refill one per frame afterwards
 local pool={}
 U.wait(3)
 local t0=t()
 for i=1,20 do pool[i]=love.graphics.newMesh(R.FORMAT,N,'triangles','static') end
 print(string.format('[bench2] pool of 20 allocated in one frame: %.1f ms',t()-t0))
 for i=1,20 do
  U.wait(1)
  local t1=t();pool[i]:setVertices(v);local t2=t();pool[i]:setVertexMap(m);local t3=t()
  print(string.format('[bench2] refill %2d (frame later): setVertices %.1f ms, setVertexMap %.1f ms',i,t2-t1,t3-t2))
 end
 -- refill the SAME mesh again (it was drawn? no) and a refill while two refills happen in one frame
 U.wait(1)
 local t1=t();pool[1]:setVertices(v);pool[2]:setVertices(v);print(string.format('[bench2] two refills in one frame: %.1f ms',t()-t1))
 print('[bench2] done')
 love.event.quit()
end
