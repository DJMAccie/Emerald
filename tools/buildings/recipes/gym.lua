-- Recipe for the Gym (6x5 cells = 96x80 px).
-- Reused across Petalburg, Rustboro, Mauville, etc.

local GYM = {
 width = 96,
 boxes = {
  -- Left wing body: cols 0..42, rows 44..80 (height 36 px), depth 4..64
  { name = 'wing_left', x0 = 0, x1 = 42, y0 = 0, y1 = 36, d0 = 4, d1 = 64,
    paint = {
      south  = {x = 0, y = 44, w = 42, h = 36},
      north  = {x = 4, y = 44, w = 38, h = 36},
      west   = {x = 0, y = 44, w = 4,  h = 36},
      east   = {x = 38, y = 44, w = 4, h = 36},
      bottom = {x = 10, y = 78, w = 1, h = 1},
    }
  },
  -- Right wing body: cols 68..96, rows 44..80 (height 36 px), depth 4..64
  { name = 'wing_right', x0 = 68, x1 = 96, y0 = 0, y1 = 36, d0 = 4, d1 = 64,
    paint = {
      south  = {x = 68, y = 44, w = 28, h = 36},
      north  = {x = 68, y = 44, w = 28, h = 36},
      east   = {x = 92, y = 44, w = 4,  h = 36},
      west   = {x = 68, y = 44, w = 4,  h = 36},
      bottom = {x = 80, y = 78, w = 1, h = 1},
    }
  },
  -- Center entrance block / portico: cols 40..70, rows 52..80, height 28 px, juts out (depth 0..64)
  { name = 'center_portico', x0 = 40, x1 = 70, y0 = 0, y1 = 28, d0 = 0, d1 = 64,
    paint = {
      south  = {x = 40, y = 52, w = 30, h = 28},
      north  = {x = 40, y = 52, w = 30, h = 28},
      east   = {x = 68, y = 52, w = 2,  h = 28},
      west   = {x = 40, y = 52, w = 2,  h = 28},
      bottom = {x = 55, y = 78, w = 1,  h = 1},
    }
  },
  -- Portico eave cap: rows 48..52, height 28..32, depth 0..64
  { name = 'portico_eave', x0 = 38, x1 = 72, y0 = 28, y1 = 32, d0 = -2, d1 = 64,
    paint = {
      south  = {x = 38, y = 48, w = 34, h = 4},
      top    = {x = 38, y = 48, w = 34, h = 2},
      east   = {x = 70, y = 48, w = 2,  h = 4},
      west   = {x = 38, y = 48, w = 2,  h = 4},
    }
  },
  -- Left wing flat roof: cols 2..40, rows 2..42, depth 4..64, height 36..40
  { name = 'roof_left', x0 = 2, x1 = 40, y0 = 36, y1 = 40, d0 = 4, d1 = 64,
    paint = {
      top    = {x = 2, y = 2,  w = 38, h = 42},
      south  = {x = 2, y = 40, w = 38, h = 4},
      north  = {x = 2, y = 2,  w = 38, h = 4},
      east   = {x = 36, y = 2, w = 4,  h = 42},
      west   = {x = 2,  y = 2, w = 4,  h = 42},
    }
  },
  -- Right wing flat roof: cols 70..94, rows 2..42, depth 4..64, height 36..40
  { name = 'roof_right', x0 = 70, x1 = 94, y0 = 36, y1 = 40, d0 = 4, d1 = 64,
    paint = {
      top    = {x = 70, y = 2,  w = 24, h = 42},
      south  = {x = 70, y = 40, w = 24, h = 4},
      north  = {x = 70, y = 2,  w = 24, h = 4},
      east   = {x = 90, y = 2,  w = 4,  h = 42},
      west   = {x = 70, y = 2,  w = 4,  h = 42},
    }
  },
  -- Center roof: cols 40..70, rows 2..48, depth 0..64, height 36..40
  { name = 'roof_center', x0 = 40, x1 = 70, y0 = 36, y1 = 40, d0 = 0, d1 = 64,
    paint = {
      top    = {x = 40, y = 2,  w = 30, h = 46},
      south  = {x = 40, y = 46, w = 30, h = 4},
      north  = {x = 40, y = 2,  w = 30, h = 4},
      east   = {x = 66, y = 2,  w = 4,  h = 46},
      west   = {x = 40, y = 2,  w = 4,  h = 46},
    }
  },
 }
}

return GYM
