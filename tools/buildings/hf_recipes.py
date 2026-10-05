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


# Professor Birch's lab, Littleroot (112x80, inventory #82, cells x3..9,
# y12..16). A long low building: facade (24 rows), dark eave fascia, a flat
# tiled roof seen from above, a white rail band along the back; the grey
# round vent on its square base stands up off the roof.
BIRCH_LAB = dict(
    inv=82, crop=(0, -1, 0, 0),
    pieces=[dict(x=(0, 112), B=79, d0=0,
                 segs=[('wall', 24), ('wall', 5), ('gable', 36, 14)],
                 side=(88, 100), back='front', fill=(88, 100))],
    keys=GRASS,
    relief=[
        dict(x=(12, 42), rows=(60, 70), k=2),     # windows set in
        dict(x=(64, 82), rows=(58, 79), k=3),     # door recess
        dict(x=(0, 112), rows=(51, 55), k=-2),    # eave overhang
    ],
    # the vent: a square base standing astride the ridge (ridge at depth 25),
    # its lit front face art rows 23-31, and the round vent on top of it
    prisms=[
        dict(x=(16, 48), d=(13, 38), h=(28, 44), B=79, rows=(14, 32), mat=(30, 27), grey=40),
        dict(x=(19, 45), d=(14, 31), h=(44, 49), B=79, rows=(0, 24), mat=(22, 18), grey=40, round=True),
    ],
)


def _shift(rec, dx, src):
    """The same recipe on a tighter source box (dx pixels removed on the left)."""
    m = dict(rec); m.pop('inv', None); m.pop('crop', None); m['src'] = src
    def sx(r): return (r[0] - dx, r[1] - dx)
    m['pieces'] = [dict(pc, x=sx(pc['x']), **({'side': sx(pc['side'])} if pc.get('side') else {}))
                   for pc in rec['pieces']]
    m['relief'] = [dict(r, x=sx(r['x'])) for r in rec['relief']]
    return m


# Devon Corp on its own cells only (x7..16, y6..15): the trees and lamp posts
# around it keep their own models.
DEVON2 = _shift(DEVON, 32, ('general__rustboro', 'EM_RUSTBORO_CITY', 7, 6, 16, 15))
# Lilycove Museum on its own cells (x7..16, y0..6): the hill, the trees, the
# flowers and the front staircase keep their own shapes.
MUSEUM2 = _shift(MUSEUM, 32, ('general__lilycove', 'EM_LILYCOVE_CITY', 7, 0, 16, 6))


# Route 119 Weather Institute (cells x1..11, y26..33 of the map). A flat
# tan roof seen from above (rows 8..54) with two radar domes and their small
# satellite balls at the back corners, over a two-storey front of pilasters
# and window bands (rows 55..119); the ends curve back as glass drums.
def _weather():
    ground = [(99, 66, 82), (132, 90, 90), (156, 115, 115), (189, 148, 140), (222, 181, 165),
              (66, 181, 132), (115, 197, 165), (165, 214, 197)] + [c for c in [(58, 82, 0), (58, 140, 49), (115, 197, 165), (132, 197, 99), (181, 255, 132)] if c[1] > c[0] + 30]
    def end(x0, x1, left):
        return lambda x: int(round(((x1 - x) if left else (x - x0)) * 0.9))
    segs = [('wall', 57), ('flat', 47)]
    return dict(
        src=('general__fortree', 'EM_ROUTE119', 1, 26, 11, 32), trim=True, flood=True,
        keys=ground,
        pieces=[
            dict(x=(0, 20), B=111, d0=end(0, 20, True), segs=segs, side=(26, 34), fill=(26, 34)),
            dict(x=(20, 156), B=111, d0=0, segs=segs, side=(26, 34), fill=(26, 34)),
            dict(x=(156, 176), B=111, d0=end(156, 176, False), segs=segs, side=(26, 34), fill=(26, 34)),
        ],
        relief=[
            dict(x=(19, 57), rows=(8, 38), k=-7),     # left radar dome
            dict(x=(121, 158), rows=(8, 38), k=-7),   # right radar dome
            dict(x=(14, 30), rows=(30, 46), k=-3),    # satellite balls
            dict(x=(30, 44), rows=(36, 48), k=-3),
            dict(x=(132, 146), rows=(36, 48), k=-3),
            dict(x=(146, 162), rows=(30, 46), k=-3),
            dict(x=(70, 106), rows=(96, 111), k=3),   # doorway set in
            dict(x=(36, 140), rows=(66, 74), k=2),    # window bands set in
            dict(x=(36, 140), rows=(88, 96), k=2),
        ],
    )


WEATHER = _weather()


# Fortree tree house (House1: cells x8..12, y1..3). The hut stands on the
# plank deck (the deck row below is walkable ground the elevation already
# raises): log walls with the doorway, flanked by stacked logs, under a
# leafy mound roof; the canopy around is cut away.
CANOPY = [(58, 82, 0), (58, 140, 49), (66, 58, 49), (107, 90, 90), (115, 197, 165), (132, 197, 99), (181, 255, 132)]
def _treehouse(x0):
    hut = [('wall', 26), ('slope', 10, 1.5), ('slope', 11, 0.3), ('mirror', 21)]
    logs = [('wall', 27)]
    return dict(
        src=('general__fortree', 'EM_FORTREE_CITY', x0, 1, x0 + 4, 3), trim=True, bgtiles=[0x0C6, 0x0C7, 0x017], keys=[],
        pieces=[dict(x=(4, 18), B=47, d0=2, segs=logs, side=(8, 12), fill=(8, 12), depth=12),
                dict(x=(18, 62), B=47, d0=0, segs=hut, side=(28, 32), fill=(28, 32)),
                dict(x=(62, 76), B=47, d0=2, segs=logs, side=(66, 70), fill=(66, 70), depth=12)],
        relief=[dict(x=(30, 52), rows=(26, 46), k=4)],   # the dark doorway goes in
        anchor_skip_cells=[(0, 0), (4, 0)],   # corner canopy differs between houses
    )


TREEHOUSE = _treehouse(8)


# Sootopolis houses (3x4 cells each). Ground = the crater rock tiles around.
SOOT_BG = [0x2D9, 0x2E1, 0x2D4, 0x2D8, 0x2E0, 0x2E2, 0x254, 0x255, 0x25E, 0x25F, 0x242, 0x241, 0x2D3, 0x2DA]
def _soot_cone(x0, y0):
    """White octagonal drum under a stepped dark pyramid (House1 kind)."""
    segs = [('wall', 30), ('flat', 42)]
    return dict(
        src=('general__sootopolis', 'EM_SOOTOPOLIS_CITY', x0, y0, x0 + 2, y0 + 4), trim=True, bgtiles=SOOT_BG, keys=[],
        pieces=[dict(x=(0, 8), B=79, d0=lambda x: 8 - x, segs=segs, side=(4, 7), fill=(4, 7)),
                dict(x=(8, 40), B=79, d0=0, segs=segs, side=(4, 7), fill=(4, 7)),
                dict(x=(40, 48), B=79, d0=lambda x: x - 39, segs=segs, side=(4, 7), fill=(4, 7))],
        relief=[dict(x=(3, 45), rows=(22, 50), k=-6),      # pyramid: outer tier
                dict(x=(8, 40), rows=(16, 44), k=-12),     # middle tier
                dict(x=(14, 34), rows=(10, 36), k=-18),    # top tier
                dict(x=(20, 28), rows=(6, 26), k=-23),     # apex
                dict(x=(16, 34), rows=(58, 79), k=2)],     # door set in
    )


def _soot_box(x0, y0):
    """Flat-roofed box with a skylight grid and a stepped porch (House2 kind)."""
    return dict(
        src=('general__sootopolis', 'EM_SOOTOPOLIS_CITY', x0, y0, x0 + 2, y0 + 4), trim=True, bgtiles=SOOT_BG, keys=[],
        pieces=[dict(x=(0, 48), B=79, d0=0, segs=[('wall', 30), ('flat', 34)], side=(4, 8), fill=(4, 8))],
        relief=[dict(x=(8, 40), rows=(22, 40), k=1),        # skylight panes set in
                dict(x=(14, 34), rows=(50, 79), k=-2),      # stepped porch stands out
                dict(x=(16, 32), rows=(60, 79), k=1)],      # door
        anchor_skip_cells=[(0, 2)],                          # left corner tile varies between houses
    )


SOOT_CONE = _soot_cone(8, 2)
SOOT_BOX = _soot_box(44, 2)
# the same box with a diamond front and no door (no warp; the town's extra buildings)
SOOT_BOX2 = dict(_soot_box(2, 5), relief=[dict(x=(8, 40), rows=(22, 40), k=1)], anchor_skip_cells=[])


# Pacifidlog hut (every hut is the same drawing; cells x15..17, y10..13 of the
# first): a round woven drum (rows 37..63) under a turtle-shell dome
# (rows 11..36), on the raft. Raft planks and sea are the ground.
def _hut():
    segs = [('wall', 27), ('slope', 12, 1.5), ('slope', 14, 0.4), ('mirror', 26)]
    return dict(
        src=('general__pacifidlog', 'EM_PACIFIDLOG_TOWN', 15, 10, 17, 13), trim=True, flood=True,
        keys=[(239, 197, 99), (239, 230, 165), (206, 156, 58), (165, 123, 25)] + [(82, 107, 214), (107, 132, 214)],
        pieces=[dict(x=(3, 11), B=63, d0=lambda x: 11 - x, segs=segs, side=(12, 16), fill=(12, 16)),
                dict(x=(11, 37), B=63, d0=0, segs=segs, side=(12, 16), fill=(12, 16)),
                dict(x=(37, 45), B=63, d0=lambda x: x - 36, segs=segs, side=(12, 16), fill=(12, 16))],
        relief=[dict(x=(18, 30), rows=(44, 63), k=2)],      # door set in
    )


HUT = _hut()

RECIPES = {'pacifidlog_hut': HUT, 'soot_box2': SOOT_BOX2, 'soot_cone': SOOT_CONE, 'soot_box': SOOT_BOX, 'treehouse': TREEHOUSE, 'weather': WEATHER, 'museum2': MUSEUM2, 'devon2': DEVON2, 'birch_lab': BIRCH_LAB, 'mart2': MART2, 'center2': CENTER2, 'littleroot_house': LITTLEROOT_HOUSE, 'littleroot_house_may': LITTLEROOT_HOUSE_MAY, 'center': CENTER, 'devon': DEVON, 'dept': DEPT, 'museum': MUSEUM}
