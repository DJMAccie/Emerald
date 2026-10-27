#!/usr/bin/env python3
# ledger.py  verdicts.txt (+ verdicts_caves.txt) -> markdown table per map: worst status over its spots, one line of notes
import sys, collections
rank={'ok':0,'ok?':1,'suspect':2,'left':3,'wrong':3,'fixed':-1}
def load(p):
    by=collections.OrderedDict()
    for l in open(p):
        p_=l.rstrip('\n').split('|',3)
        if len(p_)<4: continue
        by.setdefault(p_[0],[]).append(p_[1:])
    return by
for path,title in (('tools/review/verdicts.txt','outdoor'),('tools/review/verdicts_caves.txt','caves')):
    try: by=load(path)
    except FileNotFoundError: continue
    print('\n### %s (%d maps)\n\n| map | status | spots | notes |\n|---|---|---|---|'%(title,len(by)))
    for m,rs in by.items():
        st=max((r[1] for r in rs),key=lambda s:rank.get(s,2))
        notes='; '.join('%s: %s'%(r[0],r[2]) for r in rs if r[1]!='ok') or rs[0][2]
        print('| %s | %s | %s | %s |'%(m,st,', '.join(r[0] for r in rs),notes[:240]))
