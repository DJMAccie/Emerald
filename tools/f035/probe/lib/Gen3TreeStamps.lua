-- Which tiles draw a tree and how each is stood up (Emerald 3D task 11: one upright tree for every tree tile).
-- A cell knows its tree from its OWN tile: never from its neighbours, a connected group, a colour threshold or the
-- order the cells are visited, so a build window or a repeat build cannot turn a grove into a mass and back.
-- FAMILIES is the cut-over list: a tileset left out keeps the older paths (Gen3Objects groves, Gen3Scene canopy);
-- drop one line to revert that tileset.
local M={}
M.FAMILIES={dewford=true,lavaridge=true}

-- One-cell trees drawn as a crown over a trunk, packed edge to edge (Dewford's and Routes 105-107's groves):
--   crown: blocked tile, the crown drawn in its over layer. A tree stands in every cell of it, as the cartridge draws the grove.
--   foot : blocked tile, the trunk and its shadow in the under layer (the tree at the front of a column).
--   over : walkable tiles with the crown of the tree to the south drawn over their floor; that 3D tree holds the crown, so the
--          flat art goes only where a stamped tree stands south of the cell (claim below); the map's edge hedge keeps its drawing.
M.NARROW={
 dewford={crown=0x243,foot=0x23A,over={0x239,0x219}},
}

-- The General mountain's round trees (Route 112's terraces, the ash bushes of Routes 111/113, Lavaridge town):
-- a 16 px bush whose crown is drawn in the OVER layer, so the cartridge lets the player walk behind it, and
-- whose bottom tile (trunk and shadow) is the blocked cell one row SOUTH. Read as rock, their green printed on
-- the terrace walls and capped the terraces with leaves (F040/G2); read as walk-under canopies, the crowns hung
-- 26 px in the air with no trunk under them (F035/F032, ghost card G1: "flat green crowns in the sky").
--   base: blocked tiles drawn as the bush; the tree stands in that cell, its art the crown tile's rows above its own
--   top : the walkable crown tile drawn over the floor of the cell above the base (the crown-above, 0x210/0x211)
--   over: walkable crown tiles claimed by the tree south of them: no flat crown art and no walk-under slab
M.GENERAL={
 lavaridge={top=0x210,base={[0x210]=true,[0x211]=true,[0x218]=true,[0x21A]=true,[0x203]=true,[0x3B8]=true},over={0x210,0x211}},
}

-- Ash pines (Mt. Chimney, Jagged Pass; built by Gen3AshPine): one pine per foot cell, its crown rising into the cell above.
--   foot: blocked tiles that are the foot of a pine; tip: the crown's top drawn over bare ground (walkable, ground in 3D);
--   crown/base: the tiles whose rows are the crown's art and its bottom; ground: the floor under the pines.
M.PINE={
 lavaridge={foot={0x2C5,0x2C6,0x2C7,0x2CC,0x2CD},tip=0x2C4,crown=0x2CD,base=0x2CC,ground=0x271},
}

-- secondary: the pret secondary name; ground: the tileset's floor tile; surf: the cell's behaviour is water.
-- Returns a shape for Gen3EmeraldShapes.of, or nil (the tile is none of this tileset's tree tiles).
function M.of(secondary,mid,collision,behavior,ground,surf)
 if not M.FAMILIES[secondary] then return nil end
 local p=M.PINE[secondary]
 if p then
  if mid==p.tip then return {kind='flat',groundMid=p.ground,ashTop=true,reviewedSurface=true} end
  for _,f in ipairs(p.foot)do
   if mid==f then return {kind='flat',ground=p.ground,ashPine=true,reviewedSurface=true} end
  end
 end
 local n=M.NARROW[secondary]
 if n and (mid==n.crown or mid==n.foot) and (collision or 0)~=0 then
  return {kind='tree',root=true,narrow=true,ground=ground,anchorX=8,anchorZ=12,art={{n.crown},{n.foot}},artTipRows=1}
 end
 local g=M.GENERAL[secondary]
 if g and (collision or 0)~=0 and g.base[mid] then
  -- (the floor under the mountain's trees is the terraces' rock, not the town lawn: the pines' ground)
  return {kind='tree',root=true,general=true,ground=ground,anchorX=8,anchorZ=12,art={{g.top},{mid}},artTipRows=1}
 end
end

-- After the cells are shaped: a walkable crown tile (n.over) whose south neighbour is a stamped tree has its crown carried
-- by that tree (c.treeOwned: no flat over-art, no walk-under slab). One without (the hedge along a map's edge, its trunks
-- in the border) keeps its old drawing. Each cell reads only its own tile and its south neighbour, so the order does not matter.
function M.claim(cells)
 for _,c in pairs(cells)do
  local n=M.FAMILIES[c.secondary] and M.NARROW[c.secondary]
  if n then
   for _,o in ipairs(n.over)do
    if c.mid==o then
     local south=cells[c.cx..':'..(c.cy+1)]
     if south and south.shape and south.shape.narrow then c.treeOwned=true end
    end
   end
  end
  local g=M.FAMILIES[c.secondary] and M.GENERAL[c.secondary]
  if g then
   if c.shape and c.shape.general then
    -- the crown above the tree is the crown tile drawn over the cell north of it
    local north=cells[c.cx..':'..(c.cy-1)]
    if north and (north.collision or 0)==0 and north.mid==g.top then c.shape.art={{north.mid},{c.mid}} end
   end
   for _,o in ipairs(g.over)do
    if c.mid==o then
     local south=cells[c.cx..':'..(c.cy+1)]
     if south and south.shape and south.shape.general then c.treeOwned=true end
    end
   end
  end
 end
end
return M
