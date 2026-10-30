-- Native layouts are immutable base cells plus sparse public overrides.
-- Fingerprint those dependencies, not thousands of reconstructed cells per frame.
local M={}
function M.key(regions,x0,z0,x1,z1,tiles,cam)
 if cam and cam.replay then return nil end -- replay snapshots can edit cells in place
 local parts={x0,z0,x1,z1}
 for _,r in ipairs(regions)do
  local l=r.def.midLayout
  if not(l and type(l.cells)=='table' and type(l.overrides)=='table')then return nil end
  local ts=tiles[l.pair]
  local whole=(x0==0 and z0==0 and x1==0 and z1==0)
  local touches=whole or (r.x<=x1 and r.x+r.w-1>=x0 and r.y<=z1 and r.y+r.h-1>=z0)
  if touches then
   if whole then parts[#parts+1]=table.concat({tostring(l),tostring(l.cells),l.pair,r.x,r.y,r.w,r.h},':')
   else parts[#parts+1]=table.concat({tostring(l),tostring(l.cells),l.pair,r.x,r.y,r.w,r.h,tostring(ts),tostring(ts and ts.imageData),tostring(ts and ts.overImageData)},':') end
  parts[#parts+1]=table.concat(l.borderMids or {},',')
  local keys={};for k in pairs(l.overrides)do keys[#keys+1]=k end;table.sort(keys)
  for _,k in ipairs(keys)do local c=l.overrides[k];parts[#parts+1]=table.concat({k,c.mid or 0,c.coll or 255,c.elev or 0},',')end
  end
 end
 -- The battle's GROUND is part of the key: a fight stages on one patch of
 -- map, and the culled set -- which building is cleared, which neighbour is
 -- in range -- is a fact about that patch.
 --
 -- Its YAW deliberately is NOT. Geometry is world-space: nothing build()
 -- produces moves, changes shape or changes count when the eye swings around
 -- it. Keying on the yaw therefore did not rebuild anything that had changed
 -- -- it rebuilt the whole cell range, every frame, for a camera doing what
 -- this mod's battle camera does by design (a slow drift, plus every cut in
 -- lib/BattleShots.lua, plus the player's own orbit). At the battle's own
 -- radius that is a full-map rebuild per frame, which is where the 3 fps
 -- came from: the fight was not slow, the scene was being rebuilt under it.
 if cam and cam.battle then parts[#parts+1]=table.concat({'battle',cam.center[1],cam.center[2]},':')end
 return table.concat(parts,';')
end
return M
