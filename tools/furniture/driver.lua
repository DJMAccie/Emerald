-- POKEPORT_DRIVER script: boot Emerald in a disposable QA identity, load a few
-- early maps with Battle Art's Gen 3 camera at several levels, and capture
-- frames to SHOT_DIR.  Run from the engine root (needs tests/drivers/util.lua).
return function(game)
 local U=dofile('tests/drivers/util.lua')
 local dir=assert(os.getenv('SHOT_DIR'))
 assert(love.filesystem.getIdentity()=='pokemon-love2d-rseqa','refusing a non-QA identity')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_LITTLEROOT_TOWN',x=10,y=10,facing='down'}})
 U.wait(90)
 local exports=game.mods and game.mods.exports or {}
 local export=exports.BATTLE_ART_VOXEL_FORK
 print('[EM QA] battle art export:',export and 'yes' or 'NO')
 local ns=export and (export.gen3 or export.firered)
 local C=ns and ns.camera
 print('[EM QA] gen3 camera:',C and 'yes' or 'NO')
 local Map=require('src.core.game3.map');local Player=require('src.core.game3.player')
 local cases=os.getenv('EM_CASES') and dofile(os.getenv('EM_CASES')) or {{'EM_LITTLEROOT_TOWN',10,10}}
 for _,case in ipairs(cases) do
  local ok,err=pcall(function() assert(Map.load(nil,game,case[1],{x=case[2],y=case[3],facing='down'})) end)
  print('[EM view] load',case[1],ok,err or '')
  if ok then
   pcall(Player.reset,case[2],case[3],'down')
   -- QA only: a case may carry decor={{decorId,x,y},...}: those decorations are put on the map as
   -- the game's own decorating does (secret bases, the player's room); x,y is the bottom-left cell
   if os.getenv('EM_NO_SCRIPTS') then local okS,Sp=pcall(require,'src.core.game3.scripting.space'); if okS and Sp then Sp.runOnFrame=function() end end end
   if case.decor then
    local okD,err=pcall(function()
     local SB=require('src.core.game3.rse.secret_base');local D=require('src.core.game3.rse.decoration')
     local g=SB.fieldGrid()
     for _,d in ipairs(case.decor)do D.showOnMap(g,d[2],d[3],d[1])end
    end)
    print('[EM view] decor',okD,err or '')
   end
   -- QA only: dolls={{decorId,x,y},...} puts sprite decorations (dolls, cushions) into the current
   -- base's saved slots and spawns them as the game does (they only appear on a desk or a mat)
   if case.dolls then
    local okD,err=pcall(function()
     local SB=require('src.core.game3.rse.secret_base');local D=require('src.core.game3.rse.decoration')
     local sess=game.session;local b=SB.base(sess,0)
     for i,d in ipairs(case.dolls)do b.decorations[i]=d[1];b.decorationPositions[i]=D.encodePos(d[2],d[3])end
     local n,sp=SB.initDecorationSprites(0,sess);print('[EM view] dolls spawned',n)
    end)
    print('[EM view] dolls',okD,err or '')
   end
   -- QA only: as after using Flash, so a dark cave shows its 3D scene (EM_FLASH=1)
   if os.getenv('EM_FLASH') and game.session then game.session.flashLevel=0 end
   if os.getenv('EM_HIDE_NPCS') then local O=require('src.core.game3.objects'); O.forDraw=function() return {} end; local okT,T=pcall(require,'src.core.game3.trainer_sight'); if okT then T.check=function() return false end; T.checkLineOfSight=function() return false end end; local okS,Sp=pcall(require,'src.core.game3.scripting.space'); if okS and Sp then Sp.runOnFrame=function() end end end
   for _,level in ipairs(os.getenv('EM_LEVELS') and dofile(os.getenv('EM_LEVELS')) or {4}) do
    if C then C.setLevel(level,game);C.yaw=tonumber(os.getenv('EM_YAW')) or 0 end
    U.wait(tonumber(os.getenv('EM_WAIT')) or 150)
    -- a room's entry line ("This is the third floor.") covers the shot: tap it away with B (A would talk to whoever the player faces and open a shop menu that sticks for the rest of the run)
    if os.getenv('EM_HIDE_NPCS') then for _=1,(tonumber(os.getenv('EM_TAPS')) or 3) do pcall(U.tap,game,'b');U.wait(12) end end
    print('[EM view]',case[1],'level',level,'active',C and tostring(C.active),'rendered',C and C.rendered)
    local okZ,Zoom=pcall(require,'src.render.Zoom'); local okR,Renderer=pcall(require,'src.render.Renderer')
    local scene=export and export.lib and export.lib.require('Gen3Scene')
    local ww,wh,flags=love.window.getMode(); print('[EM win]',ww,wh,'dpi',love.window.getDPIScale(),'px',love.graphics.getWidth(),love.graphics.getHeight(),'scene',scene and scene.renderWidth,scene and scene.renderHeight,'display',flags and flags.display)
    print('[EM cam]',C and C.level,C and C.pitch,C and C.yaw,'zoom',okZ and Zoom.scale and Zoom.scale(okR and Renderer:fitScale() or 1) or '?','fit',okR and Renderer:fitScale() or '?','dist',scene and scene.distance and scene.distance.radius,'player',Player.cellX,Player.cellY)
    EM_N=(EM_N or 0)+1
    local path=os.getenv('EM_INDEXED') and string.format('%s/b%03d.png',dir,EM_N) or dir..'/'..case[1]..'_'..level..'.png'
    local f=io.open(path) if f then f:close(); path=path:gsub('%.png$','_'..(os.time()%1000)..'.png') end
    U.shot(game,path)
    if os.getenv('EM_AUDIT') and scene and scene.debugCell then
     -- the scene's window follows the player lazily: wait until it is centred on this
     -- case's spot before scanning (a stale window audited the previous spot's cells again)
     do
      local Col=package.loaded['src.core.game3.collision'];local L=Col and Col._mapDef and Col._mapDef.midLayout
      local W,Hh=L and L.width or 0,L and L.height or 0
      local px,py=case[2],case[3]
      local function has(x,y) return x<0 or y<0 or x>=W or y>=Hh or scene.debugCell(x,y)~=nil end
      for _=1,60 do
       if has(px-20,py) and has(px+20,py) and has(px,py-20) and has(px,py+20) then break end
       U.wait(15)
      end
     end
     local cx0,cy0,cx1,cy1,cn=999,999,-1,-1,0
     for y=0,140 do for x=0,140 do
      local d=scene.debugCell(x,y)
      if d then cn=cn+1;cx0=math.min(cx0,x);cy0=math.min(cy0,y);cx1=math.max(cx1,x);cy1=math.max(cy1,y) end
      if d and d.prop then print(string.format('[AUD] %s %d %d %03X %s',case[1],x,y,d.mid or 0,d.prop)) end
      if d and not d.prop and (d.collision or 0)==0 and (d.kind==nil or d.kind=='flat') and not d.stairs and not d.gym and not d.civic and os.getenv('EM_AUDIT')=='walk' then print(string.format('[WALK] %s %d %d %03X',case[1],x,y,d.mid or 0)) end
      if d and not d.prop and (d.collision or 0)~=0 and (d.kind==nil or d.kind=='flat') and not d.stairs and not d.gym and not d.civic then print(string.format('[FLAT] %s %d %d %03X',case[1],x,y,d.mid or 0)) end
     end end
     print(string.format('[COV] %s %d %d %d %d %d',case[1],cx0,cy0,cx1,cy1,cn))
    end
    if case[4] and scene and scene.debugCell then
     -- one line per map row of the building's box: kind letter, column signature
     local L={roof='R',wall='W',flat='.',tree='T',cliff='C',water='~',ledge='L',fence='F',sign='S',shrub='h',grass='g',flowers='f',rock='r',steps='s',awning='A',caveWall='V',roomWall='M'}
     for y=case[5]-1,case[7]+1 do
      local row={}
      for x=case[4]-1,case[6]+1 do
       local d=scene.debugCell(x,y)
       if not d then row[#row+1]='??????'
       else
        local k=d.prop and 'P' or d.gym and 'G' or d.civic and 'c' or d.stairs and 's' or L[d.kind or ''] or '?'
        local col=d.col and string.format('%d%d%s',math.min(9,d.col.roofs),math.min(9,d.col.walls),string.char(97+(d.col.group or 0)%26)) or '---'
        row[#row+1]=string.format('%s%s%s%03X',k,(d.collision or 0)~=0 and '#' or '.',col,d.mid or 0)
       end
      end
      print(string.format('[BLD %d] y=%d %s',EM_N,y,table.concat(row,' ')))
     end
    end
   end
  end
 end
 print('[EM QA] done')
 love.event.quit()
end
