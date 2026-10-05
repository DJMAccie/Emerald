#!/usr/bin/env python3
"""Offline recipe preview tool for buildings and landmarks using SpriteVoxel."""
import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(ROOT / 'tools'))
import model_preview

MOD_LIB = Path.home() / 'Documents/battle-art-notquiteog/lib'

DUMP_TEMPLATE = r"""
local dir = ...
local V = {}
local stub = assert(loadfile(dir..'/stub_voxel.lua'))()
stub.newMesh = function(verts, indices) return {verts=verts, indices=indices} end
V.mod = {}
local loaded = {}
V.require = function(name)
  if name == 'Voxel3D' then return stub end
  if name == 'BuildBudget' then return {tick=function() end, check=function() end} end
  error('unexpected: '..name)
end
local raw = assert(io.open(dir..'/sprite.rgba', 'rb'))
local bytes = raw:read('*a'); raw:close()
local w = tonumber(os.getenv('IMG_W') or '64')
local h = tonumber(os.getenv('IMG_H') or '64')
local imageData = {}
function imageData:getDimensions() return w, h end
function imageData:getPixel(x, y)
  local o = (y*w + x)*4 + 1
  local r, g, b, a = bytes:byte(o, o+3)
  return r/255, g/255, b/255, a/255
end
local spr = {width=w, height=h, imageData=imageData, image='stub'}
local SpriteVoxel = assert(loadfile(dir..'/SpriteVoxel.lua'))(V)
local recipe = assert(loadfile(dir..'/recipe.lua'))()
local mesh, stats = SpriteVoxel.build(spr, recipe)
if not mesh then print('[PREVIEW] build failed') os.exit(1) end
local out = assert(io.open(dir..'/model.txt', 'w'))
for _, v in ipairs(mesh.verts) do
  out:write(string.format('v %.4f %.4f %.4f %.6f %.6f %.4f\n', v[1], v[2], v[3], v[4], v[5], v[6]))
end
for _, k in ipairs(mesh.indices) do
  out:write('i '..k..'\n')
end
out:close()
print(string.format('[PREVIEW] verts=%d indices=%d quads=%d boxes=%d', #mesh.verts, #mesh.indices, stats and stats.quads or 0, stats and stats.boxes or 0))
"""


def preview(recipe_path: Path, image_path: Path, out_dir: Path, tag: str, pitch: float = 50.0, zoom: float = 0.9):
    tex = Image.open(image_path).convert('RGBA')
    w, h = tex.size

    work = Path(tempfile.mkdtemp(prefix='bld_prev-'))
    (work / 'stub_voxel.lua').write_text(model_preview.extract_tables((MOD_LIB / 'Voxel3D.lua').read_text()))
    (work / 'SpriteVoxel.lua').write_text((MOD_LIB / 'SpriteVoxel.lua').read_text())
    (work / 'recipe.lua').write_text(recipe_path.read_text())
    (work / 'sprite.rgba').write_bytes(tex.tobytes())
    (work / 'dump.lua').write_text(DUMP_TEMPLATE)

    env = dict(os.environ, IMG_W=str(w), IMG_H=str(h), PATH='/usr/bin:/bin:/opt/homebrew/bin')
    proc = subprocess.run(['luajit', str(work / 'dump.lua'), str(work)], capture_output=True, text=True, env=env)
    print(proc.stdout.strip())
    if proc.returncode != 0:
        print('Error:', proc.stderr.strip())
        return False

    verts, indices = model_preview.read_dump(work / 'model.txt')
    out_dir.mkdir(parents=True, exist_ok=True)
    sheets = []
    for yaw in (0, 90, 180, 270):
        im = model_preview.render(verts, indices, tex, yaw, pitch, size=520, zoom=zoom)
        im.save(out_dir / f'{tag}_yaw{int(yaw):03d}.png')
        sheets.append(im)

    strip = Image.new('RGB', (sum(s.width for s in sheets), sheets[0].height), (24, 26, 34))
    x = 0
    for s in sheets:
        strip.paste(s, (x, 0))
        x += s.width
    strip_path = out_dir / f'{tag}_strip.png'
    strip.save(strip_path)
    print(f'Wrote {strip_path}')
    return True


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('recipe', type=Path)
    ap.add_argument('image', type=Path)
    ap.add_argument('--out', type=Path, default=ROOT / 'shots_bld/lab')
    ap.add_argument('--tag', default='preview')
    ap.add_argument('--pitch', type=float, default=50.0)
    ap.add_argument('--zoom', type=float, default=0.9)
    args = ap.parse_args()
    preview(args.recipe, args.image, args.out, args.tag, args.pitch, args.zoom)
