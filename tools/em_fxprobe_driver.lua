-- Probe: can this install build Stadium 2 move EFFECTS, and do the Pokemon
-- models play their real move animations? Answers from the live importer, so
-- the answer is about the user's own caches rather than about the source.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,
   start={map='EM_ROUTE101',8,10,x=8,y=10,facing='down'}})
 U.wait(90)
 local ex=assert(game.mods.exports.STADIUM2_IMPORTER,'no STADIUM2_IMPORTER export')
 local function report(label,ok,value)
  print(string.format('[FX] %-28s %s %s',label,tostring(ok),tostring(value)))
 end
 for _,name in ipairs({'modelsEnabled','battleEnabled','betaBattleFxEnabled',
                       'battleFxSendOutEnabled','battleFxParticlesEnabled'}) do
  local fn=ex[name]
  report(name,type(fn)=='function',type(fn)=='function' and tostring(fn()) or 'MISSING')
 end
 report('newBattleFxPlayer',type(ex.newBattleFxPlayer)=='function','')
 -- Read the FX specials through the importer's own cache reader, so a failure
 -- names its reason instead of collapsing into a nil.
 do
  local imp=ex.cache or (game.mods.exports.STADIUM2_IMPORTER.cache)
  local Cache=imp
  if Cache and Cache.readSpecial then
   for _,name in ipairs({'battle_fx_rom','battle_fx_trig','battle_fx_resources','egg'}) do
    local okR,blob,code,msg=pcall(Cache.readSpecial,name)
    report('  readSpecial '..name,okR and blob~=nil,
      ('bytes=%s code=%s msg=%s'):format(
        type(blob)=='string' and #blob or tostring(blob),tostring(code),tostring(msg)))
   end
  else
   report('  Cache.readSpecial',false,'not exported')
  end
 end
 -- Reach the cache module through the mod loader, which is how the importer
 -- itself gets it, and ask for the FX specials by name with reasons.
 do
  local function tryRequire(name)
   local ok,m=pcall(require,name)
   return ok and type(m)=='table' and m or nil
  end
  local Cache=tryRequire('mods.STADIUM2_IMPORTER.lib.cache')
  if Cache and Cache.readSpecial then
   for _,name in ipairs({'battle_fx_rom','battle_fx_trig','battle_fx_resources','egg'}) do
    local okR,a,b,c=pcall(Cache.readSpecial,name)
    report('  cache:'..name,okR and a~=nil,
      ('bytes=%s code=%s msg=%s'):format(type(a)=='string' and #a or tostring(a),
        tostring(b),tostring(c)))
   end
  else
   report('  loader cache module',false,tostring(Cache))
  end
 end
 local cat,catErr=ex.battleFxCatalog and ex.battleFxCatalog()
 report('battleFxCatalog',cat~=nil,catErr or (cat and ('moves='..tostring(cat.moves and #cat.moves))))
 -- The exact call the catalog makes, with its own error text.
 do
  local okC,Cache=pcall(require,'mods.STADIUM2_IMPORTER.lib.cache')
  local okR,Rom=pcall(require,'mods.STADIUM2_IMPORTER.lib.stadium2_battle_fx_rom')
  if okC and okR then
   local overlay=Cache.readSpecial('battle_fx_rom')
   local trig=Cache.readSpecial('battle_fx_trig')
   report('  overlay bytes',overlay~=nil,type(overlay)=='string' and #overlay or tostring(overlay))
   report('  trig bytes',trig~=nil,type(trig)=='string' and #trig or tostring(trig))
   -- Dump the program table the decoder will read: an effect-program table
   -- is a run of VRAM pointers, so garbage here means the slice is wrong.
   if type(overlay)=='string' then
    local function u32(off)
     local a,b,c,d=overlay:byte(off+1,off+4)
     if not a then return nil end
     return ((a*256+b)*256+c)*256+d
    end
    local rows={}
    for i=0,5 do
     local off=Rom.romOffset(Rom.PROGRAM_TABLE+i*4)
     local v=u32(off)
     rows[#rows+1]=('0x%08X'):format(v or 0)
    end
    report('  program table bytes',true,'TABLE_OFF=0x'..('%X'):format(Rom.romOffset(Rom.PROGRAM_TABLE))..' '..table.concat(rows,' '))
    local o0=u32(Rom.romOffset(Rom.PROGRAM_TABLE))
    report('  program0 in range',o0~=nil and o0>=1 and o0<=#overlay,
      ('ptr=0x%08X sliceLen=%d'):format(o0 or 0,#overlay))
   end
   local okCat,c1,c2=pcall(Rom.catalog,overlay,trig)
   report('  Rom.catalog',okCat and c1~=nil,
     ('ret=%s err1=%s err2=%s'):format(tostring(c1),tostring(c2),tostring(okCat and '' or c1)))
   if okCat and type(c1)=='table' then
    local n=0; for _ in pairs(c1.moves or {}) do n=n+1 end
    report('  catalog moves',true,n)
   end
  end
 end
 if cat and cat.moves then
  local n=0
  for _ in pairs(cat.moves) do n=n+1 end
  report('  catalog move count',true,n)
 end
 local res,resErr=ex.battleFxResources and ex.battleFxResources(85)   -- Thunderbolt
 report('battleFxResources(85)',res~=nil,resErr or (res and 'ok'))
 local player,perr=ex.newBattleFxPlayer and ex.newBattleFxPlayer({})
 report('newBattleFxPlayer()',player~=nil,perr or (player and 'ok'))
 if player then
  local methods={}
  for k,v in pairs(player) do if type(v)=='function' then methods[#methods+1]=k end end
  table.sort(methods)
  report('  player methods',true,table.concat(methods,','))
 end
 -- the model side: does the instance expose move animation, and does move 85
 -- resolve to a real clip rather than the proxy?
 local inst,ierr=ex.models.newInstance(25,'normal',{})   -- Pikachu
 report('models.newInstance(25)',inst~=nil,ierr or 'ok')
 if inst then
  report('  playMove present',type(inst.playMove)=='function','')
  report('  playContext present',type(inst.playContext)=='function','')
  local mdl=inst.model and inst.model()
  if type(mdl)=='table' then
   local n=0
   for _ in pairs(mdl.moveAnim or {}) do n=n+1 end
   report('  model.moveAnim size',true,n)
   report('  model.anims count',true,#(mdl.anims or {}))
   local shown=0
   for mv=1,8 do
    local v=mdl.moveAnim and mdl.moveAnim[mv]
    if v~=nil then report('    moveAnim['..mv..']',true,tostring(v)); shown=shown+1 end
   end
   report('  moveAnim[85]',mdl.moveAnim~=nil,tostring(mdl.moveAnim and mdl.moveAnim[85]))
   -- what does the instance's own playMove do with a real move?
   local okP,errP=pcall(inst.playMove,inst,85,false)
   report('  playMove(85)',okP,errP)
   local st=inst.animationState and inst.animationState()
   report('  animationState',st~=nil,st and ('index='..tostring(st.index)..' frames?') or '')
  else
   report('  inst.model()',false,type(mdl))
  end
  report('  contextSelector(idle)',true,tostring(inst.contextSelector and inst.contextSelector('idle')))
  report('  contextSelector(attack)',true,tostring(inst.contextSelector and inst.contextSelector('attack')))
  if inst.release then pcall(inst.release,inst) end
 end
 love.event.quit()
end
