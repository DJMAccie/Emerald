# Salamence: red wings already spread on the follower sprite: shear beat front/back, stretch about the root on the sides.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import drawlib as D

P = dict(canvas=(52, 40), outline=(0, 0, 0),
         shear={0: (10, 21), 3: (12, 19)}, band={0: (2, 18), 3: (2, 20)}, stretch={0: 1.3, 3: 1.25},
         flap={0: 14, 3: 17}, span=10, ks_tip={'up': 1.4, 'mid': 1.0, 'down': 0.6, 'mid2': 1.0},
         slopes={'up': -0.5, 'mid': 0.0, 'down': 0.45, 'mid2': 0.0},
         side={1: dict(box=(11, 1, 31, 16), root=14, ks={'up': 1.3, 'mid': 1.0, 'down': 0.5, 'mid2': 1.0}),
               2: dict(box=(1, 1, 21, 16), root=14, ks={'up': 1.3, 'mid': 1.0, 'down': 0.5, 'mid2': 1.0})},
         tuck={0: (25, 2), 1: (25, 2), 2: (25, 2), 3: (25, 2)})


def build(nat, base, src):
    return D.build_existing(base, P)
