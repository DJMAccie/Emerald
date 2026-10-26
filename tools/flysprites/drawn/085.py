# Dodrio: like Doduo, a little larger: stubby flaps, legs drawn up.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import drawlib as D

P = dict(canvas=(48, 36), outline=(0, 0, 0), wing=dict(length=7, chord=4, colours=((0xf0, 0xae, 0x32), (0xb8, 0x80, 0x48), (0x88, 0x61, 0x28)), feathers=2, rise=.15), tuck={0: (24, 3), 1: (24, 3), 2: (24, 3), 3: (24, 3)}, shoulder_frac=.7, side_frac=.65, slopes={'up': -0.8, 'mid': 0.0, 'down': 0.6, 'mid2': 0.0})


def build(nat, base, src):
    return D.build_spread(base, P)
