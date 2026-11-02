-- Auditable source-consumer inventory
local V=...
local M={}
local support={ [3]={} }
local function set(gen,keys,status,consumer,detail)
 for key in keys:gmatch('%S+')do
  support[gen][key]={status=status,consumer=consumer,detail=detail}
 end
end
for _,row in ipairs(V.require('SettingsCatalog'))do
 support[3][row.key]={status='missing',consumer=false,detail='No complete native generation adapter audited for this option.'}
end
set(3,'sceneryProps','implemented','lib/TreePresentation.lua; lib/NativeTreeArt.lua; lib/Gen2Rocks.lua; lib/Gen3Cave.lua; lib/Gen3Outdoor.lua','Native solid rocks/bushes or source-art cutouts. Terrain/collision unchanged; actors, grass and flowers remain sprites.')
set(3,'battleCamera','partial','lib/BattleCam.lua','Native Gen3/FRLG fights stage through Gen3Battle, whose camera is engine-owned; the director is not wired on that path.')
set(3,'fireredCamera','implemented','lib/Gen3Integration.lua; lib/Gen3Scene.lua','Native field camera and rotated directional intent.')
set(3,'battles','implemented','lib/Gen3Battle.lua','Shared 3D-BTL control, preserving native actors/attacks/UI and legacy FireRed OFF preferences.')
set(3,'fireredBattleStage','alias','lib/Gen3Battle.lua','Legacy saved key, migrated to the shared 3D-BTL control.')
set(3,'aa daytime worldFill communitySky tiltshift','implemented','lib/Gen3SceneOptions.lua; lib/Gen3Scene.lua','Native scene supersampling, day clock/light/sky, underlay and postprocess.')
set(3,'invertY','implemented','lib/Gen3Integration.lua: look','Shared preference changes mouse and right-stick vertical look.')
set(3,'curve grid shadowQuality','implemented','lib/Voxel3D.lua; lib/ShadowMap.lua','Native scene uses the shared geometry and shadow passes.')
set(3,'renderDistance','implemented','lib/Gen3Scene.lua: prepare','Native world refresh/build budget and horizon fade.')
set(3,'water','implemented','lib/WaterSurfacePass.lua; lib/Gen3Scene.lua','Native surfable cells use shared FULL/SKY/OFF shaders with flat fallback.')
set(3,'battleUi textboxFill','implemented','lib/Gen3BattleOptions.lua; lib/Gen3BattleHud.lua','Staged native HUD/text visibility, panel fill and matching ink; unrelated menus keep native ownership.')
set(3,'hudColor hudScale','partial','lib/Gen3BattleOptions.lua; lib/Gen3BattleHud.lua','Live modern status-card palette/scale; original native HUD art remains engine-owned.')
set(3,'modernBattleUI','implemented','lib/Gen3BattleHud.lua','Native battle status cards and command overlay.')
set(3,'battleArt frontAnimatedSet backAnimatedSet playerView duplicateFix frontFlip','implemented','lib/NativeBattleArt.lua; lib/BattleArt.lua','Native displayed-battler read seam retains PID/OT/shiny identity for all four slots; unusual forms/substitutes/ghosts keep native fallback.')
set(3,'arenaFill','partial','lib/Gen3BattleBackdrop.lua; lib/Gen3Scene.lua','WHITE/GEN6/PNG and native location routing; missing image fails open. BLUE still needs a compatible Stadium provider.')
set(3,'backdropOffset bossBg','implemented','lib/Gen3BattleBackdrop.lua; lib/Gen3Scene.lua','Native location/boss identity, source-pixel crop and frozen battle day phase, using installed optional art.')
set(3,'spriteLight','partial','lib/Gen3SpriteLight.lua','World day tint multiplies native sprite flash/fade in staged battles; native UI-plane actors do not yet cast world shadows.')
set(3,'playerArtSet playerAnimatedSet trainerArtSet','implemented','lib/Gen3TrainerArt.lua; lib/AnimatedBattleArt.lua','Selected native opponent fronts and player five-frame send-out sheets. Missing user art and scripted trainer roles retain native pictures.')
set(3,'interfaceSprites interfaceScaling','implemented','lib/NativeInterfaceArt.lua','Native Summary/Pokedex scoped draw; animation-wide FIT/FULL and mon-aware Summary shininess. Other native screens keep their own art.')
set(3,'surfaceArtwork','implemented','lib/Gen3Scene.lua; lib/Voxel3D.lua','Native-palette surface grain on scenery only; camera-stable world coordinates, distance filtering and unchanged actor/UI art.')
set(3,'atmos communityForest','implemented','lib/NativeAtmosphere.lua; lib/ForestAtmos.lua','Native forest identity, real world dimensions, depth-aware rays and fog; shared atmosphere clock and OFF control.')
set(3,'towerFog towerFogSpeed towerFogThickness','implemented','lib/NativeAtmosphere.lua; lib/TowerGraveMist.lua','Native tower fog and rolling ground banks use the shared visibility, thickness and continuously integrated speed controls.')
set(3,'communityCaves communityCaveDetails communityTower towerDetails','partial','lib/NativeAtmosphere.lua','Native atmosphere controls are live; complete Gen1 specialty geometry and decorative props remain incomplete.')
set(3,'weather','implemented','lib/Weather.lua; lib/Gen3Scene.lua','Optional deterministic outdoor rain/snow/fog/storms on the world canvas, below UI. Does not change battle weather rules.')
set(3,'spatialUpscale','implemented','lib/SpatialUpscale.lua; lib/AntiAlias.lua','Shared full-precision FSR 1 EASU/RCAS postprocess; native resolution UI. Shader availability checked; no temporal/frame generation.')
set(3,'stadiumCircle','provider',false,'Requires the optional compatible Stadium scene provider; no provider means no consumer.')
function M.inventory(gen)
 local out={}
 for _,row in ipairs(V.require('SettingsCatalog'))do
  local state=assert(support[gen] and support[gen][row.key],'unknown option support')
  out[#out+1]={key=row.key,label=row.label,module=row.module,generation=gen,
   status=state.status,consumer=state.consumer,detail=state.detail,verification='source audit'}
 end
 return out
end
function M.rows(schema,gen)
 local out,seen={},{}
 for _,row in ipairs(schema)do out[#out+1]=row;seen[row.key]=true end
 for _,row in ipairs(M.inventory(gen))do
  if not seen[row.key] and row.status~='alias' then
   local labels={implemented='SUPPORTED',partial='PARTIAL',missing='UNAVAILABLE',
    not_applicable='OTHER ENGINE',provider='PROVIDER'}
   local label=labels[row.status]
   out[#out+1]={key=row.key,label=row.label,type='choice',readOnly=true,
    supportOnly=true,unavailable=label,help=row.detail}
  end
 end
 return out
end
return M
