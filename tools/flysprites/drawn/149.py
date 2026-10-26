# Dragonite: the follower sprite already shows its little green (front) / orange (back) wings spread, so they
# beat by shearing the wing columns about the torso; side rows stretch the wing box about its root.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import drawlib as D

P = dict(canvas=(52, 40), outline=(0, 0, 0),
         shear={0: (8, 23), 3: (11, 20)}, band={0: (4, 15), 3: (4, 15)}, stretch={0: 1.7, 3: 1.6},
         swing={0: 12, 3: 12}, angles={'up': 28, 'mid': 0, 'down': -24, 'mid2': 0},
         slopes={'up': -0.55, 'mid': 0.0, 'down': 0.5, 'mid2': 0.0},
         side={1: dict(box=(17, 2, 32, 17), root=13, ks={'up': 1.35, 'mid': 1.0, 'down': 0.5, 'mid2': 1.0}),
               2: dict(box=(0, 2, 15, 17), root=13, ks={'up': 1.35, 'mid': 1.0, 'down': 0.5, 'mid2': 1.0})},
         tuck={0: (24, 2), 1: (25, 2), 2: (25, 2), 3: (25, 2)})


def build(nat, base, src):
    return D.build_existing(base, P)
