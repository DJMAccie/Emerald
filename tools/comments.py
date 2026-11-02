#!/usr/bin/env python3
"""Comment clean-up for the mod's Lua files, with proof that no code changes.

  comments.py extract FILE...              -> JSON lines, one per comment run, on stdout
  comments.py apply KEEP.json FILE...      -> rewrite FILEs: drop every comment run whose id is
                                              not in KEEP.json; kept ids become one line of the
                                              given text. Collapses blank-line runs. Then checks
                                              each file with bcsig (bytecode without line info):
                                              a file whose code changed is restored and reported.
KEEP.json = {"lib/Water.lua:120": "short essential text", ...}  (ids from extract)
A run = consecutive whole-line comments (kind "lines"), a comment after code ("trail"), or a
long --[[ ]] comment ("block"). "next" in extract output = the code line the run belongs to.
"""
import json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))


def comment_spans(src):
    """(start, end) offsets of every comment, found with a small Lua lexer."""
    spans, i, n = [], 0, len(src)
    long_open = re.compile(r'\[(=*)\[')
    while i < n:
        c = src[i]
        if c == '-' and src.startswith('--', i):
            m = long_open.match(src, i + 2)
            if m:
                close = ']' + m.group(1) + ']'
                j = src.find(close, m.end())
                j = n if j < 0 else j + len(close)
            else:
                j = src.find('\n', i)
                j = n if j < 0 else j
            spans.append((i, j))
            i = j
        elif c in '"\'':
            j = i + 1
            while j < n and src[j] != c:
                if src[j] == '\\':
                    j += 1
                elif src[j] == '\n':
                    break
                j += 1
            i = j + 1
        elif c == '[':
            m = long_open.match(src, i)
            if m:
                close = ']' + m.group(1) + ']'
                j = src.find(close, m.end())
                i = n if j < 0 else j + len(close)
            else:
                i += 1
        else:
            i += 1
    return spans


def runs_of(path):
    src = open(path, encoding='utf-8', errors='surrogateescape').read()
    spans = comment_spans(src)
    line_start = lambda p: src.rfind('\n', 0, p) + 1
    def line_end(p):
        e = src.find('\n', p)
        return len(src) if e < 0 else e
    runs, cur = [], None
    for s, e in spans:
        ls = line_start(s)
        whole = src[ls:s].strip() == '' and src[e:line_end(e)].strip() == ''
        multi = '\n' in src[s:e]
        kind = 'block' if multi else ('lines' if whole else 'trail')
        if kind == 'lines' and cur and cur['kind'] == 'lines' and src[cur['end']:ls].strip() == '' \
                and src[cur['end']:ls].count('\n') == 1:
            cur['end'] = e
            cur['parts'].append((s, e))
            continue
        cur = {'kind': kind, 'start': s, 'end': e, 'ls': ls, 'parts': [(s, e)]}
        runs.append(cur)
    for r in runs:
        r['line'] = src.count('\n', 0, r['start']) + 1
        r['id'] = '%s:%d' % (path, r['line'])
        text = ' '.join(re.sub(r'^--(\[=*\[)?|(\]=*\])$', '', src[a:b]).strip() for a, b in r['parts'])
        r['text'] = re.sub(r'\s+', ' ', text).strip()
        nxt = src[r['end']:r['end'] + 400].split('\n')
        r['next'] = next((l.strip() for l in nxt if l.strip() and not l.strip().startswith('--')), '')[:120]
    return src, runs


def bcsig(path):
    return subprocess.run([sys.executable, os.path.join(HERE, 'bcsig.py'), path],
                          capture_output=True, text=True).stdout


def rewrite(path, keep):
    src, runs = runs_of(path)
    out, pos = [], 0
    for r in runs:
        new = keep.get(r['id'])
        if r['kind'] == 'trail':
            cut_from = r['start']
            while cut_from > 0 and src[cut_from - 1] in ' \t':
                cut_from -= 1
            out.append(src[pos:cut_from])
            if new:
                out.append(' -- ' + new)
            pos = r['end']
            continue
        whole = src[r['ls']:r['start']].strip() == ''
        if whole:
            out.append(src[pos:r['ls']])
            indent = src[r['ls']:r['start']]
            end = r['end'] + 1 if src[r['end']:r['end'] + 1] == '\n' else r['end']
            if new:
                out.append(indent + '-- ' + new + '\n')
            pos = end
        else:  # block comment after code on the same line
            out.append(src[pos:r['start']])
            out.append(('-- ' + new) if new else ('\n' if '\n' in src[r['start']:r['end']] else ' '))
            pos = r['end']
    out.append(src[pos:])
    text = re.sub(r'\n[ \t]*\n([ \t]*\n)+', '\n\n', ''.join(out))
    text = re.sub(r'[ \t]+\n', '\n', text)
    return src, text


def main():
    if len(sys.argv) < 3:
        print(__doc__); sys.exit(1)
    if sys.argv[1] == 'extract':
        for f in sys.argv[2:]:
            for r in runs_of(f)[1]:
                print(json.dumps({k: r[k] for k in ('id', 'kind', 'text', 'next')}, ensure_ascii=False))
    elif sys.argv[1] == 'apply':
        keep = json.load(open(sys.argv[2]))
        bad, before, after = [], 0, 0
        for f in sys.argv[3:]:
            sig = bcsig(f)
            src, text = rewrite(f, keep)
            open(f, 'w', encoding='utf-8', errors='surrogateescape').write(text)
            if bcsig(f) != sig or sig.startswith('COMPILE ERROR'):
                open(f, 'w', encoding='utf-8', errors='surrogateescape').write(src)
                bad.append(f)
                text = src
            before += src.count('\n'); after += text.count('\n')
        print('regels: %d -> %d (-%d)' % (before, after, before - after))
        print('teruggezet (code zou veranderen): %s' % (' '.join(bad) or 'geen'))
    else:
        print(__doc__); sys.exit(1)


if __name__ == '__main__':
    main()
