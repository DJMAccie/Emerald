-- Recipe for #44 Lilycove Department Store (9x7 cells = 144x112 px).
-- A tall pale-blue tower with a Poke Ball logo and 3 window storeys above entrance.

local DEPT_STORE = {
 width = 144,
 boxes = {
  -- Main tower body: rows 8..112 (height 104 px), depth 4..60
  { name = 'tower', x0 = 0, x1 = 144, y0 = 0, y1 = 104, d0 = 4, d1 = 60,
    paint = {
      south  = {x = 0, y = 8,   w = 144, h = 104},
      north  = {x = 8, y = 12,  w = 128, h = 100},
      east   = {x = 140, y = 12, w = 4,   h = 100},
      west   = {x = 0,   y = 12, w = 4,   h = 100},
      bottom = {x = 20,  y = 108, w = 1,  h = 1},
    }
  },
  -- Roof parapet / top slab: rows 0..8, height 104..110, depth 8..56
  { name = 'roof_slab', x0 = 4, x1 = 140, y0 = 104, y1 = 110, d0 = 8, d1 = 56,
    paint = {
      top    = {x = 4, y = 0,  w = 136, h = 8},
      south  = {x = 4, y = 4,  w = 136, h = 4},
      north  = {x = 4, y = 0,  w = 136, h = 4},
      east   = {x = 136, y = 0, w = 4,  h = 8},
      west   = {x = 4,   y = 0, w = 4,  h = 8},
    }
  },
  -- Entrance awning (center over door): rows 92..98 (height 14..20), juts out (depth 0..6)
  { name = 'entrance_portico', x0 = 56, x1 = 88, y0 = 14, y1 = 20, d0 = 0, d1 = 6,
    paint = {
      south  = {x = 56, y = 92, w = 32, h = 6},
      top    = {x = 56, y = 92, w = 32, h = 2},
      bottom = {x = 56, y = 96, w = 32, h = 2},
      east   = {x = 86, y = 92, w = 2,  h = 6},
      west   = {x = 56, y = 92, w = 2,  h = 6},
    }
  },
  -- Left window awnings: rows 92..98 (height 14..20), depth 0..6
  { name = 'awning_left1', x0 = 8, x1 = 24, y0 = 14, y1 = 20, d0 = 0, d1 = 6,
    paint = {
      south  = {x = 8,  y = 92, w = 16, h = 6},
      top    = {x = 8,  y = 92, w = 16, h = 2},
      bottom = {x = 8,  y = 96, w = 16, h = 2},
      east   = {x = 22, y = 92, w = 2,  h = 6},
      west   = {x = 8,  y = 92, w = 2,  h = 6},
    }
  },
  { name = 'awning_left2', x0 = 24, x1 = 40, y0 = 14, y1 = 20, d0 = 0, d1 = 6,
    paint = {
      south  = {x = 24, y = 92, w = 16, h = 6},
      top    = {x = 24, y = 92, w = 16, h = 2},
      bottom = {x = 24, y = 96, w = 16, h = 2},
      east   = {x = 38, y = 92, w = 2,  h = 6},
      west   = {x = 24, y = 92, w = 2,  h = 6},
    }
  },
  -- Right window awnings: rows 92..98 (height 14..20), depth 0..6
  { name = 'awning_right1', x0 = 104, x1 = 120, y0 = 14, y1 = 20, d0 = 0, d1 = 6,
    paint = {
      south  = {x = 104, y = 92, w = 16, h = 6},
      top    = {x = 104, y = 92, w = 16, h = 2},
      bottom = {x = 104, y = 96, w = 16, h = 2},
      east   = {x = 118, y = 92, w = 2,  h = 6},
      west   = {x = 104, y = 92, w = 2,  h = 6},
    }
  },
  { name = 'awning_right2', x0 = 120, x1 = 136, y0 = 14, y1 = 20, d0 = 0, d1 = 6,
    paint = {
      south  = {x = 120, y = 92, w = 16, h = 6},
      top    = {x = 120, y = 92, w = 16, h = 2},
      bottom = {x = 120, y = 96, w = 16, h = 2},
      east   = {x = 134, y = 92, w = 2,  h = 6},
      west   = {x = 120, y = 92, w = 2,  h = 6},
    }
  },
 }
}

return DEPT_STORE
