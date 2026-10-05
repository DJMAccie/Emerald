-- Verification set for the pending Gen3Terrain thickness/cap + Gen3Objects.shade edits.
-- 23 regression views from the brief (section 1) + Mt. Chimney, Route 114, Route 111, Rustboro.
-- Coordinates flagged BLOCKED in world.json are deliberate: they frame the subject.
return {
 {'EM_MT_CHIMNEY',20,23},                  -- terrain band end (wedge seen)
 {'EM_ROUTE114',30,53},                    -- odd slope strips
 {'EM_ROUTE114',20,40},
 {'EM_ROUTE111',32,84},
 {'EM_ROUTE111',21,70},
 {'EM_RUSTBORO_CITY',14,22},               -- lamp posts (shade() target)
 {'EM_ROUTE120',12,56},                    -- boulders
 {'EM_MOSSDEEP_CITY',4,7},                 -- sea boulders
 {'EM_MOSSDEEP_CITY',24,19},               -- tree cluster
 {'EM_ROUTE104',8,42},                     -- fences, sea rock
 {'EM_ROUTE104',6,19},                     -- flower shop must stay a building
 {'EM_BATTLE_FRONTIER_OUTSIDE_EAST',40,22},-- Battle Palace
 {'EM_BATTLE_FRONTIER_OUTSIDE_EAST',4,8},  -- frontier ground must not be sky
 {'EM_SOOTOPOLIS_CITY',31,26},             -- crater rock
 {'EM_SOOTOPOLIS_CITY',10,50},             -- rim
 {'EM_ROUTE126',40,52},                    -- rock island
 {'EM_ROUTE112',19,29},
 {'EM_LAVARIDGE_TOWN',10,10},
 {'EM_DEWFORD_TOWN',12,8},                 -- grove
 {'EM_LILYCOVE_CITY',22,8},                -- railing
 {'EM_SLATEPORT_CITY',4,20},               -- fence
 {'EM_MAUVILLE_CITY',30,6},
 {'EM_ROUTE119',20,70},                    -- grey trees (3.1)
 {'EM_SOOTOPOLIS_CITY',30,28},
 {'EM_FORTREE_CITY',20,10},
}
