# Doduo: no wings of its own; small stubby brown flaps beating fast, legs drawn up.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import drawlib as D

P = dict(canvas=(44, 34), outline=(0, 0, 0), wing=dict(length=6, chord=4, colours=((0xe0, 0xb0, 0x68), (0xb8, 0x80, 0x48), (0x88, 0x60, 0x28)), feathers=2, rise=.15), tuck={0: (24, 3), 1: (24, 3), 2: (24, 3), 3: (24, 3)}, shoulder_frac=.6, side_frac=.55, slopes={'up': -0.8, 'mid': 0.0, 'down': 0.6, 'mid2': 0.0})


def build(nat, base, src):
    return D.build_spread(base, P)
