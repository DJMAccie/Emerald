#!/usr/bin/env python3
"""Bake one flight sheet per Fly Pokemon into the mod: battle-art-notquiteog/assets/flyers/.

Run from anywhere:  python3 ~/Documents/Emerald/tools/flysprites/bake_flyers.py [--only 6,18,384]

For each species in flyers.json (national dex -> source) it writes <nat>-normal.png and <nat>-shiny.png
(rows down, left, right, up; one column per wing-beat frame, all frames the same size and aligned), then
manifest.lua (frame size, frame count, PMD durations, glide frame and seat height per row, Pokedex height),
a contact sheet and one GIF per species in docs/faults/fly/flyers/.

Sources: follow = the follower mod's followsprites (real flying poses), pmd = its PMD Collab walk cycle,
drawn = drawn/<nat>.py (frames made for this mod; until that file exists the follower sheet stands in).
The art is derived from third-party sprites, so the output stays out of git (.gitignore assets/flyers/**).
"""
import glob
import importlib.util
import json
import os
import re
import sys

from PIL import Image, ImageDraw

HOME = os.path.expanduser('~')
AS = HOME + '/Library/Application Support/pokemon-love2d'
WILDS = AS + '/mods/overworld_wild_spawns/assets/'
POKEMON = AS + '/emerald/data/generated/gba/pokemon/'
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = HOME + '/Documents/battle-art-notquiteog/assets/flyers'
SHEETS = HOME + '/Documents/Emerald/docs/faults/fly/flyers'
ROWS = ('down', 'left', 'right', 'up')


# ------- sources: each returns {'frames': [row][col] RGBA images, 'durations': [ticks of 1/60 s] or None}
def follow(nat, shiny=False):
    v = 's' if shiny else 'n'
    path = WILDS + 'enhanced_overworld/followsprites/%03d-b-%s.png' % (nat, v)
    if not os.path.exists(path):
        found = [p for p in sorted(glob.glob(WILDS + 'enhanced_overworld/followsprites/%03d-*-%s.png' % (nat, v)))
                 if 'grayscale' not in p]
        if not found:
            return None
        path = found[0]
    im = Image.open(path).convert('RGBA')
    w, h = im.size[0] // 4, im.size[1] // 4
    return {'frames': [[im.crop((c * w, r * h, (c + 1) * w, (r + 1) * h)) for c in range(4)] for r in range(4)],
            'durations': None}


def levitates(nat, shiny=False):
    """The follower mod's over-water sheet with its splash keyed out (an in-air top half)."""
    v = 'shiny' if shiny else 'normal'
    path = WILDS + 'enhanced_overworld/water_sprites/levitates/%s/levitates_%03d-b-%s.png' % (v, nat, v[0])
    if not os.path.exists(path):
        return None
    im = Image.open(path).convert('RGBA')
    px = im.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b, a = px[x, y]
            if a and 226 <= r <= 236 and 226 <= g <= 236 and 244 <= b <= 252:
                px[x, y] = (0, 0, 0, 0)
    w, h = im.size[0] // 4, im.size[1] // 4
    return {'frames': [[im.crop((c * w, r * h, (c + 1) * w, (r + 1) * h)) for c in range(4)] for r in range(4)],
            'durations': None}


_PMD = None


def pmd_meta(nat, shiny=False):
    global _PMD
    if _PMD is None:
        _PMD = open(WILDS + 'pmdcollab/sprite_table.lua').read().split('\n')
    key = 'sprites/%03d-%s.png' % (nat, 'shiny' if shiny else 'normal')
    for line in _PMD:
        if key in line:
            body = line.split('={', 1)[1]
            out = {}
            for k, val in re.findall(r'(\w+)=("[^"]*"|\{[^}]*\}|[-\d.]+)', body):
                if val.startswith('"'):
                    out[k] = val.strip('"')
                elif val.startswith('{'):
                    out[k] = [int(x) for x in val.strip('{}').split(',') if x.strip()]
                else:
                    out[k] = float(val) if '.' in val else int(val)
            return out
    return None


def pmd(nat, shiny=False):
    m = pmd_meta(nat, shiny) or pmd_meta(nat, False)
    if not m:
        return None
    im = Image.open(WILDS + m['rel'].replace('assets/', '', 1)).convert('RGBA')
    fw, fh, base, n = m['frameWidth'], m['frameHeight'], m['walkCycleBase'], m['walkFrameCount']
    groups = (0, 2, 3, 1)  # the walk block runs down, up, left, right; our rows are down, left, right, up
    frames = [[im.crop((0, (base + g * n + k) * fh, fw, (base + g * n + k + 1) * fh)) for k in range(n)]
              for g in groups]
    return {'frames': frames, 'durations': m.get('walkDurations')}


def drawn_module(nat):
    path = os.path.join(HERE, 'drawn', '%03d.py' % nat)
    if not os.path.exists(path):
        return None
    spec = importlib.util.spec_from_file_location('drawn_%03d' % nat, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def shiny_map(normal, shiny):
    """normal colour -> shiny colour, read pixel by pixel from the follower's normal/shiny pair."""
    votes = {}
    for rn, rs in zip(normal['frames'], shiny['frames']):
        for a, b in zip(rn, rs):
            for p, q in zip(a.getdata(), b.getdata()):
                if p[3] and q[3]:
                    votes.setdefault(p[:3], {}).setdefault(q[:3], 0)
                    votes[p[:3]][q[:3]] += 1
    return {k: max(v.items(), key=lambda kv: kv[1])[0] for k, v in votes.items()}


def apply_map(img, cmap):
    out = img.copy()
    px = out.load()
    for y in range(out.size[1]):
        for x in range(out.size[0]):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in cmap:
                px[x, y] = cmap[(r, g, b)] + (a,)
    return out


def source_for(nat, kind):
    """(normal, shiny, label)."""
    if kind == 'pmd':
        n, s = pmd(nat), pmd(nat, True)
        if n:
            return n, s or n, 'pmd'
    if kind == 'drawn':
        mod = drawn_module(nat)
        if mod:
            base_n, base_s = follow(nat), follow(nat, True)
            n = mod.build(nat, base_n, {'follow': follow, 'levitates': levitates, 'pmd': pmd})
            cmap = shiny_map(base_n, base_s) if base_n and base_s else {}
            cmap.update(getattr(mod, 'SHINY_EXTRA', {}))
            s = {'frames': [[apply_map(f, cmap) for f in row] for row in n['frames']], 'durations': n.get('durations')}
            return n, s, 'drawn'
        n, s = follow(nat), follow(nat, True)
        return n, s or n, 'stand-in'
    n, s = follow(nat), follow(nat, True)
    return n, s or n, 'follow'


# ------- measuring
def bbox(img):
    return img.getchannel('A').point(lambda a: 255 if a >= 128 else 0).getbbox()


def union_box(sheets):
    box = None
    for sheet in sheets:
        for row in sheet['frames']:
            for f in row:
                b = bbox(f)
                if not b:
                    continue
                box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    return box


def centre_box(sheets, w):
    """Horizontally centred union box, so mirrored rows and every frame share one centre line."""
    box = union_box(sheets)
    half = max(w / 2 - box[0], box[2] - w / 2)
    x0 = int(round(w / 2 - half))
    return (x0, box[1], x0 + int(round(2 * half)), box[3])


def glide_and_seat(row):
    """The widest frame of a row (wings fully out: the glide pose) and how high above the card's bottom the
    rider's feet go on it (half way up the body at the centre line)."""
    widths = [((bbox(f) or (0, 0, 0, 0))[2] - (bbox(f) or (0, 0, 0, 0))[0]) for f in row]
    g = widths.index(max(widths))
    f = row[g]
    w, h = f.size
    a = f.getchannel('A').load()
    ys = [y for y in range(h) for x in range(w // 2 - 2, w // 2 + 3) if 0 <= x < w and a[x, y] >= 128]
    if not ys:
        return g, h * .42
    top, bottom = min(ys), max(ys)
    return g, round((h - 1 - bottom) + (bottom - top) * .5, 1)


def dex_heights():
    src = open(POKEMON + 'dex.lua').read()
    return {int(k): int(h) for k, h in re.findall(r'\[(\d+)\] = \{[^}]*height = (\d+)', src)}


def lua_list(xs):
    return '{' + ','.join(str(x) for x in xs) + '}'


def main():
    table = json.load(open(os.path.join(HERE, 'flyers.json')))
    only = None
    if '--only' in sys.argv:
        only = {int(x) for x in sys.argv[sys.argv.index('--only') + 1].split(',')}
    heights = dex_heights()
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(SHEETS, exist_ok=True)
    manifest_path = os.path.join(OUT, 'manifest.lua')
    entries = {}
    if only and os.path.exists(manifest_path):
        for line in open(manifest_path):
            m = re.match(r'\s*\[(\d+)\]=(.*),\s*$', line)
            if m:
                entries[int(m.group(1))] = m.group(2)
    report = []
    for key, kind in table.items():
        if key.startswith('_'):
            continue
        nat = int(key)
        if only and nat not in only:
            continue
        normal, shiny, label = source_for(nat, kind)
        if not normal:
            print('MISSING', nat, kind)
            continue
        w = normal['frames'][0][0].size[0]
        box = centre_box([normal, shiny], w)
        cols = len(normal['frames'][0])
        fw, fh = box[2] - box[0], box[3] - box[1]
        glides, seats = [], []
        for variant, sheet in (('normal', normal), ('shiny', shiny)):
            out = Image.new('RGBA', (fw * cols, fh * 4), (0, 0, 0, 0))
            for r, row in enumerate(sheet['frames']):
                for c, f in enumerate(row):
                    tile = Image.new('RGBA', (fw, fh), (0, 0, 0, 0))
                    tile.paste(f.crop(box), (0, 0))
                    out.paste(tile, (c * fw, r * fh))
            out.save(os.path.join(OUT, '%03d-%s.png' % (nat, variant)))
            if variant == 'normal':
                rows = [[out.crop((c * fw, r * fh, (c + 1) * fw, (r + 1) * fh)) for c in range(cols)] for r in range(4)]
                for row in rows:
                    g, seat = glide_and_seat(row)
                    glides.append(g)
                    seats.append(seat)
                normal['cropped'] = rows
        dur = normal.get('durations')
        entries[nat] = ("{fw=%d,fh=%d,frames=%d,source='%s',glide=%s,seat=%s,height=%d%s}" %
                        (fw, fh, cols, label, lua_list(glides), lua_list(seats), heights.get(nat, 10),
                         (',durations=' + lua_list(dur)) if dur else ''))
        report.append((nat, label, normal['cropped'], dur))
        print('%3d %-8s %2dx%-2d x%d glide=%s seat=%s' % (nat, label, fw, fh, cols, glides, seats))
    with open(manifest_path, 'w') as f:
        f.write('-- Flight sheets for the Fly flight (Gen3FlyOver), baked by tools/flysprites/bake_flyers.py.\n'
                '-- [national dex] = frame size, frames per row (rows: down, left, right, up), where the art came\n'
                '-- from, the glide frame (wings out) and the rider seat height (px above the card bottom) per row,\n'
                '-- Pokedex height (dm), PMD frame durations (1/60 s) when the sheet has its own timing.\n'
                'return {\n')
        for nat in sorted(entries):
            f.write(' [%d]=%s,\n' % (nat, entries[nat]))
        f.write('}\n')
    contact(report)


def contact(report):
    if not report:
        return
    S = 3
    rows_h = [max(r[2][0][0].size[1] * S, 48) for r in report]
    width = 160 + max(len(r[2][0]) * (r[2][0][0].size[0] * S + 4) for r in report) * 4 // 4 + 40
    width = max(width, 160 + max(len(r[2][0]) * (r[2][0][0].size[0] * S + 4) for r in report))
    height = sum(4 * h + 30 for h in rows_h)
    sheet = Image.new('RGBA', (width, height), (110, 160, 210, 255))
    d = ImageDraw.Draw(sheet)
    y = 0
    for (nat, label, rows, dur), h in zip(report, rows_h):
        d.text((6, y + 6), '%d  %s' % (nat, label), fill=(0, 0, 0, 255))
        for r, row in enumerate(rows):
            d.text((6, y + 24 + r * h + h // 2), ROWS[r], fill=(30, 30, 30, 255))
            x = 160
            for f in row:
                big = f.resize((f.size[0] * S, f.size[1] * S), Image.NEAREST)
                sheet.paste(big, (x, y + 22 + r * h), big)
                x += big.size[0] + 4
        y += 4 * h + 30
        # a GIF of the back (what the chase camera sees) beside the front, at the sheet's own timing
        frames = []
        n = len(rows[0])
        for c in range(n):
            fr = Image.new('RGBA', (rows[0][0].size[0] * 2 * S + 8, rows[0][0].size[1] * S), (110, 160, 210, 255))
            for i, r in enumerate((3, 0)):
                f = rows[r][c].resize((rows[r][c].size[0] * S, rows[r][c].size[1] * S), Image.NEAREST)
                fr.paste(f, (i * (f.size[0] + 8), 0), f)
            frames.append(fr.convert('P', palette=Image.ADAPTIVE))
        ms = [int((t or 8) * 1000 / 60) for t in (dur or [8] * n)]
        frames[0].save(os.path.join(SHEETS, '%03d.gif' % nat), save_all=True, append_images=frames[1:],
                       duration=ms[:n], loop=0)
    sheet.save(os.path.join(SHEETS, 'SHEET_flyers.png'))
    print('sheet', os.path.join(SHEETS, 'SHEET_flyers.png'), sheet.size)


if __name__ == '__main__':
    main()
