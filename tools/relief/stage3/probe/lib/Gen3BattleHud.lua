-- Window-resolution status cards. The native battle still calls its own HUD
-- at the correct intro/withdrawal moments; capture those calls, then paint only
-- those cards after the complete frame. Never bake modern text into an attack.
local V=...
local Theme=V.require('BattleTheme')
local Mode=V.require('ModernBattleUI')
local Options=V.require('Gen3BattleOptions')
local UI=Options.ui
local M={cards={},drawn=0,log=false,placedOn=false}
local Bounds=V.require('SpriteHeadBounds')
function M.install(stage)
 local uninstallOptions=Options.install(stage)
 local Health=require('src.core.game3.battle.healthbox')
 local Anim=require('src.core.game3.battle.anim')
 local Battle=require('src.core.game3.battle')
 local State=require('src.core.game3.battle.state')
 local Status=require('src.core.game3.summary_data')
 local Ui=require('src.core.game3.battle.ui')
 local Moves=require('src.core.game3.battle.moves')
 local Types=require('src.core.game3.battle.types')
 local Strings=require('src.core.Strings')
 local Coords=require('src.core.game3.battle.anim_coords')
 local Pokemon=require('src.core.game3.pokemon')
 local original,input=Health.draw,Ui.handleInput
 Ui.handleInput=function(keys)
  if Mode.enabled() and stage.active and Ui._mode=='menu' and M.menu and M.menu.mode=='menu' and keys and keys.wasPressed then
   local swap={up='left',down='right',left='up',right='down'}
   local proxy=setmetatable({},{__index=keys})
   proxy.wasPressed=function(_,key)return keys:wasPressed(swap[key]or key)end
   return input(proxy)
  end
  return input(keys)
 end
 local capturing=false
 local Chrome=require('src.ui.game3.battle_chrome')
 local panel=Chrome.drawPanel
 local underlay,underlayReady
 -- Preserve the actors before the native command window covers their feet.
 -- Erasing this strip used to cut a full-body back at y=112.
 Chrome.drawPanel=function(mode,...)
  if capturing and stage.active and (mode=='menu' or mode=='moves') then
   local G=love.graphics;local source=G.getCanvas()
   if source then
    underlay=underlay or G.newCanvas(240,48,{dpiscale=1})
    underlay:setFilter('nearest','nearest')
    G.push('all')
    local ok,err=pcall(function()
     G.setCanvas(underlay);G.origin();G.setShader();G.setScissor();G.setDepthMode()
     G.setBlendMode('replace','premultiplied');G.setColor(1,1,1,1)
     G.clear(0,0,0,0);G.draw(source,0,-112)
    end)
    G.pop()
    if not ok then error(err,0)end
    underlayReady=true
   end
  end
  return panel(mode,...)
 end
 function M.reset()
 -- the stock boxes' offsets end with the 3D battle: say so once, after
 if M.placedOn and not require('src.core.game3.battle').isActive() then
  M.placedOn=false
  if M.log then print('[BBE] after battle: stock box offsets released (native positions)') end
 end
 M.cards={};M.menu=nil;M.covered=false;capturing=false;underlayReady=false;Options.drawing=false
end
 function M.begin()M.reset();capturing=Mode.enabled();Options.drawing=true end
 function M.finish()
  Options.drawing=false
  capturing=false
  if not stage.active or not Mode.enabled() then return end
  for _,name in ipairs({'bag_menu','party_menu','summary_menu','help_system'})do
   local owner=package.loaded['src.ui.game3.'..name]
   if owner and owner.isOpen and owner.isOpen()then M.covered=true;return end
  end
  if Battle._phase~='command' or not Battle._st or Battle._st.safari then return end
  local mode=Ui._mode
  if mode~='menu' and mode~='moves' and mode~='target' then return end
  local Message=package.loaded['src.ui.game3.message']
  if Message and Message.open then return end
  local st=Battle._st;local id=Ui.activeBattler()
  local battler=id==0 and st.player or st.battlers and st.battlers[id]
  if not battler or not battler.mon then return end
  M.menu={mode=mode,index=mode=='menu' and Ui._menuIndex or Ui._moveIndex,entries={}}
  if mode=='menu' then
   for i,key in ipairs({'FIGHT','ITEMS','PKMN','RUN'})do M.menu.entries[i]={name=Strings(key),kind=({'fight','bag','pokemon','run'})[i]}end
  else
   for i=1,4 do
    local move=battler.mon.moves and battler.mon.moves[i]
    local def=move and Moves.get(move)
    M.menu.entries[i]={name=def and Moves.displayName(move) or '-',
     detail=def and (Strings(Types.get(def.type) or 'NORMAL')..'  '..tostring(battler.mon.pp and battler.mon.pp[i]or 0)..' PP')or ''}
   end
   if mode=='target' then
    local target=Ui.targetCursor();local b=st.battlers and st.battlers[target]
    M.menu.target=b and State.displayName(b)or ''
   end
  end
  -- Only command screens have their native bottom strip replaced. Messages,
  -- attack frames, party/bag, evolution and special prompts keep their owner.
  local G=love.graphics;G.push('all');G.origin();G.setShader();G.setScissor()
  G.setBlendMode('replace','premultiplied');G.setColor(0,0,0,0)
  G.rectangle('fill',0,112,240,48)
  if underlayReady then G.setColor(1,1,1,1);G.draw(underlay,0,112)end
  G.pop()
 end
 -- The stock boxes (the cream Emerald healthboxes): where the engine draws them
 -- and where the 3D battle puts them. A box and everything drawn in it move
 -- together through the engine's own opts.ox/oy (Healthbox.draw adds them to
 -- the box, its bar, its text and its EXP bar), so no engine table is edited.
 -- The offset is passed only while a 3D singles battle is on, and is worked
 -- out again on every draw, so nothing has to be restored.
 -- Measured on the screen of a stock (un-offset) frame: the HUD canvas is 4 px
 -- per unit and 960x640 px, centred. The stock boxes' visible cream edges are
 -- at x 13.75 / 136.25 and y 16.25 (foe) / 109.5 bottom (player), each box
 -- 90 units wide. Targets (canvas units): the foe 3 px in from the left and
 -- the top; the player's right edge 4 px from the canvas edge, its bottom 4 px
 -- above the text band (y 112).
 local OFFSET_FOE={x=-11,y=-13}
 local OFFSET_PLAYER={x=10,y=2}
 local EX,EY=OFFSET_FOE.x,OFFSET_FOE.y
 local PX,PY=OFFSET_PLAYER.x,OFFSET_PLAYER.y
 local onNow=false
 -- the opts a native box is drawn with: the caller's, plus the 3D offset
 local function placed(side,st,opts)
  -- M.noOffset: a QA seam, to draw the stock positions for a before/after pair
  local on=stage.active and st and not st.double and not st.safari and not M.noOffset and true or false
  if not on then
   if onNow then onNow=false;M.placedOn=false end
   return opts
  end
  local key=(side=='player' or side==0) and 'player' or 'enemy'
  local dx,dy=key=='player' and PX or EX,key=='player' and PY or EY
  if not onNow and M.log then
   onNow=true;M.placedOn=true
   print(string.format('[BBE] during 3D battle: offsets player (%d,%d) enemy (%d,%d)',PX,PY,EX,EY))
  end
  onNow=true;M.placedOn=true
  local o={}
  if opts then for k,v in pairs(opts)do o[k]=v end end
  o.ox=(o.ox or 0)+dx;o.oy=(o.oy or 0)+dy
  return o
 end
 if M.log then
  print('[BBE] before: offsets none (stock positions)')
 end
 Health.draw=function(side,battler,opts)
  if stage.active and UI.uiHidden('hud') then return end
  local st=Battle._st
  if not capturing or not stage.active or not st or st.safari or not battler then
   return original(side,battler,placed(side,st,opts))
  end
  local id=type(side)=='number' and side or side=='player' and 0 or 1
  local key=id==0 and 'player' or id==1 and 'enemy' or id
  local anim=Anim.stage and Anim.stage()
  local hb=anim and anim.healthbox and (anim.healthbox[id] or anim.healthbox[key])
  if hb and hb.visible==false then return end
  -- Preserve native level-up palette flashes until the high-resolution HUD
  -- has an equivalent effect, rather than silently dropping that feedback.
  if hb and hb.levelUpBlend then return original(side,battler,placed(side,st,opts))end
  local mon=battler.mon or {}
  local _,hp,maxHp=Anim.displayHpRatio(side,battler)
  local p=Anim.present and Anim.present(side)
  local status=Status.statusAilment({status=battler.status or mon.status or mon.status1,hp=mon.hp})
  local sp=battler.species or Pokemon.speciesOf(mon)
  local pic=Ui.battlerPic(id,battler,sp)
  local bounds=Bounds.get(pic and pic.image)
  local cx,cy=Ui.battlerSpriteCenter(id,sp,Coords.coords(st,id))
  local scale=p and p.scale or 1
  local sx,sy=scale*(p and p.sx or 1),scale*(p and p.sy or 1)
  local angle=p and p.rotation or 0
  local head=math.min((bounds[2]-32)*sy,(bounds[4]-32)*sy)
  if angle~=0 then head=-math.abs(math.sin(angle)*32*sx)-math.abs(math.cos(angle)*32*sy)end
  local r=require('src.render.Renderer'):frameRects()
  local anchor={r.uox+(cx+(p and p.ox or 0))*r.Ux,
   r.uoy+(cy+(p and p.oy or 0)+Ui.bounceOffset('mon',id)+head)*r.Uy}
  M.cards[id]={anchor=anchor,name=State.displayName(battler),level=p and p.displayLevel or mon.level or 1,
   hp=math.max(0,math.floor(hp or mon.hp or 0)),maximum=math.max(1,math.floor(maxHp or mon.maxHp or 1)),
   status=({'SLP','PSN','BRN','FRZ','PAR','PSN'})[status],gender=mon.gender,
   caught=id%2==1 and Health.shouldShowCaughtMarker(st,battler),
   exp=id%2==0 and Anim.displayExpRatio(side,battler) or nil,
   ox=((hb and hb.ox)or 0)+((opts and opts.ox)or 0),oy=((hb and hb.oy)or 0)+((opts and opts.oy)or 0)}
 end
 local function paint()
  local G=love.graphics;local w,h=G.getDimensions();local k=Options.hudScale(w,h)
  G.origin();G.scale(k);w,h=w/k,h/k
  local function label(value,x,y,width)return Theme.text(value,x,y,width,Options.ink())end
  -- The card body without the pointer (the same paper Options.card uses).
  local function plainCard(x,y,cw,ch,selected)
   local paper=Theme.paper
   if not UI.hudUsesColor()then Theme.paper={.07,.10,.13,.96}end
   local ok,err=pcall(Theme.panel,x,y,cw,ch,selected)
   Theme.paper=paper
   if not ok then error(err,0)end
  end
  local items={}
  for id=0,3 do local c=M.cards[id];if c then
   items[#items+1]={id=id,x=c.anchor[1]/k,y=c.anchor[2]/k,w=76,h=id%2==0 and 27 or 22}
  end end
  local layout=Theme.layoutStatusCards(items,w,h)
  -- The cards are FIXED in the HUD, not on the sprites: the foe's in the
  -- top-left corner, the player's against the right edge just above the text
  -- band (0.70 of the height). The canvas is centred in the window: 240 units
  -- wide at original scale, 320 when scaled. A corner card has no pointer (it
  -- would point at nothing), so neither card draws one.
  local og=Options.scale:get()=='og'
  local cw=og and 240 or 320
  local mg=4*h/160
  local x0=(w-cw)/2
  layout[1]={x=x0+mg,y=mg}
  layout[0]={x=x0+cw-mg-76,y=h*.7-mg-27}
  for id=0,3 do local c=M.cards[id];if c then
   local ally=id%2==0
   local cardH=ally and 27 or 22
   local x,y=layout[id].x,layout[id].y
   local selected=Ui._mode=='target' and Ui.targetCursor()==id
   if id==0 or id==1 then plainCard(x,y,76,cardH,selected)
   else Options.card(x,y,76,cardH,c.anchor[1]/k,selected) end
   label(c.name,x+3,y+2,49);label('Lv.'..c.level,x+53,y+2,21)
   label(c.status or 'HP',x+3,y+11,19)
   local fraction=math.min(1,c.hp/c.maximum)
   G.setColor(.20,.27,.29,1);G.rectangle('fill',x+24,y+12,48,3,1,1)
   G.setColor(Theme.hpColor(fraction));G.rectangle('fill',x+24,y+12,48*fraction,3,1,1)
   if ally then
    label(c.hp..' / '..c.maximum,x+24,y+16,48)
    G.setColor(.24,.57,.81,1);G.rectangle('fill',x+3,y+25,70*math.max(0,math.min(1,c.exp or 0)),1)
   end
  end end
  if M.menu and not UI.uiHidden('text') then
   local x,y=w-168,h-62
   local title=M.menu.target and ('TARGET: '..M.menu.target)or nil
   if title then label(title,x+4,y-10,152)end
   Theme.commandHub(x+82,y+29)
   for i,entry in ipairs(M.menu.entries)do
    local pos=M.menu.mode=='menu' and ({1,3,2,4})[i]or i
    local bx,by=x+3+(pos-1)%2*82,y+3+math.floor((pos-1)/2)*30
    local chosen=M.menu.index==i
    Theme.button(bx,by,76,22,entry.kind,chosen,pos%2==0)
    Theme.text(entry.name,bx+5,by+(entry.detail and 2 or 5),66,{1,1,.96,1},not entry.detail)
    if entry.detail then Theme.text(entry.detail,bx+3,by+12,70,{1,1,.96,1})end
   end
  end
 end
 V.mod.hooks:wrap('render.hud',function(inner,game,viewport)
  local result=inner(game,viewport)
  if stage.active and not M.covered and Battle.isActive() and (next(M.cards)~=nil or M.menu) then
   local G=love.graphics;G.push('all');G.setShader();G.setScissor()
   local ok,err=pcall(paint);G.pop()
   if not ok then error(err,0)end
   M.drawn=M.drawn+1
  end
  return result
 end)
 return function()
  Health.draw=original;Ui.handleInput=input;Chrome.drawPanel=panel;M.reset();uninstallOptions()
  if underlay then underlay:release();underlay=nil end
 end
end
return M
