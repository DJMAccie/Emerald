#!/usr/bin/env python3
"""The one place for hand-made terrain height rows (Gen3StairTerraces.lua).

gen_stair_terraces.py builds a row per map from the cartridge data; the installed file also carries rows
that were spliced by hand or tuned after generation, so a fresh run lost them. Those rows now live in
height_overrides.json and the generator applies them, so generator + overrides reproduces the installed
file. An entry is either
    "EM_MAP": {"row": ["<first lua line>", "<second lua line>"], "why": "..."}   replaces (or adds) the map's row
    "EM_MAP": {"drop": true, "why": "..."}                                        leaves the generated row out
Edit this file (never the output) to change a height by hand; give every entry a "why".

    python3 height_overrides.py snapshot [GENERATED.lua]   write an entry for every map where GENERATED differs from the installed file
    python3 height_overrides.py check [GENERATED.lua]      semantic compare of GENERATED (default: GEN_OUT=/tmp/...) with the installed file
"""
import json, os, re, sys, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
PATH = os.path.join(HERE, 'height_overrides.json')
INSTALLED = os.path.expanduser('~/Documents/battle-art-notquiteog/lib/Gen3StairTerraces.lua')
ROWSTART = re.compile(r'^ (EM_[A-Z0-9_]+)=\{')


def load():
    return json.load(open(PATH)) if os.path.exists(PATH) else {}


def apply(rows):
    """rows: {map: [line1, line2]} in generator order -> with the overrides applied (replaced rows keep their place)."""
    ov = load()
    out = {}
    for mp, r in rows.items():
        o = ov.get(mp)
        if o and o.get('drop'):
            continue
        out[mp] = o['row'] if o and 'row' in o else r
    for mp, o in ov.items():
        if mp not in out and 'row' in o:
            out[mp] = o['row']
    return out


def parse(text):
    """{map: [lines]}: a row starts at ' EM_X={' and runs to the next row or the closing brace."""
    rows, cur = {}, None
    for line in text.split('\n'):
        m = ROWSTART.match(line)
        if m:
            cur = m.group(1); rows[cur] = [line]
        elif line.startswith('}'):
            cur = None
        elif cur and line.strip():
            rows[cur].append(line)
    return rows


def snapshot(gen_path):
    gen, inst = parse(open(gen_path).read()), parse(open(INSTALLED).read())
    ov = load()
    for mp in sorted(set(gen) | set(inst)):
        if gen.get(mp) == inst.get(mp):
            continue
        if mp in inst:
            ov[mp] = {'row': inst[mp], 'why': ov.get(mp, {}).get('why', 'installed row kept: differs from a fresh generator run (hand-spliced or tuned after generation); review when touching this map')}
        else:
            ov[mp] = {'drop': True, 'why': ov.get(mp, {}).get('why', 'not in the installed file: a fresh run would add it')}
    json.dump(ov, open(PATH, 'w'), indent=1)
    open(PATH, 'a').write('\n')
    print('overrides:', len(ov), sorted(ov))


def check(gen_path):
    """Deep compare through luajit: both files must load to equal tables."""
    lua = ("local function load_(p) return assert(loadfile(p))() end "
           "local function eq(a,b) if type(a)~=type(b) then return false end "
           "if type(a)~='table' then return a==b end "
           "for k,v in pairs(a) do if not eq(v,b[k]) then return false,k end end "
           "for k in pairs(b) do if a[k]==nil then return false,k end end return true end "
           "local ok,k=eq(load_(arg[1]),load_(arg[2])) print(ok and 'IDENTICAL' or ('DIFFERENT at '..tostring(k))) os.exit(ok and 0 or 1)")
    r = subprocess.run(['luajit', '-e', 'arg={[1]="%s",[2]="%s"}' % (gen_path, INSTALLED), '-e', lua], capture_output=True, text=True)
    print(r.stdout.strip() or r.stderr.strip())
    return r.returncode


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'check'
    path = sys.argv[2] if len(sys.argv) > 2 else os.environ.get('GEN_OUT', '/tmp/Gen3StairTerraces.regen.lua')
    sys.exit(snapshot(path) if cmd == 'snapshot' else check(path))
