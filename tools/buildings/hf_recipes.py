"""Heightfield recipes for tools/buildings/hf.py.

Rows/x are in the building's own drawing (catalogue box + `crop` cell offsets).
`B` is the last facade row of a piece (ground contact at depth d0).  A piece is a
set of columns that share a path; `d0` may be a function of x (chamfers).
relief k > 0 pushes the pixel in (wall) / digs it down (roof); k < 0 pulls it out.
"""
import math

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
        # 40 deep where the roofs are drawn 32/33 rows: the 8 rows of extra depth carry the roof's own
        # courses (flatx), not a plain navy fill (which stood on every roof as a dark band)
        pieces=[
            dict(x=(32, 72), B=110, d0=0, segs=[('wall', 46), ('flatx', 32, 48, 8, 8)], side=(34, 44), back='front'),
            dict(x=(72, 152), B=110, d0=0, segs=[('wall', 69), ('flatx', 33, 25, 8, 8)], side=(73, 82), back='front'),
            dict(x=(152, 192), B=110, d0=0, segs=[('wall', 46), ('flatx', 32, 48, 8, 8)], side=(176, 186), back='front'),
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
            dict(x=(0, 8), B=63, d0=lambda x: 8 - x, segs=shoulder(0), side=(9, 14), fill=(9, 15), paint=(9, 14)),
            dict(x=(8, 16), B=63, d0=0, segs=shoulder(0), side=(9, 14), fill=(9, 15)),
            dict(x=(16, 48), B=63, d0=0, segs=mid(0), side=(9, 14), fill=(9, 15)),
            dict(x=(48, 56), B=63, d0=0, segs=shoulder(0), side=(9, 14), fill=(9, 15)),
            dict(x=(56, 64), B=63, d0=lambda x: x - 55, segs=shoulder(0), side=(9, 14), fill=(9, 15), paint=(9, 14)),
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
    # the glass bows: the drawing's bands slope about 0.45 rows per column
    # from the pilasters (x48, x128) out to the silhouette (x8, x167), so the
    # front steps back 0.45 voxel per column there and the bow's roof is cut
    # by its silhouette
    def bow(x0, x1, left):
        return lambda x: int(round(0.45 * ((x1 - x) if left else (x - x0))))
    segs = [('wall', 57), ('flat', 47)]
    return dict(
        src=('general__fortree', 'EM_ROUTE119', 1, 26, 11, 32), trim=True, flood=True,
        keys=ground,
        pieces=[
            dict(x=(8, 48), B=111, d0=bow(8, 48, True), segs=segs, side=(26, 34), fill=(26, 34)),
            dict(x=(48, 128), B=111, d0=0, segs=segs, side=(56, 72), fill=(56, 72)),
            dict(x=(128, 168), B=111, d0=bow(128, 168, False), segs=segs, side=(26, 34), fill=(26, 34)),
        ],
        relief=[
            dict(x=(70, 106), rows=(96, 111), k=3),   # doorway set in
            dict(x=(36, 140), rows=(66, 74), k=2),    # window bands set in
            dict(x=(36, 140), rows=(88, 96), k=2),
        ],
        # the two radar domes: three round drums of shrinking radius stand on
        # the roof (h 57 = roof), each painted from its own drawing rows 8..50
        prisms=[
            dict(x=(18, 46), d=(11, 39), h=(57, 62), B=111, mat=(40, 46), rows=(8, 50), round=True),
            dict(x=(21, 43), d=(14, 36), h=(62, 67), B=111, mat=(40, 46), rows=(8, 50), round=True),
            dict(x=(24, 40), d=(17, 33), h=(67, 71), B=111, mat=(40, 46), rows=(8, 50), round=True),
            dict(x=(130, 158), d=(11, 39), h=(57, 62), B=111, mat=(40, 46), rows=(8, 50), round=True),
            dict(x=(133, 155), d=(14, 36), h=(62, 67), B=111, mat=(40, 46), rows=(8, 50), round=True),
            dict(x=(136, 152), d=(17, 33), h=(67, 71), B=111, mat=(40, 46), rows=(8, 50), round=True),
            # the two small vents each side: 4-5 px drums on the roof
            dict(x=(12, 25), d=(7, 20), h=(57, 62), B=111, mat=(40, 46), rows=(30, 48), round=True),
            dict(x=(28, 38), d=(6, 16), h=(57, 61), B=111, mat=(40, 46), rows=(30, 48), round=True),
            dict(x=(151, 164), d=(7, 20), h=(57, 62), B=111, mat=(40, 46), rows=(30, 48), round=True),
            dict(x=(138, 148), d=(6, 16), h=(57, 61), B=111, mat=(40, 46), rows=(30, 48), round=True),
        ],
    )


WEATHER = _weather()


# Fortree tree house (House1: cells x8..12, y1..3). The hut stands on the
# plank deck (the deck row below is walkable ground the elevation already
# raises): log walls with the doorway under a leafy mound roof. The plank
# strips either side are the deck itself running back beside the hut (flat
# boardwalk on the ground, not stacked logs): no voxels, the scene's ground
# under the building shows them (a flat piece left stray pegs after the
# trim); the canopy around is cut away.
CANOPY = [(58, 82, 0), (58, 140, 49), (66, 58, 49), (107, 90, 90), (115, 197, 165), (132, 197, 99), (181, 255, 132)]
def _treehouse(x0):
    hut = [('wall', 26), ('slope', 10, 1.5), ('slope', 11, 0.3), ('mirror', 21)]
    return dict(
        src=('general__fortree', 'EM_FORTREE_CITY', x0, 1, x0 + 4, 3), trim=True, bgtiles=[0x0C6, 0x0C7, 0x017], keys=[],
        pieces=[dict(x=(18, 62), B=47, d0=0, segs=hut, side=(22, 32), fill=(28, 32))],   # (side: the ringed post and the plank wall beside it)
        relief=[dict(x=(30, 52), rows=(26, 46), k=4),    # the dark doorway goes in
                dict(x=(24, 26), rows=(23, 46), k=-1),   # the yellow corner posts stand proud
                dict(x=(54, 56), rows=(23, 46), k=-1),
                dict(x=(27, 53), rows=(24, 26), k=-1)],  # the lintel beam over the door stands proud
        anchor_skip_cells=[(0, 0), (4, 0)],   # corner canopy differs between houses
    )


TREEHOUSE = _treehouse(8)


# Mossdeep Space Center (cells x60..68, y2..15; drawing 144x224). The drawing
# reads as: an 80-row front wall (rows 144..223) under a 48-row flat roof
# (rows 96..143) carrying a dome, a big dish, a small dish and the stair up
# the middle to the launch deck at its back edge, where the rocket (86 rows),
# two 96-row gantry towers with arms reaching for it and a small 32-row tower
# stand (h0: on the roof, 80 up; the same drawing as standing on the ground
# behind, but it towers over the building from every side as the art does). Those stand as 16-thick cards of their own pixels, the
# sea and grass round them cut away; the rows over the sea (y2..7) stay their
# own cells (claimFrom), so the water is still water.
def _space_center():
    return dict(
        src=('general__mossdeep', 'EM_MOSSDEEP_CITY', 60, 2, 68, 15), trim=True,
        # sea and grass colours are ground everywhere (also seen through the
        # gantries' lattice); the building never uses them
        keys=[(82, 107, 214), (107, 132, 214), (66, 181, 132), (115, 197, 165), (165, 214, 197),
              (156, 115, 115), (132, 90, 90), (189, 148, 140)], claimFrom=6,   # + the shoreline
        pieces=[dict(x=(14, 114), B=223, d0=48, h0=80, segs=[('wall', 96)], tail=16, back='front', cutout=True),
                dict(x=(0, 144), B=223, d0=0, segs=[('wall', 80), ('flat', 48)], back='front')],
        relief=[dict(x=(64, 80), rows=(144, 200), k=-4),    # the glass tower stands out
                dict(x=(56, 88), rows=(201, 223), k=2),     # the entrance goes in
                dict(x=(16, 56), rows=(97, 131), k=-8),     # dome on the roof
                dict(x=(86, 122), rows=(97, 124), k=-6),    # big dish
                dict(x=(128, 141), rows=(128, 142), k=-4)], # small dish
    )


SPACE_CENTER = _space_center()


# Mossdeep's red two-storey houses (b056/b059/b061/b062/b063, one drawing,
# 4x4 cells). Read as: ground storey with door and window (rows 36..63, 28
# tall), the balcony ledge (rows 32..35, 4 deep), the red upper storey with
# its white posts and the roof railing standing on top (rows 0..31, 32 tall),
# then the house runs back 40 px more in its own material (the automatic read
# was a 1-cell-deep box; user: make them deeper).
# The Abandoned Ship's wreck on Route 108 (cells x27..33, y3..5; drawing
# 112x48): a hull whose waterline side is the dark green band (rows 38..46, 9
# tall) under its deck (rows 16..37, running back from the pointed bow), and
# the cabin block standing on the deck (front wall rows 28..36 with its
# windows, striped roof rows 10..27). The sea and shoal colours round it are
# ground; only the wreck's blocked cells are claimed (claimBlocked), so the
# sea under and round it stays water. The gangway (row y6) stays drawn.
WRECK_SEA = [(156, 165, 189), (173, 197, 230), (82, 107, 214), (189, 206, 230)]
def _wreck():
    return dict(
        src=('general__slateport', 'EM_ROUTE108', 27, 3, 33, 5), trim=True,
        keys=WRECK_SEA, claimBlocked=True,
        pieces=[dict(x=(0, 90), B=46, d0=0, segs=[('wall', 9), ('flat', 'top')], side=(30, 34), fill=(30, 34)),
                dict(x=(24, 76), B=46, d0=1, h0=9, segs=[('wall', 9), ('flat', 'top')], side=(30, 34), fill=(30, 34)),
                # the cabin's siding is a tall front, not a roof: 8 more rows of wall
                # over x 24..60 (the cream ribs at x 61..73 run back as the roof they are)
                dict(x=(24, 61), B=46, d0=1, h0=18, segs=[('wall', 8), ('flat', 'top')], side=(30, 34), fill=(30, 34)),
                # the pointed bow: its rounded front stands 4 back from the deck edge
                dict(x=(0, 24), B=46, d0=4, h0=9, segs=[('wall', 14), ('flat', 'top')], side=(4, 14), fill=(4, 14)),
                # the aft house: its horizontal siding is a front wall, flush with the hull, as tall as the
                # cabin (h 26); its roof runs 4 back (the rock hides the rest)
                dict(x=(74, 90), B=46, d0=0, h0=9, segs=[('wall', 17), ('flat', 4)], side=(76, 84), fill=(76, 84))],
        # the aft house is a box behind its front: 8 deep, painted from its siding
        prisms=[dict(x=(74, 87), d=(1, 9), h=(9, 26), B=46, rows=(17, 37), mat=(80, 30))],
        relief=[],
    )


WRECK = _wreck()


# Trainer Hill's rooftop penthouse (cells x7..17, y0..6 of the roof map): a
# glass box whose front (the doors and windows, drawing rows 56..95, 40 tall)
# stands under its faceted teal roof (rows 0..55), on the pink terrace tiles
# (0x36B, cut away). Built as a model on this indoor map (indoor=True).
# The Seagallop ferry moored at Birth Island and Navel Rock (Dewford tiles,
# 7x5 cells): its white hull front (rows 64..79, 16 tall) under the orange
# striped deck awning seen from above (rows 0..63), the crane arms either side;
# the sea round it is ground and stays water (claimBlocked).
FERRY_SEA = [(82, 107, 214), (107, 132, 214), (74, 99, 206), (115, 140, 222), (90, 115, 222)]
def _ferry(mp, x0, y0):
    return dict(
        src=('general__dewford', mp, x0, y0, x0 + 6, y0 + 4), trim=True, bgtiles=[0x170, 0x189], keys=[],
        claimBlocked=True,
        # the hull (white, rows 64..79) to h 16, the cabin front (windows, rows 55..63)
        # to h 25, then the striped deck at h 25 running back to row 9; the drawn
        # deck is x 16..95 only, the lifeboat crates stand outboard of it
        pieces=[dict(x=(16, 96), B=79, d0=0, segs=[('wall', 16), ('wall', 9), ('flat', 46)], side=(50, 54), fill=(50, 54), back='front')],
        # the wheelhouse on the deck's back edge (rows 0..8, x 33..78): its white front
        # is depth 46 and it is 6 high (h 25..31)
        prisms=[dict(x=(33, 79), d=(46, 50), h=(25, 31), B=79, rows=(0, 9), mat=(55, 5)),
                # lifeboats in their davits, one each side and two tiers each (rows 18..42 and 50..74)
                dict(x=(1, 16), d=(32, 46), h=(5, 30), B=79, rows=(17, 43), mat=(3, 19)),
                dict(x=(96, 111), d=(32, 46), h=(5, 30), B=79, rows=(17, 43), mat=(3, 19)),
                dict(x=(1, 16), d=(0, 14), h=(5, 30), B=79, rows=(49, 75), mat=(3, 19)),
                dict(x=(96, 111), d=(0, 14), h=(5, 30), B=79, rows=(49, 75), mat=(3, 19))],
        relief=[])


TRAINER_HILL_PENTHOUSE = dict(
    src=('building__trainer_hill', 'EM_TRAINER_HILL_ROOF', 7, 0, 17, 6), trim=True,
    bgtiles=[0x36B], keys=[], indoor=True,
    # the front is a chevron: its foot runs from row 107 at the middle column up
    # to row 67 at both ends (40 rows over 88 px), so each column starts that
    # much further back; B is the drawing's last row, where the game puts depth 0
    pieces=[dict(x=(0, 176), B=111, d0=lambda x: 4 + int(round(abs(x - 88) * 40 / 88.0)),
                 segs=[('wall', 28), ('flat', 'top')], side=(40, 44), fill=(40, 44), back='front')],
    relief=[dict(x=(44, 66), rows=(64, 95), k=3), dict(x=(110, 136), rows=(64, 95), k=3)],
)


MOSSDEEP_HOUSE_BOXES = {'b056_mossdeepcity_house1': (27, 6), 'b059_mossdeepcity_house2': (66, 22),
                        'b061_mossdeepcity_house3': (48, 3), 'b062_mossdeepcity_stevenshouse': (18, 7),
                        'b063_mossdeepcity_house4': (17, 13)}
def _mossdeep_house(x0, y0):
    return dict(
        src=('general__mossdeep', 'EM_MOSSDEEP_CITY', x0, y0, x0 + 3, y0 + 3), trim=True,
        bgtiles=[0x001, 0x002, 0x00A, 0x00B], keys=[],
        pieces=[dict(x=(0, 64), B=63, d0=0, segs=[('wall', 28), ('flat', 4), ('wall', 32)], tail=40, roofRow=34,
                     side=(36, 60), fill=(12, 16))],   # (sides and back: the window bay, wall-window-wall,
                                                      # not the front again: that put the door on the back)
        relief=[dict(x=(16, 31), rows=(42, 63), k=2),     # the door set in
                dict(x=(40, 56), rows=(41, 52), k=2)],    # the window set in
    )


# Sootopolis houses (3x4 cells each). Ground = the crater rock tiles around.
SOOT_BG = [0x2D9, 0x2E1, 0x2D4, 0x2D8, 0x2E0, 0x2E2, 0x254, 0x255, 0x25E, 0x25F, 0x242, 0x241, 0x2D3, 0x2DA]
def _soot_cone(x0, y0):
    """Spire house (House1 kind): an octagonal white base under an eight-sided pyramid of dark stone.
    It was a round drum under stepped round tiers, which is not what the drawing shows. Measurements
    from Emerald 3DS's sootopolis_spire (MIT): base 22 high on the octagon x 0-48, depth 0-39 with
    8 px corners cut; the spire's base octagon x 4-44, depth 6-40, its apex 48 high over x 24,
    depth 23 (art row 8)."""
    base = dict(shape='plan', poly=[(8, 0), (40, 0), (48, 8), (48, 31), (40, 39), (8, 39), (0, 31), (0, 8)],
                h=(0, 22), B=79, mat=(5, 66), side=(2, 7, 58, 71), corner=(0, 1))   # (the outline at each vertex)
    spire = dict(shape='pyramid', poly=[(13, 40), (35, 40), (44, 29), (44, 14), (37, 6), (11, 6), (4, 14), (4, 29)],
                 h0=22, apex=(24, 23, 48), B=79, mat=(24, 24), side=(16, 34))
    return dict(
        src=('general__sootopolis', 'EM_SOOTOPOLIS_CITY', x0, y0, x0 + 2, y0 + 4), trim=True, bgtiles=SOOT_BG, keys=[],
        volumes=[base, spire],
        # the two dark pillars stand proud of the base, painted from their own drawing rows
        prisms=[dict(x=(9, 14), d=(-2, 1), h=(0, 23), B=77, rows=(56, 79), mat=(10, 70)),
                dict(x=(34, 39), d=(-2, 1), h=(0, 23), B=77, rows=(56, 79), mat=(38, 70))],
    )


def _proud(x, rows, n, mat, B=79):
    """A strip of the front standing n px proud (a porch, a pilaster, a badge): a box in front of the
    wall whose face shows its own drawing rows (B shifted by n so the rows stay where they are drawn)."""
    return dict(x=x, d=(-n, 0), h=(B + 1 - rows[1], B + 1 - rows[0]), B=B - n, rows=rows, mat=mat)


def _soot_box(x0, y0, front):
    """Flat-roofed white house (House2 kind): a block 30 high and 34 deep whose flat roof carries the
    drawn skylight grid (Emerald 3DS's sootopolis_flat_house, MIT). Its roof had been relief pushed up
    into a parapet that read as battlements; now the roof is flat and the grid lies on it."""
    house = dict(shape='plan', poly=[(0, 0), (48, 0), (48, 34), (0, 34)], h=(0, 30), B=79, mat=(4, 55),
                 side=(3, 13, 50, 78), corner=(1, 7))   # (pilaster columns 9-11 repeat along the sides: a plain stucco side read as a flat slab) (outline, highlight, stucco, shadow: the front's corner)
    return dict(
        src=('general__sootopolis', 'EM_SOOTOPOLIS_CITY', x0, y0, x0 + 2, y0 + 4), trim=True, bgtiles=SOOT_BG, keys=[],
        volumes=[house], prisms=front,
        anchor_skip_cells=[(0, 2)],                          # left corner tile varies between houses
    )


# The Battle Dome (cells x14..25, y6..17; drawing 192x192). It was read as a gable roof, and from
# behind its ribs stood as a comb of slabs. Rebuilt after Emerald 3DS's battle_dome (MIT): a white
# superellipse dome 92 high on an ellipse 98 by 70 (p 2.6), its far half wearing the near half's
# drawing (ribs and the orange rim, mirrored), standing within a two-tier glass base (24 then 48
# high) with the porch in front. 3DS coordinates (art 208x224 from map row 4) converted: x = X - 8,
# d = 224 - Z. Its crown rises past the drawing's top row (the cell rect starts two rows lower),
# so the crown takes the dome's own white.
def _frontier_dome():
    # (2026-10-18: the drawing is not symmetric - its west foot stands out to the drawing's edge, its east foot
    # recedes behind the glass base with lawn beside it - so the west half is squarer, pl 3.4, and the east half
    # a little narrower, 93: the round foot laid in voxels had stood as a 1 px stair on both corners)
    dome = dict(shape='dome', c=(96, 78), r=(98, 70), p=2.6, pl=3.4, rxr=93, top=92, B=191, mat=(96, 40), mirror=78)
    glass = lambda x0, x1, d0, d1, h: dict(shape='plan', poly=[(x0, d0), (x1, d0), (x1, d1), (x0, d1)], h=(0, h),
                                           B=191, mat=(x0 + 8, 191 - d0 - h // 2), side=(x0 + 4, x0 + 20))
    return dict(
        src=('general__battle_frontier_outside_west', 'EM_BATTLE_FRONTIER_OUTSIDE_WEST', 14, 6, 25, 17), trim=True,
        keys=[(115, 197, 165), (66, 181, 132), (165, 214, 197)],   # the lawn round it is ground, never dome
        volumes=[glass(16, 176, 8, 54, 24), glass(32, 160, 24, 64, 48), glass(72, 120, 0, 28, 30), dome],
    )


FRONTIER_DOME = _frontier_dome()


def _oct(x0, x1, d0, d1, cut):
    """A plan octagon (x, d): the rectangle with its corners cut."""
    return [(x0 + cut, d0), (x1 - cut, d0), (x1, d0 + cut), (x1, d1 - cut), (x1 - cut, d1),
            (x0 + cut, d1), (x0, d1 - cut), (x0, d0 + cut)]


# The Battle Factory (cells x4..18, y30..38; drawing 240x144). It was read as one wavy block whose
# sides and back were horizontal streaks. Rebuilt after Emerald 3DS's battle_factory (MIT):
# octagonal towers side by side, flat topped, their corners cut - the middle one (x 87-153) 101
# high, the outer pairs 80 - and a fence line down each end. 3DS z converted: d = 144 - z.
def _frontier_factory():
    side = (100, 108)
    tower = lambda x0, x1, d0, d1, cut, h: dict(shape='plan', poly=_oct(x0, x1, d0, d1, cut), h=(0, h), B=143,
                                               mat=(120, 60), side=side, corner=(x0, x0 + 1))
    return dict(
        src=('general__battle_frontier_outside_west', 'EM_BATTLE_FRONTIER_OUTSIDE_WEST', 4, 30, 18, 38), trim=True, keys=[],
        volumes=[tower(87, 153, 0, 43, 8, 101),
                 tower(8, 64, 8, 48, 8, 80), tower(176, 232, 8, 48, 8, 80),
                 tower(60, 92, 8, 48, 6, 80), tower(148, 180, 8, 48, 6, 80),
                 dict(shape='plan', poly=[(0, 0), (8, 0), (8, 84), (0, 84)], h=(0, 14), B=143, mat=(4, 136), side=(0, 8)),
                 dict(shape='plan', poly=[(232, 0), (240, 0), (240, 84), (232, 84)], h=(0, 14), B=143, mat=(236, 136), side=(232, 240))],
    )


FRONTIER_FACTORY = _frontier_factory()


# The Battle Pyramid (cells x51..65, y5..14; drawing 240x160). After Emerald 3DS's battle_pyramid
# (MIT): thirteen tiers 8 high, each 8 in on the sides and 4 in front and back (the base x 8-232,
# depth 0-104), the portico before the entrance and its tower, the chain-fence posts either side.
# 3DS z converted: d = 160 - z (its drawing is a row taller; the steps before the door stand on
# that row, outside this cell rect, and are the map's own).
def _frontier_pyramid():
    box = lambda x0, x1, d0, d1, h0, h1, sd: dict(shape='plan', poly=[(x0, d0), (x1, d0), (x1, d1), (x0, d1)],
                                                  h=(h0, h1), B=159, mat=(120, 80), side=sd)
    # (each tier's hidden faces take its own front band's rows, never the sand above it)
    vols = [box(8 + 8 * i, 232 - 8 * i, 4 * i, 104 - 4 * i, 8 * i, 8 * i + 8,
                (16 + 8 * i, 32 + 8 * i, 152 - 12 * i, 160 - 12 * i)) for i in range(13)]
    vols += [box(40, 200, 0, 20, 0, 20, (60, 76)), box(104, 136, 0, 40, 0, 40, (60, 76)),
             box(0, 16, 0, 130, 0, 10, (2, 6)), box(224, 240, 0, 130, 0, 10, (226, 230))]
    return dict(src=('general__battle_frontier_outside_east', 'EM_BATTLE_FRONTIER_OUTSIDE_EAST', 51, 5, 65, 14),
                trim=True, keys=[], volumes=vols)


FRONTIER_PYRAMID = _frontier_pyramid()


# The Battle Pike (cells x40..44, y19..29; drawing 80x176): Seviper lying on the ground, the open
# mouth the door. It stood as a banded box. After Emerald 3DS's battle_pike_volume (MIT): the body
# a tube (r 26-30) along the middle, the tail lying behind it and curling west, the head a broad
# dome, the yellow fins along its sides, the tongue a carpeted ramp. 3DS z converted: d = 208 - z
# (its drawing starts two rows higher: the tail's tip lies on rows 17-18, outside this cell rect,
# so the tail is cut at the rect's back edge). Hidden faces carry its back's pattern round.
def _frontier_pike():
    fins = [(8, 112), (72, 112), (6, 92), (74, 92), (8, 80), (72, 80), (10, 58), (70, 58)]
    parts = [('tube', [(40, 20, 112, 26), (40, 22, 88, 28), (40, 24, 58, 30)]),
             ('tube', [(44, 12, 118, 14), (54, 12, 146, 13.5), (50, 12, 170, 12.5), (48, 12, 176, 11.3)]),
             ('dome', 40, 34, 38, 30, 44, 2.0)] + [('dome', x, d, 9, 9, 16, 2.0) for x, d in fins] + \
            [('box', 24, 56, 0, 8, 0, 32)]
    return dict(src=('general__battle_frontier_outside_west', 'EM_BATTLE_FRONTIER_OUTSIDE_WEST', 40, 19, 44, 29), trim=True,
                keys=[(115, 197, 165), (189, 189, 189), (214, 214, 214), (165, 165, 165), (165, 214, 197)],
                volumes=[dict(shape='union', parts=parts, B=175, mat=(20, 60), carry=(40, .3), carve=True)])


FRONTIER_PIKE = _frontier_pike()


def _rounded_plan(cx, cd, rx, rd, p=4.0, n=32):
    """A superellipse plan polygon (x, d), its corners rounded (3DS's rounded_plan)."""
    pts = []
    for k in range(n):
        t = 2 * math.pi * k / n
        c, s_ = math.cos(t), math.sin(t)
        pts.append((cx + rx * math.copysign(abs(c) ** (2 / p), c), cd + rd * math.copysign(abs(s_) ** (2 / p), s_)))
    return pts


# The Battle Frontier's small houses and lounges (48 or 96 wide). They were boxes whose sides were
# the roof's red stripes stacked. After Emerald 3DS's frontier_house (MIT): a rounded block 36 high,
# its plan a superellipse (front at depth 0.3, 28 deep), the flat orange roof and the red band on
# top, the walls its front; the door ones take their wall beside the door round the sides, the
# glass ones their glass. 3DS z converted: d = 64 - z (the drawings are bottom-aligned).
def _frontier_house(mp, pair, x0, y0, x1, y1, glass):
    W, H = (x1 - x0 + 1) * 16, (y1 - y0 + 1) * 16
    plan = _rounded_plan(W / 2.0, 14.5, W / 2.0 + .6, 14.2, p=10.0 if W <= 48 else 14.0, n=32 if W <= 48 else 48)
    side = (20, 28) if glass else (10, 18)
    return dict(src=(pair, mp, x0, y0, x1, y1), trim=True, keys=list(GRASS),
                volumes=[dict(shape='plan', poly=plan, h=(0, 36), B=H - 1, mat=(side[0] + 2, H - 12), side=side)])


_FW, _FE = ('EM_BATTLE_FRONTIER_OUTSIDE_WEST', 'general__battle_frontier_outside_west'), ('EM_BATTLE_FRONTIER_OUTSIDE_EAST', 'general__battle_frontier_outside_east')
FRONTIER_HOUSES = {
    'b143_battlefrontier_lounge2': _frontier_house(*_FW, 44, 41, 49, 44, False),
    'b145_battlefrontier_scottshouse': _frontier_house(*_FW, 43, 2, 45, 5, False),
    'b146_battlefrontier_lounge4': _frontier_house(*_FW, 52, 42, 54, 44, True),
    'b147_battlefrontier_lounge7': _frontier_house(*_FW, 4, 17, 6, 20, True),
    'b155_battlefrontier_lounge1': _frontier_house(*_FE, 3, 42, 5, 44, True),
    'b157_battlefrontier_lounge5': _frontier_house(*_FE, 21, 48, 26, 51, False),
    'b158_battlefrontier_lounge6': _frontier_house(*_FE, 4, 6, 6, 8, True),
    'b159_battlefrontier_lounge3': _frontier_house(*_FE, 64, 28, 66, 31, False),
    'b160_battlefrontier_lounge8': _frontier_house(*_FE, 13, 49, 15, 51, True),
}
SOOT_CONE = _soot_cone(8, 2)
# the porch round the door and the pilasters either side of it stand out
SOOT_BOX = _soot_box(44, 2, [_proud((14, 34), (50, 80), 2, (4, 55)), _proud((9, 11), (50, 80), 2, (4, 55)),
                             _proud((37, 39), (50, 80), 2, (4, 55))])
# the same box with a diamond front and no door (no warp; the town's extra buildings): wall pilasters and
# the stepped diamond badge stand out
SOOT_BOX2 = dict(_soot_box(2, 5, [_proud((3, 6), (50, 77), 1, (4, 55)), _proud((43, 46), (50, 77), 1, (4, 55)),
                                  _proud((21, 27), (58, 60), 1, (4, 55)), _proud((19, 29), (61, 67), 1, (4, 55)),
                                  _proud((21, 27), (68, 70), 1, (4, 55))]),
                 anchor_skip_cells=[])


# Pacifidlog hut (every hut is the same drawing; cells x15..17, y10..13 of the
# first): a round woven wall under a thatch cone with its finial, on the raft.
# Raft planks and sea are the ground.
def _hut():
    """Measurements from Emerald 3DS's pacifidlog_hut (MIT): the wall 21 high on a rounded plan half
    as deep as wide (superellipse, centre x 24 depth 10.5, radii 21 x 11); the thatch a cone and its
    finial whose eave overhangs the wall, its foot lifted 21 along the view (centre depth 12). It was
    a drum 40 deep under a dome of rings, twice too deep and without the finial."""
    wall = dict(shape='super', c=(24, 10.5), r=(21, 11), p=8.0, h=(0, 21), B=63, mat=(9, 45),
                wrap=(0, 5, 46, 59))                 # the golden weave with one blue post runs round it
    # (2026-10-18: squash .54 -> .47: the eave's front corners stood 1-2 px outside the drawn eave, a 1 px stair)
    thatch = dict(shape='lathe', c=(24, 12), h0=21, squash=.47, B=63, mat=(21, 10), wrap=(9, 21, 26, 32),
                  prof=[[(0, 25.5), (3, 25.5), (4, 24), (16, 2.5), (17.5, 0)],             # the cone, eave first
                        [(13, 3.5), (19, 3.5), (21, 7), (28, 7), (31, 4), (33, 0)]])        # the finial
    return dict(
        src=('general__pacifidlog', 'EM_PACIFIDLOG_TOWN', 15, 10, 17, 13), trim=True, flood=True,
        # the top row of the square is sea behind the hut: the model draws it but the cells stay water
        claimFrom=1,
        # the golden wall weave is not ground: only the pale raft edge and the sea are keys
        keys=[(239, 230, 165)] + [(82, 107, 214), (107, 132, 214)],
        volumes=[wall, thatch],
        # the door stands a pixel proud of the wall, painted from its own drawing rows
        prisms=[dict(x=(18, 30), d=(-2, 0), h=(0, 20), B=63, rows=(44, 64), mat=(9, 45))],
    )


HUT = _hut()

# The Battle Frontier's entrance hall on the west pier (cells x23..29,
# y61..65; drawing 112x80): two round-ended wings, each a blue glass front
# (rows 63..79, 17 tall) under a red canopy band and a peach drum roof seen
# from above, and between them the entrance with the Frontier crest standing
# taller over the doors. The paving round it is ground.
def _frontier_gate():
    wing = [('wall', 17), ('wall', 10), ('flat', 'top')]
    mid = [('wall', 17), ('wall', 20), ('flat', 'top')]
    return dict(
        src=('general__battle_frontier_outside_west', 'EM_BATTLE_FRONTIER_OUTSIDE_WEST', 23, 61, 29, 65), trim=True,
        bgtiles=[0x05E], keys=[], claimBlocked=True,
        pieces=[dict(x=(0, 6), B=79, d0=lambda x: 6 - x, segs=wing, side=(30, 34), fill=(30, 34)),
                dict(x=(6, 40), B=79, d0=0, segs=wing, side=(30, 34), fill=(30, 34)),
                dict(x=(40, 72), B=79, d0=2, segs=mid, side=(30, 34), fill=(30, 34)),
                dict(x=(72, 106), B=79, d0=0, segs=wing, side=(30, 34), fill=(30, 34)),
                dict(x=(106, 112), B=79, d0=lambda x: x - 105, segs=wing, side=(30, 34), fill=(30, 34))],
        relief=[dict(x=(46, 66), rows=(62, 79), k=3)],      # the doors set in
    )


FRONTIER_GATE = _frontier_gate()


# The Battle Palace lobby (cells x40..49, y51..55; drawing 176x96). Depth 0 is the
# centre entrance's carpet (row 95); the wings and the middle run back 31 px to
# their plinth (row 64), the flower beds in front are ground props and stay out.
# Three hipped roofs stand on the walls, each a stack of boxes: the eave layer
# overhangs the front by 3, every layer is one px smaller on each side and higher
# (side roofs 2 px a layer, the tall centre roof 1), so they read as pyramids
# from the side and the back. Their faces are the drawing's own rows; the roof
# brown (12,8) is the material behind the drawn rows and above the picture's top.
def _palace_lobby():
    B = 95
    def pyr(x0, x1, d0, d1, h0, K, r, rows):
        return [dict(x=(x0 + k, x1 - k), d=(d0 + k, d1 - k), h=(h0 + r * k, h0 + r * (k + 1)), B=B, rows=rows, mat=(12, 8))
                for k in range(K + 1)]
    return dict(
        src=('general__battle_frontier_outside_east', 'EM_BATTLE_FRONTIER_OUTSIDE_EAST', 40, 51, 50, 56), trim=True, keys=GRASS,
        pieces=[dict(x=(0, 48), B=B, d0=31, segs=[('wall', 36), ('flat', 35)], side=(40, 48), fill=(40, 48), back='front'),
                dict(x=(48, 128), B=B, d0=31, segs=[('wall', 29), ('flat', 45)], side=(40, 48), fill=(48, 56), back='front'),
                dict(x=(128, 176), B=B, d0=31, segs=[('wall', 36), ('flat', 35)], side=(128, 136), fill=(128, 136), back='front'),
                dict(x=(64, 112), B=B, d0=0, segs=[('wall', 43), ('flat', 34)], side=(66, 72), fill=(66, 72), back='front')],
        relief=[dict(x=(80, 96), rows=(65, 82), k=3),                       # the arched doorway set in
                dict(x=(73, 80), rows=(56, 95), k=-2), dict(x=(96, 103), rows=(56, 95), k=-2),   # centre columns
                dict(x=(16, 24), rows=(42, 56), k=2), dict(x=(152, 160), rows=(42, 56), k=2)]    # arched windows
        + [dict(x=(a, a + 8), rows=(32, 64), k=-2) for a in (0, 32, 56, 112, 136, 168)],          # wing columns
        prisms=pyr(1, 40, 28, 66, 36, 10, 2, (0, 32)) + pyr(136, 175, 28, 66, 36, 10, 2, (0, 32))
             + pyr(48, 128, 28, 66, 29, 21, 1, (0, 39))            # the tall centre roof behind (its walls run back 36)
             + pyr(62, 114, -3, 33, 43, 17, 1, (0, 56)))           # the pavilion over the entrance


PALACE_LOBBY = _palace_lobby()

RECIPES = {'frontier_gate': FRONTIER_GATE, 'ferry_birth_island': _ferry('EM_BIRTH_ISLAND_EXTERIOR', 12, 24), 'ferry_navel_rock': _ferry('EM_NAVEL_ROCK_EXTERIOR', 7, 18),
           'trainer_hill_penthouse': TRAINER_HILL_PENTHOUSE, 'abandoned_ship_wreck': WRECK, 'b064_mossdeepcity_spacecenter': SPACE_CENTER,
           **{k: _mossdeep_house(*v) for k, v in MOSSDEEP_HOUSE_BOXES.items()}, 'pacifidlog_hut': HUT, 'soot_box2': SOOT_BOX2, 'soot_cone': SOOT_CONE, 'frontier_dome': FRONTIER_DOME, 'frontier_factory': FRONTIER_FACTORY, 'frontier_pyramid': FRONTIER_PYRAMID, 'frontier_pike': FRONTIER_PIKE, **FRONTIER_HOUSES, 'soot_box': SOOT_BOX, 'treehouse': TREEHOUSE, 'weather': WEATHER, 'museum2': MUSEUM2, 'devon2': DEVON2, 'birch_lab': BIRCH_LAB, 'mart2': MART2, 'center2': CENTER2, 'littleroot_house': LITTLEROOT_HOUSE, 'littleroot_house_may': LITTLEROOT_HOUSE_MAY, 'center': CENTER, 'devon': DEVON, 'dept': DEPT, 'museum': MUSEUM, 'b152_battlefrontier_battlepalacelobby': PALACE_LOBBY}
