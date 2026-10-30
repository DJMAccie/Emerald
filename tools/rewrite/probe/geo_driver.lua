-- POKEPORT_DRIVER: MOD-NEUTRAL geometry + cell dump (M0 of docs/proposals/REWRITE-PLAN.md).
-- Same walk and output as tools/relief/stage3/ab/h3_geo_driver.lua, but it reads the scene ONLY through the probe of
-- emerald3d docs/specs/ProbeContract.md (exports.<mod>.gen3.probe), so it measures the old mod and the rewrite alike.
-- For the old mod the probe comes from EM_PROBE_ADAPTER (default tools/rewrite/probe/old_adapter.lua).
--   EM_MAPS=<file of "MAP x y" lines>  EM_GEO_DIR=<absolute output dir>  [EM_SETTLE=240]  [EM_MARGIN=8]  [EM_IDLE=300]
--   EM_IDLE: frames without a new build before a spot counts as unsettled; big cave maps need more than 300.
-- Out per map: <dir>/<MAP>.geo.gz (TAG lines carry the probe layer name instead of a source line) and <dir>/<MAP>.cells.
-- QA identity only.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 require('src.core.game3.rng').Random=function()return 0 end
 require('src.core.game3.tileset_anim')._enabled=false
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local probe
 for _,ex in pairs(game.mods.exports or {})do
  if type(ex)=='table' and type(ex.gen3)=='table' and type(ex.gen3.probe)=='table' then probe=ex.gen3.probe end
 end
 if not probe then
  local A=os.getenv('EM_PROBE_ADAPTER') or (os.getenv('HOME')..'/Documents/Emerald/tools/rewrite/probe/old_adapter.lua')
  probe=dofile(A)(game)
 end
 local Map=require('src.core.game3.map')
 local DIR=assert(os.getenv('EM_GEO_DIR'),'EM_GEO_DIR')
 local SETTLE=tonumber(os.getenv('EM_SETTLE') or '240')
 local IDLE=tonumber(os.getenv('EM_IDLE') or '300')
 local MARGIN=tonumber(os.getenv('EM_MARGIN') or '8')
 local FIELD={ground=true,roof=true,canopy=true,over=true,plants=true}
 local groups,order={},{}
 -- group key = builds started so far (a dropped build counts too, so this is not completed + in flight)
 local function key() return probe.started() end
 probe.onMesh(function(layer,verts,map)
  local k=key()
  local g=groups[k];if not g then g={};groups[k]=g;order[#order+1]=k end
  g[#g+1]={verts=verts,map=map,layer=layer}
 end)
 local function settle()
  local b0=probe.builds()
  local n=0
  repeat U.wait(1);n=n+1 until probe.active() or n>900
  local last,stable=-1,0
  local p0=key()
  for i=1,3600 do
   if i==IDLE and key()==p0 and probe.builds()==b0 then return false end
   local b=probe.builds()
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
  local cur=Map.currentDef and Map.currentDef()
  if Map.current==id or (cur and cur.id==id) then
   pcall(Map.load,nil,game,id=='EM_ROUTE101' and 'EM_OLDALE_TOWN' or 'EM_ROUTE101',{x=10,y=10,facing='down'})
   settle()
  end
  if game.session then game.session.flashLevel=0 end
  local ok=pcall(Map.load,nil,game,id,{x=m[2],y=m[3],facing='down'})
  probe.setLevel(4)
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
     probe.setLevel(4)
    else groups,order={},{} end
    local bBefore=probe.builds()
    local settledOk=settle()
    if spot>1 and probe.builds()==bBefore then break end
    if not settledOk then allSettled=false end
    spots=spot
    local mine={}
    local wx0,wy0,wx1,wy1=probe.window()
    if not wx0 then wx0,wy0,wx1,wy1=-1e9,-1e9,1e9,1e9 end
    local INNER=6
    local ix0=(wx0<=-MARGIN) and -1e9 or wx0+INNER
    local ix1=(wx1>=W-1+MARGIN) and 1e9 or wx1-INNER
    local iy0=(wy0<=-MARGIN) and -1e9 or wy0+INNER
    local iy1=(wy1>=H-1+MARGIN) and 1e9 or wy1-INNER
    for cy=-MARGIN,H-1+MARGIN do for cx=-MARGIN,W-1+MARGIN do
     local c=not written[cx..':'..cy] and cx>=ix0 and cx<=ix1 and cy>=iy0 and cy<=iy1 and probe.cell(cx,cy)
     if c then written[cx..':'..cy]=true;mine[cx..':'..cy]=true
      local sk=c.kind or ''
      local g=c.stairs
      local sdir=(g and g.dir) and (g.dir..(g.up and '-up' or '-down')) or (sk=='steps' and 'steps') or '-'
      cl[#cl+1]=('%s %d %d %03X %s coll=%s prop=%s col=%s base=%s stairs=%d sdir=%s ladder=%d ledge=%d rail=%d bridge=%d door=%d elev=%s ldrop=%s mass=%s'):format(id,cx,cy,c.mid or 0,tostring(c.kind),tostring(c.collision),tostring(c.prop),c.column and 'y' or '-',tostring(c.base),
       (g or sk=='steps') and 1 or 0,sdir,sk=='ladder' and 1 or 0,sk=='ledge' and 1 or 0,sk=='rail' and 1 or 0,c.bridge and 1 or 0,doors[cx..','..cy] or 0,tostring(def.midLayout:elevAt(cx,cy)),
       c.drop and (c.drop.from..','..c.drop.to) or '-',tostring(c.mass or '-'))
     end
    end end
    local last
    for i=#order,1,-1 do local g=groups[order[i]]
     local field=false;for _,me in ipairs(g or {})do if FIELD[me.layer] then field=true;break end end
     if field then last=g;break end
    end
    for _,me in ipairs(last or {})do
     local tg=tags[me.layer];if not tg then tagN[#tagN+1]={me.layer,me.layer,0,0};tg=#tagN;tags[me.layer]=tg end
     local rec=tagN[tg];rec[3]=rec[3]+1;rec[4]=rec[4]+#me.verts
     local v,ix=me.verts,me.map
     local n=ix and #ix>0 and #ix or #v
     for k=1,n-2,3 do
      local a,b,c
      if ix and #ix>0 then a,b,c=v[ix[k]],v[ix[k+1]],v[ix[k+2]] else a,b,c=v[k],v[k+1],v[k+2] end
      if a and b and c then
       local cx=math.floor((a[1]+b[1]+c[1])/48);local cz=math.floor((a[3]+b[3]+c[3])/48)
       if mine[cx..':'..cz] then
        out[#out+1]=('T %d %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f'):format(tg,a[1],a[2],a[3],b[1],b[2],b[3],c[1],c[2],c[3])
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
