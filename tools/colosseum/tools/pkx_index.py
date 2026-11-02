#!/usr/bin/env python3
"""Index every pkx_*.fsys: PKX header species/type ids and animation entries."""
import os, sys, json, glob
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pkx_to_ir  # stubs bpy and sets up the addon path
from importer.phases.extract.extract import extract_dat
import fsys
rows = []
for path in sorted(glob.glob('fs/pkx_*.fsys')):
    d = open(path, 'rb').read()
    for e in fsys.entries(d):
        raw = fsys.payload(d, e)
        try:
            (dat, meta), = extract_dat(raw, e['name'] + '.pkx', options={})
            h = meta.pkx_header
            rows.append(dict(file=os.path.basename(path), entry=e['name'], ftype=e['ftype'], size=len(raw),
                             species=h.species_id, type=h.type_id, anims=len(h.anim_entries), flags=h.flags,
                             shiny=meta.shiny_params is not None))
        except Exception as ex:
            rows.append(dict(file=os.path.basename(path), entry=e['name'], error=str(ex)[:120]))
json.dump(rows, open('pkx_index.json', 'w'), indent=0)
ok = [r for r in rows if 'species' in r]
print(len(rows), 'entries;', len(ok), 'parsed headers;', len(rows) - len(ok), 'errors')
print('species ids range', min(r['species'] for r in ok), max(r['species'] for r in ok))
from collections import Counter
print('types', Counter(r['type'] for r in ok))
print('multi-species files', Counter(r['species'] for r in ok).most_common(5))
for r in ok[:8]: print(r)
for r in rows:
    if 'error' in r: print('ERR', r); break
