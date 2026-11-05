-- Boot Emerald in the QA identity, give the player a Gen 1 starter, wait for
-- the battle models, start a wild battle against a Gen 1 species and
-- capture frames through the intro and the fight menu.
return function(game)
 local U=dofile('tests/drivers/util.lua')
 local dir=assert(os.getenv('SHOT_DIR'))
 assert((love.filesystem.getIdentity()=='pokemon-love2d-rseqa' or love.filesystem.getIdentity():match('^pokemon%-love2d%-rseqa%-p%d$')),'refusing a non-QA identity')
 do
  local okV,Ver=pcall(require,'src.core.Version')
  local okC,C=pcall(require,'src.mods.Gen3Compat')
  print('[BT] engine='..tostring(okV and Ver.engine)..' wrapPictures='..tostring(okC and type(C.wrapPictures))
   ..' Gen3Compat@'..tostring(okC and debug.getinfo(C.applyMerged,'S').source))
 end
 -- EM_TRAPPIC=1: report every reassignment of Pokemon.frontPic/backPic with
 -- the writer's call stack (diagnoses wrapper chains growing at runtime).
 if os.getenv('EM_TRAPPIC') then
  local Pokemon=require('src.core.game3.pokemon')
  local shadow={frontPic=rawget(Pokemon,'frontPic'),backPic=rawget(Pokemon,'backPic')}
  local writes=0
  rawset(Pokemon,'frontPic',nil);rawset(Pokemon,'backPic',nil)
  setmetatable(Pokemon,{
   __index=function(_,k) return shadow[k] end,
   __newindex=function(t,k,v)
    if k=='frontPic' or k=='backPic' then
     writes=writes+1
     local i=type(v)=='function' and debug.getinfo(v,'S')
     print('[BT trap] '..k..' write #'..writes..' -> '..(i and (i.short_src..':'..i.linedefined) or type(v)))
     if writes<=8 then print(debug.traceback('',2)) end
     shadow[k]=v
    else rawset(t,k,v) end
   end})
 end
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,start={map='EM_ROUTE101',8,10,x=8,y=10,facing='down'}})
 U.wait(90)
 local Party=require('src.core.game3.party')
 -- EM_PLAYER_SPECIES / EM_FOE_SPECIES are national numbers; the cart's own
 -- species ids differ for Hoenn (Treecko is 277 internally).
 local Pokemon=require('src.core.game3.pokemon')
 local function internal(nat) return Pokemon.speciesFromNational(tonumber(nat)) or tonumber(nat) end
 local playerSp=internal(os.getenv('EM_PLAYER_SPECIES') or 4)
 local foeSp=internal(os.getenv('EM_FOE_SPECIES') or 25)
 print('[BT] species internal ids: player',playerSp,'foe',foeSp)
 local code,mon=Party.giveMonToPlayer(game.session,playerSp,12)
 print('[BT] give mon:',code,mon and mon.species)
 local ex=game.mods.exports.emerald_3d_voxel_mod
 for i=1,120 do
  U.wait(30)
  local st=ex and ex.status()
  if st and (st.state=='ready' or st.state=='failed') then print('[BT] importer',st.state,'after',i*0.5,'s') break end
 end
 local Bridge=require('src.core.game3.battle_bridge')
 local ok,err=pcall(Bridge.startWild,game.mods,game,{species=foeSp,level=8},{})
 print('[BT] startWild:',ok,err)
 local Battle=require('src.core.game3.battle')
 local Models=game.mods.exports.emerald_3d_voxel_mod.lib.require('Gen3StadiumModels')
 -- EM_DEEPTRACE=1: print the call chain the first time the Lua stack gets
 -- unusually deep, since a stack-overflow traceback hides the loop itself.
 if os.getenv('EM_DEEPTRACE') then
  local fired=false
  debug.sethook(function()
   if not fired and debug.getinfo(140,'S') then
    fired=true
    debug.sethook()
    local lines={}
    for lv=2,400 do
     local i=debug.getinfo(lv,'Slnf')
     if not i then break end
     local ups={}
     if lv<=24 then
      for u=1,12 do
       local n,v=debug.getupvalue(i.func,u)
       if not n then break end
       if type(v)=='function' then local vi=debug.getinfo(v,'S');ups[#ups+1]=n..'='..tostring(v)..'@'..vi.short_src..':'..vi.linedefined end
      end
     end
     lines[#lines+1]=string.format('%3d %s:%s %s fn=%s def=%d %s',lv,i.short_src,tostring(i.currentline),tostring(i.name),tostring(i.func),i.linedefined,table.concat(ups,' '))
    end
    print('[BT deep] full stack\n'..table.concat(lines,'\n'))
   end
  end,'c')
 end
 local frames=tonumber(os.getenv('EM_BATTLE_FRAMES') or 900)
 for t=1,frames do
  U.wait(1)
  if t%60==0 then
   local s=Models.status()
   if t==120 or t==300 then
    local lib=game.mods.exports.emerald_3d_voxel_mod.lib
    local BA=lib.require('BattleSpecies'); local SM=lib.require('StadiumModels')
    local b=Models.battle()
    print('[BT dbg] battle?',b~=nil,'player',b and b.player and b.player.species,'enemy',b and b.enemy and b.enemy.species,
     'speciesFor',b and tostring(BA.speciesFor(b.player)),tostring(b and BA.speciesFor(b.enemy)),'shiny',b and tostring(pcall(BA.isShiny,b.player)),
     'installed',tostring(SM.installed()),'active',tostring(SM.active()))
    local info=debug.getinfo(BA.speciesFor,'S'); print('[BT dbg] speciesFor from',info.short_src,info.linedefined,'probe280',tostring(BA.speciesFor({mon={species=280}})),'probe406',tostring(BA.speciesFor({mon={species=406}})))
    local Gen=lib.require('Generation'); local okN,natv=pcall(require('src.core.game3.pokemon').national,b and b.player and b.player.species)
    print('[BT dbg] Generation.number',tostring(Gen.number()),'isGen3',tostring(Gen.isGen3()),'national(player)',tostring(okN),tostring(natv),'speciesMax',tostring(game.mods.exports.emerald_3d_voxel_mod.speciesMax and game.mods.exports.emerald_3d_voxel_mod.speciesMax()))
    local ex=game.mods.exports.emerald_3d_voxel_mod
    print('[BT dbg] importer modelsEnabled',tostring(ex.modelsEnabled()),'battleEnabled',tostring(ex.battleEnabled()),'available',tostring(ex.available()))
    local okI,inst=pcall(function() return ex.models.newInstance(b and b.enemy and b.enemy.species or 25,'normal',{}) end)
    print('[BT dbg] newInstance enemy species:',okI, okI and (inst and 'ok' or 'nil') or tostring(inst))
   end
   print(string.format('[BT] t=%d active=%s owned=%s/%s provider=%s sides=%s/%s battle=%s',t,tostring(s.active),tostring(s.owned.player),tostring(s.owned.enemy),tostring(s.provider.active),tostring(s.provider.sides.player),tostring(s.provider.sides.enemy),tostring(Battle.isActive())))
  end
  if os.getenv('EM_ORBIT') and (t==400 or t==640) then
   local cam=game.mods.exports.emerald_3d_voxel_mod.lib.require('Gen3Battle').camera
   if cam then cam.yaw=(cam.yaw+tonumber(os.getenv('EM_ORBIT')))%(math.pi*2) print('[BT] orbit yaw',cam.yaw) end
  end
  if t==150 or t==190 or t==240 or t==480 or t==720 then U.shot(game,dir..'/battle_'..t..'.png') end
  if t>300 and t%90==0 then U.tap(game,'a') end
 end
 love.event.quit()
end
