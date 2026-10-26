# Hoothoot: round owl wings, dark brown with tan edges; its one foot tucked.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import drawlib as D

P = dict(canvas=(50, 34), outline=(0, 0, 0), wing=dict(length=10, chord=6, colours=((0xcf, 0xae, 0x85), (0x88, 0x57, 0x3f), (0x50, 0x28, 0x08)), feathers=3, rise=.15), tuck={0: (25, 2), 1: (25, 2), 2: (25, 2), 3: (25, 2)}, shoulder_frac=.45, side_frac=.4)


def build(nat, base, src):
    return D.build_spread(base, P)
