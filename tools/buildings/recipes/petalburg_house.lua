-- Recipe for Petalburg House (4x4 cells = 64x64 px).
-- Red tile roof town house.

local PETALBURG_HOUSE = {
 width = 64,
 boxes = {
  -- Main facade & wall body: rows 38..64 (height 26 px), depth 2..46
  { name = 'body', x0 = 0, x1 = 64, y0 = 0, y1 = 26, d0 = 2, d1 = 46,
    paint = {
      south  = {x = 0, y = 38, w = 64, h = 26},
      north  = {x = 4, y = 42, w = 56, h = 20},
      east   = {x = 58, y = 42, w = 4,  h = 20},
      west   = {x = 2,  y = 42, w = 4,  h = 20},
      bottom = {x = 8,  y = 60, w = 1,  h = 1},
    }
  },
  -- Eave overhang: rows 36..38, height 26..28, depth 0..48
  { name = 'eave', x0 = 0, x1 = 64, y0 = 26, y1 = 28, d0 = 0, d1 = 48,
    paint = {
      south  = {x = 0, y = 36, w = 64, h = 2},
      top    = {x = 0, y = 36, w = 64, h = 2},
      north  = {x = 0, y = 36, w = 64, h = 2},
      east   = {x = 60, y = 36, w = 2,  h = 2},
      west   = {x = 2,  y = 36, w = 2,  h = 2},
    }
  },
  -- Main sloped red tile roof: rows 14..36, height 28..50, depth 4..44
  { name = 'roof_slope', x0 = 0, x1 = 64, y0 = 28, y1 = 50, d0 = 4, d1 = 44,
    paint = {
      south  = {x = 0, y = 14, w = 64, h = 22},
      top    = {x = 0, y = 14, w = 64, h = 4},
      north  = {x = 0, y = 14, w = 64, h = 22},
      east   = {x = 58, y = 14, w = 4,  h = 22},
      west   = {x = 2,  y = 14, w = 4,  h = 22},
    }
  },
  -- Upper roof ridge tier: rows 0..14, height 50..64, depth 12..36
  { name = 'roof_ridge', x0 = 0, x1 = 64, y0 = 50, y1 = 64, d0 = 12, d1 = 36,
    paint = {
      south  = {x = 0, y = 0,  w = 64, h = 14},
      top    = {x = 0, y = 0,  w = 64, h = 4},
      north  = {x = 0, y = 0,  w = 64, h = 14},
      east   = {x = 58, y = 0,  w = 4,  h = 14},
      west   = {x = 2,  y = 0,  w = 4,  h = 14},
    }
  },
 }
}

return PETALBURG_HOUSE
