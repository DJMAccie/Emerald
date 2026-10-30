-- POKEPORT_DRIVER: building-mesh cost probe (stage B step 1). For every map in EM_MAPS ("MAP x y" lines) wrap Voxel3D.newMesh and print,
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

 local BM=ex.lib.require('BuildingModels');local BV=ex.lib.require('BuildingVoxels');local okF,FM=pcall(ex.lib.require,'FlatMesh');if not okF then FM=nil end
 local GM=ex.lib.require('GlassMask');local SV=ex.lib.require('SpriteVoxel')
 local T,N={},{}   -- timer name -> seconds, call count (per map)
 local depth=0
 local function wrap(tbl,name,label,nested)
  local o=tbl[name]
  tbl[name]=function(...)
   local t0=love.timer.getTime()
   local a,b,c,d=o(...)
   T[label]=(T[label] or 0)+love.timer.getTime()-t0;N[label]=(N[label] or 0)+1
   return a,b,c,d
  end
  return function() tbl[name]=o end
 end
 local undo={}
 undo[#undo+1]=wrap(BM,'mesh','BM.mesh(total)')
 undo[#undo+1]=wrap(BM,'compose','compose')
 undo[#undo+1]=wrap(BV,'mesh','BV.mesh')
 if FM then undo[#undo+1]=wrap(FM,'mesh','FlatMesh.mesh') end
 undo[#undo+1]=wrap(SV,'build','SpriteVoxel.build')
 undo[#undo+1]=wrap(GM,'building','GlassMask.building')
 -- EM_BLDCACHE: off (cache disabled), cold (disk cache wiped first), warm/other (as found)
 local okC,BMC=pcall(ex.lib.require,'BuildingMeshCache')
 local mode=os.getenv('EM_BLDCACHE') or 'warm'
 if okC then
  if mode=='off' then BMC.enabled=false end
  if mode=='corrupt' then
   for i,n in ipairs(love.filesystem.getDirectoryItems('bldcache'))do
    local path='bldcache/'..n;local d=love.filesystem.read(path)
    if i%3==0 then love.filesystem.write(path,d:sub(1,math.floor(#d/2)))        -- truncated
    elseif i%3==1 then local k=math.floor(#d/2);love.filesystem.write(path,d:sub(1,k-1)..string.char((d:byte(k)+1)%256)..d:sub(k+1))   -- one byte flipped
    else love.filesystem.write(path,'junk') end
   end
  end
  if mode=='cold' then for _,n in ipairs(love.filesystem.getDirectoryItems('bldcache'))do love.filesystem.remove('bldcache/'..n) end end
 end
 -- exact content of every building mesh: md5 of its vertex bytes, by building (one line per distinct mesh)
 local cur,seen={},{}
 local oFS=FM and FM.fromString
 if oFS then
  FM.fromString=function(str,n)
   if cur.name and cur.str==nil then cur.str=str;cur.n=n end
   local t0=love.timer.getTime();local a,b=oFS(str,n)
   T['fromString']=(T['fromString'] or 0)+love.timer.getTime()-t0;N['fromString']=(N['fromString'] or 0)+1
   return a,b
  end
 end
 do
  local oB=BM.mesh
  BM.mesh=function(bld,cells)
   cur={name=bld.name or '?',cx=bld.cx,cy=bld.cy}
   local a,b=oB(bld,cells)
   if cur.str then
    local k=string.format('%s@%d,%d n=%d md5=%s',cur.name,cur.cx,cur.cy,cur.n,love.data.encode('string','hex',love.data.hash('md5',cur.str)))
    seen[k]=true
   end
   cur={}
   return a,b
  end
  undo[#undo+1]=function()BM.mesh=oB end
 end
 -- newMesh inside BM.mesh only
 local inBM=0
 local oM=BM.mesh
 local oN=R.newMesh
 R.newMesh=function(...)
  local t0=love.timer.getTime();local a,b=oN(...)
  T['newMesh(all)']=(T['newMesh(all)'] or 0)+love.timer.getTime()-t0;N['newMesh(all)']=(N['newMesh(all)'] or 0)+1
  return a,b
 end
 local nBld,nQuads={}, {}
 for _,m in ipairs(maps)do
  T,N={},{}
  local t0=love.timer.getTime()
  Map.load(nil,game,m[1],{x=m[2],y=m[3],facing='down'});C.setLevel(4,game)
  U.wait(frames)
  print(string.format('[EM bld]\t%s\twall %.1f s\tbuilds %s',m[1],love.timer.getTime()-t0,tostring(Scene.builds)))
  local ks={};for k in pairs(T)do ks[#ks+1]=k end;table.sort(ks)
  for _,k in ipairs(ks)do print(string.format('[EM bld]\t%s\t%-20s\t%8.0f ms\t%d calls',m[1],k,T[k]*1000,N[k])) end
  local ks2={};for k in pairs(seen)do ks2[#ks2+1]=k end;table.sort(ks2)
  for _,k in ipairs(ks2)do print('[EM bmesh]\t'..m[1]..'\t'..k) end
  seen={}
  if okC then local st=BMC.stats;print(string.format('[EM bmc]\t%s\tmode=%s ram=%d disk=%d miss=%d bad=%d fail=%d wrote=%d',m[1],mode,st.ram,st.disk,st.miss,st.bad,st.fail,st.wrote)) end
  local r=Scene.debugTimes and Scene.debugTimes() or {}
  print('[EM stage]',m[1],table.concat(r,' | '))
 end
 for _,u in ipairs(undo)do u() end
 R.newMesh=oN
 love.event.quit()
end
