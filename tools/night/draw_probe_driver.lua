-- POKEPORT_DRIVER: one frame's draw calls of a settled map, to find WHERE an instanced model stands (installed look and rewrite alike).
-- Wraps love.graphics.draw / drawInstanced / Shader:send / translate / applyTransform / push / pop / origin and logs, for every
-- Mesh draw whose vertex count is in EM_VC (comma list; empty = all meshes), the Shader:send values and transform ops since the last
-- draw. Engine-side observation only; no mod file read. QA identity only.
--   EM_MAPS="MAP x y" file (first line used), EM_OUT=<file>, EM_VC=4284,4080,...
return function(game)
 io.stdout:setvbuf('no')
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 require('src.core.game3.rng').Random=function()return 0 end
 require('src.core.game3.tileset_anim')._enabled=false
 love.window.setMode(1280,720,{resizable=true})
 -- instance data lives in meshes attached per-instance: remember every attachAttribute call from here on
 local att=setmetatable({},{__mode='k'})
 do
  local m0=love.graphics.newMesh(1,'points')
  local mi=getmetatable(m0).__index
  local oa=mi.attachAttribute
  mi.attachAttribute=function(self,name,other,step,...)
   local t=att[self];if not t then t={};att[self]=t end
   t[name]={name=name,mesh=other,step=step}
   return oa(self,name,other,step,...)
  end
 end
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(120)
 local P
 for _,ex in pairs(game.mods.exports or {})do
  if type(ex)=='table' and type(ex.gen3)=='table' and type(ex.gen3.probe)=='table' then P=ex.gen3.probe end
 end
 if not P then P=dofile(os.getenv('HOME')..'/Documents/Emerald/tools/rewrite/probe/old_adapter.lua')(game) end
 local Map=require('src.core.game3.map');local Player=require('src.core.game3.player')
 local id,mx,my
 for l in io.lines(os.getenv('EM_MAPS'))do id,mx,my=l:match('^(%S+)%s+(%d+)%s+(%d+)');if id then break end end
 mx,my=tonumber(mx),tonumber(my)
 assert(Map.load(nil,game,id,{x=mx,y=my,facing='down'}))
 pcall(Player.reset,mx,my,'down')
 U.wait(120)
 for _=1,900 do if P.active and P.active() then break end;U.wait(1) end
 P.setLevel(4)
 -- settle: builds stable
 local last,stable=-1,0
 for _=1,3000 do
  local b=P.builds();if b==last then stable=stable+1 else stable=0;last=b end
  if stable>=300 then break end
  U.wait(1)
 end
 local want
 if os.getenv('EM_VC') and os.getenv('EM_VC')~='' then want={};for v in os.getenv('EM_VC'):gmatch('%d+')do want[tonumber(v)]=true end end
 local out=assert(io.open(assert(os.getenv('EM_OUT')),'w'))
 local pending={}
 local seenInst={}
 local function fmt(v)
  if type(v)=='table' then local t={};for i=1,#v do t[i]=fmt(v[i]) end;return '{'..table.concat(t,',')..'}' end
  if type(v)=='number' then return ('%.3f'):format(v) end
  return tostring(v)
 end
 local g=love.graphics
 local orig={}
 local function wrap(name)
  local f=g[name];if not f then return end
  orig[name]=f
  g[name]=function(...)
   local a={...}
   if name=='draw' or name=='drawInstanced' then
    local d=a[1]
    if type(d)=='userdata' and d.getVertexCount then
     local okc,vc=pcall(d.getVertexCount,d)
     if okc and (not want or want[vc]) then
      local sh=g.getShader and g.getShader()
      out:write(('D %s vc=%s args=%s pend=%s\n'):format(name,tostring(vc),fmt({select(2,...)}),table.concat(pending,' ')))
      local inst=name=='drawInstanced' and att[d] and att[d].VertexInstanceOffset
      local sig
      if inst then local om0=inst.mesh;local nn=om0:getVertexCount();sig=tostring(vc)..':'..nn..':'..fmt({om0:getVertex(1)})..fmt({om0:getVertex(nn)}) end
      if inst and not seenInst[sig] then
       seenInst[sig]=true
       for _,a2 in pairs{inst} do
        local om=a2.mesh
        local okf,fmtt=pcall(om.getVertexFormat,om)
        local fl={};if okf then for _,f in ipairs(fmtt)do fl[#fl+1]=tostring(f[1])..':'..tostring(f[2])..':'..tostring(f[3]) end end
        out:write(('A vc=%s attr=%s step=%s fmt=%s n=%d\n'):format(tostring(vc),tostring(a2.name),tostring(a2.step),table.concat(fl,','),om:getVertexCount()))
        for i=1,om:getVertexCount() do
         local v={om:getVertex(i)}
         out:write(('I %s %d %s\n'):format(tostring(vc),i,fmt(v)))
        end
       end
      end
     end
    end
    pending={}
   else
    local t={};for i=1,select('#',...) do t[#t+1]=fmt(a[i]) end
    pending[#pending+1]=name..'('..table.concat(t,',')..')'
    if #pending>40 then table.remove(pending,1) end
   end
   return f(...)
  end
 end
 for _,n in ipairs({'draw','drawInstanced','translate','push','pop','origin','scale','rotate','applyTransform','replaceTransform'})do wrap(n) end
 -- Shader:send
 local sh=g.newShader('vec4 position(mat4 m,vec4 p){return m*p;} vec4 effect(vec4 c,Image t,vec2 u,vec2 s){return c;}')
 local mt=getmetatable(sh)
 local idx=mt.__index
 local osend=idx.send
 idx.send=function(self,name,...)
  local t={};for i=1,select('#',...) do t[#t+1]=fmt((select(i,...))) end
  pending[#pending+1]='send:'..tostring(name)..'='..table.concat(t,';'):sub(1,200)
  if #pending>40 then table.remove(pending,1) end
  return osend(self,name,...)
 end
 local ob=love.graphics.getCanvas
 U.wait(3)
 for n,f in pairs(orig)do g[n]=f end
 idx.send=osend
 out:close()
 print('[EM drawprobe] done',id)
 love.event.quit()
end
