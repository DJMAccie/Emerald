-- Extend each FireRed perimeter from its own native scenery. Connected maps
-- remain authoritative; this adapter only receives the engine's void fallback.
local V=...
local Select=V.require('BoundaryScenery')
local Shapes=V.require('Gen3TileShape')
local Pairs=V.require('Gen3Tilesets')
local Versions=require('src.import.gba.versions')
local Collision=require('src.core.game3.collision')
local M={}
local key,regions
-- Emerald's General tree drawing; boundary trees must name it or the shared
-- tree model is built from FireRed's ids and every tree turns into a bush.
local function treeArt(shape)
 if shape.art then return shape.art end
 local v=V.require('Generation').version()
 if v=='emerald' or v=='ruby' or v=='sapphire' then return V.require('Gen3EmeraldShapes').treeArt end
end
function M.regions(def,world)
 local parts={tostring(def),tostring(def.midLayout)}
 for _,e in ipairs(world or {})do parts[#parts+1]=table.concat({e.id or '',e.ox,e.oy,tostring(e.def.midLayout)},':')end
 local nextKey=table.concat(parts,';')
 if nextKey==key then return regions end
 key=nextKey;regions={}
 local function add(d,x,y)
  local L=d.midLayout
  if L then regions[#regions+1]={def=d,x=x,y=y,w=L.width,h=L.height}end
 end
 add(def,0,0)
 for _,e in ipairs(world or {})do add(e.def,e.ox,e.oy)end
 return regions
end
local function sample(r,x,y)
 local L=r.def.midLayout;local mid=L:midAt(x,y);local pair=L.pair
 local spec=Pairs.resolve(pair,Versions.TILESET_PAIRS)
 if not spec then return end
 local shape=Shapes.of(spec.primary,spec.secondary,mid)
 local kind=shape.kind
 local biome=kind=='tree' and 'forest' or kind=='cliff' and 'mountain'
 if Collision.isSurfable(Collision.behaviorOn(r.def,x,y))then biome='water'end
 return {mid=mid,pair=pair,biome=biome,primary=spec.primary,secondary=spec.secondary,shape=shape}
end
-- maps standing in the sky: nothing beyond their edge (the Sky Pillar's
-- summit was ringed by an endless lawn)
M.SKY={EM_SKY_PILLAR_TOP=true}
function M.resolve(rs,x,y)
 local donor,real=Select.resolve(rs,x,y,sample)
 if real or not donor or donor.primary~='general' then return end
 do local o=Select.owner(rs,x,y);if o and o.def and M.SKY[o.def.id or ''] then return end end
 if donor.biome=='forest' then
  local source=donor.shape;local spacing=source.spacing or 2
  return donor.mid,donor.pair,{kind='tree',ground=source.ground or 1,root=x%spacing==0 and y%spacing==0,
   spacing=source.spacing,anchorX=source.anchorX or 16,anchorZ=source.anchorZ or 12,treeScale=source.treeScale,art=treeArt(source),artTipRows=source.artTipRows or (not source.art and treeArt(source) and 1 or nil)},'forest'
 elseif donor.biome=='mountain' then
  return 113,donor.pair,{kind='cliff',height=32,ground=1},'mountain'
 elseif donor.biome=='water' then
  -- repeat PLAIN water beyond the edge: the nearest edge cell is often a shore tile (sand or foam
  -- baked in), and repeating it repeated the shoreline (Gen3WaterEdge, tools/props/gen_water_edge.py)
  return V.require('Gen3WaterEdge').plain(donor.pair,donor.mid),donor.pair,{kind='water',reviewedSurface=true},'water'
 end
 -- The cartridge fills the void with the map's own BORDER block. Where an
 -- edge cell is open ground but the border block is forest, rock or sea,
 -- the town is ringed by that, not by an open lawn.
 local r=Select.owner(rs,x,y)
 local L=r and r.def and r.def.midLayout
 if L and L.borderMids then
  local spec=Pairs.resolve(L.pair,Versions.TILESET_PAIRS)
  if spec and spec.primary=='general' then
   local tree,cliff
   for _,mid in ipairs(L.borderMids)do
    local shape=Shapes.of(spec.primary,spec.secondary,mid)
    if shape.kind=='tree' then if not tree or shape.root then tree={mid=mid,shape=shape} end
    elseif shape.kind=='cliff' then cliff=true end
   end
   if tree then
    local source=tree.shape;local spacing=source.spacing or 2
    return tree.mid,L.pair,{kind='tree',ground=source.ground or 1,root=x%spacing==0 and y%spacing==0,
     spacing=source.spacing,anchorX=source.anchorX or 16,anchorZ=source.anchorZ or 12,treeScale=source.treeScale,art=treeArt(source),artTipRows=source.artTipRows or (not source.art and treeArt(source) and 1 or nil)},'forest'
   elseif cliff then
    return 113,L.pair,{kind='cliff',height=32,ground=1},'mountain'
   end
  end
 end
 -- Never propagate a facade, decoration or door into the void: plain ground of the donor's OWN
 -- tileset. The old tile 1 is General grass, which turned every sandy town's surroundings into a
 -- grass blob (Dewford).
 local floor
 if donor.primary=='general' then
  local gen=V.require('Generation').version()
  if gen=='emerald' or gen=='ruby' or gen=='sapphire' then floor=V.require('Gen3EmeraldShapes').floor(donor.secondary) end
 end
 -- Mt. Pyre (the facility tileset outdoors) has no neighbours: open ground
 -- beyond its edge is its grass, not the tileset's yellow indoor floor laid
 -- out at a high terrace's height. (Rock all round instead merged the margin
 -- into one rock mass too big to build: every cliff fell flat.)
 if donor.secondary=='facility' then floor=0x001 end
 if floor then return floor,donor.pair,{kind='flat',reviewedSurface=true},'ground' end
 -- Never propagate a facade, decoration or door into the void.
 return 1,donor.pair,{kind='flat',reviewedSurface=true},'ground'
end
function M.clear()key,regions=nil,nil end
return M
