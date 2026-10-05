-- Recipe for #47 Lilycove Museum (10x6 cells = 160x96 px).
-- White building with flat roof and side wings, central elevated pavilion.

local MUSEUM = {
 width = 160,
 boxes = {
  -- Lower floor left wing: cols 0..56, facade rows 52..96 (height 44 px), depth 4..52
  { name = 'wing_left', x0 = 0, x1 = 56, y0 = 0, y1 = 44, d0 = 4, d1 = 52,
    paint = {
      south  = {x = 0, y = 52, w = 56, h = 44},
      north  = {x = 4, y = 52, w = 52, h = 44},
      west   = {x = 0, y = 52, w = 4,  h = 44},
      east   = {x = 52, y = 52, w = 4, h = 44},
      bottom = {x = 10, y = 92, w = 1, h = 1},
    }
  },
  -- Lower floor right wing: cols 104..160, facade rows 52..96 (height 44 px), depth 4..52
  { name = 'wing_right', x0 = 104, x1 = 160, y0 = 0, y1 = 44, d0 = 4, d1 = 52,
    paint = {
      south  = {x = 104, y = 52, w = 56, h = 44},
      north  = {x = 104, y = 52, w = 52, h = 44},
      east   = {x = 156, y = 52, w = 4,  h = 44},
      west   = {x = 104, y = 52, w = 4,  h = 44},
      bottom = {x = 110, y = 92, w = 1, h = 1},
    }
  },
  -- Center entrance block / portico: cols 56..104, juts out (depth 0..52), height 48 px (rows 48..96)
  { name = 'center_portico', x0 = 56, x1 = 104, y0 = 0, y1 = 48, d0 = 0, d1 = 52,
    paint = {
      south  = {x = 56, y = 48, w = 48, h = 48},
      north  = {x = 56, y = 48, w = 48, h = 48},
      east   = {x = 100, y = 48, w = 4, h = 48},
      west   = {x = 56,  y = 48, w = 4, h = 48},
      bottom = {x = 70,  y = 92, w = 1, h = 1},
    }
  },
  -- Left wing flat roof (patterned tile): rows 20..52, depth 6..48, height 44..48
  { name = 'roof_left', x0 = 2, x1 = 54, y0 = 44, y1 = 48, d0 = 6, d1 = 48,
    paint = {
      top    = {x = 2, y = 20, w = 52, h = 32},
      south  = {x = 2, y = 48, w = 52, h = 4},
      north  = {x = 2, y = 20, w = 52, h = 4},
      east   = {x = 50, y = 20, w = 4,  h = 32},
      west   = {x = 2,  y = 20, w = 4,  h = 32},
    }
  },
  -- Right wing flat roof (patterned tile): rows 20..52, depth 6..48, height 44..48
  { name = 'roof_right', x0 = 106, x1 = 158, y0 = 44, y1 = 48, d0 = 6, d1 = 48,
    paint = {
      top    = {x = 106, y = 20, w = 52, h = 32},
      south  = {x = 106, y = 48, w = 52, h = 4},
      north  = {x = 106, y = 20, w = 52, h = 4},
      east   = {x = 154, y = 20, w = 4,  h = 32},
      west   = {x = 106, y = 20, w = 4,  h = 32},
    }
  },
  -- Upper central pavilion: cols 40..120, height 48..70 (rows 24..48), depth 14..48
  { name = 'upper_pavilion', x0 = 40, x1 = 120, y0 = 48, y1 = 70, d0 = 14, d1 = 48,
    paint = {
      south  = {x = 40, y = 24, w = 80, h = 24},
      north  = {x = 40, y = 24, w = 80, h = 24},
      east   = {x = 116, y = 24, w = 4, h = 24},
      west   = {x = 40,  y = 24, w = 4, h = 24},
    }
  },
  -- Upper pavilion roof slab (patterned tile & parapet): rows 0..24, depth 16..46, height 70..76
  { name = 'upper_roof', x0 = 42, x1 = 118, y0 = 70, y1 = 76, d0 = 16, d1 = 46,
    paint = {
      top    = {x = 42, y = 0,  w = 76, h = 24},
      south  = {x = 42, y = 20, w = 76, h = 4},
      north  = {x = 42, y = 0,  w = 76, h = 4},
      east   = {x = 114, y = 0, w = 4,  h = 24},
      west   = {x = 42,  y = 0, w = 4,  h = 24},
    }
  },
 }
}

return MUSEUM
