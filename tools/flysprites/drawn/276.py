# Taillow: long dark-blue swallow wings with lighter coverts; feet tucked.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import drawlib as D

P = dict(canvas=(50, 34), outline=(0, 0, 0), wing=dict(length=12, chord=4, colours=((0x68, 0x88, 0xc0), (0x30, 0x48, 0x70), (0x10, 0x30, 0x48)), feathers=3, rise=.25, tip_chord=1), tuck={0: (26, 2), 1: (26, 2), 2: (26, 2), 3: (26, 2)}, shoulder_frac=.4, side_frac=.3)


def build(nat, base, src):
    return D.build_spread(base, P)
