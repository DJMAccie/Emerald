"""Hand-authored tile tables for the rock classes Emerald 3DS has no tables for.

BROWN: the Fallarbor tileset's terrace (metatiles 0x268-0x27A), read by eye on
tools/relief/render.py (2026-10-18). Each id: the General tile it redraws (its
role), what it is. lib/Gen3RockTables.lua carries the same ids for the claim
rule; tests/gen3_relief_test.lua checks they agree.
"""
# own id -> (General twin the counter reads it as, role)
BROWN = {
    0x268: (0x07c, "face"),             # terrace face, dark strokes
    0x269: (0x07c, "face"),             # terrace face, banded
    0x26a: (0x074, "end"),              # diagonal edge, face turning south-east
    0x270: (0x070, "band"),             # dark vertical band (west/east side)
    0x278: (0x07c, "face"),             # face with a shadow wedge
    0x27a: (0x07d, "end"),              # diagonal face end
}
BROWN_TOPS = (0x271, 0x279)             # light ground the terrace stands on
BROWN_TREES = (0x26b, 0x26c, 0x273, 0x274)   # bushes in this tileset: out of scope
OWN_TWINS_BROWN = {m: t for m, (t, _) in BROWN.items()}

# RED: the Lavaridge tileset's rock (Route 112's east ridge, Mt. Chimney), read by eye on the
# tile sheet (2026-10-18). own id -> (General twin, role); the alias reading (emdata.alias_of)
# already maps these, the table pins them.
RED = {
    0x270: (0x073, "band"),             # dark band, west side
    0x272: (0x075, "band"),             # dark band, east side
    0x274: (0x07c, "face"),             # the face (Gen3Rock.FACE_TILE)
    0x278: (0x07b, "face"),             # face with a corner
    0x279: (0x079, "end"),              # arch / base of a face
    0x27a: (0x07d, "end"),
    0x27b: (0x074, "end"),
    0x27c: (0x089, "end"),
    0x289: (0x070, "band"),
}
RED_TOPS = (0x269, 0x271, 0x27d, 0x27e, 0x27f)   # light ground tops
