#!/usr/bin/env python3
"""Convert Pokemon Colosseum PKX models (via the addon's Blender-free IR) into
Stadium 2 importer DSM5 packs, so the importer's own renderer/animation player
draws Hoenn Pokemon in gen1recomp battles.

  colo2dsm.py <out-dir> [name ...]        (default: every mapped Pokemon model)

Conventions (verified against lib/pack.lua, build.lua, renderer.lua):
  * bone/vertex units: GameCube units x100 as int16, rootScale = S/100 where S
    is the global Colosseum->Stadium size factor (calibrated after a full run,
    see --calibrate in tools/calibrate.py); rotations are binary angles
    (65536 = 360 deg), Euler XYZ composed as Rz*Ry*Rx; scale is 16.16 fixed;
    hierarchy uses aligned scale inheritance (HSD == Stadium, checked 1e-16).
  * vertices are stored bone-local (max-weight bone for envelopes); UVs are
    normalized x512 with GameCube's top-left origin, textures top-to-bottom.
  * animations are baked at 30 fps from the 60 fps keyframes over [0,end_frame].
"""
import os, sys, json, math, struct, csv
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pkx_to_ir, fsys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')
UNITS = 100.0            # int16 units per GameCube unit
GC_PER_METER = 10.0      # the addon stores metres (GC * 0.1)
N_MOVES, N_CTX, NONE16 = 251, 20, 0xFFFF
FPS_SRC, FPS_DST = 30, 30   # Colosseum clips are authored at 30 fps (header timings agree)
N64_WRAP, N64_MIRROR, N64_CLAMP = 0, 1, 2

# ---------------------------------------------------------------- math
def rot(r):
    sx, cx = math.sin(r[0]), math.cos(r[0]); sy, cy = math.sin(r[1]), math.cos(r[1]); sz, cz = math.sin(r[2]), math.cos(r[2])
    return [[cy*cz, sx*sy*cz-cx*sz, cx*sy*cz+sx*sz], [cy*sz, sx*sy*sz+cx*cz, cx*sy*sz-sx*cz], [-sy, sx*cy, cx*cy]]

def mul(a, b):
    return [[sum(a[r][k]*b[k][c] for k in range(3)) for c in range(3)] + [sum(a[r][k]*b[k][3] for k in range(3)) + a[r][3]] for r in range(3)]

IDENT = [[1,0,0,0],[0,1,0,0],[0,0,1,0]]

def compose(bones, sample):
    """Stadium/HSD aligned-scale composition. sample(i) -> (t, r, s) in GC units/radians."""
    pivot, acc, draw = [], [], []
    for i, b in enumerate(bones):
        t, r, s = sample(i)
        p = b['parent']
        pa = acc[p] if p >= 0 else (1.0, 1.0, 1.0)
        pm = pivot[p] if p >= 0 else IDENT
        R = rot(r)
        M = mul(pm, [[R[k][0], R[k][1], R[k][2], t[k]*pa[k]] for k in range(3)])
        a = [pa[k]*s[k] for k in range(3)]
        pivot.append(M); acc.append(a)
        draw.append([[M[k][c]*a[c] for c in range(3)] + [M[k][3]] for k in range(3)])
    return draw, pivot, acc

def bang(rad):
    v = int(round(rad / (2*math.pi) * 65536)) % 65536
    return v - 65536 if v >= 32768 else v

def i16(v):
    return max(-32768, min(32767, int(round(v))))

# ---------------------------------------------------------------- keyframes
def evaluate(keys, frame, fallback):
    if not keys: return fallback
    if frame <= keys[0].frame: return keys[0].value
    if frame >= keys[-1].frame: return keys[-1].value
    lo, hi = 0, len(keys) - 1
    while hi - lo > 1:
        mid = (lo + hi) // 2
        if keys[mid].frame <= frame: lo = mid
        else: hi = mid
    k0, k1 = keys[lo], keys[hi]
    span = k1.frame - k0.frame
    if span <= 0: return k1.value
    t = (frame - k0.frame) / span
    interp = str(k0.interpolation).split('.')[-1].upper()
    if interp == 'CONSTANT': return k0.value
    m0 = k0.slope_out if k0.slope_out is not None else None
    m1 = k1.slope_in if k1.slope_in is not None else None
    if interp == 'BEZIER' and m0 is not None and m1 is not None:
        m0 *= span; m1 *= span
        t2, t3 = t*t, t*t*t
        return (2*t3-3*t2+1)*k0.value + (t3-2*t2+t)*m0 + (-2*t3+3*t2)*k1.value + (t3-t2)*m1
    return k0.value + (k1.value - k0.value) * t

# ---------------------------------------------------------------- writer
class W:
    def __init__(self): self.b = bytearray()
    def u8(self, v): self.b += struct.pack('<B', v & 0xFF)
    def i8(self, v): self.b += struct.pack('<b', v)
    def u16(self, v): self.b += struct.pack('<H', v & 0xFFFF)
    def i16(self, v): self.b += struct.pack('<h', i16(v))
    def u32(self, v): self.b += struct.pack('<I', v & 0xFFFFFFFF)
    def i32(self, v): self.b += struct.pack('<i', int(v))
    def f32(self, v): self.b += struct.pack('<f', v)
    def fixed(self, v): self.b += struct.pack('<i', max(-2**31, min(2**31-1, int(round(v*65536)))))
    def raw(self, s): self.b += s

# ---------------------------------------------------------------- move tables
def move_categories():
    """move id (1..251) -> 'physical' | 'special' | 'status' by Gen 3 rules."""
    tclass = {int(r['id']): int(r['damage_class_id'] or 0) for r in csv.DictReader(open(os.path.join(ROOT, 'types.csv')))}
    out = {}
    for r in csv.DictReader(open(os.path.join(ROOT, 'moves.csv'))):
        mid = int(r['id'])
        if mid > N_MOVES: continue
        dc = int(r['damage_class_id'] or 1)
        if dc == 1: out[mid] = 'status'
        else: out[mid] = 'physical' if tclass.get(int(r['type_id']), 2) == 2 else 'special'
    return out

# ---------------------------------------------------------------- conversion
def convert(model, header, categories):
    bones = [dict(parent=(-1 if b.parent_index is None else b.parent_index),
                  t=[c*GC_PER_METER for c in b.position], r=list(b.rotation), s=list(b.scale), name=b.name)
             for b in model.bones]
    name_to_index = {b['name']: i for i, b in enumerate(bones)}
    draw, pivot, acc = compose(bones, lambda i: (bones[i]['t'], bones[i]['r'], bones[i]['s']))

    # inverse of draw[i]: local = diag(1/a) * R^T * (p - t)
    def to_local(i, p):
        M, a = pivot[i], acc[i]
        d = [p[0]-M[0][3], p[1]-M[1][3], p[2]-M[2][3]]
        l = [M[0][k]*d[0] + M[1][k]*d[1] + M[2][k]*d[2] for k in range(3)]
        return [l[k] / (a[k] if abs(a[k]) > 1e-9 else 1e-9) for k in range(3)]
    def nrm_local(i, n):
        M = pivot[i]
        l = [M[0][k]*n[0] + M[1][k]*n[1] + M[2][k]*n[2] for k in range(3)]
        m = math.sqrt(sum(c*c for c in l)) or 1.0
        return [c/m for c in l]

    textures, tex_index = [], {}
    def texture_for(mesh):
        mat = mesh.material
        layer = mat.texture_layers[0] if mat and mat.texture_layers else None
        if layer is None:
            key = ('solid', tuple(round(c, 3) for c in (mat.diffuse_color if mat else (1, 1, 1, 1))))
            if key not in tex_index:
                r, g, b = [int(max(0, min(1, c))*255) for c in key[1][:3]]
                textures.append(dict(w=4, h=4, rgba=bytes([r, g, b, 255])*16))
                tex_index[key] = len(textures) - 1
            return tex_index[key], None
        img = layer.image
        key = ('img', img.image_id, img.palette_id, img.name)
        if key not in tex_index:
            row = img.width * 4
            px = img.pixels
            flipped = b''.join(px[y*row:(y+1)*row] for y in range(img.height-1, -1, -1))
            textures.append(dict(w=img.width, h=img.height, rgba=flipped))
            tex_index[key] = len(textures) - 1
        return tex_index[key], layer

    def wrap_code(mode):
        m = str(mode).split('.')[-1].upper()
        if 'MIRROR' in m: return N64_MIRROR
        if 'CLAMP' in m: return N64_CLAMP
        return N64_WRAP

    prims = []
    for mesh in model.meshes:
        if mesh.is_hidden or not mesh.faces: continue
        tex, layer = texture_for(mesh)
        bw = mesh.bone_weights
        skin_type = str(bw.type).split('.')[-1] if bw else 'RIGID'
        per_vertex_bone = {}
        if skin_type == 'WEIGHTED' and bw.assignments:
            for vi, pairs in bw.assignments:
                best = max(pairs, key=lambda p: p[1]) if pairs else None
                per_vertex_bone[vi] = name_to_index.get(best[0], mesh.parent_bone_index) if best else mesh.parent_bone_index
        elif skin_type == 'SINGLE_BONE' and bw and bw.bone_name in name_to_index:
            default_bone = name_to_index[bw.bone_name]
        else:
            default_bone = mesh.parent_bone_index
        uvs = mesh.uv_layers[0].uvs if mesh.uv_layers else None
        normals = mesh.normals
        verts, vkey, idx = [], {}, []
        loop = 0
        for face in mesh.faces:
            corners = []
            for vi in face:
                uv = uvs[loop] if uvs else (0.0, 0.0)
                n = normals[loop] if normals else (0.0, 1.0, 0.0)
                key = (vi, round(uv[0], 5), round(uv[1], 5), round(n[0], 3), round(n[1], 3), round(n[2], 3))
                if key not in vkey:
                    bone = per_vertex_bone.get(vi, default_bone if skin_type != 'WEIGHTED' else mesh.parent_bone_index)
                    p = [c*GC_PER_METER for c in mesh.vertices[vi]]
                    lp = to_local(bone, p)
                    ln = nrm_local(bone, n)
                    vkey[key] = len(verts)
                    verts.append(dict(pos=[c*UNITS for c in lp], uv=(uv[0], 1.0 - uv[1]), nrm=ln, skin=bone))
                corners.append(vkey[key]); loop += 1
            for k in range(1, len(corners) - 1):   # fan-triangulate
                idx += [corners[0], corners[k], corners[k+1]]
        if len(verts) > 65535 or not idx: continue
        prims.append(dict(tex=tex, verts=verts, idx=idx,
                          cms=wrap_code(layer.wrap_s) if layer else N64_WRAP,
                          cmt=wrap_code(layer.wrap_t) if layer else N64_WRAP,
                          translucent=bool(mesh.material and mesh.material.is_translucent)))

    # ---- animations: bake every DAT clip at 30 fps
    anims = []
    for a in model.bone_animations:
        end = max([t.end_frame for t in a.tracks] + [1.0])
        frames = int(end) + 1
        tracks = {}
        for tr in a.tracks:
            bi = tr.bone_index
            if bi is None or bi < 0 or bi >= len(bones): continue
            b = bones[bi]
            def channel(keys_xyz, rest, conv):
                out = []
                for c in range(3):
                    keys = sorted(keys_xyz[c], key=lambda k: k.frame) if keys_xyz and keys_xyz[c] else []
                    if not keys: out.append(conv(rest[c])); continue
                    vals = [conv(evaluate(keys, f, rest[c])) for f in range(frames)]
                    out.append(vals if len(set(vals)) > 1 else vals[0])
                return out
            tracks[bi] = dict(
                # location keys and rest_position are metres; the units factor is applied once below
                t=channel(tr.location, tr.rest_position if tr.rest_position else [c/GC_PER_METER for c in b['t']], lambda v: v),
                r=channel(tr.rotation, tr.rest_rotation or b['r'], lambda v: v),
                s=channel(tr.scale, tr.rest_scale or b['s'], lambda v: v))
            # location channels are metres in the IR: convert to int16 units here
            tt = tracks[bi]['t']
            tracks[bi]['t'] = [([v*GC_PER_METER*UNITS for v in ch] if isinstance(ch, list) else ch*GC_PER_METER*UNITS) for ch in tt]
        anims.append(dict(name=a.name[:255], frames=max(1, frames), loop=bool(a.loop), tracks=tracks))

    # ---- contexts from the 17 Colosseum slots
    def slot_anim(slot):
        e = header.anim_entries[slot] if header and slot < len(header.anim_entries) else None
        if not e or not e.sub_anims: return None
        s = e.sub_anims[0]
        if s.motion_type != 0: return None
        return s.anim_index if s.anim_index < len(anims) else None
    idle = slot_anim(0); hit = slot_anim(8); faint = slot_anim(10)
    physical = slot_anim(2) or slot_anim(7) or idle
    special = slot_anim(1) if slot_anim(1) not in (None, idle) else physical
    status = slot_anim(6) if slot_anim(6) not in (None,) else (slot_anim(1) or idle)
    if idle is None: idle = 0
    ctx = [NONE16]*N_CTX
    ctx[0] = idle; ctx[1] = idle
    if faint is not None: ctx[2] = faint
    if hit is not None: ctx[3] = hit
    ctx[4] = physical if physical is not None else idle     # rom_context_255 = physical attack
    ctx[5] = special if special is not None else idle       # rom_context_256 = special attack
    moves = []
    for m in range(1, N_MOVES+1):
        cat = categories.get(m, 'physical')
        moves.append({'physical': physical, 'special': special, 'status': status}[cat] if True else idle)
    moves = [NONE16 if v is None else v for v in moves]

    # ---- rest pose := first idle frame. Many Colosseum files keep a bind pose
    # that stands well off the model's origin (Poochyena: 25 units forward)
    # while every animation is centred; the renderer anchors a model to its
    # rest pose, so such a model was drawn displaced onto the other battler.
    # Vertices are bone-local, so only the bones' rest SRT changes; clips that
    # do not animate a changed bone get its original rest as an explicit track.
    idle_anim = anims[idle] if anims and idle < len(anims) else None
    if idle_anim:
        first = lambda ch: ch[0] if isinstance(ch, list) else ch
        changed = {}
        for bi, tr in idle_anim['tracks'].items():
            b = bones[bi]
            nt = [first(c) / UNITS for c in tr['t']]; nr = [first(c) for c in tr['r']]; ns = [first(c) for c in tr['s']]
            if any(abs(a - c) > 1e-6 for a, c in zip(nt + nr + ns, list(b['t']) + list(b['r']) + list(b['s']))):
                changed[bi] = (list(b['t']), list(b['r']), list(b['s']))
                b['t'], b['r'], b['s'] = nt, nr, ns
        for a in anims:
            for bi, (ot, orr, os_) in changed.items():
                if bi not in a['tracks']:
                    a['tracks'][bi] = dict(t=[c * UNITS for c in ot], r=list(orr), s=list(os_))
        draw, pivot, acc = compose(bones, lambda i: (bones[i]['t'], bones[i]['r'], bones[i]['s']))

    # ---- metrics in raw units (rootScale applied by the caller)
    lo = [1e30]*3; hi = [-1e30]*3
    for p in prims:
        for v in p['verts']:
            m = draw[v['skin']]
            x, y, z = [c/UNITS for c in v['pos']]
            w = [(m[k][0]*x + m[k][1]*y + m[k][2]*z + m[k][3])*UNITS for k in range(3)]
            for k in range(3):
                lo[k] = min(lo[k], w[k]); hi[k] = max(hi[k], w[k])
    metrics = dict(height=hi[1]-lo[1], floor=lo[1], radius=max(hi[0]-lo[0], hi[2]-lo[2])/2) if prims else dict(height=0, floor=0, radius=0)
    return dict(bones=bones, prims=prims, textures=textures, anims=anims, ctx=ctx, moves=moves, metrics=metrics)

def pack(species, data, root_scale):
    w = W()
    bones, prims, textures, anims = data['bones'], data['prims'], data['textures'], data['anims']
    w.raw(b'DSM5'); w.u16(species); w.u16(len(bones)); w.u16(len(prims)); w.u16(len(textures)); w.u16(len(anims)); w.u16(0)
    w.f32(root_scale); w.u8(0)
    m = data['metrics']
    w.f32(m['height']*root_scale); w.f32(m['floor']*root_scale); w.f32(m['radius']*root_scale)
    for v in data['moves']: w.u16(v)
    for _ in range(N_MOVES): w.i16(-1)
    for v in data['ctx']: w.u16(v)
    for b in bones:
        w.i16(b['parent'])
        for k in range(3): w.i16(b['t'][k]*UNITS)
        for k in range(3): w.i16(bang(b['r'][k]))
        for k in range(3): w.fixed(b['s'][k])
    for p in prims:
        w.u16(p['tex'])
        flags = 4 | (2 if p.get('additive') else 0)   # lighting on, no cull
        w.u8(flags); w.u32(0)
        w.u8(p['cms']); w.u8(p['cmt']); w.u8(0); w.u8(0); w.u8(0); w.u8(0)
        w.f32(1.0); w.f32(1.0); w.i16(-1); w.u8(0); w.u16(0)
        w.u16(len(p['verts'])); w.u16(len(p['idx']))
        for v in p['verts']:
            for k in range(3): w.i16(v['pos'][k])
            w.i16(v['uv'][0]*512); w.i16(v['uv'][1]*512)
            for k in range(3): w.u8(int(round(v['nrm'][k]*127)) % 256)
            w.u8(255); w.u8(v['skin'])
        for i in p['idx']: w.u16(i)
    for t in textures:
        w.u16(t['w']); w.u16(t['h']); w.u32(len(t['rgba'])); w.raw(t['rgba'])
    for a in anims:
        name = a['name'].encode('latin1', 'replace')[:255]
        w.u8(len(name)); w.raw(name); w.u16(a['frames']); w.u16(0); w.i16(-1)
        for bi in range(len(bones)):
            tr = a['tracks'].get(bi)
            if not tr: w.u8(0); continue
            w.u8(1)
            for key, conv, write in (('t', lambda v: v, w.i16), ('r', bang, w.i16), ('s', lambda v: v, w.fixed)):
                for ch in tr[key]:
                    if isinstance(ch, list):
                        w.u8(1)
                        for v in ch: write(conv(v))
                    else:
                        w.u8(0); write(conv(ch))
    return bytes(w.b)

# ---------------------------------------------------------------- driver
def main():
    out_dir = sys.argv[1]; only = set(sys.argv[2:])
    mapping = json.load(open(os.path.join(ROOT, 'name_to_dex.json')))
    categories = move_categories()
    os.makedirs(out_dir, exist_ok=True)
    report = {}
    for name, dex in sorted(mapping.items(), key=lambda kv: (kv[1], kv[0])):
        if only and name not in only: continue
        path = os.path.join(ROOT, 'fs', f'pkx_{name}.fsys')
        if not os.path.exists(path): continue
        try:
            d = open(path, 'rb').read()
            e = fsys.entries(d)[0]
            raw = fsys.payload(d, e)
            tmp = os.path.join(out_dir, name + '.pkx'); open(tmp, 'wb').write(raw)
            (meta, scene), = pkx_to_ir.load(tmp, name + '.pkx')
            data = convert(scene.models[0], meta.pkx_header, categories)
            blob = pack(dex, data, 1.0/UNITS)
            open(os.path.join(out_dir, f'{name}.dsm'), 'wb').write(blob)
            os.remove(tmp)
            report[name] = dict(dex=dex, bones=len(data['bones']), prims=len(data['prims']), textures=len(data['textures']),
                                anims=[(a['name'], a['frames']) for a in data['anims']], ctx=data['ctx'][:6],
                                height_gc=data['metrics']['height']/UNITS, bytes=len(blob))
            print(f"{name:24s} #{dex:03d} bones={len(data['bones'])} prims={len(data['prims'])} tex={len(data['textures'])} anims={len(data['anims'])} h={data['metrics']['height']/UNITS:.2f}gc {len(blob)//1024}KB", flush=True)
        except Exception as ex:
            import traceback
            report[name] = dict(dex=dex, error=str(ex)[:300])
            print(f"{name:24s} #{dex:03d} ERROR {ex}", flush=True)
            if only: traceback.print_exc()
    json.dump(report, open(os.path.join(out_dir, 'report.json'), 'w'), indent=1)

if __name__ == '__main__':
    main()
