# Tropius: its leaf wings are already spread on the follower sprite; they beat by shear (front/back) and a
# vertical stretch about the root (sides).
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import drawlib as D

P = dict(canvas=(48, 40), outline=(0, 0, 0),
         shear={0: (9, 21), 3: (12, 20)}, band={0: (4, 24), 3: (4, 26)}, stretch={0: 1.25, 3: 1.25},
         flap={0: 20, 3: 22}, span=9, ks_tip={'up': 1.4, 'mid': 1.0, 'down': 0.6, 'mid2': 1.0},
         slopes={'up': -0.5, 'mid': 0.0, 'down': 0.4, 'mid2': 0.0},
         side={1: dict(box=(1, 2, 16, 22), root=19, ks={'up': 1.3, 'mid': 1.0, 'down': 0.5, 'mid2': 1.0}),
               2: dict(box=(16, 2, 31, 22), root=19, ks={'up': 1.3, 'mid': 1.0, 'down': 0.5, 'mid2': 1.0})},
         tuck={0: (24, 1), 1: (24, 1), 2: (24, 1), 3: (26, 1)})


def build(nat, base, src):
    return D.build_existing(base, P)
