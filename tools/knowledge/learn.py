#!/usr/bin/env python3
"""learn.py: turn a user correction into a rule, a lesson, a gate or a journal line in docs/knowledge (one call each).

  learn.py rule "Title" --group "World shape" --rule "..." --source "user 2026-10-27: \\"...\\"" [--gate G-02] [--applied ...] [--lessons L-01] [--status active]
  learn.py lesson "Title" --symptom "..." --wrong "..." --cause "..." --fix "..." --proof "..." --rules R-04
  learn.py gate "Title" --checks "..." --command "..." --reads "..." --target "..." --rules R-04
  learn.py journal "one line" [--session "plateau builder 6"] [--date 2026-10-27]

Ids are assigned as the next free number and never reused. A rule goes at the end of its ## group (a new group is appended).
Runs check.py afterwards. Prints the new id."""
import argparse, datetime, os, re, subprocess, sys
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
K = os.path.join(R, 'docs', 'knowledge')

def next_id(path, prefix):
    ids = [int(m) for m in re.findall(r'^### %s-(\d+) ' % prefix, open(path, encoding='utf-8').read(), re.M)]
    return '%s-%02d' % (prefix, (max(ids) if ids else 0) + 1)

def record(rid, title, fields):
    return '\n### %s %s\n' % (rid, title) + ''.join('%s: %s\n' % (k, v) for k, v in fields)

def append_in_group(path, group, text):
    lines = open(path, encoding='utf-8').read().split('\n')
    heads = [i for i, l in enumerate(lines) if l.startswith('## ')]
    start = next((i for i in heads if l_eq(lines[i], group)), None)
    if start is None:
        body = '\n'.join(lines).rstrip('\n') + '\n\n## %s\n%s' % (group, text)
    else:
        end = next((i for i in heads if i > start), len(lines))
        while end > start and lines[end - 1].strip() == '': end -= 1
        lines[end:end] = text.rstrip('\n').split('\n')
        body = '\n'.join(lines)
    open(path, 'w', encoding='utf-8').write(body.rstrip('\n') + '\n')

def l_eq(line, group): return line[3:].strip().lower() == group.strip().lower()

def append_end(path, text):
    body = open(path, encoding='utf-8').read().rstrip('\n') + '\n' + text
    open(path, 'w', encoding='utf-8').write(body.rstrip('\n') + '\n')

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='kind', required=True)
    r = sub.add_parser('rule'); r.add_argument('title'); r.add_argument('--group', default='Workflow'); r.add_argument('--rule', required=True)
    r.add_argument('--source', required=True); r.add_argument('--gate', default='none yet'); r.add_argument('--applied', default='not yet')
    r.add_argument('--lessons', default='none'); r.add_argument('--status', default='active')
    l = sub.add_parser('lesson'); l.add_argument('title')
    for f in ('symptom', 'wrong', 'cause', 'fix', 'proof', 'rules'): l.add_argument('--' + f, required=True)
    g = sub.add_parser('gate'); g.add_argument('title')
    for f in ('checks', 'command', 'reads', 'target', 'rules'): g.add_argument('--' + f, required=True)
    j = sub.add_parser('journal'); j.add_argument('line'); j.add_argument('--session', default=''); j.add_argument('--date', default=datetime.date.today().isoformat())
    a = ap.parse_args()
    if a.kind == 'rule':
        p = os.path.join(K, 'rules.md'); rid = next_id(p, 'R')
        append_in_group(p, a.group, record(rid, a.title, [('Rule', a.rule), ('Source', a.source), ('Gate', a.gate), ('Applied', a.applied), ('Lessons', a.lessons), ('Status', a.status)]))
    elif a.kind == 'lesson':
        p = os.path.join(K, 'lessons.md'); rid = next_id(p, 'L')
        append_end(p, record(rid, a.title, [('Symptom', a.symptom), ('Wrong model', a.wrong), ('Cause', a.cause), ('Fix', a.fix), ('Proof', a.proof), ('Rules', a.rules)]))
        # link the lesson from each rule it names (Lessons: line), so check.py finds it from both sides
        rp = os.path.join(K, 'rules.md'); txt = open(rp, encoding='utf-8').read()
        for rr in re.findall(r'\bR-\d+\b', a.rules):
            txt = re.sub(r'(### %s .*?\nLessons: )(.*?)\n' % re.escape(rr), lambda m: m.group(1) + ('%s, %s' % (m.group(2), rid) if m.group(2).strip() not in ('none', '') else rid) + '\n', txt, count=1, flags=re.S)
        open(rp, 'w', encoding='utf-8').write(txt)
    elif a.kind == 'gate':
        p = os.path.join(K, 'gates.md'); rid = next_id(p, 'G')
        append_end(p, record(rid, a.title, [('Checks', a.checks), ('Command', a.command), ('Reads', a.reads), ('Target', a.target), ('Rules', a.rules)]))
    else:
        p = os.path.join(K, 'journal.md'); rid = 'journal'
        who = ' (%s)' % a.session if a.session else ''
        append_end(p, '- %s%s: %s' % (a.date, who, a.line.strip()))
    print(rid)
    sys.exit(subprocess.call([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'check.py')]))

if __name__ == '__main__': main()
