#!/usr/bin/env python3
"""trace_merge.py <out.tsv> <files.log>...   merge runtime file traces (docs/proposals/dropin/trace_driver.lua output).

Keeps the mod's own files (mods/BATTLE_ART_VOXEL_FORK/... read by the game, and `cache` lines = modules in the
mod's require cache), classes each with docs/proposals/dropin/classes.tsv (same / modified / new vs upstream base
03882a9; '?' = not installed), and writes "class<TAB>path<TAB>runs" sorted like runtime_files.tsv.
Prints the counts and the upstream (same/modified) files that the earlier trace (runtime_files.tsv) did not list."""
import sys, os, collections

HERE = os.path.dirname(os.path.abspath(__file__))
DROP = os.path.join(HERE, '..', '..', 'docs', 'proposals', 'dropin')
PREFIX = 'mods/BATTLE_ART_VOXEL_FORK/'


def main():
    out, logs = sys.argv[1], sys.argv[2:]
    cls = {}
    for l in open(os.path.join(DROP, 'classes.tsv')):
        k, p = l.rstrip('\n').split('\t', 1)
        cls[p] = k
    old = {}
    for l in open(os.path.join(DROP, 'runtime_files.tsv')):
        k, p = l.rstrip('\n').split('\t')[:2]
        old[p] = k
    runs = collections.Counter()
    for log in logs:
        seen = set()
        for l in open(log, errors='replace'):
            parts = l.rstrip('\n').split('\t', 1)
            if len(parts) != 2:
                continue
            kind, p = parts
            if kind == 'trace' or kind in ('dir', 'info'):
                continue
            if kind == 'cache':
                rel = p
            else:
                i = p.find(PREFIX)
                if i < 0:
                    continue
                rel = p[i + len(PREFIX):]
            if rel and rel not in seen:
                seen.add(rel)
                runs[rel] += 1
    rows = sorted((cls.get(p, '?'), p, n) for p, n in runs.items())
    with open(out, 'w') as f:
        for k, p, n in rows:
            f.write(f'{k}\t{p}\t{n}\n')
    c = collections.Counter(k for k, _, _ in rows)
    print('files', len(rows), dict(c), 'logs', len(logs))
    up = [(k, p) for k, p, _ in rows if k in ('same', 'modified') and p not in old]
    lua = [x for x in up if x[1].endswith('.lua')]
    print(f'upstream files not in the earlier trace: {len(up)} ({len(lua)} .lua)')
    for k, p in up:
        print(f'  NEW {k}\t{p}')
    gone = [p for p, k in old.items() if k in ('same', 'modified') and p not in runs]
    print(f'earlier-trace upstream files not seen now: {len(gone)}')
    for p in gone:
        print(f'  NOTSEEN\t{p}')


if __name__ == '__main__':
    main()
