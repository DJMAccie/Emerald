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
   for _,level in ipairs(os.getenv('EM_LEVELS') and dofile(os.getenv('EM_LEVELS')) or {4}) do
    if C then C.setLevel(level,game);C.yaw=tonumber(os.getenv('EM_YAW')) or 0
     -- EM_PITCH: free-camera pitch in radians (0.16 = low, 1.0..1.5 = nearly top-down); the interactive clamp is bypassed
     if os.getenv('EM_PITCH') then C.pitch=tonumber(os.getenv('EM_PITCH')) end end
    U.wait(tonumber(os.getenv('EM_WAIT')) or 150)
    print('[EM view]',case[1],'level',level,'active',C and tostring(C.active),'rendered',C and C.rendered)
    local okZ,Zoom=pcall(require,'src.render.Zoom'); local okR,Renderer=pcall(require,'src.render.Renderer')
    local scene=export and export.lib and export.lib.require('Gen3Scene')
    local ww,wh,flags=love.window.getMode(); print('[EM win]',ww,wh,'dpi',love.window.getDPIScale(),'px',love.graphics.getWidth(),love.graphics.getHeight(),'scene',scene and scene.renderWidth,scene and scene.renderHeight,'display',flags and flags.display)
    print('[EM cam]',C and C.level,C and C.pitch,C and C.yaw,'zoom',okZ and Zoom.scale and Zoom.scale(okR and Renderer:fitScale() or 1) or '?','fit',okR and Renderer:fitScale() or '?','dist',scene and scene.distance and scene.distance.radius,'player',Player.cellX,Player.cellY)
    EM_N=(EM_N or 0)+1
    local path=os.getenv('EM_INDEXED') and string.format('%s/b%03d.png',dir,EM_N) or dir..'/'..case[1]..'_'..level..'.png'
    local f=io.open(path) if f then f:close(); path=path:gsub('%.png$','_'..(os.time()%1000)..'.png') end
    U.shot(game,path)
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
        -- optional height column: base / floor height (EM_HEIGHTS=1)
        if os.getenv('EM_HEIGHTS') then
         row[#row+1]=string.format('b%03d%s',math.floor((d.base or 0)+.5),
          d.floor and string.format('/f%03d',math.floor((d.floor.height or 0)+.5)) or '/f---')
        end
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
