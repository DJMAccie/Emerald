#!/usr/bin/env python3
"""Offline preview of a landmark model, driven by the mod's own Lua.

The game round trip is minutes; this is seconds. It runs the real
SpriteVoxel/LandmarkModels under luajit with stubs for the engine's mesh and
budget modules, takes the vertices they emit, and rasterises them
orthographically from a few angles so the geometry and the face registration
can be judged before any capture is spent.

The FACE_CORNERS/FACE_SHADE tables are extracted from the installed mod, so
the preview cannot silently disagree with the engine about winding or shading.

Usage: python3 tools/model_preview.py [gid] [--out shots_model]
"""
import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
MOD_LIB = Path.home() / "Documents/battle-art-notquiteog/lib"
STAGED = ROOT / ".qa-stage/landmark/lib"

DUMP_LUA = r"""
-- luajit harness: build one landmark model with the real staged modules.
local dir=...
local V={}
local stub=assert(loadfile(dir..'/stub_voxel.lua'))()
-- The engine side of newMesh is a LOVE mesh; here it just holds the arrays.
stub.newMesh=function(verts,indices) return {verts=verts,indices=indices} end
V.mod={}
local loaded={}
V.require=function(name)
  if name=='Voxel3D' then return stub end
  if name=='BuildBudget' then return {tick=function() end,check=function() end} end
  if loaded[name] then return loaded[name] end
  local f=io.open(dir..'/'..name..'.lua','r')
  if not f then error('unexpected require: '..name) end
  local src=f:read('*a');f:close()
  loaded[name]=assert(load(src,'@'..name..'.lua'))(V)
  return loaded[name]
end
local raw=assert(io.open(dir..'/sprite.rgba','rb'))
local bytes=raw:read('*a');raw:close()
local w=tonumber(os.getenv('SPRITE_W') or '48')
local h=tonumber(os.getenv('SPRITE_H') or '48')
local imageData={}
function imageData:getDimensions() return w,h end
function imageData:getPixel(x,y)
  local o=(y*w+x)*4+1
  local r,g,b,a=bytes:byte(o,o+3)
  return r/255,g/255,b/255,a/255
end
local spr={width=w,height=h,imageData=imageData,image='stub'}
local SpriteVoxel=assert(loadfile(dir..'/SpriteVoxel.lua'))(V)
local Landmarks=assert(loadfile(dir..'/LandmarkModels.lua'))(V)
local gid=tonumber(os.getenv('MODEL_GID') or '94')
SpriteVoxel.log=true
local mesh,stats=SpriteVoxel.build(spr,Landmarks.recipe(gid))
if not mesh then print('[MODEL] build failed') os.exit(1) end
local out=assert(io.open(dir..'/model.txt','w'))
for _,v in ipairs(mesh.verts) do
  out:write(('v %.4f %.4f %.4f %.6f %.6f %.4f\n'):format(v[1],v[2],v[3],v[4],v[5],v[6]))
end
for _,k in ipairs(mesh.indices) do out:write('i '..k..'\n') end
out:close()
print(('[MODEL] gid=%d verts=%d indices=%d quads=%s'):format(gid,#mesh.verts,#mesh.indices,
  stats and tostring(stats.quads) or '?'))
"""

TABLE_RE = r"Voxel3D\.{name}\s*=\s*\{{(.*?)\n\}}"


def extract_tables(src: str) -> str:
    out = ["return {"]
    for name in ("FACE_SHADE", "FACE_CORNERS"):
        m = re.search(TABLE_RE.format(name=name), src, re.S)
        if not m:
            raise SystemExit(f"could not extract Voxel3D.{name}")
        out.append(f"{name} = {{{m.group(1)}\n}},")
    out.append("}")
    return "\n".join(out)


def read_dump(path: Path):
    verts, indices = [], []
    for line in path.read_text().splitlines():
        p = line.split()
        if p[0] == "v":
            verts.append(tuple(float(x) for x in p[1:]))
        elif p[0] == "i":
            indices.append(int(p[1]))
    return verts, indices


def sample(im: Image.Image, u: float, v: float):
    x = min(im.width - 1, max(0, int(u * im.width)))
    y = min(im.height - 1, max(0, int(v * im.height)))
    return im.getpixel((x, y))


def render(verts, indices, tex: Image.Image, yaw_deg: float, pitch_deg: float, size=520, zoom=1.0):
    import math

    yaw, pitch = math.radians(yaw_deg), math.radians(pitch_deg)
    cy, sy = math.cos(yaw), math.sin(yaw)
    cp, sp = math.cos(pitch), math.sin(pitch)

    def project(p):
        x, y, z = p[0], p[1], p[2]
        xr, zr = x * cy - z * sy, x * sy + z * cy
        yr = y * cp - zr * sp
        depth = zr * cp + y * sp
        return xr, yr, depth

    scale = zoom * size / 90.0
    tris = []
    for t in range(0, len(indices), 3):
        idx = indices[t : t + 3]
        ps = [verts[i - 1] for i in idx]
        proj = [project(p) for p in ps]
        depth = sum(q[2] for q in proj) / 3.0
        tris.append((depth, proj, ps))
    tris.sort(key=lambda item: item[0])  # farthest (smallest view depth) first

    im = Image.new("RGB", (size, size), (24, 26, 34))
    px = im.load()
    for _, proj, ps in tris:
        pts = [(size / 2 + q[0] * scale, size * 0.74 - q[1] * scale) for q in proj]
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        x0, x1 = max(0, int(min(xs))), min(size - 1, int(max(xs)) + 1)
        y0, y1 = max(0, int(min(ys))), min(size - 1, int(max(ys)) + 1)
        ax, ay = pts[0]
        bx, by = pts[1]
        cx, cyy = pts[2]
        det = (by - cyy) * (ax - cx) + (cx - bx) * (ay - cyy)
        if abs(det) < 1e-9:
            continue
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                pxc, pyc = x + 0.5 - cx, y + 0.5 - cyy
                w0 = ((by - cyy) * pxc + (cx - bx) * pyc) / det
                w1 = ((cyy - ay) * pxc + (ax - cx) * pyc) / det
                w2 = 1.0 - w0 - w1
                if w0 < -0.002 or w1 < -0.002 or w2 < -0.002:
                    continue
                u = w0 * ps[0][3] + w1 * ps[1][3] + w2 * ps[2][3]
                v = w0 * ps[0][4] + w1 * ps[1][4] + w2 * ps[2][4]
                shade = w0 * ps[0][5] + w1 * ps[1][5] + w2 * ps[2][5]
                r, g, b, a = sample(tex, u, v)
                if a < 128:
                    continue
                px[x, y] = (min(255, int(r * shade)), min(255, int(g * shade)), min(255, int(b * shade)))
    return im


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("gid", nargs="?", type=int, default=94)
    ap.add_argument("--out", default=str(ROOT / "shots_model"))
    ap.add_argument("--sprite", default=str(ROOT / "shots_art/gid94.png"))
    ap.add_argument("--views", default="0,90,180,270")
    ap.add_argument("--pitch", type=float, default=50.0)
    args = ap.parse_args()

    work = Path(tempfile.mkdtemp(prefix="landmark-"))
    (work / "stub_voxel.lua").write_text(extract_tables((MOD_LIB / "Voxel3D.lua").read_text()))
    for name in ("SpriteVoxel.lua", "LandmarkModels.lua"):
        src_path = (MOD_LIB / name) if (MOD_LIB / name).exists() else (STAGED / name)
        (work / name).write_text(src_path.read_text())
    
    sprite_path = Path(args.sprite)
    if not sprite_path.exists() or sprite_path == ROOT / "shots_art/gid94.png" and args.gid != 94:
        cand = [
            Path(f"/tmp/emerald_sprites/gid_{args.gid}_f0.png"),
            ROOT / f"shots_art/gid{args.gid}.png",
        ]
        found = False
        for c in cand:
            if c.exists():
                sprite_path = c
                found = True
                break
        if not found:
            ow_rgba = Path.home() / f"Library/Application Support/pokemon-love2d-rseqa/emerald/data/generated/gba/ow/{args.gid}.rgba"
            if ow_rgba.exists():
                # Read first frame using manifest
                raw = ow_rgba.read_bytes()
                # If 1024 bytes -> 16x16
                if len(raw) == 1024 or len(raw) == 4096:
                    arr = np.frombuffer(raw[:1024], dtype=np.uint8).reshape((16, 16, 4))
                    Image.fromarray(arr).save(f"/tmp/emerald_sprites/gid_{args.gid}_f0.png")
                    sprite_path = Path(f"/tmp/emerald_sprites/gid_{args.gid}_f0.png")
    
    tex = Image.open(sprite_path).convert("RGBA")
    (work / "sprite.rgba").write_bytes(tex.tobytes())
    (work / "dump.lua").write_text(DUMP_LUA)
    env = {
        "MODEL_GID": str(args.gid),
        "SPRITE_W": str(tex.width),
        "SPRITE_H": str(tex.height),
        "PATH": "/usr/bin:/bin:/opt/homebrew/bin"
    }
    proc = subprocess.run(
        ["luajit", str(work / "dump.lua"), str(work)],
        capture_output=True, text=True, env=env,
    )
    print(proc.stdout.strip())
    if proc.returncode != 0:
        print(proc.stderr.strip(), file=sys.stderr)
        return 1
    verts, indices = read_dump(work / "model.txt")
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    views = [float(v) for v in args.views.split(",")]
    sheets = []
    for yaw in views:
        im = render(verts, indices, tex, yaw, args.pitch)
        im.save(out / f"model_gid{args.gid}_yaw{int(yaw):03d}.png")
        sheets.append(im)
    if sheets:
        strip = Image.new("RGB", (sum(s.width for s in sheets), sheets[0].height), (24, 26, 34))
        x = 0
        for s in sheets:
            strip.paste(s, (x, 0))
            x += s.width
        strip.save(out / f"model_gid{args.gid}_strip.png")
    bbox = {
        "verts": len(verts),
        "triangles": len(indices) // 3,
        "x": [min(v[0] for v in verts), max(v[0] for v in verts)],
        "y": [min(v[1] for v in verts), max(v[1] for v in verts)],
        "z": [min(v[2] for v in verts), max(v[2] for v in verts)],
    }
    print(json.dumps(bbox))
    print(f"previews in {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
