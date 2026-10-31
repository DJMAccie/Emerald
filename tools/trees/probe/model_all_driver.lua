-- POKEPORT_DRIVER: per-UPLOAD geometry dump, plus every tree model of every build (tools/trees copy of tools/rewrite/probe/model_driver.lua).
-- geo_driver.lua concatenates every upload of a layer, which is useless for a layer the mod INSTANCES: both
-- sides upload one model per drawing and translate it, so all the models sit on the origin and overlap.
-- This driver writes each upload of the settled build to its own file, so one model can be read and diffed
-- against the same drawing's model on the other side.
--   EM_MAPS=<file of "MAP x y" lines>  EM_GEO_DIR=<absolute output dir>
-- Out: <dir>/<MAP>/NNN.<layer>.tri   first line: "verts <n> tris <n> idx <n> bbox x0 y0 z0 x1 y1 z1"
--                                    then one triangle per line: "x y z x y z x y z"
-- QA identity only.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 require('src.core.game3.rng').Random=function()return 0 end
 require('src.core.game3.tileset_anim')._enabled=false
 love.window.setMode(1280,720,{resizable=true})
 if love.window.minimize then pcall(love.window.minimize) end
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map=os.getenv('EM_BOOT') or 'EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
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
 local FIELD={ground=true,roof=true,canopy=true,over=true,plants=true}
 local groups,order={},{}
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
  local id=m[1]
  groups,order={},{}
  local ok=pcall(Map.load,nil,game,id,{x=m[2],y=m[3],facing='down'})
  probe.setLevel(4)
  local settled=settle()
  -- the last group that carries a field upload is the settled build (a dropped or partial build has none)
  local last
  for i=#order,1,-1 do
   local g=groups[order[i]]
   local field=false;for _,me in ipairs(g or {})do if FIELD[me.layer] then field=true;break end end
   if field then last=g;break end
  end
  -- tree models are built once per (card, variant) and reported only by the build that made them:
  -- keep every tree/other upload of every group, not only the settled one
  local seen={};for _,me in ipairs(last or {})do seen[me]=true end
  last=last or {}
  for _,k in ipairs(order)do for _,me in ipairs(groups[k])do
   if (me.layer=='tree' or me.layer=='other' or me.layer=='canopy') and not seen[me] then seen[me]=true;last[#last+1]=me end
  end end
  local od=DIR..'/'..id
  os.execute('mkdir -p "'..od..'"')
  local n,sum=0,0
  local summary={}
  for _,me in ipairs(last or {})do
   n=n+1
   local v,ix=me.verts,me.map
   local nt=0
   local x0,y0,z0,x1,y1,z1=1e9,1e9,1e9,-1e9,-1e9,-1e9
   local out={}
   local nv=ix and #ix>0 and #ix or #v
   for k=1,nv-2,3 do
    local a,b,c
    if ix and #ix>0 then a,b,c=v[ix[k]],v[ix[k+1]],v[ix[k+2]] else a,b,c=v[k],v[k+1],v[k+2] end
    if a and b and c and a[1] and b[1] and c[1] then
     local p={a[1],a[2],a[3],b[1],b[2],b[3],c[1],c[2],c[3]}
     out[#out+1]=('%.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f'):format(p[1],p[2],p[3],p[4],p[5],p[6],p[7],p[8],p[9])
     nt=nt+1
     for q=1,9,3 do
      local X,Y,Z=p[q],p[q+1],p[q+2]
      if X<x0 then x0=X end;if X>x1 then x1=X end
      if Y<y0 then y0=Y end;if Y>y1 then y1=Y end
      if Z<z0 then z0=Z end;if Z>z1 then z1=Z end
     end
    end
   end
   sum=sum+nt
   local name=('%03d.%s.tri'):format(n,(tostring(me.layer):gsub('[^%w]','_')))
   local f=assert(io.open(od..'/'..name,'w'))
   f:write(('verts %d tris %d idx %d bbox %.3f %.3f %.3f %.3f %.3f %.3f\n'):format(#v,nt,ix and #ix or 0,x0,y0,z0,x1,y1,z1))
   f:write(table.concat(out,'\n'),'\n');f:close()
   summary[#summary+1]=('%s:%d'):format(me.layer,nt)
  end
  print(('[EM model]\t%s\t%d\t%d\t%s\t%s'):format(id,n,sum,settled and 'ok' or 'unsettled',table.concat(summary,',')))
 end
 love.event.quit()
end
