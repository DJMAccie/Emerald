#!/usr/bin/env python3
"""simcheck.py: does new code copy upstream code?  (verifier tool; lives on the dirty side)

  simcheck.py <file-or-dir> [...] [--ref DIR]... [--git REPO:REV:PATH]... [--report OUT.md]

Default reference: upstream base 03882a9 lib/ + data/ of ~/Documents/battle-art-notquiteog.
Per checked Lua file:
  exact  = code lines (>24 chars, not comments, not on the trivial list) identical to any reference line
  share  = winnowed token fingerprints (k=12 tokens; strings/numbers normalised, identifiers kept unless
           --normalise; window 8) found anywhere in the reference, as a fraction of the file's fingerprints.
           Fingerprints that also occur in an independent corpus (--null, default the engine's src/) are
           common Lua idioms and are left out on both sides.
  best   = the reference file sharing the most fingerprints, and that count
Calibration (2026-10-29): independent code (the engine's mods/examples) scores up to 11 % share and 3 exact
idiom lines per file; our own 51 new modules score 0-13 % (Gen3EmeraldAuto, Gen3CyclingRoad top) with exact hits
that are idioms (4-neighbour loops, pixel keys, uv sub-rects). So: FLAG at share >= 15 % or any exact line
(interface lines excluded), and a person reviews every flagged file and every exact line; target for new code:
no unexplained exact line and share well under 15 %.
"""
import os, re, sys, subprocess, hashlib, collections, argparse

TRIVIAL = {'local V=...', 'local V = ...', 'return M', 'end', 'else'}
KEYWORDS = set('and break do else elseif end false for function goto if in local nil not or repeat return then true until while'.split())
TOK = re.compile(r"""--\[(=*)\[.*?\]\1\]|--[^\n]*|\[(=*)\[.*?\]\2\]|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|0[xX][0-9a-fA-F]+|\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+|[A-Za-z_][A-Za-z0-9_]*|\.\.\.|\.\.|==|~=|<=|>=|::|\S""", re.S)
K, W = 12, 8   # k tokens per gram, winnow window

def tokens(src, keep_ids=False):
    out = []
    for m in TOK.finditer(src):
        t = m.group(0)
        if t.startswith('--'): continue
        if t[0] in '"\'' or t.startswith('[['): out.append('S')
        elif t[0].isdigit() or (t[0] == '.' and len(t) > 1 and t[1].isdigit()): out.append('N')
        elif t[0].isalpha() or t[0] == '_': out.append(t if (keep_ids or t in KEYWORDS) else 'I')
        else: out.append(t)
    return out

def fingerprints(src, keep_ids=False):
    toks = tokens(src, keep_ids)
    hs = [int(hashlib.md5(' '.join(toks[i:i+K]).encode()).hexdigest()[:12], 16) for i in range(max(0, len(toks)-K+1))]
    fp = set()
    for i in range(max(0, len(hs)-W+1)):
        fp.add(min(hs[i:i+W]))
    if hs and len(hs) < W: fp.add(min(hs))
    return fp

INTERFACE = re.compile(r"""^local\s+[\w,\s]+=\s*(V\.require|V\.data|require)\s*\(?\s*['"][\w./]+['"]\s*\)?;?$""")

def code_lines(src):
    for l in src.splitlines():
        s = l.strip()
        # interface lines (a module name the new code must also require) are facts, not copying
        if len(s) > 24 and not s.startswith('--') and s not in TRIVIAL and not INTERFACE.match(s):
            yield s

def ref_files(args):
    refs = {}
    gits = args.git or ['%s:03882a9:lib' % os.path.expanduser('~/Documents/battle-art-notquiteog'),
                        '%s:03882a9:data' % os.path.expanduser('~/Documents/battle-art-notquiteog')]
    if args.ref: gits = [] if not args.git else gits
    for g in gits:
        repo, rev, path = g.split(':', 2)
        names = subprocess.run(['git', '-C', repo, 'ls-tree', '-r', '--name-only', rev, path], capture_output=True, text=True).stdout.split()
        for n in names:
            if n.endswith('.lua'):
                refs['%s@%s:%s' % (os.path.basename(repo), rev, n)] = subprocess.run(['git', '-C', repo, 'show', '%s:%s' % (rev, n)], capture_output=True, text=True, errors='replace').stdout
    for d in args.ref or []:
        for root, _, fs in os.walk(d):
            for f in fs:
                if f.endswith('.lua'):
                    p = os.path.join(root, f); refs[p] = open(p, errors='replace').read()
    return refs

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('paths', nargs='+'); ap.add_argument('--ref', action='append'); ap.add_argument('--git', action='append')
    ap.add_argument('--report'); ap.add_argument('--min-share', type=float, default=0.15)
    ap.add_argument('--null', action='append', help='independent Lua corpus: fingerprints found there are common idioms, ignored (default: the gen1recomp engine src/)')
    ap.add_argument('--normalise', action='store_true', help='normalise identifiers too (stricter, more false hits)')
    a = ap.parse_args()
    refs = ref_files(a)
    keep = not a.normalise
    common = set(); commonlines = set()
    for d in (a.null or [os.path.expanduser('~/Documents/gen1recomp/src')]):
        for root, _, fs in os.walk(d):
            for f in fs:
                if f.endswith('.lua'):
                    t = open(os.path.join(root, f), errors='replace').read()
                    common |= fingerprints(t, keep); commonlines.update(code_lines(t))
    lines = set(); owner = collections.defaultdict(set)
    for name, src in refs.items():
        lines.update(l for l in code_lines(src) if l not in commonlines)
        for h in fingerprints(src, keep):
            if h not in common: owner[h].add(name)
    files = []
    for p in a.paths:
        if os.path.isdir(p):
            for root, _, fs in os.walk(p):
                files += [os.path.join(root, f) for f in fs if f.endswith('.lua')]
        else: files.append(p)
    rows = []; bad = 0
    for f in sorted(files):
        src = open(f, errors='replace').read()
        cl = list(code_lines(src)); ex = [l for l in cl if l in lines]
        fp = fingerprints(src, keep) - common; shared = [h for h in fp if h in owner]
        best = collections.Counter(n for h in shared for n in owner[h]).most_common(1)
        share = len(shared) / len(fp) if fp else 0.0
        flag = bool(ex) or share >= a.min_share
        bad += flag
        rows.append((share, f, len(cl), len(ex), best[0] if best else ('-', 0), flag, ex[:5]))
    rows.sort(reverse=True)
    out = ['# simcheck report', '', 'reference files: %d; checked files: %d; flagged: %d' % (len(refs), len(rows), bad), '',
           '| flag | file | code lines | exact | share | best match |', '|---|---|---|---|---|---|']
    for share, f, n, ne, best, flag, ex in rows:
        out.append('| %s | %s | %d | %d | %.1f%% | %s (%d) |' % ('FLAG' if flag else 'ok', f, n, ne, share*100, best[0], best[1]))
    out.append('')
    for share, f, n, ne, best, flag, ex in rows:
        if ex:
            out.append('- %s exact lines, e.g.: %s' % (f, ' | '.join(e[:80] for e in ex)))
    text = '\n'.join(out) + '\n'
    if a.report: open(a.report, 'w').write(text)
    print('\n'.join(out[:3]))
    for share, f, n, ne, best, flag, ex in rows[:15]:
        print('%s %-60s exact=%d share=%.1f%% best=%s' % ('FLAG' if flag else 'ok  ', f[-60:], ne, share*100, best[0][-40:]))
    sys.exit(1 if bad else 0)

if __name__ == '__main__':
    main()
