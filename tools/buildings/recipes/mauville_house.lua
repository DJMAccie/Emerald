-- Recipe for Mauville House (4x4 cells = 64x64 px).
-- Pink corrugated metal/tile roof and corrugated steel siding.

local MAUVILLE_HOUSE = {
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
  -- Eave overhang: rows 34..38, height 26..30, depth 0..48
  { name = 'eave', x0 = 0, x1 = 64, y0 = 26, y1 = 30, d0 = 0, d1 = 48,
    paint = {
      south  = {x = 0, y = 34, w = 64, h = 4},
      top    = {x = 0, y = 34, w = 64, h = 2},
      north  = {x = 0, y = 34, w = 64, h = 4},
      east   = {x = 60, y = 34, w = 2,  h = 4},
      west   = {x = 2,  y = 34, w = 2,  h = 4},
    }
  },
  -- Main sloped pink ribbed roof: rows 12..34, height 30..52, depth 4..44
  { name = 'roof_slope', x0 = 0, x1 = 64, y0 = 30, y1 = 52, d0 = 4, d1 = 44,
    paint = {
      south  = {x = 0, y = 12, w = 64, h = 22},
      top    = {x = 0, y = 12, w = 64, h = 4},
      north  = {x = 0, y = 12, w = 64, h = 22},
      east   = {x = 58, y = 12, w = 4,  h = 22},
      west   = {x = 2,  y = 12, w = 4,  h = 22},
    }
  },
  -- Upper roof ridge tier: rows 0..12, height 52..64, depth 12..36
  { name = 'roof_ridge', x0 = 0, x1 = 64, y0 = 52, y1 = 64, d0 = 12, d1 = 36,
    paint = {
      south  = {x = 0, y = 0,  w = 64, h = 12},
      top    = {x = 0, y = 0,  w = 64, h = 4},
      north  = {x = 0, y = 0,  w = 64, h = 12},
      east   = {x = 58, y = 0,  w = 4,  h = 12},
      west   = {x = 2,  y = 0,  w = 4,  h = 12},
    }
  },
 }
}

return MAUVILLE_HOUSE
