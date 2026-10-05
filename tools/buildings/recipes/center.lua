-- Recipe for the Pokemon Center (4x4 cells = 64x64 px).
-- Reused across Petalburg, Slateport, Mauville, Rustboro, Mossdeep, etc.

local CENTER = {
 width = 64,
 boxes = {
  -- Main facade & body: rows 42..63 (height 22 px), full width 64, depth 2..48
  { name = 'body', x0 = 0, x1 = 64, y0 = 0, y1 = 22, d0 = 2, d1 = 48,
    paint = {
      south  = {x = 0, y = 42, w = 64, h = 22},
      north  = {x = 8, y = 44, w = 48, h = 18},
      east   = {x = 58, y = 44, w = 4, h = 18},
      west   = {x = 2,  y = 44, w = 4, h = 18},
      bottom = {x = 8,  y = 60, w = 1, h = 1},
    }
  },
  -- Blue eave rim: overhangs 2 px forward (d0=0, d1=48), height 22..25 (rows 38..41)
  { name = 'eave', x0 = 0, x1 = 64, y0 = 22, y1 = 25, d0 = 0, d1 = 48,
    paint = {
      south  = {x = 0, y = 38, w = 64, h = 4},
      top    = {x = 0, y = 37, w = 64, h = 2},
      north  = {x = 0, y = 38, w = 64, h = 4},
      east   = {x = 60, y = 38, w = 2, h = 4},
      west   = {x = 2,  y = 38, w = 2, h = 4},
    }
  },
  -- Roof tier 1: red band with the Poke Ball logo (rows 24..37), height 25..36, depth 4..46
  { name = 'red_roof', x0 = 2, x1 = 62, y0 = 25, y1 = 36, d0 = 4, d1 = 46,
    paint = {
      south  = {x = 2, y = 25, w = 60, h = 12},
      top    = {x = 2, y = 23, w = 60, h = 4},
      north  = {x = 2, y = 25, w = 60, h = 12},
      east   = {x = 58, y = 25, w = 2, h = 12},
      west   = {x = 4,  y = 25, w = 2, h = 12},
    }
  },
  -- Roof tier 2: ribbed drum dome (rows 8..23), width 48 (x=8..56), height 36..46, depth 10..42
  { name = 'drum_dome', x0 = 8, x1 = 56, y0 = 36, y1 = 46, d0 = 10, d1 = 42,
    paint = {
      south  = {x = 8, y = 10, w = 48, h = 14},
      top    = {x = 8, y = 8,  w = 48, h = 4},
      north  = {x = 8, y = 10, w = 48, h = 14},
      east   = {x = 54, y = 10, w = 2, h = 14},
      west   = {x = 8,  y = 10, w = 2, h = 14},
    }
  },
  -- Roof tier 3: top crest of the dome (rows 0..8), width 20 (x=22..42), height 46..52, depth 18..36
  { name = 'top_crest', x0 = 22, x1 = 42, y0 = 46, y1 = 52, d0 = 18, d1 = 36,
    paint = {
      south  = {x = 22, y = 2,  w = 20, h = 6},
      top    = {x = 22, y = 0,  w = 20, h = 3},
      north  = {x = 22, y = 2,  w = 20, h = 6},
      east   = {x = 40, y = 2,  w = 2, h = 6},
      west   = {x = 22, y = 2,  w = 2, h = 6},
    }
  },
 }
}

return CENTER
