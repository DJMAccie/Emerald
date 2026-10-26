"""Pixel tools for the drawn flight frames (tools/flysprites/drawn/<nat>.py).

Frames are RGBA PIL images. Everything works on whole pixels (no smoothing), so the result stays pixel art:
- wings beat by SHEARING columns (each column of the wing moves up or down as a block), not by rotating;
- legs tuck by moving the bottom band up under the body;
- new pixels get an outline in the species' own outline colour.
Rows of a flight sheet: 0 down (facing the camera), 1 left, 2 right, 3 up (seen from behind).
"""
from PIL import Image

BEATS = ('up', 'mid', 'down', 'mid2')   # the four frames of one wing beat


def blank(w, h):
    return Image.new('RGBA', (w, h), (0, 0, 0, 0))


def on(img, x, y):
    if x < 0 or y < 0 or x >= img.size[0] or y >= img.size[1]:
        return False
    return img.getpixel((x, y))[3] >= 128


def pad(img, w, h, dx=None, dy=None):
    """img centred (or at dx, dy) on a w x h canvas."""
    out = blank(w, h)
    if dx is None:
        dx = (w - img.size[0]) // 2
    if dy is None:
        dy = h - img.size[1]
    out.paste(img, (dx, dy), img)
    return out


def over(base, top, dx=0, dy=0):
    out = base.copy()
    out.paste(top, (dx, dy), top)
    return out


def under(base, bottom, dx=0, dy=0):
    out = blank(*base.size)
    out.paste(bottom, (dx, dy), bottom)
    out.paste(base, (0, 0), base)
    return out


def outline(img, colour, only_new_of=None):
    """Add a 1 px outline (4-neighbour) around img's opaque pixels; with only_new_of, only where that image
    has nothing (so a wing gets an outline but the body's own edge is left alone)."""
    out = img.copy()
    px = out.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if on(img, x, y):
                continue
            if only_new_of is not None and on(only_new_of, x, y):
                continue
            if on(img, x - 1, y) or on(img, x + 1, y) or on(img, x, y - 1) or on(img, x, y + 1):
                px[x, y] = tuple(colour) + (255,)
    return out


def shear(img, pivot_x, slope, direction=1, pivot_y=None):
    """Shift each column by round((x - pivot_x) * slope) rows, for columns on one side of the pivot
    (direction=1: x > pivot_x, -1: x < pivot_x). slope < 0 raises the far end (wing up)."""
    w, h = img.size
    out = blank(w, h)
    src = img.load()
    dst = out.load()
    for x in range(w):
        d = (x - pivot_x) * direction
        dy = int(round(d * slope)) if d > 0 else 0
        for y in range(h):
            p = src[x, y]
            if p[3] and 0 <= y + dy < h:
                dst[x, y + dy] = p
    return out


def vstretch(img, root_y, k):
    """Scale rows about root_y by k (k < 0 flips below the root): a side-view wing seen raised or lowered."""
    w, h = img.size
    out = blank(w, h)
    src = img.load()
    dst = out.load()
    for y in range(h):
        sy = root_y + (y - root_y) / k if k != 0 else None
        if sy is None:
            continue
        sy = int(round(sy))
        if 0 <= sy < h:
            for x in range(w):
                p = src[x, sy]
                if p[3]:
                    dst[x, y] = p
    return out


def mask_colours(img, colours, region=None):
    """(wing, rest): pixels of the given colours (inside region x0,y0,x1,y1 if given) lifted out."""
    cols = {tuple(c) for c in colours}
    wing, rest = blank(*img.size), img.copy()
    src = img.load()
    wp, rp = wing.load(), rest.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            p = src[x, y]
            if not p[3] or p[:3] not in cols:
                continue
            if region and not (region[0] <= x < region[2] and region[1] <= y < region[3]):
                continue
            wp[x, y] = p
            rp[x, y] = (0, 0, 0, 0)
    return wing, rest


def mask_box(img, box):
    """(part, rest): everything inside box lifted out."""
    part, rest = blank(*img.size), img.copy()
    crop = img.crop(box)
    part.paste(crop, box[:2])
    rest.paste(blank(box[2] - box[0], box[3] - box[1]), box[:2])
    return part, rest


def tuck(img, from_y, by, colour_keep=None):
    """Legs up: the band from from_y down moves up by `by` rows and goes UNDER the body above it."""
    w, h = img.size
    legs, body = mask_box(img, (0, from_y, w, h))
    return under(body, legs, 0, -by)


def palette(img, n=12):
    counts = {}
    for p in img.getdata():
        if p[3]:
            counts[p[:3]] = counts.get(p[:3], 0) + 1
    return sorted(counts.items(), key=lambda kv: -kv[1])[:n]


def wing_flat(length, chord, colours, feathers=3, rise=0.25, tip_chord=2):
    """A spread wing seen from above/below, root at the left edge, pointing right (mirror for the other
    side). colours = (light leading edge, base, dark feather tips). Returns (image, root_y)."""
    light, base, dark = colours
    h = chord + int(length * rise) + 4
    img = blank(length, h)
    px = img.load()
    for x in range(length):
        u = x / max(1, length - 1)
        top = h - chord - 2 - int(round(x * rise))            # the leading edge climbs toward the tip
        c = max(tip_chord, int(round(chord + (tip_chord - chord) * u)))
        if u > .45 and feathers:                               # primaries: stepped tips along the trailing edge
            step = int((x * feathers * 2) / length) % 2
            c += 1 if step == 0 else 0
        for k in range(c):
            y = top + k
            if 0 <= y < h:
                col = light if k == 0 else (dark if k >= c - 1 and u > .25 else base)
                px[x, y] = tuple(col) + (255,)
    return img, h - chord - 2


def flip(img):
    return img.transpose(Image.FLIP_LEFT_RIGHT)


def beat_slopes(up=-0.6, down=0.5):
    """Column shear per beat frame: up, mid, down, mid."""
    return {'up': up, 'mid': 0.0, 'down': down, 'mid2': 0.0}


def spread_pair(body, canvas, shoulder, wing, root_y, slope, outline_colour, gap=0):
    """Front/back view: the body on a canvas with a wing out of each shoulder, beat by `slope`.
    shoulder = (left x, right x, y) on the body image (before centring on the canvas)."""
    W, H = canvas
    bx = (W - body.size[0]) // 2
    by = H - body.size[1]
    lx, rx, sy = shoulder
    wl = blank(W, H)
    wr = blank(W, H)
    wr.paste(wing, (bx + rx + 1 - gap, by + sy - root_y), wing)
    fl = flip(wing)
    wl.paste(fl, (bx + lx - fl.size[0] + gap, by + sy - root_y), fl)
    wr = shear(wr, bx + rx, slope, 1)
    wl = shear(wl, bx + lx, slope, -1)
    wings = over(wl, wr)
    wings = outline(wings, outline_colour)
    framed = pad(body, W, H, bx, by)
    return under(framed, wings)


def darker(img, k=0.7):
    out = img.copy()
    px = out.load()
    for y in range(out.size[1]):
        for x in range(out.size[0]):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (int(r * k), int(g * k), int(b * k), a)
    return out


def rotated(wing, root_y, deg):
    """The wing turned `deg` degrees counter-clockwise about its root (left edge, root_y), on a square
    canvas whose centre is the root. Returns (image, centre)."""
    n = 2 * max(wing.size) + 4
    sq = blank(n, n)
    c = n // 2
    sq.paste(wing, (c, c - root_y), wing)
    return sq.rotate(deg, resample=Image.NEAREST, center=(c, c)), c


SIDE_ANGLES = {'up': 62, 'mid': 14, 'down': -38, 'mid2': 14}


def side_wing(body, canvas, root, wing, root_y, beat, outline_colour, head_left=True, far=True, angles=None):
    """Side view: the near wing out of the back at root=(x, y) (body image coordinates): raised, level or
    lowered for the beat; the far wing shows above the back on the up beat (darker, behind)."""
    W, H = canvas
    bx = (W - body.size[0]) // 2
    by = H - body.size[1]
    ang = (angles or SIDE_ANGLES)[beat]
    img, c = rotated(wing, root_y, ang)
    if not head_left:
        img = flip(img)
    layer = blank(W, H)
    layer.paste(img, (bx + root[0] - c, by + root[1] - c), img)
    layer = outline(layer, outline_colour)
    framed = pad(body, W, H, bx, by)
    out = over(framed, layer)
    if far and beat in ('up', 'mid', 'mid2'):
        fimg, fc = rotated(wing, root_y, ang + (8 if beat == 'up' else 4))
        if not head_left:
            fimg = flip(fimg)
        fl = blank(W, H)
        dx = -2 if head_left else 2
        fl.paste(fimg, (bx + root[0] - fc + dx, by + root[1] - fc - 1), fimg)
        fl = outline(darker(fl, .72), outline_colour)
        out = under(out, fl)
    return out


def build_spread(base, p):
    """All four rows x four beats for a species whose wings are folded on the follower sprite.
    p: canvas (W, H); wing dict(length, chord, colours, feathers, rise); outline colour; tuck {row: (from_y, by)};
    shoulder_frac (0..1 down the body for the shoulder line); side_len (share of the wing length shown from the
    side); slopes (front/back beat shear); body_frame (which follower column is the body)."""
    W, H = p['canvas']
    wing, root_y = wing_flat(**p['wing'])
    sw = p.get('side_len', .8)
    side, side_root = wing_flat(**dict(p['wing'], length=max(4, int(p['wing']['length'] * sw)),
                                       chord=p['wing']['chord'] + p.get('side_chord_add', 2)))
    slopes = p.get('slopes') or beat_slopes()
    rows = []
    for r in range(4):
        body = base['frames'][r][p.get('body_frame', 0)]
        if r in p.get('tuck', {}):
            body = tuck(body, *p['tuck'][r])
        bb = body.getchannel('A').getbbox()
        frames = []
        for beat in BEATS:
            if r in (0, 3):
                inset = p.get('shoulder_inset', 2)
                sy = bb[1] + int((bb[3] - bb[1]) * p.get('shoulder_frac', .4))
                f = spread_pair(body, (W, H), (bb[0] + inset, bb[2] - 1 - inset, sy), wing, root_y,
                                slopes[beat], p['outline'])
            else:
                head_left = (r == 1)
                cx = (bb[0] + bb[2]) // 2 + (p.get('side_back', 1) if head_left else -p.get('side_back', 1))
                sy = bb[1] + int((bb[3] - bb[1]) * p.get('side_frac', .35))
                f = side_wing(body, (W, H), (cx, sy), side, side_root, beat, p['outline'], head_left,
                              far=p.get('far', True), angles=p.get('side_angles'))
            frames.append(f)
        rows.append(frames)
    return {'frames': rows, 'durations': None}


def shear_both(img, left_pivot, right_pivot, slope):
    """Both wings of a front/back sprite beat: columns left of left_pivot and right of right_pivot shift by
    their distance from the pivot times slope (slope < 0 raises the tips)."""
    return over(shear(img, left_pivot, slope, -1), shear(img, right_pivot, slope, 1))


def stretch_out(img, left_pivot, right_pivot, k):
    """The columns outside the pivots pulled outward by k (nearest): longer wings, same pixel size."""
    w, h = img.size
    out = blank(w, h)
    src = img.load()
    dst = out.load()
    for x in range(w):
        if x < left_pivot:
            sx = left_pivot - int(round((left_pivot - x) / k))
        elif x > right_pivot:
            sx = right_pivot + int(round((x - right_pivot) / k))
        else:
            sx = x
        if 0 <= sx < w:
            for y in range(h):
                if src[sx, y][3]:
                    dst[x, y] = src[sx, y]
    return out


def swing(img, pivot_x, direction, root_y, deg):
    """The part of img beyond pivot_x (direction=1 right, -1 left) turned deg degrees about (pivot_x, root_y):
    deg > 0 lifts the tip for either wing (the left wing turns the other way). Nearest-neighbour, so the pixels
    stay pixels; the part inside the pivot is not touched (it is returned separately)."""
    w, h = img.size
    box = (pivot_x + 1, 0, w, h) if direction > 0 else (0, 0, pivot_x, h)
    wing, rest = mask_box(img, box)
    a = deg if direction > 0 else -deg
    c = (pivot_x + (0.5 if direction > 0 else 0.5), root_y + 0.5)
    turned = wing.rotate(a, resample=Image.NEAREST, center=c)
    return turned, rest


def swing_both(img, left_pivot, right_pivot, root_y, deg):
    wr, rest = swing(img, right_pivot, 1, root_y, deg)
    wl, rest = swing(rest, left_pivot, -1, root_y, deg)
    return over(rest, over(wl, wr))


def flap_scale(img, left_pivot, right_pivot, root_y, k_tip, span):
    """Wing beat for big cape-like wings: every column outside the pivots is scaled vertically about root_y, by
    1 at the pivot growing linearly to k_tip at `span` columns out. Vertical outlines stay unbroken (no shear
    dashes); k_tip > 1 raises the tips, < 1 drops them toward the root."""
    w, h = img.size
    out = blank(w, h)
    src = img.load()
    dst = out.load()
    for x in range(w):
        d = left_pivot - x if x < left_pivot else (x - right_pivot if x > right_pivot else 0)
        k = 1 + (k_tip - 1) * min(1.0, d / float(span)) if d > 0 else 1.0
        for y in range(h):
            sy = int(round(root_y + (y - root_y) / k))
            if 0 <= sy < h and src[x, sy][3]:
                dst[x, y] = src[x, sy]
    return out


def wing_only(img, box):
    """(wing, rest) for a box (x0, y0, x1, y1) of img."""
    return mask_box(img, box)


def shear_into(rest, wing, pivot_x, slope, direction):
    """Beat one wing piece about pivot_x and lay it back over/under the rest (wing on top)."""
    return over(rest, shear(wing, pivot_x, slope, direction))


def build_existing(base, p):
    """Rows x beats for a species whose wings are ALREADY spread on the follower sprite (Dragonite, Tropius,
    Salamence; Togetic's wings are small and also beat this way). Front/back rows (0, 3): the columns outside
    the torso band shear up or down (the wing beats about its root). Side rows (1, 2): the wing box is stretched
    vertically about its root (up beat taller, down beat flipped under the root), the rest stays.
    p: canvas (W, H); shear {row: (left_pivot, right_pivot)}; slopes; side {row: dict(box, root, ks)};
    tuck {row: (from_y, by)}; body_frame; outline colour (re-outline the moved wing)."""
    W, H = p['canvas']
    slopes = p.get('slopes') or beat_slopes()
    rows = []
    for r in range(4):
        body = base['frames'][r][p.get('body_frame', 0)]
        if r in p.get('tuck', {}):
            body = tuck(body, *p['tuck'][r])
        bw, bh = body.size
        dx = (W - bw) // 2
        dy = H - bh
        frames = []
        for beat in BEATS:
            canvas = pad(body, W, H, dx, dy)
            if r in (0, 3):
                lp, rp = p['shear'][r]
                band = p.get('band', {}).get(r)
                if band:
                    part, rest = mask_box(canvas, (0, band[0] + dy, W, band[1] + dy))
                    if p.get('stretch', {}).get(r):
                        part = stretch_out(part, lp + dx, rp + dx, p['stretch'][r])
                    if p.get('flap'):
                        f = over(rest, flap_scale(part, lp + dx, rp + dx, p['flap'][r] + dy, p['ks_tip'][beat], p['span']))
                    elif p.get('swing'):
                        f = over(rest, swing_both(part, lp + dx, rp + dx, p['swing'][r] + dy, p['angles'][beat]))
                    else:
                        f = over(rest, shear_both(part, lp + dx, rp + dx, slopes[beat]))
                else:
                    f = shear_both(canvas, lp + dx, rp + dx, slopes[beat])
            elif r not in p.get('side', {}):
                f = canvas
            else:
                spec = p['side'][r]
                x0, y0, x1, y1 = spec['box']
                part, rest = mask_box(canvas, (x0 + dx, y0 + dy, x1 + dx, y1 + dy))
                k = spec['ks'][beat]
                root = spec['root'] + dy
                moved = vstretch(part, root, k) if k != 1 else part
                if k < 0:
                    f = under(rest, moved)
                else:
                    f = over(rest, moved)
            if p.get('outline') and beat != 'mid':
                pass
            frames.append(f)
        rows.append(frames)
    return {'frames': rows, 'durations': None}
