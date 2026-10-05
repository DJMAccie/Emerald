-- Recipe for #132 Route 119 Weather Institute (10x7 cells = 160x112 px).
-- Two cylindrical corner towers with observation domes, stepped central roof.

local WEATHER_INST = {
 width = 160,
 boxes = {
  -- Central main building body: cols 32..128, height 64 px (rows 48..112), depth 6..56
  { name = 'body_center', x0 = 32, x1 = 128, y0 = 0, y1 = 64, d0 = 6, d1 = 56,
    paint = {
      south  = {x = 32, y = 48, w = 96, h = 64},
      north  = {x = 32, y = 48, w = 96, h = 64},
      east   = {x = 120, y = 48, w = 4, h = 64},
      west   = {x = 32,  y = 48, w = 4, h = 64},
      bottom = {x = 76,  y = 108, w = 1, h = 1},
    }
  },
  -- Left corner tower (cylindrical with glass ribbons): cols 0..32, height 64 px (rows 48..112), depth 2..48
  { name = 'tower_left', x0 = 0, x1 = 34, y0 = 0, y1 = 64, d0 = 2, d1 = 48,
    paint = {
      south  = {x = 0, y = 48, w = 34, h = 64},
      north  = {x = 0, y = 48, w = 34, h = 64},
      west   = {x = 0, y = 48, w = 4,  h = 64},
      east   = {x = 30, y = 48, w = 4, h = 64},
      top    = {x = 2, y = 42, w = 32, h = 6},
    }
  },
  -- Right corner tower (cylindrical with glass ribbons): cols 126..160, height 64 px (rows 48..112), depth 2..48
  { name = 'tower_right', x0 = 126, x1 = 160, y0 = 0, y1 = 64, d0 = 2, d1 = 48,
    paint = {
      south  = {x = 126, y = 48, w = 34, h = 64},
      north  = {x = 126, y = 48, w = 34, h = 64},
      east   = {x = 156, y = 48, w = 4, h = 64},
      west   = {x = 126, y = 48, w = 4, h = 64},
      top    = {x = 126, y = 42, w = 32, h = 6},
    }
  },
  -- Central sloped roof: lower step (rows 32..48), height 64..72, depth 6..52
  { name = 'roof_step1', x0 = 30, x1 = 130, y0 = 64, y1 = 72, d0 = 6, d1 = 52,
    paint = {
      south  = {x = 30, y = 40, w = 100, h = 8},
      top    = {x = 30, y = 32, w = 100, h = 8},
      north  = {x = 30, y = 32, w = 100, h = 8},
      east   = {x = 124, y = 32, w = 4,  h = 16},
      west   = {x = 30,  y = 32, w = 4,  h = 16},
    }
  },
  -- Central sloped roof: upper step (rows 12..32), height 72..82, depth 14..48
  { name = 'roof_step2', x0 = 32, x1 = 128, y0 = 72, y1 = 82, d0 = 14, d1 = 48,
    paint = {
      south  = {x = 32, y = 20, w = 96, h = 10},
      top    = {x = 32, y = 10, w = 96, h = 10},
      north  = {x = 32, y = 10, w = 96, h = 10},
      east   = {x = 120, y = 10, w = 4, h = 20},
      west   = {x = 32,  y = 10, w = 4, h = 20},
    }
  },
  -- Left weather dome: cols 4..36, sits atop left tower, height 64..94 (rows 8..44), depth 6..38
  { name = 'dome_left', x0 = 4, x1 = 36, y0 = 64, y1 = 94, d0 = 6, d1 = 38,
    paint = {
      south  = {x = 4, y = 16, w = 32, h = 28},
      north  = {x = 4, y = 16, w = 32, h = 28},
      west   = {x = 4, y = 16, w = 4,  h = 28},
      east   = {x = 32, y = 16, w = 4, h = 28},
      top    = {x = 4, y = 8,  w = 32, h = 8},
    }
  },
  -- Right weather dome: cols 124..156, sits atop right tower, height 64..94 (rows 8..44), depth 6..38
  { name = 'dome_right', x0 = 124, x1 = 156, y0 = 64, y1 = 94, d0 = 6, d1 = 38,
    paint = {
      south  = {x = 124, y = 16, w = 32, h = 28},
      north  = {x = 124, y = 16, w = 32, h = 28},
      east   = {x = 152, y = 16, w = 4, h = 28},
      west   = {x = 124, y = 16, w = 4, h = 28},
      top    = {x = 124, y = 8,  w = 32, h = 8},
    }
  },
 }
}

return WEATHER_INST
