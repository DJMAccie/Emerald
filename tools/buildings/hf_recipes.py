"""Heightfield recipes for tools/buildings/hf.py.

Rows/x are in the building's own drawing (catalogue box + `crop` cell offsets).
`B` is the last facade row of a piece (ground contact at depth d0).  A piece is a
set of columns that share a path; `d0` may be a function of x (chamfers).
relief k > 0 pushes the pixel in (wall) / digs it down (roof); k < 0 pulls it out.
"""

# Pokemon Center: 64x48 drawing (inventory #4).  Chamfered front corners, a
# dark canopy band, a red drum roof with the ball logo standing as a wall, and
# a ribbed crest on top.
CENTER = dict(
    inv=4,
    pieces=[
        dict(x=(0, 7), B=46, d0=lambda x: 7 - x,
             segs=[('wall', 22), ('flat', 'top')], depth=30),
        dict(x=(7, 57), B=46, d0=0,
             segs=[('wall', 23), ('wall', 15), ('flat', 'top')], depth=30),
        dict(x=(57, 64), B=46, d0=lambda x: x - 56,
             segs=[('wall', 22), ('flat', 'top')], depth=30),
    ],
    relief=[
        dict(x=(7, 57), rows=(24, 28), k=-2),     # canopy overhang
        dict(x=(17, 32), rows=(29, 46), k=3),     # door recess
        dict(x=(9, 16), rows=(29, 41), k=1),      # glass bays
        dict(x=(33, 40), rows=(29, 41), k=1),
        dict(x=(41, 57), rows=(29, 41), k=-1),    # P.C sign board
    ],
)


def _win(c, r0, r1, half=2, k=3, w=5):
    return dict(x=(c - half, c - half + w), rows=(r0, r1), k=k)


def _devon():
    rel = []
    wings = [(32, 80), (144, 192)]
    for (a, b) in wings:
        rel += [dict(x=(a, b), rows=(49, 56), k=-2),      # top cornice
                dict(x=(a, b), rows=(79, 89), k=-2),      # floor band
                dict(x=(a, b), rows=(134, 144), k=-1)]    # plinth
    rel += [dict(x=(33, 41), rows=(56, 134), k=-2), dict(x=(184, 192), rows=(56, 134), k=-2)]
    # roof panels dug inside the white parapet
    rel += [dict(x=(37, 80), rows=(22, 45), k=2), dict(x=(144, 188), rows=(22, 45), k=2),
            dict(x=(88, 136), rows=(21, 57), k=2)]
    # tall arched windows: frame in 1, glass in 3
    for c in (52, 76, 156, 172):
        for (r0, r1) in ((57, 72), (89, 103)):
            rel.append(dict(x=(c - 4, c + 5), rows=(r0, r1), k=1))
            rel.append(_win(c, r0 + 1, r1, k=3))
    # little arched windows and round windows on the ground storey
    for c in (44, 52, 60, 68, 76, 148, 156, 164, 172, 180):
        rel.append(_win(c, 120, 128, k=3))
    for c in (44, 60, 76, 148, 164, 180):
        rel.append(_win(c, 112, 119, k=2))
    # central block: pilasters and cornices stand proud, panels and doors go in
    rel += [dict(x=(80, 88), rows=(66, 159), k=-3), dict(x=(136, 144), rows=(66, 159), k=-3),
            dict(x=(80, 144), rows=(61, 69), k=-3), dict(x=(80, 144), rows=(96, 105), k=-3)]
    for (r0, r1) in ((72, 92), (105, 126)):
        rel += [dict(x=(89, 96), rows=(r0, r1), k=1), dict(x=(128, 136), rows=(r0, r1), k=1),
                dict(x=(98, 111), rows=(r0, r1), k=2), dict(x=(114, 127), rows=(r0, r1), k=2)]
    rel += [dict(x=(88, 136), rows=(131, 156), k=1),
            dict(x=(97, 111), rows=(138, 157), k=4), dict(x=(113, 127), rows=(138, 157), k=4)]
    return dict(
        inv=29, crop=(0, 6, 0, 2),
        pieces=[
            dict(x=(32, 80), B=159, d0=16, segs=[('wall', 95), ('flat', 30)], depth=48,
                 side=(34, 42), back='front'),
            dict(x=(80, 144), B=159, d0=0, segs=[('wall', 99), ('flat', 45)], depth=48,
                 side=(98, 111), back='front'),
            dict(x=(144, 192), B=159, d0=16, segs=[('wall', 95), ('flat', 30)], depth=48,
                 side=(154, 162), back='front'),
        ],
        keys=[(115, 197, 165), (66, 181, 132)],
        relief=rel,
    )


DEVON = _devon()


def _dept():
    # coordinates read off a 5.2x contact image: tower x 80..223, base row 111
    rel = [dict(x=(80, 224), rows=(104, 112), k=-2)]                # plinth band
    for a in (89, 105, 185, 201):                                   # striped awnings
        rel += [dict(x=(a, a + 14), rows=(89, 97), k=-4), dict(x=(a + 2, a + 12), rows=(97, 104), k=1)]
    rel += [dict(x=(136, 168), rows=(88, 95), k=-4),                # entrance canopy
            dict(x=(138, 166), rows=(95, 112), k=3)]                # glass doors
    for c in (112, 152, 192):                                       # arched windows
        for (r0, r1) in ((2, 14), (32, 47), (64, 79)):
            rel += [dict(x=(c - 6, c + 6), rows=(r0, r1), k=2)]
    return dict(
        inv=44, crop=(0, 0, 0, 1),
        pieces=[dict(x=(80, 224), B=111, d0=0, segs=[('wall', 112)], depth=48,
                     side=(82, 92), back='front')],
        relief=rel, keys=[(115, 197, 165), (66, 181, 132)],
    )


def _museum():
    rel = []
    # cornices and the balcony band
    rel += [dict(x=(32, 72), rows=(65, 71), k=-2), dict(x=(152, 192), rows=(65, 71), k=-2),
            dict(x=(72, 152), rows=(41, 50), k=-2), dict(x=(32, 192), rows=(71, 80), k=-1)]
    # yellow pilasters stand proud
    for a in (32, 57, 80, 136, 160, 184):
        rel.append(dict(x=(a, a + 8), rows=(80, 101), k=-2))
    for a in (73, 97, 121, 145):
        rel.append(dict(x=(a, a + 7), rows=(50, 64), k=-2))
    # windows go in
    for a in (42, 66, 145, 168):
        rel.append(dict(x=(a, a + 12), rows=(80, 92), k=2))
    for a in (83, 107, 130):
        rel.append(dict(x=(a, a + 12), rows=(48, 57), k=2))
    # porch: canopy out, doorway in, slats shallow
    rel += [dict(x=(88, 136), rows=(78, 87), k=-5), dict(x=(96, 128), rows=(88, 112), k=4),
            dict(x=(95, 129), rows=(70, 80), k=1), dict(x=(32, 192), rows=(100, 111), k=-1)]
    # roof panels dug inside their frames
    rel += [dict(x=(80, 144), rows=(11, 38), k=2), dict(x=(38, 72), rows=(36, 62), k=2),
            dict(x=(152, 186), rows=(36, 62), k=2)]
    return dict(
        inv=47, crop=(0, 0, 0, 1),
        pieces=[
            dict(x=(32, 72), B=110, d0=0, segs=[('wall', 46), ('flat', 32)], depth=40, side=(34, 44), back='front'),
            dict(x=(72, 152), B=110, d0=0, segs=[('wall', 69), ('flat', 33)], depth=40, side=(73, 82), back='front'),
            dict(x=(152, 192), B=110, d0=0, segs=[('wall', 46), ('flat', 32)], depth=40, side=(176, 186), back='front'),
        ],
        relief=rel, keys=[(115, 197, 165), (66, 181, 132)],
    )


DEPT = _dept()
MUSEUM = _museum()


# Littleroot house (Brendan's / May's): 80x80 drawing (inventory #81, cells
# x2..6, y4..8). Two storeys: ground floor, a skirt roof on three sides, an
# upper storey with a strip window, its tiled roof and a yellow ridge cap.
GRASS = [(115, 197, 165), (66, 181, 132), (165, 214, 197)]
LITTLEROOT_HOUSE = dict(
    inv=81, crop=(0, -1, -1, 0),
    pieces=[
        # skirt-roof wings either side of the upper storey
        dict(x=(0, 9), B=79, d0=0, segs=[('wall', 27), ('slope', 36, 0.25), ('mirror', 36)], depth=56, side=(12, 16), back='front'),
        dict(x=(9, 71), B=79, d0=0,
             segs=[('wall', 27),            # ground floor
                   ('slope', 8, 0.5),       # skirt roof in front of the upper storey
                   ('wall', 9),             # upper storey, strip window
                   ('slope', 21, 1.0),      # upper roof
                   ('slope', 11, 0.2),      # ridge cap, nearly flat
                   ('mirror', 49)],         # back half: skirt, window band and roof reflected
             depth=56, side=(12, 16), back='front'),
        dict(x=(71, 80), B=79, d0=0, segs=[('wall', 27), ('slope', 36, 0.25), ('mirror', 36)], depth=56, side=(12, 16), back='front'),
    ],
    keys=GRASS,
    relief=[
        dict(x=(17, 30), rows=(62, 70), k=2),     # ground-floor window glass
        dict(x=(48, 63), rows=(60, 79), k=2),     # door recess
        dict(x=(40, 47), rows=(55, 79), k=-1),    # wooden post stands proud
        dict(x=(64, 71), rows=(55, 79), k=-1),
        dict(x=(13, 68), rows=(40, 43), k=2),     # strip window set back
        dict(x=(9, 71), rows=(51, 53), k=-2),     # skirt eave overhangs the wall
    ],
)


def _mirror_house(rec, inv, crop):
    """May's house is Brendan's drawn mirror-image (door on the left)."""
    m = dict(rec); m['inv'] = inv; m['crop'] = crop
    m['relief'] = [dict(r, x=(80 - r['x'][1], 80 - r['x'][0])) for r in rec['relief']]
    m['pieces'] = [dict(pc, side=(80 - pc['side'][1], 80 - pc['side'][0])) if pc.get('side') else pc
                   for pc in rec['pieces']]
    return m


LITTLEROOT_HOUSE_MAY = _mirror_house(LITTLEROOT_HOUSE, 80, (1, -1, 0, 0))


# Pokemon Center, every town (64x64 drawing: inventory #4 cells x19..22,
# y13..16 incl. the walkable crown row). Chamfered ground floor, dark eave,
# a steep red band carrying the Poke Ball emblem, the red crest above it and
# the orange ribbed dome, highest in the middle. The back mirrors the roof so
# the dome is round from every side.
def _center():
    def mid(x):            # columns under the full dome
        return [('wall', 22), ('flat', 3), ('slope', 15, 3.0), ('slope', 7, 1.0),
                ('slope', 16, 0.3), ('mirror', 41)]
    def shoulder(x):       # dome shoulders: no crest, the dome starts lower
        return [('wall', 22), ('flat', 3), ('slope', 15, 3.0), ('slope', 23, 0.2), ('mirror', 41)]
    return dict(
        inv=4, crop=(0, -1, 0, 0), trim=True,
        pieces=[
            dict(x=(0, 8), B=63, d0=lambda x: 8 - x, segs=shoulder(0), side=(9, 14), fill=(9, 15)),
            dict(x=(8, 16), B=63, d0=0, segs=shoulder(0), side=(9, 14), fill=(9, 15)),
            dict(x=(16, 48), B=63, d0=0, segs=mid(0), side=(9, 14), fill=(9, 15)),
            dict(x=(48, 56), B=63, d0=0, segs=shoulder(0), side=(9, 14), fill=(9, 15)),
            dict(x=(56, 64), B=63, d0=lambda x: x - 55, segs=shoulder(0), side=(9, 14), fill=(9, 15)),
        ],
        keys=GRASS,
        relief=[
            dict(x=(17, 31), rows=(45, 60), k=3),     # glass doors set in
            dict(x=(40, 56), rows=(44, 56), k=-1),    # P.C board stands out
            dict(x=(8, 56), rows=(39, 42), k=-2),     # eave overhang
            dict(x=(22, 42), rows=(24, 39), k=-1),    # the emblem stands proud
        ],
    )


CENTER2 = _center()


# Poke Mart, every town (64x64: Slateport's Mart, inventory #8, whose crown
# row is clean; Petalburg's is drawn merged with a fence). Same body as the
# Center; the roof is the emblem band then one ribbed slope, chamfered at the
# corners like the ground floor.
def _mart():
    segs = [('wall', 22), ('flat', 3), ('slope', 15, 3.0), ('slope', 16, 0.4), ('mirror', 31)]
    return dict(
        inv=8, crop=(0, -1, 0, 0), trim=True,
        pieces=[
            dict(x=(0, 8), B=63, d0=lambda x: 8 - x, segs=segs, side=(9, 14), fill=(9, 15)),
            dict(x=(8, 56), B=63, d0=0, segs=segs, side=(9, 14), fill=(9, 15)),
            dict(x=(56, 64), B=63, d0=lambda x: x - 55, segs=segs, side=(9, 14), fill=(9, 15)),
        ],
        keys=GRASS,
        relief=[
            dict(x=(17, 31), rows=(45, 60), k=3),     # glass doors set in
            dict(x=(8, 56), rows=(39, 42), k=-2),     # eave overhang
            dict(x=(22, 42), rows=(24, 39), k=-1),    # the emblem stands proud
        ],
    )


MART2 = _mart()

RECIPES = {'mart2': MART2, 'center2': CENTER2, 'littleroot_house': LITTLEROOT_HOUSE, 'littleroot_house_may': LITTLEROOT_HOUSE_MAY, 'center': CENTER, 'devon': DEVON, 'dept': DEPT, 'museum': MUSEUM}
