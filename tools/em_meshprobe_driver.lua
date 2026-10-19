-- POKEPORT_DRIVER: bake spike, stage A. For every map in EM_MAPS ("MAP x y" lines) wrap Voxel3D.newMesh and print,
-- per completed scene build, the mesh count, vertices, indices, an ORDER-INDEPENDENT checksum (set of vertices),
-- an ORDERED checksum (sequence) and the seconds spent inside newMesh itself (upload), plus the stage marks.
--   [EM mesh]  map  build#  meshes  verts  idx  setsum  seqsum  uploadMs
--   [EM stage] map  <Scene.debugTimes()>
-- Run twice (separate games) and diff the [EM mesh] lines: equal setsum = same geometry, equal seqsum = same order too.
-- EM_WAIT_FRAMES (default 900) is how long each map builds before it prints. QA identity only; changes nothing.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert(love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa'),'QA only')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(200)
 local ex=game.mods.exports.BATTLE_ART_VOXEL_FORK
 local Scene=ex.lib.require('Gen3Scene');local C=(ex.gen3 or ex.firered).camera
 local R=ex.lib.require('Voxel3D')
 local Map=require('src.core.game3.map')
 local frames=tonumber(os.getenv('EM_WAIT_FRAMES') or '900')
 local maps={}
 for l in io.lines(os.getenv('EM_MAPS'))do local m,x,y=l:match('(%S+)%s+(%d+)%s+(%d+)');if m then maps[#maps+1]={m,tonumber(x),tonumber(y)} end end
 local MOD=2147483629
 local acc={}                                   -- build number -> totals
 local DUMP=os.getenv('EM_MESH_DUMP') and io.open(os.getenv('EM_MESH_DUMP'),'w')   -- every vertex of meshes up to EM_MESH_DUMP_MAX vertices
 local DUMPMAX=tonumber(os.getenv('EM_MESH_DUMP_MAX') or '20000')
 local orig=R.newMesh
 R.newMesh=function(verts,map,format)
  local b=Scene.builds or 0
  local a=acc[b];if not a then a={meshes=0,verts=0,idx=0,set=0,seq=0,up=0};acc[b]=a end
  for _,v in ipairs(verts)do
   local h=0
   for k=1,#v do local q=math.floor((v[k] or 0)*4096+.5);h=(h*31+q)%MOD end
   a.set=(a.set+h)%MOD;a.seq=(a.seq*1000003+h)%MOD
  end
  if map then for _,i in ipairs(map)do a.seq=(a.seq*1000003+i)%MOD end;a.idx=a.idx+#map end
  a.meshes=a.meshes+1;a.verts=a.verts+#verts
  if os.getenv('EM_MESH_EACH') then
   local ms=0;for _,v in ipairs(verts)do local h=0;for k=1,#v do h=(h*31+math.floor((v[k] or 0)*4096+.5))%MOD end;ms=(ms+h)%MOD end
   print(string.format('[EM one]\t%s\t%d\t%d\t%d\t%d',Scene.sceneDef and Scene.sceneDef.id or '?',b,a.meshes,#verts,ms))
  end
  if DUMP and #verts<=DUMPMAX then
   for _,v in ipairs(verts)do local t={};for k=1,#v do t[k]=string.format('%.3f',v[k] or 0) end;DUMP:write(Scene.sceneDef and Scene.sceneDef.id or '?',' ',b,' ',a.meshes,' ',#verts,' ',table.concat(t,' '),'\n') end
  end
  local t0=love.timer.getTime()
  local mesh,err=orig(verts,map,format)
  a.up=a.up+(love.timer.getTime()-t0)
  return mesh,err
 end
 for _,m in ipairs(maps)do
  acc={}
  local t0=love.timer.getTime()
  Map.load(nil,game,m[1],{x=m[2],y=m[3],facing='down'});C.setLevel(4,game)
  U.wait(frames)
  local keys={};for k in pairs(acc)do keys[#keys+1]=k end;table.sort(keys)
  for _,k in ipairs(keys)do local a=acc[k]
   print(string.format('[EM mesh]\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%.0f',m[1],k,a.meshes,a.verts,a.idx,a.set,a.seq,a.up*1000))
  end
  local r=Scene.debugTimes and Scene.debugTimes() or {}
  print('[EM stage]',m[1],table.concat(r,' | '))
  print(string.format('[EM wall]\t%s\t%.1f s',m[1],love.timer.getTime()-t0))
 end
 R.newMesh=orig
 if DUMP then DUMP:close() end
 love.event.quit()
end
