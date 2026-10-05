-- Recipe for #29 Rustboro Devon Corporation (10x9 cells = 160x144 px).
-- A tall grey office block: three window storeys and a flat roof with parapet.
-- Main block + roof slab inset by parapet + entrance portico + proud corner columns.

local DEVON = {
 width = 160,
 boxes = {
  -- Left wing body: cols 0..56, facade rows 36..144 (height 108 px), depth 4..64
  { name = 'wing_left', x0 = 2, x1 = 56, y0 = 0, y1 = 108, d0 = 4, d1 = 64,
    paint = {
      south  = {x = 2, y = 36, w = 54, h = 108},
      north  = {x = 10, y = 38, w = 46, h = 106},
      west   = {x = 2,  y = 38, w = 4,  h = 106},
      east   = {x = 52, y = 38, w = 4,  h = 106},
      bottom = {x = 20, y = 140, w = 1, h = 1},
    }
  },
  -- Right wing body: cols 104..160, facade rows 36..144 (height 108 px), depth 4..64
  { name = 'wing_right', x0 = 104, x1 = 158, y0 = 0, y1 = 108, d0 = 4, d1 = 64,
    paint = {
      south  = {x = 104, y = 36, w = 54, h = 108},
      north  = {x = 104, y = 38, w = 46, h = 106},
      east   = {x = 154, y = 38, w = 4,  h = 106},
      west   = {x = 104, y = 38, w = 4,  h = 106},
      bottom = {x = 140, y = 140, w = 1, h = 1},
    }
  },
  -- Left wing roof slab (inset by parapet): rows 8..36 (depth 4..60)
  { name = 'roof_left', x0 = 4, x1 = 54, y0 = 108, y1 = 112, d0 = 6, d1 = 60,
    paint = {
      top    = {x = 4, y = 8,  w = 50, h = 28},
      south  = {x = 4, y = 34, w = 50, h = 4},
      north  = {x = 4, y = 8,  w = 50, h = 4},
      east   = {x = 50, y = 8, w = 4,  h = 28},
      west   = {x = 4,  y = 8, w = 4,  h = 28},
    }
  },
  -- Right wing roof slab (inset by parapet): rows 8..36 (depth 4..60)
  { name = 'roof_right', x0 = 106, x1 = 156, y0 = 108, y1 = 112, d0 = 6, d1 = 60,
    paint = {
      top    = {x = 106, y = 8,  w = 50, h = 28},
      south  = {x = 106, y = 34, w = 50, h = 4},
      north  = {x = 106, y = 8,  w = 50, h = 4},
      east   = {x = 152, y = 8,  w = 4,  h = 28},
      west   = {x = 106, y = 8,  w = 4,  h = 28},
    }
  },
  -- Center portico body: cols 56..104, juts out (depth 0..64), height 120 px (rows 24..144)
  { name = 'portico', x0 = 56, x1 = 104, y0 = 0, y1 = 120, d0 = 0, d1 = 64,
    paint = {
      south  = {x = 56, y = 24, w = 48, h = 120},
      north  = {x = 56, y = 24, w = 48, h = 120},
      east   = {x = 100, y = 24, w = 4, h = 120},
      west   = {x = 56,  y = 24, w = 4, h = 120},
      bottom = {x = 80,  y = 140, w = 1, h = 1},
    }
  },
  -- Center portico roof slab (with crest & parapet): rows 0..24, depth 4..60, height 120..126
  { name = 'roof_portico', x0 = 58, x1 = 102, y0 = 120, y1 = 126, d0 = 2, d1 = 60,
    paint = {
      top    = {x = 58, y = 0,  w = 44, h = 24},
      south  = {x = 58, y = 20, w = 44, h = 4},
      north  = {x = 58, y = 0,  w = 44, h = 4},
      east   = {x = 98, y = 0,  w = 4,  h = 24},
      west   = {x = 58, y = 0,  w = 4,  h = 24},
    }
  },
  -- Proud corner column: Far West
  { name = 'col_west', x0 = 0, x1 = 4, y0 = 0, y1 = 110, d0 = 2, d1 = 6,
    paint = {
      south  = {x = 0, y = 36, w = 4, h = 108},
      west   = {x = 0, y = 36, w = 4, h = 108},
      top    = {x = 0, y = 34, w = 4, h = 4},
    }
  },
  -- Proud corner column: Portico West
  { name = 'col_portico_w', x0 = 54, x1 = 58, y0 = 0, y1 = 122, d0 = -2, d1 = 2,
    paint = {
      south  = {x = 54, y = 24, w = 4, h = 120},
      west   = {x = 54, y = 24, w = 4, h = 120},
      top    = {x = 54, y = 22, w = 4, h = 4},
    }
  },
  -- Proud corner column: Portico East
  { name = 'col_portico_e', x0 = 102, x1 = 106, y0 = 0, y1 = 122, d0 = -2, d1 = 2,
    paint = {
      south  = {x = 102, y = 24, w = 4, h = 120},
      east   = {x = 102, y = 24, w = 4, h = 120},
      top    = {x = 102, y = 22, w = 4, h = 4},
    }
  },
  -- Proud corner column: Far East
  { name = 'col_east', x0 = 156, x1 = 160, y0 = 0, y1 = 110, d0 = 2, d1 = 6,
    paint = {
      south  = {x = 156, y = 36, w = 4, h = 108},
      east   = {x = 156, y = 36, w = 4, h = 108},
      top    = {x = 156, y = 34, w = 4, h = 4},
    }
  },
 }
}

return DEVON
