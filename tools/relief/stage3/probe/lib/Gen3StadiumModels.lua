-- Stadium 2 models inside native Gen 3 battles (FireRed/LeafGreen/Emerald).
--
-- The Gen 1/2 staged battle (lib/BattleScene.lua) already places optional
-- provider models through lib/StadiumModels.lua. On Gen 3 the native battle
-- engine owns the screen and Battle Art only swaps the backdrop for its voxel
-- plate (lib/Gen3Battle.lua), so the models are drawn into that plate here,
-- and the native 2D battler picture is withheld for any side a model owns.
--
-- StadiumModels expects a Gen 1/2 battle table; this module presents the
-- game3 battle state through a small adapter: `player`/`enemy` battlers (the
-- game3 records already carry `species`, `mon`, `fainted`), a one-frame
-- `animPlaying` pulse when the native engine launches a move animation, and
-- the faint hook. Species ids 1-251 are national numbers on every Gen 3 cart,
-- and Stadium 2 has no models beyond #251, so Hoenn natives keep their sprites.
local V=...
local M={owned={},drawing=false,active=false}
local StadiumModels=V.require('StadiumModels')
local BattleArt=V.require('BattleArt')
local Mat4=V.require('Mat4')
local R=V.require('Voxel3D')
local adapter

local function battler(st,id)
 local State=require('src.core.game3.battle.state')
 return State.battler(st,id)
end

-- The battle-like view StadiumModels reads. Rebuilt from the live game3
-- state every call; the table identity is kept so sync() sees one battle.
function M.battle()
 local Battle=require('src.core.game3.battle')
 local st=Battle._st
 if not (st and Battle.isActive and Battle.isActive()) then return nil end
 -- Move numbers, for the model's move animation.
 --
 -- StadiumModels decides which move animation a model plays by looking the
 -- running animation up in `battle.data.moves` and reading `def.index` off
 -- the row. On Gen 1/2 that table is the battle's own move list, keyed by the
 -- animation name the engine put in `battle.animName` ("TACKLE", "EMBER").
 -- The Gen 3 engine has no such table on the battle state -- `data.moves` is
 -- nil there -- so the lookup silently found nothing and every move fell back
 -- to `playContext("attack")`, the generic swing. The move animations were
 -- imported, wired, and never reached.
 --
 -- Gen 3 does have the mapping, in its own move table, by the same names:
 -- `Moves.numForName("TACKLE")` answers the cart's move number. So publish a
 -- row per animation name on demand and cache it.
 --
 -- `index` is the move number StadiumModels reads. The importer's own
 -- `moveSelector` then applies the Stadium 2 ceiling: moves past #251 (every
 -- Hoenn move, and the later Kanto ones) proxy by category, which is the
 -- honest limit of a Stadium 2 source and is exactly what the importer's move
 -- table is built to answer.
 local moveRows={}
 local function moveRow(name)
  local hit=moveRows[name]
  if hit~=nil then return hit or nil end
  local okM,Moves=pcall(require,'src.core.game3.battle.moves')
  local num=okM and Moves.numForName and Moves.numForName(name)
  num=tonumber(num)
  if num then
   moveRows[name]={index=num,number=num}
   return moveRows[name]
  end
  moveRows[name]=false
  return nil
 end

 -- The names this mod's own driver and the engine's own scripts use, warmed
 -- once so a battle never pays the move-table build mid-animation. Unknown
 -- names are still resolved on demand; this is a cache, not a whitelist.
 local WARM_MOVES={
  "TACKLE","SCRATCH","POUND","GROWL","TAIL_WHIP","EMBER","WATER_GUN",
  "VINE_WHIP","THUNDER_SHOCK","QUICK_ATTACK","LEER","STRING_SHOT","ABSORB",
  "GUST","SAND_ATTACK","CONFUSION","BITE","HEADBUTT","FLAME_WHEEL","FLY",
  "DIG","SURF","THUNDERBOLT","FLAMETHROWER","ICE_BEAM","HYPER_BEAM","BODY_SLAM",
  "DOUBLE_EDGE","SOLAR_BEAM","EARTHQUAKE","PSYCHIC","SHADOW_BALL","SLUDGE_BOMB",
 }

 adapter=adapter or {
  data={moves=setmetatable({},{
    __index=function(t,k) local row=moveRow(k); if row then rawset(t,k,row) end; return row end,
  }),pokemon={}},
  picFx={},
  -- Rises once per damaging hit on each side (the engine's hit flash); see
  -- M.install. StadiumModels plays the hit clip on a rise.
  hitSerial={player=0,enemy=0},
  -- The native send-out drives the model: hidden until the ball opens
  -- (presentation.visible), then growing with the sprite's own scale.
  growInScale=function(self,b)
   local id=b==self.enemy and 1 or 0
   local ok,pres=pcall(require('src.core.game3.battle.anim').present,id)
   if not (ok and type(pres)=='table') then return nil end
   if pres.visible==false then return 0 end
   local scale=tonumber(pres.scale) or 1
   if scale<.999 then return math.max(0,scale) end
   return nil
  end,
  fxFaintActive=function(_,b) return b and b.fainted or false end,
 }
 adapter.player=battler(st,0)
 adapter.enemy=battler(st,1)
 -- BattleArt.speciesFor turns a numeric Gen 3 species into its Gen 1/2 name;
 -- StadiumModels then resolves that name through battle.data.pokemon, so
 -- publish the national number under it (1-251 are national on every cart).
 -- BattleArt.speciesFor answers the national number (or its Gen 1/2 name);
 -- StadiumModels resolves a name through battle.data.pokemon, so publish the
 -- national number under it (1-386 national on every Gen 3 cart).
 local Pokemon=require('src.core.game3.pokemon')
 for _,name in ipairs(WARM_MOVES)do moveRow(name) end
 for _,bt in pairs({adapter.player,adapter.enemy})do
  local sp=tonumber(bt.species or (bt.mon and bt.mon.species))
  local key=BattleArt.speciesFor(bt)
  if sp and type(key)=='string' then
   local okN,nat=pcall(Pokemon.national,sp)
   nat=okN and tonumber(nat) or (sp<=251 and sp or nil)
   if nat then adapter.data.pokemon[key]={dex=nat,index=nat} end
  end
 end
 return adapter
end

-- The provider's move table covers #1-251 (the Stadium 2 move list). A Gen 3
-- move beyond it plays the animation of a stand-in move of the same category,
-- which the Gen 3 engine decides by type: Tackle, Ember or Growl.
--
-- A CATEGORY stand-in rather than a nearest-neighbour: Stadium 2 has no data
-- for a Hoenn move at all, so the honest answer is "a physical move plays a
-- physical move's animation", not a guess at which one it resembles.
local PROXY={physical=33,special=52,status=45}
function M.moveSelector(move)
 move=tonumber(move)
 if not move then return nil end
 if move<=251 then return move end
 local okM,Moves=pcall(require,'src.core.game3.battle.moves')
 local okR,row=okM and pcall(Moves.get,move)
 local cat=okR and type(row)=='table' and row.category or 'physical'
 return PROXY[cat] or PROXY.physical
end

function M.reset()
 StadiumModels.release()
 adapter=nil;M.owned={};M.active=false;M.pendingMove=nil
end

-- Perform the move animation StadiumModels plays on the rising edge of a
-- move animation.
--
-- WHY THIS EXISTS. StadiumModels watches `battle.animPlaying` flip, which is
-- how the Gen 1/2 battle states announce a move animation. The Gen 3 battle
-- has no such field: it launches its effects through `Anim.launchMove`, the
-- hook M.install wraps, and it never puts a move animation on the battle
-- state. So on Emerald the edge never rose, `StadiumModels` never reached its
-- `playMove` branch, and EVERY move in every fight played the generic
-- `attack` context -- a swing with no relation to the move. The model
-- animations were imported and wired, and nothing ever asked for them.
--
-- The hook already carries exactly what is needed: the move number and which
-- side threw it. So publish it to StadiumModels in the shape it reads -- a
-- battle whose `data.moves` holds one row, named as `animName`, with the
-- move's Stadium number and the attacker's side -- and clear the latch.
--
-- The number is translated through the same proxy the provider's own table
-- uses, so a Hoenn move plays its category's clip instead of nothing.
local function performPendingMove(b)
 local pending=M.pendingMove
 M.pendingMove=nil
 if not (pending and pending.move and b and next(M.owned or {})~=nil) then
  return false
 end
 local stadiumMove=M.moveSelector(pending.move) or pending.move
 -- StadiumModels resolves the running animation through battle.data.moves.
 -- This adapter already answers that lookup by NAME for the engine's own
 -- names; here the number is known outright, so publish it under a private
 -- key and point animName at it for the length of the call.
 local key="\0move:"..tostring(stadiumMove)
 b.data=b.data or {}
 b.data.moves=b.data.moves or {}
 b.data.moves[key]={index=stadiumMove,number=stadiumMove}
 local hadName,hadPlaying,hadAttacker=b.animName,b.animPlaying,b.animAttackerIsPlayer
 b.animName,b.animPlaying,b.animAttackerIsPlayer=key,true,pending.player~=false
 -- StadiumModels only fires on a RISING edge, so lower it first: two moves in
 -- consecutive frames must both play.
 StadiumModels.animWasPlaying=false
 local ok,err=pcall(StadiumModels.update,b,0)
 b.animName,b.animPlaying,b.animAttackerIsPlayer=hadName,hadPlaying,hadAttacker
 if not ok then
  print('[Battle Art Gen 3] move animation: '..tostring(err))
  return false
 end
 M.lastMove={move=pending.move,stadiumMove=stadiumMove,player=pending.player~=false}
 return true
end

-- Exposed so the handoff can be exercised without a battle (tests/
-- gen3_move_animation_test.lua): it takes the adapter's own battle view.
M.performPendingMove = performPendingMove

-- Called once per frame from the Gen 3 battle stage, before the scene draws.
function M.update(dt)
 -- Once per session, before anything else: record (and log) whether the
 -- Stadium 2 effect runtime could come up at all. A ROM-revision mismatch is
 -- otherwise completely silent -- the effects simply do not happen.
 StadiumModels.reportEffectAvailability()
 local b=M.battle()
 if not b then
  if M.active then M.reset() end
  return false
 end
 M.active=true
 -- The battle's own move cue first, so the model starts the move on the frame
 -- the engine starts its effect rather than one frame later.
 performPendingMove(b)
 local ok,err=pcall(StadiumModels.update,b,dt)
 if not ok then print('[Battle Art Gen 3] stadium update: '..tostring(err)) end
 return true
end

-- Contact shadow under a model: a soft dark ellipse on the ground at the
-- model's own ground height. Same mechanism as ActorContact (a radial alpha
-- image on a flat quad, depth-tested, no depth write), but sized from the
-- model's footprint and offset a little along the sun's travel direction, so
-- it reads as a shadow on the ground rather than a fixed blob. Drawn before
-- the model: the model's opaque pixels overwrite it where they stand over it.
local contactMesh,contactImage
local function contactShadow(c,travel)
 if not V.require('Shadows').enabled() then return end
 if not contactImage then
  local data=love.image.newImageData(16,16)
  for y=0,15 do for x=0,15 do
   local d=math.sqrt(((x+.5-8)/8)^2+((y+.5-8)/8)^2)
   -- Peak alpha is higher than the 35% a plain black would need: the effect
   -- pass darkens much less than its alpha suggests (measured in QA).
   data:setPixel(x,y,.02,.025,.03,math.max(0,1-d*d)*.85)
  end end
  contactImage=love.graphics.newImage(data);contactImage:setFilter('linear','linear');data:release()
  contactMesh=R.newMesh({{-1,0,-1,0,0,1},{1,0,-1,1,0,1},{1,0,1,1,1,1},{-1,0,1,0,1,1}},{1,2,3,1,3,4})
 end
 if not contactMesh then return end
 M.contactDraws=(M.contactDraws or 0)+1
 M.lastContact=c
 local r=c.radius
 -- The light's travel direction, flattened to the ground, sets the offset.
 local lx,lz=(travel and travel[1] or 0),(travel and travel[3] or 0)
 local len=math.sqrt(lx*lx+lz*lz)
 local ox,oz=0,0
 if len>1e-6 then ox,oz=lx/len*r*.2,lz/len*r*.2 end
 R.withEffect('alpha',function()
  love.graphics.setColor(1,1,1,1)
  love.graphics.setDepthMode('always',false)
  R.draw(contactMesh,contactImage,Mat4.mul(Mat4.translate(c.x+ox,(c.y or 0)+.08,c.z+oz),
    Mat4.scale(r,1,r*.8)))
 end)
end

-- Arena points along the battle camera's yaw: the player's model close to
-- the camera, the foe further out, both on the scene ground.
-- The hour's light on a model is half the world's: at dusk a white Pokemon
-- (Absol, Lugia) read peach-pink under the full tint, and at night a model
-- at the world's darkness is hard to see in a fight.
local function modelTint(t)
 if not t then return {1,1,1} end
 return {1-(1-(t[1] or 1))*.5,1-(1-(t[2] or 1))*.5,1-(1-(t[3] or 1))*.5}
end
function M.draw(game,cam,cx,cz,groundAt)
 local b=M.active and M.battle()
 if not b then M.owned={} return end
 local yaw=cam.arenaYaw or cam.yaw or 0
 local dx,dz=math.sin(yaw),-math.cos(yaw)
 local arena={player={cx-dx*18,cz-dz*18},enemy={cx+dx*26,cz+dz*26}}
 local groundY=groundAt(cx,cz)
 local ok,placements=pcall(StadiumModels.placements,arena,groundY,{player={},enemy={}},b)
 if not ok then print('[Battle Art Gen 3] stadium placements: '..tostring(placements));M.owned={} return end
 local context={
  viewProjection=R.vp,
  view=Mat4.lookAt(R.eye,R.focus,{0,1,0}),
  tint=modelTint(R.tint),
  light={direction={0.35,0.7,0.62},ambient={0.46,0.46,0.46},diffuse={0.72,0.72,0.72}},
 }
 local owned={}
 for _,pass in ipairs({'opaque','additive'})do
  -- Every contact shadow goes down before any model, so a model is never
  -- under another model's shadow.
  if pass=='opaque' then
   for _,placement in pairs(placements)do
    if placement.contact then contactShadow(placement.contact,context.light.direction) end
   end
  end
  for side,placement in pairs(placements)do
   if StadiumModels.draw(placement,context,pass) then owned[side]=true end
  end
 end
 M.owned=owned
end

-- Hooks into the native battle: move launches and faints drive the model
-- animations. The picture functions are deliberately NOT wrapped: other mods
-- (Kanto in Motion's FRLG bridge) re-wrap Pokemon.frontPic/backPic on later
-- events and capture whatever they find as upstream, so two wrappers end up
-- calling each other. Owned sprites are hidden per frame through the engine's
-- own presentation flag instead (M.hideNative).
function M.install()
 local Anim=require('src.core.game3.battle.anim')
 local launch,faint=Anim.launchMove,Anim.faintMon
 Anim.launchMove=function(moveId,opts)
  if M.active then M.pendingMove={move=tonumber(moveId),player=(opts and opts.attackerSide)=='player'} end
  return launch(moveId,opts)
 end
 Anim.faintMon=function(key,opts)
  local b=M.active and adapter
  if b then
   local side=(key=='player' or key==0) and 'player' or ((key=='enemy' or key==1) and 'enemy' or nil)
   local bt=side and b[side]
   if bt then bt.fainted=true end
  end
  return faint(key,opts)
 end
 -- The hit flash the engine plays on a damaging hit (AnimSeq's hitfx step).
 -- Status-only moves never reach it, and send-out does not either.
 local blink=Anim.blinkMon
 Anim.blinkMon=function(key,opts)
  local b=M.active and adapter
  if b then
   local side=(key=='player' or key==0) and 'player' or ((key=='enemy' or key==1) and 'enemy' or nil)
   if side then b.hitSerial[side]=b.hitSerial[side]+1 end
  end
  return blink(key,opts)
 end
 return function()
  Anim.launchMove,Anim.faintMon,Anim.blinkMon=launch,faint,blink
  M.reset()
 end
end

-- Withhold the native 2D battler picture of every side a model owns for the
-- duration of one native draw: draw_mon_sprite skips a presentation marked
-- battlerInvisible. Returns a closure that restores the previous flags.
function M.hideNative()
 if not (M.active and adapter) then return function() end end
 local Anim=require('src.core.game3.battle.anim')
 local restore={}
 for side,id in pairs({player=0,enemy=1})do
  if M.owned[side] then
   local ok,pres=pcall(Anim.present,id)
   if ok and type(pres)=='table' then
    restore[#restore+1]={pres,pres.battlerInvisible}
    pres.battlerInvisible=true
   end
  end
 end
 return function()
  for _,r in ipairs(restore)do r[1].battlerInvisible=r[2] end
 end
end

function M.status()
 return {active=M.active,owned=M.owned,provider=StadiumModels.status(),
  pendingMove=M.pendingMove,lastMove=M.lastMove,
  contactDraws=M.contactDraws,lastContact=M.lastContact}
end
return M
