-- General-tileset mountain tiles by the surface they are a picture of.
-- Data only; nothing reads this yet.
--
-- Source: the tables in ZallaxDev/pokeemerald-3Ds-dualscreen
-- (3ds_port/scripts/gen_voxel_relief.py and voxel_terraces.py, MIT,
-- Copyright (c) 2026 ZallaxDev and Pokémon Emerald 3Ds Dual Screen
-- contributors), transcribed 2026-10-13 at commit e80ba61. Ids are primary
-- (General) metatile ids, the same numbering as our grid's bits 0-9.
--
-- The reading: the art is a 45-degree oblique drawing, a point (X, h, Z)
-- lands at u = X, v = Z - h. Every mountain tile spans exactly one LEVEL:
--   top    flat terrace surface
--   face   south wall, vertical: one tile down a column = one level down
--   band   west/east side, a 45-degree slope one tile wide: one tile across
--          = one level down (high side towards the terrace)
--   end    a face's end piece: one level; down a column an UPPER end over a
--          LOWER end is ONE diagonal edge, one level, not two
-- so heights are counted (k rock tiles between two flat cells = k levels),
-- not guessed, and live on cell CORNERS so neighbours share them.
return {
 LEVEL=16,
 -- pixel colours (RGB) that say what a rock pixel is, whatever tile it is in
 colours={
  top  ={{0xde,0xb4,0xa4},{0xbd,0x94,0x8b}},
  rim  ={{0xee,0xd5,0xcd}},                 -- a top's lit edge; a rim on a tile's NORTH edge is the terrace's back
  face ={{0x83,0x5a,0x5a},{0x62,0x41,0x52},{0x41,0x31,0x41}},
  fleck={{0x9c,0x73,0x73}},                 -- in both: goes with the majority of its 8 neighbours
 },
 -- only these ids are ever mountain, whatever colours a tile is drawn in
 -- (soil, signs and house walls share the rock's browns)
 mountain={ranges={{0x064,0x0bf},{0x172,0x192}},ids={0x1a0,0x1a8,0x1b0,0x1f0,0x1f1,0x33b,0x33c}},
 not_rock={0x113,0x114,0x115,0x14b,0x14c,0x14d},  -- bare soil patches on grass: flat
 -- south faces, one level each (faces, cave mouths and doors in them, feet over grass/trees)
 face_south={0x07c,0x0a9,0x09f,0x0a7,0x091,0x079,0x1b0,0x0af,0x0cf,0x1f0,0x1f1,0x33b,0x33c},
 -- bands: the hatching does not say which way it falls, so it is a table.
 -- band_west = the slope faces west (high side EAST); band_east the reverse.
 band_west={0x070,0x073,0x088,0x06b,0x080,0x083,0x068, 0x172,0x175,0x177,0x17a},
 band_east={0x072,0x075,0x0a2,0x08a,0x06d,0x082,0x084,0x06a, 0x174,0x176,0x17c},
 -- 0x172-0x17c are the same pieces drawn over the sea (Route 105 ridges, rocks off Route 106);
 -- 0x172/0x174 are a ridge's rounded north caps, mostly sea pixels but rock hung from its top
 sea_caps={0x172,0x174},
 -- face ends (diagonal edges drawn as a staircase of ends)
 end_upper={0x074,0x089},
 end_lower={0x07d,0x07b,0x078},
 -- boulders drawn on a terrace: all of it is top (head over foot, two cells tall)
 boulder={head={0x093,0x094},foot={0x09b,0x09c}},
 loose_boulder={0x0df,0x0e0,0x0e1,0x0e2},    -- drawn on whatever ground: take the ground round them
 -- Lavaridge / Jagged Pass / Mt. Chimney use a secondary tileset whose rock he
 -- maps onto these roles by matching pixels (>= 90% of rock pixels agreeing);
 -- no id table exists for them upstream.
}
