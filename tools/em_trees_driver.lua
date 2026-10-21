-- POKEPORT_DRIVER: tree census. For every cell of the given maps print how the scene classified it and how much of its
-- tile is foliage, so a script can list which tree path built each cell and which foliage cells no tree path claimed.
--   EM_MAPS=<file with "MAP x y" lines> EM_DUMP=<out.txt>  (QA identity only)
--   EM_DUMP_WAIT=<frames a spot builds, default 300>   EM_FULL=1: further spots until the whole map is in (as em_cells_driver)
--   EM_EARLY=<frames>: also dump the cells round the first spot that many frames after loading ('E' rows, the first-area
--   build) before the full dump ('F' rows), to see which cells change class when the build grows (window dependence)
-- row: stage map cx cy pair mid coll kind path gU gO base
--   path: how the scene built the cell: tree:<general|canopy|ftree|fortree|palm|other>, ashpine, obj:<ash|stacked|grove|line|plain>,
--   objtop, bank-grove, or '-' ; gU/gO: leaf-green share of the tile's under / over layer (0..1)
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local Scene=game.mods.exports.BATTLE_ART_VOXEL_FORK.lib.require('Gen3Scene')
 -- same pins as em_cells_driver: the Mirage Tower coin flip and the animated tiles repainting the atlas
 require('src.core.game3.rng').Random=function()return 0 end
 if os.getenv('EM_ANIM')~='1' then require('src.core.game3.tileset_anim')._enabled=false end
 local Map=require('src.core.game3.map')
 local f=assert(io.open(os.getenv('EM_DUMP'),'w'))
 local memo=setmetatable({},{__mode='k'})
 -- leaf-green share of one tile's pixels (opaque ones for the over layer), memoised per tileset and mid
 local function green(ts,mid,over)
  local data=over and ts.overImageData or ts.imageData
  if not (data and ts.midToSlot and ts.midToSlot[mid]) then return 0 end
  local m=memo[ts];if not m then m={};memo[ts]=m end
  local k=(over and 'o' or 'u')..mid
  if m[k]~=nil then return m[k] end
  local slot=ts.midToSlot[mid];local ox,oy=slot%ts.cols*16,math.floor(slot/ts.cols)*16
  local n,g=0,0
  for ly=0,15 do for lx=0,15 do
   local r,gg,b,a=data:getPixel(ox+lx,oy+ly)
   if (not over) or (a or 1)>.5 then
    n=n+1;if gg>r*1.1 and gg>b*1.05 then g=g+1 end
   end
  end end
  m[k]=n>0 and g/n or 0
  return m[k]
 end
 local function path(c)
  local s=c.shape or {}
  if s.kind=='tree' then
   local fam=s.fortree and 'fortree' or s.palmCrown and 'palm' or s.canopy and 'canopy' or s.planeOwn and 'ftree' or s.art and 'general' or 'other'
   return 'tree:'..fam
  end
  if s.ashPine then return 'ashpine' end
  local o=c.object
  if o then return 'obj:'..(o.ashTree and 'ash' or o.trees and 'stacked' or o.grove and 'grove' or o.line and 'line' or 'plain') end
  if c.objectTop then return 'objtop' end
  if s.bank and s.grove then return 'bank-grove' end
  return '-'
 end
 local function row(stage,id,cx,cy,c)
  local ts=c.ts
  local gu=ts and green(ts,c.mid,false) or 0
  local go=ts and green(ts,c.mid,true) or 0
  local p=path(c)
  if p=='-' and gu<.15 and go<.15 then return end
  f:write(('%s %s %d %d %s %03X %s %s %s %.2f %.2f %s\n'):format(stage,id,cx,cy,tostring(c.pair),c.mid or 0,tostring(c.collision),
   c.shape and c.shape.kind or '-',p,gu,go,tostring(c.base)))
 end
 local early=tonumber(os.getenv('EM_EARLY') or '') or 0
 for line in io.lines(os.getenv('EM_MAPS'))do
  local id,x,y=line:match('^(%S+)%s+(%d+)%s+(%d+)')
  if id then
   local wait=tonumber(os.getenv('EM_DUMP_WAIT') or '') or 300
   Map.load(nil,game,id,{x=tonumber(x),y=tonumber(y),facing='down'})
   local def
   if early>0 then
    U.wait(early)
    for cy=y-18,y+18 do for cx=x-18,x+18 do
     local c=Scene.debugRaw(cx,cy);if c then row('E',id,cx,cy,c) end
    end end
    U.wait(math.max(1,wait-early))
   else U.wait(wait) end
   def=Map.currentDef()
   if not (def and def.midLayout) then f:write(('SKIP %s no midLayout\n'):format(id))
   else
    local W,H=def.midLayout.width,def.midLayout.height
    local written,tried={}, {}
    for spot=1,(os.getenv('EM_FULL')=='1' and 12 or 1) do
     if spot>1 then
      local mx,my
      for cy=0,H-1 do for cx=0,W-1 do if not mx and not written[cx..':'..cy] and not tried[cx..':'..cy] then mx,my=cx,cy end end end
      if not mx then break end
      tried[mx..':'..my]=true
      Map.load(nil,game,id,{x=math.min(W-1,mx+24),y=math.min(H-1,my+24),facing='down'});U.wait(wait)
     end
     for cy=-3,H+2 do for cx=-4,W+3 do
      if not written[cx..':'..cy] then
       local c=Scene.debugRaw(cx,cy)
       if c then written[cx..':'..cy]=true;row('F',id,cx,cy,c) end
      end
     end end
    end
   end
  end
  f:flush()
 end
 f:close();love.event.quit()
end
