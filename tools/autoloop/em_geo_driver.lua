-- POKEPORT_DRIVER (autoloop, docs/AUTOLOOP.md): dump the built 3D geometry of whole maps for the offline detectors.
--   EM_MAPS=<file of "MAP x y" lines>  EM_GEO_DIR=<absolute output dir>  [EM_SETTLE=240 frames]  [EM_MARGIN=8 cells]
-- For every map: walks spots like tools/em_cells_driver.lua until every cell of the map has been built, waits for
-- each spot's builds to settle (no build in flight for EM_SETTLE frames), and keeps only the meshes of the LAST
-- completed build (near and upgrade builds are smaller windows and are dropped). Each triangle is written once, by
-- the first spot whose build contained its centroid cell, into <dir>/<MAP>.geo.gz (gzip text):
--   MAP <id> <W> <H>
--   TAG <n> <file:line> <function> <meshes> <verts>        one per mesh origin (which code made it)
--   T <tag> x1 y1 z1 x2 y2 z2 x3 y3 z3                      world px, map-relative (cell = floor(x/16), floor(z/16))
-- and <dir>/<MAP>.cells (em_cells_driver line format, so heights_compare/stairs tools read it).
-- Prints [EM geo] <map> spots tris secs ok. QA identity only; changes nothing in the game.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 -- Pins BEFORE the boot (engine E1 finding 2026-10-20): Mirage Tower hidden, tileset animation off. Pinned after the
 -- 90-frame Littleroot boot, the general__petalburg atlas stayed at whatever water/flower frame the boot reached, and the
 -- rock builder reads those pixels: Route 103's dump then depended on boot timing (168 of 420 rock/shore triangles).
 require('src.core.game3.rng').Random=function()return 0 end
 require('src.core.game3.tileset_anim')._enabled=false
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local ex=game.mods.exports.BATTLE_ART_VOXEL_FORK
 local Scene=ex.lib.require('Gen3Scene')
 local C=(ex.gen3 or ex.firered).camera
 local R=ex.lib.require('Voxel3D')
 local Map=require('src.core.game3.map')
 local DIR=assert(os.getenv('EM_GEO_DIR'),'EM_GEO_DIR')
 local SETTLE=tonumber(os.getenv('EM_SETTLE') or '240')
 local MARGIN=tonumber(os.getenv('EM_MARGIN') or '8')
 -- capture: every mesh with its origin, grouped by the scene's build counter at creation time
 local groups,order={},{}
 local function key() return (Scene.prepares or 0) end
 local orig=R.newMesh
 R.newMesh=function(verts,map,format)
  -- origin = file:line of the caller AND of its caller: Gen3Scene's field meshes all come from one local
  -- upload() helper, so only the line that called upload('under'|'roof'|'canopy'|'over'|'plants') tells them apart
  local info=debug.getinfo(2,'Sln') or {}
  local up=debug.getinfo(3,'Sl') or {}
  local tag=tostring(info.short_src or '?'):match('[^/]*$')..':'..tostring(info.currentline or 0)..'<'..tostring(up.short_src or '?'):match('[^/]*$')..':'..tostring(up.currentline or 0)
  local k=key()
  local g=groups[k];if not g then g={};groups[k]=g;order[#order+1]=k end
  g[#g+1]={verts=verts,map=map,tag=tag,fn=info.name or '-'}
  return orig(verts,map,format)
 end
 -- Building/prop models are packed as a flat number list by FlatMesh and uploaded with love.graphics.newMesh, so
 -- Voxel3D.newMesh never sees them and the dumps had no models at all: F038 (houses 32 px low inside a fill) could not be
 -- gated on geometry for that reason. Wrap FlatMesh.mesh and turn its flat list back into the same vertex tables.
 do local ok,FM=pcall(ex.lib.require,'FlatMesh')
  if ok and type(FM)=='table' and type(FM.mesh)=='function' then
   local omesh=FM.mesh
   FM.mesh=function(f,n)
    if n and n>0 then
     local k=key()
     local g=groups[k];if not g then g={};groups[k]=g;order[#order+1]=k end
     local verts={}
     for v=0,n/6-1 do local o=v*6;verts[v+1]={f[o+1],f[o+2],f[o+3],f[o+4],f[o+5],f[o+6]} end
     local idx={}
     for q=0,#verts/4-1 do local b=q*4;local m=#idx
      idx[m+1],idx[m+2],idx[m+3],idx[m+4],idx[m+5],idx[m+6]=b+1,b+2,b+3,b+1,b+3,b+4
     end
     g[#g+1]={verts=verts,map=idx,tag='FlatMesh:model',fn='model'}
    end
    return omesh(f,n)
   end
  end
 end
 local DECK={general__fortree={[0x256]=1}}
 for t=0x210,0x21D do DECK.general__fortree[t]=1 end
 local function settle()
  -- settled = at least one build completed since the map load and no further completion for SETTLE frames
  -- (stream.stats.started can stay ahead of completed for good when a build is dropped, so started/completed
  -- equality never comes on some maps: Route 112 waited 60 s for it)
  local b0=Scene.builds or 0
  local n=0
  repeat U.wait(1);n=n+1 until (C.active) or n>900
  local last,stable=-1,0
  local p0=Scene.prepares or 0
  for i=1,3600 do
   -- nothing started within 300 frames: this load builds nothing new (same window), stop waiting
   if i==300 and (Scene.prepares or 0)==p0 and (Scene.builds or 0)==b0 then return false end
   local b=Scene.builds or 0
   if b==last then stable=stable+1 else stable=0;last=b end
   if b>b0 and stable>=SETTLE then return true end
   U.wait(1)
  end
  return false
 end
 local maps={}
 for l in io.lines(os.getenv('EM_MAPS'))do local m,x,y=l:match('^(%S+)%s+(%d+)%s+(%d+)');if m then maps[#maps+1]={m,tonumber(x),tonumber(y)} end end
 for _,m in ipairs(maps)do
  local id=m[1];local t0=love.timer.getTime()
  -- reloading the map already loaded (the boot map, Littleroot) starts no build, so settle() would wait for nothing:
  -- step onto another map first (Littleroot came out empty and 'unsettled' in the first world sweep)
  local cur=Map.currentDef and Map.currentDef()
  if Map.current==id or (cur and cur.id==id) then
   pcall(Map.load,nil,game,id=='EM_ROUTE101' and 'EM_OLDALE_TOWN' or 'EM_ROUTE101',{x=10,y=10,facing='down'})
   settle()
  end
  -- dark caves (Granite Cave B1F/B2F...) draw flat without Flash: light them so their 3D is dumped (engine E1 note)
  if game.session then game.session.flashLevel=0 end
  local ok=pcall(Map.load,nil,game,id,{x=m[2],y=m[3],facing='down'})
  C.setLevel(4,game)
  local def=Map.currentDef()
  if not (ok and def and def.midLayout) then print(('[EM geo]\t%s\t0\t0\t0\tskip'):format(id))
  else
   local W,H=def.midLayout.width,def.midLayout.height
   local doors={}
   for _,w in ipairs(def.warps or {})do if tonumber(w.x) and tonumber(w.y) then doors[tonumber(w.x)..','..tonumber(w.y)]=1 end end
   local out,cl,tags,tagN={},{},{},{}
   local written,tried={},{}
   local spots,tris,allSettled=0,0,true
   for spot=1,20 do
    if spot>1 then
     local mx,my
     for cy=0,H-1 do for cx=0,W-1 do if not mx and not written[cx..':'..cy] and not tried[cx..':'..cy] then mx,my=cx,cy end end end
     if not mx then break end
     tried[mx..':'..my]=true
     groups,order={},{}
     pcall(Map.load,nil,game,id,{x=math.min(W-1,mx+24),y=math.min(H-1,my+24),facing='down'})
     C.setLevel(4,game)
    else groups,order={},{} end
    local bBefore=Scene.builds or 0
    local settledOk=settle()
    -- a reload that starts no build (maps with black padding cells that are never built: Abandoned Ship, New Mauville)
    -- adds nothing: stop walking spots instead of waiting a full settle per spot (engine E1 note)
    if spot>1 and (Scene.builds or 0)==bBefore then break end
    if not settledOk then allSettled=false end
    spots=spot
    -- cells built in this spot and not written before (margin round the map included)
    local mine={}
    -- Own only cells well inside this spot's build window (INNER cells from its edge, unless that edge is the end of
    -- the dumped area): at a window edge the builders round or drop geometry toward the missing cells (F031 finding:
    -- Route 103's rock lost its closing wall at a spot seam and a 2 px crack opened the whole interior to the sky).
    -- (engine E1 proposal: the REQUEST window, not the built cells: nothing is built outside a cave, so its
    -- built extent is the map edge and the edge rows were never owned)
    local b=Scene.distance and Scene.distance.bounds or {-1e9,-1e9,1e9,1e9}
    local wx0,wy0,wx1,wy1=b[1],b[2],b[3],b[4]
    local INNER=6
    local ix0=(wx0<=-MARGIN) and -1e9 or wx0+INNER
    local ix1=(wx1>=W-1+MARGIN) and 1e9 or wx1-INNER
    local iy0=(wy0<=-MARGIN) and -1e9 or wy0+INNER
    local iy1=(wy1>=H-1+MARGIN) and 1e9 or wy1-INNER
    for cy=-MARGIN,H-1+MARGIN do for cx=-MARGIN,W-1+MARGIN do
     local c=not written[cx..':'..cy] and cx>=ix0 and cx<=ix1 and cy>=iy0 and cy<=iy1 and Scene.debugCell(cx,cy)
     if c then written[cx..':'..cy]=true;mine[cx..':'..cy]=true
      local r=Scene.debugRaw(cx,cy) or {}
      local g=r.stairs;local sk=r.shape and r.shape.kind or ''
      local sdir=(g and g.r) and ((g.r.east and 'E' or 'W')..(g.r.down and '-down' or '-up')) or (sk=='steps' and 'steps') or '-'
      local fam=DECK[r.pair]
      local bridge=(r.shape and r.shape.underWater) or (r.collision==0 and r.floor and (r.floor.layer==15 or (fam and fam[r.mid]))) or sk:match('^deck')
      cl[#cl+1]=('%s %d %d %03X %s coll=%s prop=%s col=%s base=%s stairs=%d sdir=%s ladder=%d ledge=%d rail=%d bridge=%d door=%d elev=%s ldrop=%s mass=%s'):format(id,cx,cy,c.mid or 0,tostring(c.kind),tostring(c.collision),tostring(c.prop),c.col and 'y' or '-',tostring(c.base),
       (g or sk=='steps') and 1 or 0,sdir,sk=='ladder' and 1 or 0,sk=='ledge' and 1 or 0,sk=='rail' and 1 or 0,bridge and 1 or 0,doors[cx..','..cy] or 0,tostring(def.midLayout:elevAt(cx,cy)),
       (r.floor and r.floor.drop) and (r.floor.drop[1]..','..r.floor.drop[2]) or '-',tostring(r.mass and (type(r.mass)=='table' and (r.mass.id or 't') or r.mass) or '-'))
     end
    end end
    -- the last build that made scene meshes
    -- the last group holding Gen3Scene field meshes (the upload() helper): sprite and actor meshes are made
    -- lazily while drawing and come later, so "the last group with any mesh" can be a handful of sprites
    local last
    for i=#order,1,-1 do local g=groups[order[i]]
     local field=false;for _,me in ipairs(g or {})do if me.fn=='upload' then field=true;break end end
     if field then last=g;break end
    end
    for _,me in ipairs(last or {})do
     local tg=tags[me.tag];if not tg then tagN[#tagN+1]={me.tag,me.fn,0,0};tg=#tagN;tags[me.tag]=tg end
     local rec=tagN[tg];rec[3]=rec[3]+1;rec[4]=rec[4]+#me.verts
     local v,ix=me.verts,me.map
     local n=ix and #ix>0 and #ix or #v
     for k=1,n-2,3 do
      local a,b,c
      if ix and #ix>0 then a,b,c=v[ix[k]],v[ix[k+1]],v[ix[k+2]] else a,b,c=v[k],v[k+1],v[k+2] end
      if a and b and c then
       local cx=math.floor((a[1]+b[1]+c[1])/48);local cz=math.floor((a[3]+b[3]+c[3])/48)
       if mine[cx..':'..cz] then
        out[#out+1]=('T %d %.1f %.1f %.1f %.1f %.1f %.1f %.1f %.1f %.1f'):format(tg,a[1],a[2],a[3],b[1],b[2],b[3],c[1],c[2],c[3])
        tris=tris+1
       end
      end
     end
    end
   end
   local head={('MAP %s %d %d'):format(id,W,H)}
   for i,t in ipairs(tagN)do head[#head+1]=('TAG %d %s %s %d %d'):format(i,t[1],t[2],t[3],t[4]) end
   local body=table.concat(head,'\n')..'\n'..table.concat(out,'\n')..'\n'
   local f=assert(io.open(DIR..'/'..id..'.geo.gz','wb'))
   f:write(love.data.compress('string','gzip',body));f:close()
   local fc=assert(io.open(DIR..'/'..id..'.cells','w'));fc:write(table.concat(cl,'\n'),'\n');fc:close()
   print(('[EM geo]\t%s\t%d\t%d\t%.1f\t%s'):format(id,spots,tris,love.timer.getTime()-t0,allSettled and 'ok' or 'unsettled'))
  end
  groups,order={},{}
  collectgarbage()
 end
 love.event.quit()
end
