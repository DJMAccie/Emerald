import sys,glob,collections
d=sys.argv[1]
per=collections.defaultdict(lambda:collections.Counter())
for f in sorted(glob.glob(d+'/dump_*.txt')):
    for l in open(f):
        p=l.split()
        if len(p)<7 or p[0]=='SKIP':
            if p and p[0]=='SKIP': print(l.strip())
            continue
        m,x,y,mid,b,rel,sea=p
        c=per[m]; c['cells']+=1
        c['relief' if rel=='1' else 'norelief']+=1
        if sea=='1': c['sea']+=1
        if rel=='0' and sea=='0': c['rockOrDomeNotSea']+=1
print("%-34s %6s %7s %9s %5s %s"%('map','cells','relief','norelief','sea','not-relief-not-sea'))
tot=collections.Counter()
for m,c in sorted(per.items(), key=lambda kv:-kv[1]['norelief']-kv[1]['relief']):
    print("%-34s %6d %7d %9d %5d %d"%(m,c['cells'],c['relief'],c['norelief'],c['sea'],c['rockOrDomeNotSea']))
    tot.update(c)
print('TOTAL',dict(tot))
