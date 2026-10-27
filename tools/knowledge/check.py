#!/usr/bin/env python3
"""check.py: lint docs/knowledge (G-09).
Errors: duplicate / non-sequential ids, a rule whose Gate: names a gate that does not exist (or is not 'none yet'),
a lesson or gate whose Rules: names a rule that does not exist, a record missing a required field, an undated journal line.
Warnings: PLAN.md Tasks that still say "waits for the user" (R-24). Exit 1 on errors."""
import re, sys, os
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
K = os.path.join(R, 'docs', 'knowledge')
FIELDS = {'R': ['Rule', 'Source', 'Gate', 'Applied', 'Lessons', 'Status'],
          'L': ['Symptom', 'Wrong model', 'Cause', 'Fix', 'Proof', 'Rules'],
          'G': ['Checks', 'Command', 'Reads', 'Target', 'Rules']}
FILES = {'R': 'rules.md', 'L': 'lessons.md', 'G': 'gates.md'}

def records(prefix):
    """-> list of (id, title, {field: text}) in file order"""
    out = []; cur = None
    for line in open(os.path.join(K, FILES[prefix]), encoding='utf-8'):
        m = re.match(r'### (%s-\d+) (.*)' % prefix, line)
        if m:
            cur = (m.group(1), m.group(2).strip(), {}); out.append(cur); continue
        if cur:
            m = re.match(r'([A-Z][a-z ]+): ?(.*)', line)
            if m and m.group(1) in FIELDS[prefix]: cur[2][m.group(1)] = m.group(2).strip()
    return out

def ids_in(text, prefix):
    return re.findall(r'\b%s-\d+\b' % prefix, text)

def main():
    errors, warns = [], []
    recs = {p: records(p) for p in FILES}
    known = {p: {r[0] for r in recs[p]} for p in recs}
    for p, rs in recs.items():
        seen = set()
        for i, (rid, title, f) in enumerate(rs, 1):
            if rid in seen: errors.append('%s duplicated' % rid)
            seen.add(rid)
            if int(rid.split('-')[1]) != i: errors.append('%s out of order (expected %s-%02d)' % (rid, p, i))
            for fld in FIELDS[p]:
                if fld not in f: errors.append('%s missing field %s:' % (rid, fld))
        for rid, title, f in rs:
            if p == 'R':
                g = f.get('Gate', '')
                if g.strip() != 'none yet':
                    gs = ids_in(g, 'G')
                    if not gs: errors.append('%s Gate: names no gate (use "none yet")' % rid)
                    for x in gs:
                        if x not in known['G']: errors.append('%s names unknown gate %s' % (rid, x))
                for x in ids_in(f.get('Lessons', ''), 'L'):
                    if x not in known['L']: errors.append('%s names unknown lesson %s' % (rid, x))
                for x in ids_in(f.get('Status', ''), 'R'):
                    if x not in known['R']: errors.append('%s Status names unknown rule %s' % (rid, x))
            else:
                rs_ = ids_in(f.get('Rules', ''), 'R')
                if not rs_: errors.append('%s names no rule' % rid)
                for x in rs_:
                    if x not in known['R']: errors.append('%s names unknown rule %s' % (rid, x))
    # lessons linked back: every lesson should be named by at least one rule's Lessons: (warning only)
    linked = set()
    for rid, title, f in recs['R']: linked.update(ids_in(f.get('Lessons', ''), 'L'))
    for lid, title, f in recs['L']:
        if lid not in linked: warns.append('%s is not named by any rule\'s Lessons: line' % lid)
    for n, line in enumerate(open(os.path.join(K, 'journal.md'), encoding='utf-8'), 1):
        if line.startswith('- ') and not re.match(r'- \d{4}-\d{2}-\d{2} ', line):
            errors.append('journal.md:%d line not dated (- YYYY-MM-DD ...)' % n)
    plan = os.path.join(R, '.claude', 'handoffs', 'PLAN.md')
    if os.path.exists(plan):
        intasks = False
        for n, line in enumerate(open(plan, encoding='utf-8'), 1):
            if line.startswith('## '): intasks = line.startswith('## Tasks')
            if intasks and re.search(r'waits? for (the )?(a )?user', line, re.I) and '[done' not in line:
                warns.append('PLAN.md:%d task still waits for the user (R-24): %s' % (n, line[:70].strip()))
    for w in warns: print('WARN', w)
    for e in errors: print('ERROR', e)
    print('check.py: %d rules, %d lessons, %d gates, %d errors, %d warnings' % (len(recs['R']), len(recs['L']), len(recs['G']), len(errors), len(warns)))
    sys.exit(1 if errors else 0)

if __name__ == '__main__': main()
