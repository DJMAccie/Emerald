"""Offline prototype: build a building as pixel voxels from its own art and
render it from the game's camera (orthographic, pitch ~50 deg, optional yaw).

Rule: one art pixel = one voxel unit; every visible face shows one pixel.
 - wall rows stand on the front plane, pixel for pixel;
 - roof rows become voxel steps (one art row = one step deep, rising toward
   the back), so the slope is made of the drawing's own pixels;
 - sides/back/underside take the nearest edge pixel's colour.
Reads the QA cache via ../analysis/layers.py (no ROM data is written here).
"""
import sys, os, math, json, struct
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'analysis'))
import layers

G = layers.G.replace('/native/', '')

def map_cells(map_id):
    census = json.load(open(G + '/map_tree/census.json'))
    key = map_id[3:].replace('_', '').lower()
    slot = None
    for g in census['groups']:
        for m in g['maps']:
            if m['id'].replace('_', '').lower() == key: slot = m['slot']
    hdr = json.load(open(G + '/map_tree/maps/%s/header.json' % slot))
    W, H = hdr['width'], hdr['height']
    cells = struct.unpack('<%dH' % (W * H), open(G + '/map_tree/maps/%s/grid.bin' % slot, 'rb').read())
    return W, H, cells

def art(L, mid):
    u = layers.tile(L, 'u', mid).astype(float)
    if 'o' in L:
        o = layers.tile(L, 'o', mid)
        if o is not None:
            k = o[..., 3:4] / 255.0
            u[..., :3] = o[..., :3] * k + u[..., :3] * (1 - k)
    return u[..., :3].astype(np.uint8)

def building(pair, map_id, x0, x1, roof_rows, wall_rows, ground_mid, rise_every=2):
    """x0..x1 inclusive columns; roof_rows/wall_rows are lists of map rows.
    ground_mid: the tile the building stands on; its pixels at the same spot
    are not building (rounded roof corners, gaps beside the walls)."""
    L = layers.load(pair)
    W, H, cells = map_cells(map_id)
    cols = x1 - x0 + 1
    g = art(L, ground_mid).astype(int)
    def strip(rows):
        out = np.zeros((len(rows) * 16, cols * 16, 3), np.uint8)
        keep = np.zeros((len(rows) * 16, cols * 16), bool)
        for i, y in enumerate(rows):
            for j in range(cols):
                t = art(L, cells[y * W + x0 + j] & 0x3ff)
                out[i*16:(i+1)*16, j*16:(j+1)*16] = t
                keep[i*16:(i+1)*16, j*16:(j+1)*16] = np.abs(t.astype(int) - g).sum(2) > 0
        return out, keep
    (roof, rkeep), (wall, wkeep) = strip(roof_rows), strip(wall_rows)
    Hw = wall.shape[0]; R = roof.shape[0]; Wd = cols * 16
    steps = (R - 1 - np.arange(R)) // rise_every
    def inner(x):  # a colour from inside the drawing, never its outline
        return min(max(x, 3), Wd - 4)
    vox = {}
    zfront = R
    for x in range(Wd):
        for r in range(R):
            if not rkeep[r, x]: continue
            top = Hw + steps[r]
            for y in range(top):
                # body: wall material below the eave line, roof above it
                c = wall[Hw - 1 - y, inner(x)] if y < Hw else roof[r, inner(x)]
                vox[(x, y, r)] = tuple(c)
            vox[(x, top, r)] = tuple(roof[r, x])    # the drawn pixel on top
        for ry in range(Hw):
            if wkeep[ry, x]:
                vox[(x, Hw - 1 - ry, zfront)] = tuple(wall[ry, x])
    return vox, (Wd, Hw + int(steps.max()) + 1, R + 1)

def faces(vox):
    out = []
    dirs = [((0,1,0),1.0),((0,0,1),.95),((1,0,0),.78),((-1,0,0),.78),((0,0,-1),.7)]
    for (x,y,z), c in vox.items():
        for (dx,dy,dz), sh in dirs:
            if (x+dx,y+dy,z+dz) in vox: continue
            out.append(((x,y,z),(dx,dy,dz),c,sh))
    return out

def render(vox, pitch=50, yaw=0, scale=4):
    fs = faces(vox)
    p, w = math.radians(pitch), math.radians(yaw)
    cw, sw, cp, sp = math.cos(w), math.sin(w), math.cos(p), math.sin(p)
    def proj(x, y, z):
        xr = x*cw - z*sw; zr = x*sw + z*cw
        sx = xr; sy = -y*cp + zr*sp; depth = zr*cp + y*sp
        return sx, sy, depth
    quads = []
    for (x,y,z),(dx,dy,dz),c,sh in fs:
        if dy == 1:   q=[(x,y+1,z),(x+1,y+1,z),(x+1,y+1,z+1),(x,y+1,z+1)]
        elif dz == 1: q=[(x,y,z+1),(x+1,y,z+1),(x+1,y+1,z+1),(x,y+1,z+1)]
        elif dz == -1:q=[(x,y,z),(x+1,y,z),(x+1,y+1,z),(x,y+1,z)]
        elif dx == 1: q=[(x+1,y,z),(x+1,y,z+1),(x+1,y+1,z+1),(x+1,y+1,z)]
        else:         q=[(x,y,z),(x,y,z+1),(x,y+1,z+1),(x,y+1,z)]
        pts = [proj(*v) for v in q]
        quads.append((sum(t[2] for t in pts)/4, [(t[0],t[1]) for t in pts], tuple(int(v*sh) for v in c)))
    quads.sort(key=lambda q: q[0])
    xs=[p[0] for q in quads for p in q[1]]; ys=[p[1] for q in quads for p in q[1]]
    ox, oy = min(xs), min(ys)
    img = Image.new('RGB', (int((max(xs)-ox)*scale)+2, int((max(ys)-oy)*scale)+2), (40,40,48))
    d = ImageDraw.Draw(img)
    for _, pts, c in quads:
        d.polygon([((x-ox)*scale,(y-oy)*scale) for x,y in pts], fill=c)
    return img

if __name__ == '__main__':
    vox, dims = building('general__petalburg', 'EM_PETALBURG_CITY', 19, 22, [13,14], [15,16], 0x001)
    out = sys.argv[1] if len(sys.argv) > 1 else 'pc_voxel.png'
    imgs = [render(vox, 50, 0), render(vox, 50, 35)]
    # the original 2D drawing for comparison
    L = layers.load('general__petalburg'); W, H, cells = map_cells('EM_PETALBURG_CITY')
    orig = np.zeros((4*16, 4*16, 3), np.uint8)
    for i, y in enumerate(range(13,17)):
        for j in range(4): orig[i*16:(i+1)*16, j*16:(j+1)*16] = art(L, cells[y*W+19+j] & 0x3ff)
    o = Image.fromarray(orig).resize((256,256), Image.NEAREST)
    Wt = o.width + sum(i.width for i in imgs) + 40; Ht = max([o.height] + [i.height for i in imgs])
    s = Image.new('RGB', (Wt, Ht), (20,20,20)); x = 0
    for im in [o] + imgs: s.paste(im, (x, 0)); x += im.width + 20
    s.save(out); print('voxels', len(vox), 'dims', dims, '->', out)
