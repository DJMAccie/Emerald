#!/usr/bin/env python3
"""learn.py: add a rule, a lesson or a journal line to docs/knowledge, then run check.py.

  learn.py rule "Title" --rule "..." --source "Petya 2026-11-02: \\"...\\"" [--group Workflow]
  learn.py lesson "Title" --cause "..." --fix "..." [--rules R-38]
  learn.py journal "one line" [--date 2026-11-02]

New ids are the next free number. A rule goes at the end of its ## group (a new group is appended)."""
import argparse, datetime, os, re, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
K = os.path.join(HERE, '..', '..', 'docs', 'knowledge')

def next_id(path, prefix):
    ids = [int(n) for n in re.findall(r'^### %s-(\d+) ' % prefix, open(path, encoding='utf-8').read(), re.M)]
    return '%s-%02d' % (prefix, (max(ids) if ids else 0) + 1)

def record(rid, title, fields):
    return '\n### %s %s\n' % (rid, title) + ''.join('%s: %s\n' % (k, v) for k, v in fields if v)

def write(path, text):
    open(path, 'w', encoding='utf-8').write(text.rstrip('\n') + '\n')

def append_in_group(path, group, text):
    lines = open(path, encoding='utf-8').read().split('\n')
    heads = [i for i, l in enumerate(lines) if l.startswith('## ')]
    start = next((i for i in heads if lines[i][3:].strip().lower() == group.strip().lower()), None)
    if start is None:
        return write(path, '\n'.join(lines).rstrip('\n') + '\n\n## %s\n%s' % (group, text))
    end = next((i for i in heads if i > start), len(lines))
    while end > start and lines[end - 1].strip() == '': end -= 1
    lines[end:end] = text.rstrip('\n').split('\n')
    write(path, '\n'.join(lines))

def append_end(path, text):
    write(path, open(path, encoding='utf-8').read().rstrip('\n') + '\n' + text)

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='kind', required=True)
    r = sub.add_parser('rule'); r.add_argument('title'); r.add_argument('--rule', required=True)
    r.add_argument('--source', required=True); r.add_argument('--group', default='Workflow')
    l = sub.add_parser('lesson'); l.add_argument('title'); l.add_argument('--cause', required=True)
    l.add_argument('--fix', required=True); l.add_argument('--rules', default='')
    j = sub.add_parser('journal'); j.add_argument('line'); j.add_argument('--date', default=datetime.date.today().isoformat())
    a = ap.parse_args()
    if a.kind == 'rule':
        p = os.path.join(K, 'rules.md'); rid = next_id(p, 'R')
        append_in_group(p, a.group, record(rid, a.title, [('Rule', a.rule), ('Source', a.source)]))
    elif a.kind == 'lesson':
        p = os.path.join(K, 'lessons.md'); rid = next_id(p, 'L')
        append_end(p, record(rid, a.title, [('Cause', a.cause), ('Fix', a.fix), ('Rules', a.rules)]))
    else:
        rid = 'journal'
        append_end(os.path.join(K, 'journal.md'), '- %s: %s' % (a.date, a.line.strip()))
    print(rid)
    sys.exit(subprocess.call([sys.executable, os.path.join(HERE, 'check.py')]))

if __name__ == '__main__': main()
