-- Recipe for the Poke Mart (4x4 cells = 64x64 px).
-- Reused across Petalburg, Slateport, Mauville, Rustboro, Mossdeep, etc.

local MART = {
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
  -- Roof tier 1: dark blue band with the Poke Ball logo (rows 24..37), height 25..36, depth 4..46
  { name = 'blue_roof', x0 = 2, x1 = 62, y0 = 25, y1 = 36, d0 = 4, d1 = 46,
    paint = {
      south  = {x = 2, y = 25, w = 60, h = 12},
      top    = {x = 2, y = 23, w = 60, h = 4},
      north  = {x = 2, y = 25, w = 60, h = 12},
      east   = {x = 58, y = 25, w = 2, h = 12},
      west   = {x = 4,  y = 25, w = 2, h = 12},
    }
  },
  -- Roof tier 2: ribbed hipped roof slope (rows 10..24), width 52 (x=6..58), height 36..46, depth 8..42
  { name = 'hipped_slope', x0 = 6, x1 = 58, y0 = 36, y1 = 46, d0 = 8, d1 = 42,
    paint = {
      south  = {x = 6, y = 10, w = 52, h = 14},
      top    = {x = 6, y = 8,  w = 52, h = 2},
      north  = {x = 6, y = 10, w = 52, h = 14},
      east   = {x = 54, y = 10, w = 2, h = 14},
      west   = {x = 6,  y = 10, w = 2, h = 14},
    }
  },
  -- Roof ridge cap: top edge of the ribbed roof (row 8), height 46..48, depth 16..34
  { name = 'top_ridge', x0 = 8, x1 = 56, y0 = 46, y1 = 48, d0 = 16, d1 = 34,
    paint = {
      south  = {x = 8, y = 8, w = 48, h = 2},
      top    = {x = 8, y = 8, w = 48, h = 2},
      north  = {x = 8, y = 8, w = 48, h = 2},
      east   = {x = 54, y = 8, w = 2, h = 2},
      west   = {x = 8,  y = 8, w = 2, h = 2},
    }
  },
 }
}

return MART
