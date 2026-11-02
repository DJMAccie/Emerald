-- Stadium 2 models inside native Gen 3 battles
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

function M.battle()
 local Battle=require('src.core.game3.battle')
 local st=Battle._st
 if not (st and Battle.isActive and Battle.isActive()) then return nil end
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
  hitSerial={player=0,enemy=0},
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

-- Gen 3 battles never flip battle.animPlaying, so this starts StadiumModels' move animation.
local function performPendingMove(b)
 local pending=M.pendingMove
 M.pendingMove=nil
 if not (pending and pending.move and b and next(M.owned or {})~=nil) then
  return false
 end
 local stadiumMove=M.moveSelector(pending.move) or pending.move
 local key="\0move:"..tostring(stadiumMove)
 b.data=b.data or {}
 b.data.moves=b.data.moves or {}
 b.data.moves[key]={index=stadiumMove,number=stadiumMove}
 local hadName,hadPlaying,hadAttacker=b.animName,b.animPlaying,b.animAttackerIsPlayer
 b.animName,b.animPlaying,b.animAttackerIsPlayer=key,true,pending.player~=false
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

M.performPendingMove = performPendingMove

function M.update(dt)
 -- Log once whether the Stadium 2 effect runtime came up: a ROM-revision mismatch is silent.
 StadiumModels.reportEffectAvailability()
 local b=M.battle()
 if not b then
  if M.active then M.reset() end
  return false
 end
 M.active=true
 performPendingMove(b)
 local ok,err=pcall(StadiumModels.update,b,dt)
 if not ok then print('[Battle Art Gen 3] stadium update: '..tostring(err)) end
 return true
end

local contactMesh,contactImage
local function contactShadow(c,travel)
 if not V.require('Shadows').enabled() then return end
 if not contactImage then
  local data=love.image.newImageData(16,16)
  for y=0,15 do for x=0,15 do
   local d=math.sqrt(((x+.5-8)/8)^2+((y+.5-8)/8)^2)
   data:setPixel(x,y,.02,.025,.03,math.max(0,1-d*d)*.85)
  end end
  contactImage=love.graphics.newImage(data);contactImage:setFilter('linear','linear');data:release()
  contactMesh=R.newMesh({{-1,0,-1,0,0,1},{1,0,-1,1,0,1},{1,0,1,1,1,1},{-1,0,1,0,1,1}},{1,2,3,1,3,4})
 end
 if not contactMesh then return end
 M.contactDraws=(M.contactDraws or 0)+1
 M.lastContact=c
 local r=c.radius
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
