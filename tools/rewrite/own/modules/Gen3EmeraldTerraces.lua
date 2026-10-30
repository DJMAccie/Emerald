-- LIFTED OWN MODULE from lib/Gen3EmeraldTerraces.lua (~/Documents/battle-art-notquiteog at Gen3EmeraldTerraces, 2026-10-29) -- Petya's code, crosses after simcheck; see docs/PROVENANCE.md.
-- Do not edit except where this spec says so; it is the field's data/dependency module.

-- Authored terrace levels for Hoenn maps whose relief cannot be read from the
-- cartridge alone. One row per terrace: {anchorX, anchorY, level}; the anchor
-- is the first cell of the walkable component in reading order and the level
-- is in courses above the water (Gen3Elevation turns a course into M.COURSE
-- world units and pins the component that contains the anchor).
--
-- Data from Gen2Recomped-DramaticShapes (data/gen3_terraces.lua), MIT License,
-- Copyright (c) 2026 DramaticShape, modified by UNDERdecodedHD. Re-keyed to
-- gen1recomp map ids.
-- DISABLED: the scene has no terrace-face or under-deck geometry yet, so
-- pinned levels leave raised paths as bare slabs (Sootopolis) and striped
-- ramps (Route 112). Set enabled=true once that machinery exists.
-- 2026-10-05: the scene now builds terrace faces (Gen3Mass walls, terrace
-- skirts), so maps are switched on one at a time as each is checked.
local M={COURSE=16,enabled=true,on={},  -- Sootopolis OFF: unanchored areas (the lakeside grass) borrow a high neighbour and stand as green walls (morning check 2026-10-06)
 -- generated stair platforms (Gen3StairTerraces), per map once checked in game.
 -- Safari Zone NE stays off: its cliffs already carry the height and the
 -- platforms opened sky slivers beside them (2026-10-06)
 onStairs={EM_BATTLE_FRONTIER_OUTSIDE_EAST=true,EM_SAFARI_ZONE_SOUTHEAST=true,EM_SOOTOPOLIS_CITY=true,EM_MT_CHIMNEY=true,EM_JAGGED_PASS=true,EM_MT_PYRE_EXTERIOR=true,EM_MT_PYRE_SUMMIT=true},maps={
 EM_FORTREE_CITY={
  {32,2,1},{10,3,1},{17,3,1},{25,3,1},{12,4,0},{19,4,0},{27,4,0},{10,5,0},{25,5,0},{13,8,0},{29,8,0},{12,13,1},{37,13,1}
 },
 EM_ROUTE112={
  {26,6,0},{23,19,3},{21,20,3},{20,21,3},{22,21,3},{24,22,3},{30,22,3},{22,23,3},{34,23,3},{33,25,3},{11,26,3},{21,27,3},{28,27,3},{22,28,3},{19,29,3},{34,29,3},{16,30,3},{35,31,3},{34,33,3},{15,34,3},{35,35,0},{34,36,0},{35,41,0},{31,42,0},{14,43,0},{26,43,0},{36,43,0},{16,44,0},{6,46,0},{11,46,0},{18,54,0}
 },
 EM_SOOTOPOLIS_CITY={
  {16,0,6},{18,0,6},{39,0,5},{55,0,4},{13,2,6},{34,2,5},{43,2,5},{25,3,5},{38,3,5},{7,5,7},{15,5,6},{37,5,5},{41,5,5},{57,5,4},{47,6,5},{9,7,7},{5,8,7},{43,8,5},{7,9,6},{27,9,4},{19,10,5},{40,11,4},{45,11,4},{56,11,4},{59,11,4},{0,12,5},{10,12,5},{23,12,3},{37,12,3},{3,13,5},{18,13,4},{25,13,3},{53,13,4},{58,13,4},{5,14,4},{12,14,4},{19,15,4},{22,15,2},{36,15,3},{24,16,2},{31,16,1},{39,16,3},{42,16,3},{35,17,1},{16,18,3},{47,18,3},{59,18,4},{7,21,3},{52,21,3},{9,22,3},{20,22,2},{55,22,2},{5,23,2},{44,23,2},{51,23,3},{12,24,2},{0,25,2},{18,25,1},{21,25,1},{55,26,2},{0,29,2},{3,30,2},{7,30,2},{15,30,2},{27,32,0},{42,32,1},{54,32,2},{58,32,1},{4,34,2},{53,34,1},{15,35,1},{2,36,2},{5,36,2},{19,36,0},{40,37,0},{57,37,1},{0,38,0},{2,38,0},{17,38,0},{50,48,0}
 },
}}
return M
