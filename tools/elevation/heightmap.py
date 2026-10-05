#!/usr/bin/env python3
"""Offline floor heights for a map, solved by the mod's own TerrainLevels.lua
(no game, no display). Mirrors Gen3Elevation's inputs from the cartridge data:
walkable floor, stairs (walkable e0 cells between levels), ledges (raw
behaviours 0x38-0x3B), water (elevation 1), the nibble pins, and optionally
the authored terrace anchors.

python3 heightmap.py MAP out.png [--lib DIR] [--terraces]
  --lib DIR    lib folder holding TerrainLevels.lua / Gen3EmeraldTerraces.lua
               (default: the mod source; pass an extracted committed tree to
               compare before/after)
Writes a PNG (art darkened, heights as colour bands + numbers per 16 px) and
prints height statistics per water body and terrace."""
import sys, os, json, struct, subprocess, tempfile, argparse
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'voxel_proto')); sys.path.insert(0, os.path.join(HERE, '..', 'buildings'))
import voxproto

COURSE, MAX_STEP = 16, 3

def tileset_attrs(ts):
    p = os.path.join(voxproto.G, 'map_tree', 'tilesets', ts, 'attributes.bin')
    b = open(p, 'rb').read()
    import zlib
    if b[:1] == b'\x78':
        b = zlib.decompress(b)
    return struct.unpack('<%dH' % (len(b) // 2), b)

def load(mp):
    G = voxproto.G
    census = json.load(open(G + '/map_tree/census.json'))
    key = mp[3:].replace('_', '').lower()
    for g in census['groups']:
        for m in g['maps']:
            if m['id'].replace('_', '').lower() == key: slot = m['slot']
    h = json.load(open(G + '/map_tree/maps/%s/header.json' % slot))
    W, H = h['width'], h['height']
    cells = struct.unpack('<%dH' % (W * H), open(G + '/map_tree/maps/%s/grid.bin' % slot, 'rb').read())
    prim, sec = tileset_attrs(h['primaryTileset']), tileset_attrs(h['secondaryTileset'])
    def beh(mid):
        a = prim[mid] if mid < 512 else (sec[mid - 512] if mid - 512 < len(sec) else 0)
        return a & 0xff
    return W, H, cells, beh

LUA = r'''
local lib,data,terr,mapid=...
package.path=lib..'/?.lua;'..package.path
local Levels=dofile(lib..'/TerrainLevels.lua')
local d=dofile(data)
local W,H=d.W,d.H
local pins,stairs
if terr~='' then
 local env={V=nil}
 local T=dofile(lib..'/Gen3EmeraldTerraces.lua')
 local rows=T.maps[mapid]
 if rows then pins={};for _,r in ipairs(rows)do pins[r[1]..':'..r[2]]=r[3]*T.COURSE end end
 local ok,G=pcall(dofile,lib..'/Gen3StairTerraces.lua')
 local g=ok and G[mapid]
 if g then pins=pins or {};for _,r in ipairs(g.pins)do pins[r[1]..':'..r[2]]=r[3]*(G.rise or T.COURSE) end
  stairs={};for _,c in ipairs(g.stairs)do stairs[c[1]..':'..c[2]]=true end end
end
local drop={[0x38]={1,0},[0x39]={-1,0},[0x3A]={0,-1},[0x3B]={0,1}}
local blocked={{},{},{},{}}
local f=Levels.build(W,H,function(x,y)
 local c=d.c[y*W+x+1];local mid,coll,elev,beh,climb=c[1],c[2],c[3],c[4],c[5]
 local step=beh==0xD0 or climb==1 or (stairs and stairs[x..':'..y]==true);local jump=beh>=0x38 and beh<=0x3F
 local water=elev==1
 local pinned=coll~=1 and not step and not jump and elev>=3 and not water
 local pin
 if pins then pin=pins[x..':'..y] else pin=pinned and math.min(elev-3,%d)*%d or nil end
 return {floor=coll==0 and not step and not jump,step=step,drop=drop[beh],layer=elev,behavior=beh,
  kind=water and 'water' or 'flat',seed=0,pin=pin,waterfall=beh==0x13}
end,function(a,b,dd)
 return a.layer==b.layer and (a.kind=='water')==(b.kind=='water')
end,6)
local out={}
for y=0,H-1 do local row={} for x=0,W-1 do local c=f.cells[Levels.key(x,y)];row[#row+1]=string.format('%%d',math.floor((c.height or -1)+.5)) end out[#out+1]=table.concat(row,' ') end
io.write(table.concat(out,'\n'))
'''

def solve(mp, lib, terraces):
    W, H, cells, beh = load(mp)
    rows = []
    def at(x, y):
        if 0 <= x < W and 0 <= y < H:
            v = cells[y * W + x]; return v & 0x3ff, (v >> 10) & 3, v >> 12
    for y in range(H):
        for x in range(W):
            mid, coll, el = at(x, y)
            climb = 0
            if coll == 0 and el == 0:
                lv = [n[2] for n in (at(x + 1, y), at(x - 1, y), at(x, y + 1), at(x, y - 1)) if n and n[1] == 0 and n[2] >= 3]
                if lv and max(lv) > min(lv): climb = 1
            rows.append('{%d,%d,%d,%d,%d}' % (mid, 1 if coll else 0, el, beh(mid), climb))
    with tempfile.NamedTemporaryFile('w', suffix='.lua', delete=False) as t:
        t.write('return {W=%d,H=%d,c={%s}}' % (W, H, ','.join(rows))); data = t.name
    with tempfile.NamedTemporaryFile('w', suffix='.lua', delete=False) as t:
        t.write(LUA % (MAX_STEP, COURSE)); prog = t.name
    out = subprocess.run(['luajit', prog, lib, data, '1' if terraces else '', mp], capture_output=True, text=True)
    if out.returncode: raise SystemExit(out.stderr)
    hts = [[int(v) for v in line.split()] for line in out.stdout.strip().split('\n')]
    return W, H, cells, hts

def render(mp, W, H, cells, hts, path, pair=None):
    from PIL import Image, ImageDraw
    import bldmodel as M
    try:
        img = Image.fromarray(M.compose(pair, mp, 0, 0, W - 1, H - 1)).convert('RGB') if pair else Image.new('RGB', (W * 16, H * 16))
    except Exception:
        img = Image.new('RGB', (W * 16, H * 16))
    img = img.point(lambda v: v // 2)
    d = ImageDraw.Draw(img, 'RGBA')
    for y in range(H):
        for x in range(W):
            hgt = hts[y][x]
            if hgt < 0: continue
            k = min(255, hgt * 2)
            d.rectangle((x * 16, y * 16, x * 16 + 15, y * 16 + 15), fill=(k, 255 - k, 80, 90))
            if (cells[y * W + x] >> 12) == 1: d.rectangle((x * 16 + 6, y * 16 + 6, x * 16 + 9, y * 16 + 9), fill=(80, 160, 255, 255))
            d.text((x * 16 + 1, y * 16 + 3), str(hgt), fill=(255, 255, 255, 255))
    img.save(path)

if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('map'); ap.add_argument('out')
    ap.add_argument('--lib', default=os.path.expanduser('~/Documents/battle-art-notquiteog/lib'))
    ap.add_argument('--terraces', action='store_true'); ap.add_argument('--pair')
    a = ap.parse_args()
    W, H, cells, hts = solve(a.map, a.lib, a.terraces)
    render(a.map, W, H, cells, hts, a.out, a.pair)
    water = sorted({hts[y][x] for y in range(H) for x in range(W) if (cells[y * W + x] >> 12) == 1})
    land = sorted({hts[y][x] for y in range(H) for x in range(W) if (cells[y * W + x] >> 12) >= 3})
    print(a.map, 'water heights', water, 'land heights', land)
