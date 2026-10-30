-- NEUTRAL FIELD GATE DRIVER (verifier side, Emerald repo): P2 gate for EMERALD_3D and any mod exposing
-- docs/specs/ProbeContract.md (mod.exports.<id>.gen3.probe.field).
--   EM_MAPS=<file "MAP x y" lines> EM_DUMP=<out.txt> EM_KIND=pins|cls QA identity only.
-- Same formats as tools/elevation/qa/em_pins_driver.lua / em_blocks_driver.lua, read through the probe:
--   pins: PIN / COUNT / GRID rows (height in 8 px units, base 36, '.' no cell)
--   cls : CLS (counts + rock/unclassified/faceHigh/massNotFlat) / FACEHIGH / MASSDIFF / GRID rows
return function(game)
 local U=dofile('tests/drivers/util.lua')
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 require('src.core.game3.rng').Random=function()return 0 end
 require('src.core.game3.tileset_anim')._enabled=false
 local Map=require('src.core.game3.map')
 local probe
 for _,ex in pairs(game.mods.exports or {})do
  if type(ex)=='table' and type(ex.gen3)=='table' and type(ex.gen3.probe)=='table' and type(ex.gen3.probe.field)=='function' then probe=ex.gen3.probe end
 end
 assert(probe,'no mod exports gen3.probe.field')
 local KIND=os.getenv('EM_KIND') or 'pins'
 local f=assert(io.open(os.getenv('EM_DUMP'),'w'))
 local chars='0123456789abcdefghijklmnopqrstuvwxyz'
 local function gchar(h)if h==nil then return '.' end return string.sub(chars,math.min(35,math.floor(h/8+.5))+1,math.min(35,math.floor(h/8+.5))+1)end
 for line in io.lines(os.getenv('EM_MAPS'))do
  local id,x,y=line:match('^(%S+)%s+(%d+)%s+(%d+)')
  if id then
   if not os.getenv('EM_NOLOAD') then Map.load(nil,game,id,{x=tonumber(x),y=tonumber(y),facing='down'});U.wait(120) end
   local rows=probe.field(id)
   local def=Map.currentDef()
   if not (rows and def and def.midLayout) then f:write('SKIP '..id..'\n') else
    local W,H=def.midLayout.width,def.midLayout.height
    if KIND=='pins' then
     local ok,bad=0,0
     for yy=0,H-1 do for xx=0,W-1 do
      local c=rows[yy] and rows[yy][xx]
      if c and c.pin~=nil then
       local want=c.pin*16;local got=c.height
       if got==want then ok=ok+1 else bad=bad+1 end
       f:write(('PIN %s %d %d want=%d got=%s group=nil kind=%s %s\n'):format(id,xx,yy,want,tostring(got),tostring(c.kind),got==want and 'ok' or 'DIFF'))
      end
     end end
     f:write(('COUNT %s ok=%d diff=%d size=%dx%d\n'):format(id,ok,bad,W,H))
    else
     local cnt={PLATEAU=0,FACE=0,MASS=0,WATER=0,DECK=0,OTHER=0,unclassified=0}
     local rock,faceHigh,massDiff=0,0,0
     local cells={}
     for yy=0,H-1 do for xx=0,W-1 do local c=rows[yy] and rows[yy][xx]
      if c then
       if c.cls then cnt[c.cls]=(cnt[c.cls]or 0)+1 else cnt.unclassified=cnt.unclassified+1 end
       if c.cls=='FACE' or c.cls=='MASS' then rock=rock+1 end
       cells[yy*W+xx]=c
      end
     end end
     for yy=0,H-1 do for xx=0,W-1 do local c=rows[yy] and rows[yy][xx]
      if c and c.cls=='FACE' then
       local mx
       for dy=-4,4 do for dx=-4,4 do local n=rows[yy+dy] and rows[yy+dy][xx+dx]
        if n and n.cls~='FACE' and n.cls~='MASS' and n.cls~='OTHER' and n.height then mx=math.max(mx or n.height,n.height) end
       end end
       if mx and c.height and c.height>mx+.01 then faceHigh=faceHigh+1;f:write(('FACEHIGH %s %d %d h=%s max=%s\n'):format(id,xx,yy,tostring(c.height),tostring(mx))) end
      elseif c and c.cls=='MASS' and c.pin~=nil then
       local want=c.pin*16
       if c.height~=want then massDiff=massDiff+1;f:write(('MASSDIFF %s %d %d h=%s pin=%s\n'):format(id,xx,yy,tostring(c.height),tostring(want))) end
      end
     end end
     f:write(('CLS %s PLATEAU=%d FACE=%d MASS=%d WATER=%d DECK=%d OTHER=%d rock=%d unclassified=%d faceHigh=%d massNotFlat=%d size=%dx%d\n')
       :format(id,cnt.PLATEAU,cnt.FACE,cnt.MASS,cnt.WATER,cnt.DECK,cnt.OTHER,rock,cnt.unclassified,faceHigh,massDiff,W,H))
    end
    for yy=0,H-1 do
     local row={}
     for xx=0,W-1 do local c=rows[yy] and rows[yy][xx];row[#row+1]=gchar(c and c.height) end
     f:write(('GRID %s %02d %s\n'):format(id,yy,table.concat(row)))
    end
   end
  end
 end
 f:close();love.event.quit()
end
