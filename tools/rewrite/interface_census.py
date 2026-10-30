#!/usr/bin/env python3
"""interface_census.py — what the own-code rewrite's engine modules must provide, measured from our own code.

Two directions, both read only from files that are OURS (the 53 modules classified `new` in
docs/proposals/dropin/classes.tsv) plus the classification table itself:

  requires  module -> members of it that our own modules call (the interface the new engine must expose)
  host      own module -> members that other files call on it (the interface the new scene must honour)
  vfields   the fields of the `V` table our own modules use

Usage: python3 tools/rewrite/interface_census.py [--write ~/Documents/emerald3d/docs/rewrite/interface-census.md]
       (reads ~/Documents/battle-art-notquiteog/lib by default; CENSUS_SRC overrides)
"""
import argparse
import collections
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CLASSES = os.path.join(ROOT, 'docs', 'proposals', 'dropin', 'classes.tsv')
SRC = os.environ.get('CENSUS_SRC', os.path.expanduser('~/Documents/battle-art-notquiteog/lib'))

REQ = re.compile(r'V\.require\s*\(\s*[\'"]([\w]+)[\'"]\s*\)')
REQ2 = re.compile(r'V\.require\s*[\'"]([\w]+)[\'"]')
LOCALS = re.compile(r'local\s+([\w,\s]+?)\s*=\s*([^\n]*)')


def own_modules():
    own = set()
    for line in open(CLASSES):
        cls, path = line.rstrip('\n').split('\t')[:2]
        if cls == 'new' and path.startswith('lib/') and path.endswith('.lua'):
            own.add(path[4:-4])
    return own


def read(name):
    with open(os.path.join(SRC, name + '.lua'), errors='replace') as fh:
        return fh.read()


def aliases(src):
    """local A, B = V.require('X'), V.require('Y')  and  local A = V.require 'X'"""
    out = {}
    for m in LOCALS.finditer(src):
        rhs = m.group(2)
        if 'V.require' not in rhs:
            continue
        names = [n.strip() for n in m.group(1).split(',')]
        mods = REQ.findall(rhs) or REQ2.findall(rhs)
        for name, mod in zip(names, mods):
            out[name] = mod
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--write')
    args = ap.parse_args()
    own = own_modules()
    files = sorted(f[:-4] for f in os.listdir(SRC) if f.endswith('.lua'))
    requires = collections.defaultdict(lambda: collections.defaultdict(set))
    vfields = collections.Counter()
    vfiles = collections.defaultdict(set)
    for name in files:
        src = read(name)
        if name in own:
            for f in re.finditer(r'(?<![\w.])V\.(\w+)', src):
                vfields[f.group(1)] += 1
                vfiles[f.group(1)].add(name)
        for m in re.finditer(r'V\.require\s*\(\s*[\'"]([\w]+)[\'"]\s*\)\s*\.\s*(\w+)', src):
            requires[m.group(1)][m.group(2)].add(name)
        for alias, mod in aliases(src).items():
            for m in re.finditer(r'(?<![\w.])' + re.escape(alias) + r'\.(\w+)', src):
                requires[mod][m.group(1)].add(name)
    lines = ['# Interface census (own code -> engine modules)', '',
             'Measured by `tools/rewrite/interface_census.py` on 2026-10-29 from the 53 own modules '
             '(`new` in `docs/proposals/dropin/classes.tsv`). It lists only members our own code actually touches; '
             'the new engine only has to provide these.', '',
             '## `V` fields used by our own modules', '',
             '| field | uses | modules |', '|---|---|---|']
    for field, n in vfields.most_common():
        lines.append('| `V.%s` | %d | %d |' % (field, n, len(vfiles[field])))
    lines += ['', '## Modules and members our own code calls', '',
              '| module | members | used by (own modules) |', '|---|---|---|']
    for mod in sorted(requires):
        mem = requires[mod]
        if not mem:
            continue
        own_callers = sorted({c for callers in mem.values() for c in callers if c in own})
        other = sorted({c for callers in mem.values() for c in callers if c not in own})
        lines.append('| `%s` | %s | %s |' % (
            mod, ', '.join('`%s`' % m for m in sorted(mem)),
            ', '.join(own_callers) + (' (+%d other files)' % len(other) if other else '')))
    text = '\n'.join(lines) + '\n'
    if args.write:
        os.makedirs(os.path.dirname(os.path.abspath(args.write)), exist_ok=True)
        with open(args.write, 'w') as fh:
            fh.write(text)
        print('wrote', args.write, len(lines), 'lines')
    else:
        sys.stdout.write(text)


if __name__ == '__main__':
    main()
