-- QA driver: what does a mesh cost on this machine? (the flight lays its ground as meshes while flying)
--   EM_DRIVER=<this file> tools/qa_tryp.sh "Gen3FlyOver.lua" <abs out> "-" 4 0 200
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
 for _,n in ipairs({1200,3000,6000,12000,24000}) do
  for rep=1,3 do
   local v=verts(n);local m=map(n/4)
   U.wait(2)
   local t0=t();local mesh=love.graphics.newMesh(R.FORMAT,v,'triangles','static');local t1=t()
   mesh:setVertexMap(m);local t2=t()
   local m2=love.graphics.newMesh(R.FORMAT,n,'triangles','static');local t3=t()
   m2:setVertices(v);local t4=t()
   m2:setVertexMap(m);local t5=t()
   print(string.format('[bench] %5d verts: newMesh(table) %.1f ms, +setVertexMap %.1f ms | newMesh(count) %.1f ms, +setVertices %.1f ms, +setVertexMap %.1f ms',n,t1-t0,t2-t1,t3-t2,t4-t3,t5-t4))
   mesh:release();m2:release()
  end
 end
 print('[bench] done')
 love.event.quit()
end
