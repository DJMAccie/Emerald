#!/usr/bin/env python3
"""Join everything the engine knows about each metatile of a Gen 3 tileset pair:

  * canonical behavior id   (<cache>/objects/pack.lua  behaviors[pair][mid])
  * collision byte          (<cache>/mid_index.lua     [pair][mid].coll)
  * pret metatile label     (engine src/core/game3/constants/<game>/metatile_labels.lua)
  * behavior name           (engine constants metatile_behaviors, canonicalised the
                             way src/core/game3/mb.lua does: FRLG ids by name,
                             Emerald-only ones at 0x100 + raw)

and write <out>/<pair>.tsv plus a compact summary to stdout.

  python3 annotate.py <cache-root> <engine-root> <game> <pair> <out-dir>
"""
import os, re, sys, json, collections

def lua_int(s):
    s = s.strip()
    return int(s, 16) if s.lower().startswith('0x') else int(s)

def load_behavior_names(engine, game):
    """name -> raw id for one game's metatile_behaviors.lua"""
    p = os.path.join(engine, 'src/core/game3/constants', game, 'metatile_behaviors.lua')
    out = {}
    for m in re.finditer(r'(MB_[A-Z0-9_]+)\s*=\s*(0x[0-9A-Fa-f]+|\d+)', open(p).read()):
        out[m.group(1)] = lua_int(m.group(2))
    return out

RENAMES = {'NO_RUNNING': 'RUNNING_DISALLOWED', 'NO_SURFACING': 'UNDERWATER_BLOCKED_ABOVE',
           'NON_ANIMATED_DOOR': 'CAVE_DOOR', 'ANIMATED_DOOR': 'WARP_DOOR'}

def canonical_names(engine):
    """canonical id -> name, following src/core/game3/mb.lua"""
    fr = load_behavior_names(engine, 'firered')
    em = load_behavior_names(engine, 'emerald')
    ids, names = {}, {}
    for full, v in sorted(fr.items(), key=lambda kv: (kv[1], kv[0])):
        n = full[3:]
        ids[n] = v
        names.setdefault(v, n)
    for full, raw in sorted(em.items(), key=lambda kv: (kv[1], kv[0])):
        n = full[3:]
        if n in ids:
            continue
        alias = RENAMES.get(n)
        if alias and alias in ids:
            ids[n] = ids[alias]
        else:
            v = 0x100 + raw
            ids[n] = v
            names.setdefault(v, n)
    return names

def load_labels(engine, game):
    p = os.path.join(engine, 'src/core/game3/constants', game, 'metatile_labels.lua')
    out = collections.defaultdict(dict)  # tileset-name -> mid -> label
    for m in re.finditer(r'METATILE_([A-Za-z0-9]+)_([A-Za-z0-9_]+)\s*=\s*(0x[0-9A-Fa-f]+|\d+)', open(p).read()):
        out[m.group(1)][lua_int(m.group(3))] = m.group(2)
    return out

def load_pack_behaviors(cache, pair):
    s = open(os.path.join(cache, 'objects/pack.lua')).read()
    m = re.search(r'\["behaviors"\]=\{', s)
    body = s[m.end():]
    m2 = re.search(r'\["%s"\]=\{([^}]*)\}' % re.escape(pair), body)
    out = {}
    for k, v in re.findall(r'\[(\d+)\]=(\d+)', m2.group(1)):
        out[int(k)] = int(v)
    return out

def load_mid_index(cache, pair):
    s = open(os.path.join(cache, 'mid_index.lua')).read()
    a = s.index('["%s"] = {' % pair)
    b = s.find('\n  ["', a + 10)
    body = s[a:b if b > 0 else len(s)]
    out = {}
    for mid, coll, beh in re.findall(r'\[(\d+)\]\s*=\s*\{\s*tiles\s*=\s*\{[^}]*\},\s*coll\s*=\s*(\d+),\s*behavior\s*=\s*(\d+)', body):
        out[int(mid)] = (int(coll), int(beh))
    return out

def main():
    cache, engine, game, pair, out = sys.argv[1:6]
    names = canonical_names(engine)
    labels = load_labels(engine, game)
    beh = load_pack_behaviors(cache, pair)
    idx = load_mid_index(cache, pair)
    primary, secondary = pair.split('__', 1)
    # pret label tileset names: primary "General"; secondary CamelCase of the pair suffix
    sec_label_key = ''.join(w.capitalize() for w in secondary.split('_'))
    sec_labels = None
    for k in labels:
        if k.lower() == sec_label_key.lower():
            sec_labels = labels[k]
    os.makedirs(out, exist_ok=True)
    rows = []
    for mid in sorted(set(beh) | set(idx)):
        coll, rawbeh = idx.get(mid, (None, None))
        b = beh.get(mid)
        bname = names.get(b, '?') if b is not None else ''
        if mid < 0x200:
            label = labels.get('General', {}).get(mid, '')
        else:
            label = (sec_labels or {}).get(mid, '') or (sec_labels or {}).get(mid - 0x200, '')
        rows.append((mid, coll, b, bname, label))
    with open(os.path.join(out, pair + '.tsv'), 'w') as f:
        f.write('mid\tcoll\tbeh\tbeh_name\tlabel\n')
        for mid, coll, b, bname, label in rows:
            f.write('0x%03X\t%s\t%s\t%s\t%s\n' % (mid, coll, ('0x%X' % b) if b is not None else '', bname, label))
    hist = collections.Counter(r[3] for r in rows if r[2] not in (None, 0))
    print(pair, 'mids=%d' % len(rows), 'secondary label set:', 'yes' if sec_labels else 'none')
    print('behaviors (non-NORMAL):')
    for n, c in hist.most_common():
        mids = [r[0] for r in rows if r[3] == n]
        print('  %-32s %3d  %s' % (n, c, ' '.join('%03X' % m for m in mids[:40]) + (' ...' if len(mids) > 40 else '')))
    lab = [r for r in rows if r[4]]
    print('labelled: %d' % len(lab))
    for mid, coll, b, bname, label in lab:
        print('  %03X coll=%s %-28s %s' % (mid, coll, bname, label))

if __name__ == '__main__':
    main()
