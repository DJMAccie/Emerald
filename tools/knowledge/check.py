#!/usr/bin/env python3
"""check.py: lint docs/knowledge. Errors: a duplicate id, a record missing a required field, a Rules: line naming an unknown
rule, an undated journal line. Gaps in ids are fine (retired records). Exit 1 on errors."""
import os, re, sys
K = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'docs', 'knowledge')
FIELDS = {'R': ('rules.md', ['Rule', 'Source']), 'L': ('lessons.md', ['Cause', 'Fix'])}

def records(prefix):
    out, cur = [], None
    for line in open(os.path.join(K, FIELDS[prefix][0]), encoding='utf-8'):
        m = re.match(r'### (%s-\d+) ' % prefix, line)
        if m:
            cur = (m.group(1), {}); out.append(cur); continue
        m = re.match(r'([A-Z][a-z]+): ?(.*)', line)
        if cur and m: cur[1][m.group(1)] = m.group(2).strip()
    return out

def main():
    errors, recs = [], {p: records(p) for p in FIELDS}
    for p, rs in recs.items():
        seen = set()
        for rid, f in rs:
            if rid in seen: errors.append('%s duplicated' % rid)
            seen.add(rid)
            errors += ['%s missing %s:' % (rid, fld) for fld in FIELDS[p][1] if not f.get(fld)]
    rules = {rid for rid, _ in recs['R']}
    for lid, f in recs['L']:
        errors += ['%s names unknown rule %s' % (lid, x) for x in re.findall(r'\bR-\d+\b', f.get('Rules', '')) if x not in rules]
    for n, line in enumerate(open(os.path.join(K, 'journal.md'), encoding='utf-8'), 1):
        if line.startswith('- ') and not re.match(r'- \d{4}-\d{2}-\d{2}\b', line):
            errors.append('journal.md:%d not dated (- YYYY-MM-DD: ...)' % n)
    for e in errors: print('ERROR', e)
    print('check.py: %d rules, %d lessons, %d errors' % (len(recs['R']), len(recs['L']), len(errors)))
    sys.exit(1 if errors else 0)

if __name__ == '__main__': main()
