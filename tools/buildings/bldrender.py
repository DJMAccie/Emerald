#!/usr/bin/env python3
"""Render a building model offline, driven by the mod's own BuildingVoxel.lua.

Runs the real Lua builder under luajit with a stub Voxel3D/BuildBudget and a
stub ImageData, takes the vertices it emits, and rasterises them through the
EXACT game camera (tools/buildings/gamecam.py), then compares the head-on view
with the building's own drawing. Seconds per iteration instead of a capture
round trip.

Usage:
  python3 tools/buildings/bldrender.py <bNNN> [--level 4] [--front 16] [--out DIR]
"""
import argparse, json, os, subprocess, sys, tempfile
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / 'analysis'))
sys.path.insert(0, str(HERE.parent / 'voxel_proto'))
import layers
import voxproto
from gamecam import Camera

MOD_LIB = Path.home() / 'Documents/battle-art-notquiteog/lib'
STAGED = ROOT / '.qa-stage/landmark/lib'
INVENTORY = json.load(open(HERE / 'inventory.json'))

DUMP = r"""
-- luajit harness: build one building model with the real staged module.
local dir=...
local stub=assert(loadfile(dir..'/stub_voxel.lua'))()
stub.newMesh=function(verts,indices) return {verts=verts,indices=indices} end
local V={}
V.require=function(name)
 if name=='Voxel3D' then return stub end
 if name=='BuildBudget' then return {tick=function()end,check=function()end} end
 if name=='VoxelState' then return {level=tonumber(os.getenv('MODEL_LEVEL') or '4'),ANGLES_DEG={0,35,15,35,50,75,75,75}} end
 error('unexpected require: '..name)
end
-- ImageData stub over the composed drawing
local raw=assert(io.open(dir..'/drawing.rgba','rb'))
local bytes=raw:read('*a');raw:close()
local w,h=tonumber(os.getenv('IMG_W')),tonumber(os.getenv('IMG_H'))
local ID={}
function ID:getDimensions() return w,h end
function ID:getPixel(x,y)
 local o=(y*w+x)*4+1
 local r,g,b,a=bytes:byte(o,o+3)
 return r/255,g/255,b/255,a/255
end
function ID:setPixel() end
love={image={newImageData=function() return ID end}}
local BV=assert(loadfile(dir..'/BuildingVoxel.lua'))(V)
BV.log=false
local mesh,stats=BV.build{image=ID,width=w,front=tonumber(os.getenv('MODEL_FRONT') or '16'),
 rise=tonumber(os.getenv('MODEL_RISE') or '') or nil,
 depth=tonumber(os.getenv('MODEL_DEPTH') or '') or nil,
 eave=tonumber(os.getenv('MODEL_EAVE') or '') or nil}
if not mesh then print('[BLD] build failed') os.exit(1) end
local out=assert(io.open(dir..'/model.txt','w'))
for _,v in ipairs(mesh.verts) do
 out:write(('v %.5f %.5f %.5f %.8f %.8f %.4f\n'):format(v[1],v[2],v[3],v[4],v[5],v[6]))
end
for _,k in ipairs(mesh.indices) do out:write('i '..k..'\n') end
out:close()
print(('[BLD] verts=%d indices=%d quads=%d eave=%d wallRows=%d wallH=%.2f height=%.2f depth=%.2f k=%.4f')
 :format(#mesh.verts,#mesh.indices,stats.quads,stats.eave,stats.wallRows,stats.wallHeight,stats.height,stats.depth,stats.scale))
"""

TABLE_RE = r"Voxel3D\.{name}\s*=\s*\{{(.*?)\n\}}"


def extract_tables(src):
    out = ["return {"]
    for name in ("FACE_SHADE", "FACE_CORNERS"):
        import re
        m = re.search(TABLE_RE.format(name=name), src, re.S)
        if not m:
            raise SystemExit(f"could not extract Voxel3D.{name}")
        out.append(f"{name} = {{{m.group(1)}\n}},")
    out.append("}")
    return "\n".join(out)


def compose(entry):
    L = layers.load(entry['pair'])
    W, H, cells = voxproto.map_cells(entry['map'])
    x0, y0, x1, y1 = entry['box']
    w, h = x1 - x0 + 1, y1 - y0 + 1
    img = np.zeros((h * 16, w * 16, 4), np.uint8)
    for yy in range(h):
        for xx in range(w):
            mid = cells[(y0 + yy) * W + x0 + xx] & 0x3FF
            u = layers.tile(L, 'u', mid)
            if u is None:
                continue
            t = u.astype(float)
            o = layers.tile(L, 'o', mid) if 'o' in L else None
            if o is not None:
                k = o[..., 3:4] / 255.0
                t[..., :3] = o[..., :3] * k + t[..., :3] * (1 - k)
                t[..., 3:4] = np.maximum(t[..., 3:4], o[..., 3:4])
            img[yy * 16:(yy + 1) * 16, xx * 16:(xx + 1) * 16] = t.astype(np.uint8)
    return img


def read_dump(path):
    verts, indices = [], []
    for line in path.read_text().splitlines():
        p = line.split()
        if p[0] == 'v':
            verts.append(tuple(float(v) for v in p[1:]))
        elif p[0] == 'i':
            indices.append(int(p[1]))
    return verts, indices


UV = {
    'south': [(0, 1), (1, 1), (1, 0), (0, 0)],
    'north': [(1, 1), (0, 1), (0, 0), (1, 0)],
    'top': [(0, 1), (1, 1), (1, 0), (0, 0)],
    'bottom': [(0, 0), (1, 0), (1, 1), (0, 1)],
    'east': [(0, 1), (0, 0), (1, 0), (1, 1)],
    'west': [(0, 1), (0, 0), (1, 0), (1, 1)],
}


def render(verts, indices, tex, vw, vh, level, focus, ground=0.0, yaw=0.0,
           bg=(26, 28, 34), crop=None, scale=1):
    import math
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    cam = Camera(vw, vh, level, ground=ground, cx=focus[0], cz=focus[2])
    tris = []
    for t in range(0, len(indices), 3):
        idx = indices[t:t + 3]
        quad = [verts[i - 1] for i in idx]
        pts = [(p[0] * cy - p[2] * sy, p[1] + ground, p[0] * sy + p[2] * cy) for p in quad]
        tris.append(pts)
    # painter's algorithm: sort quads (groups of 6 indices) by view depth
    quads = []
    for t in range(0, len(indices), 6):
        idx = indices[t:t + 6]
        ps = [verts[i - 1] for i in idx]
        pts = [(p[0] * cy - p[2] * sy, p[1] + ground, p[0] * sy + p[2] * cy) for p in ps]
        d = sum(cam.mvp[8] * p[0] + cam.mvp[9] * p[1] + cam.mvp[10] * p[2] + cam.mvp[11] for p in pts[:4]) / 4
        quads.append((d, ps))
    quads.sort(key=lambda q: q[0])
    canvas = np.zeros((vh, vw, 3), np.uint8)
    canvas[:, :] = np.array(bg, np.uint8)
    for d, ps in quads:
        sc = [cam.project(p[0], p[1], p[2]) for p in ps]
        tris_idx = [(0, 1, 2), (0, 2, 3)]
        for (a, b, c) in tris_idx:
            q = [sc[a], sc[b], sc[c]]
            uvq = [ps[a], ps[b], ps[c]]
            xs = [p[0] for p in q]; ys = [p[1] for p in q]
            xa, xb = max(0, int(min(xs))), min(vw - 1, int(max(xs)) + 1)
            ya, yb = max(0, int(min(ys))), min(vh - 1, int(max(ys)) + 1)
            ax, ay = q[0]; bx, by = q[1]; cx2, cy2 = q[2]
            det = (by - cy2) * (ax - cx2) + (cx2 - bx) * (ay - cy2)
            if abs(det) < 1e-9:
                continue
            for y in range(ya, yb + 1):
                for x in range(xa, xb + 1):
                    pxc, pyc = x + 0.5 - cx2, y + 0.5 - cy2
                    w0 = ((by - cy2) * pxc + (cx2 - bx) * pyc) / det
                    w1 = ((cy2 - ay) * pxc + (ax - cx2) * pyc) / det
                    w2 = 1.0 - w0 - w1
                    if w0 < -0.02 or w1 < -0.02 or w2 < -0.02:
                        continue
                    u = w0 * uvq[0][3] + w1 * uvq[1][3] + w2 * uvq[2][3]
                    v = w0 * uvq[0][4] + w1 * uvq[1][4] + w2 * uvq[2][4]
                    tx = min(tex.shape[1] - 1, max(0, int(u * tex.shape[1])))
                    ty = min(tex.shape[0] - 1, max(0, int(v * tex.shape[0])))
                    cpx = tex[ty, tx]
                    if cpx[3] < 128:
                        continue
                    sh = (uvq[0][5] + uvq[1][5] + uvq[2][5]) / 3.0
                    canvas[y, x] = np.clip(cpx[:3].astype(float) * sh, 0, 255).astype(np.uint8)
    im = Image.fromarray(canvas)
    if crop:
        im = im.crop(crop)
    if scale != 1:
        im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    return im


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('which')
    ap.add_argument('--level', type=int, default=4)
    ap.add_argument('--front', type=float, default=16)
    ap.add_argument('--rise', type=float, default=None)
    ap.add_argument('--depth', type=float, default=None)
    ap.add_argument('--eave', type=int, default=None)
    ap.add_argument('--yaws', default='0,90,180,270')
    ap.add_argument('--scale', type=int, default=4)
    ap.add_argument('--out', default=str(ROOT / 'shots_bld' / 'lab'))
    args = ap.parse_args()
    n = int(args.which.lstrip('bB'))
    entry = next(e for e in INVENTORY if e['n'] == n)
    cat = {m['n']: m for m in json.load(open(ROOT / 'shots_inv/catalogue.json'))}
    if n in cat:
        entry = dict(entry, box=cat[n]['box'])
    img = compose(entry)
    H, W = img.shape[0], img.shape[1]

    work = Path(tempfile.mkdtemp(prefix='bld-'))
    (work / 'stub_voxel.lua').write_text(extract_tables((MOD_LIB / 'Voxel3D.lua').read_text()))
    (work / 'BuildingVoxel.lua').write_text((STAGED / 'BuildingVoxel.lua').read_text())
    (work / 'drawing.rgba').write_bytes(img.tobytes())
    (work / 'dump.lua').write_text(DUMP)
    env = dict(os.environ)
    env.update({'IMG_W': str(W), 'IMG_H': str(H), 'MODEL_LEVEL': str(args.level),
                'MODEL_FRONT': str(args.front), 'PATH': '/usr/bin:/bin:/opt/homebrew/bin'})
    if args.rise is not None:
        env['MODEL_RISE'] = str(args.rise)
    if args.depth is not None:
        env['MODEL_DEPTH'] = str(args.depth)
    if args.eave is not None:
        env['MODEL_EAVE'] = str(args.eave)
    proc = subprocess.run(['luajit', str(work / 'dump.lua'), str(work)],
                          capture_output=True, text=True, env=env)
    print(proc.stdout.strip())
    if proc.returncode != 0:
        print(proc.stderr.strip(), file=sys.stderr)
        return 1
    verts, indices = read_dump(work / 'model.txt')
    os.makedirs(args.out, exist_ok=True)
    tag = 'v%03d' % n
    # camera: centre on the model, one frame high enough to hold it
    ymax = max(v[1] for v in verts)
    zmax = max(-v[2] for v in verts)
    vw, vh = 420, 420
    focus = (W / 2.0, ymax / 2.0, zmax / 2.0)
    cam = Camera(vw, vh, args.level, ground=0.0, cx=focus[0], cz=focus[2])
    xs, ys = [], []
    for v in verts:
        sx, sy = cam.project(v[0], v[1], -v[2])
        xs.append(sx); ys.append(sy)
    pad = 10
    crop = (max(0, int(min(xs)) - pad), max(0, int(min(ys)) - pad),
            min(vw, int(max(xs)) + pad), min(vh, int(max(ys)) + pad))
    head = render(verts, indices, img, vw, vh, args.level, focus, yaw=0, crop=crop, scale=args.scale)
    head.save(os.path.join(args.out, tag + '_head.png'))
    orig = Image.fromarray(img).convert('RGB')
    S = max(1, round(head.width / max(1, orig.width)))
    o = orig.resize((orig.width * S, orig.height * S), Image.NEAREST)
    strip = Image.new('RGB', (o.width + head.width + 6, max(o.height, head.height)), (20, 20, 24))
    strip.paste(o, (0, 0)); strip.paste(head, (o.width + 6, 0))
    strip.save(os.path.join(args.out, tag + '_cmp.png'))
    for yaw in [float(y) for y in args.yaws.split(',')]:
        im = render(verts, indices, img, vw, vh, args.level, focus, yaw=yaw, crop=crop, scale=args.scale)
        im.save(os.path.join(args.out, '%s_yaw%03d.png' % (tag, yaw)))
    print('wrote %s_cmp.png (%s)' % (tag, os.path.join(args.out, tag + '_cmp.png')))
    return 0


if __name__ == '__main__':
    sys.exit(main())
