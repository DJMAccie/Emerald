# Delibird: small red-and-white wings flapping hard; feet tucked under the sack-tail.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import drawlib as D

P = dict(canvas=(46, 34), outline=(0, 0, 0), wing=dict(length=8, chord=5, colours=((0xe8, 0xe8, 0xf8), (0xc8, 0x18, 0x18), (0x58, 0x08, 0x08)), feathers=2, rise=.15), tuck={0: (26, 2), 1: (26, 2), 2: (26, 2), 3: (26, 2)}, shoulder_frac=.45, side_frac=.4)


def build(nat, base, src):
    return D.build_spread(base, P)
