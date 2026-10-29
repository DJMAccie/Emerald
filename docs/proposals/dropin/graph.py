import re,os,sys,subprocess,collections
SRC=os.path.expanduser('~/Documents/battle-art-notquiteog')
MOD=os.path.expanduser('~/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK')
R=re.compile(r"""V\.(require|data)\s*\(?\s*['"]([A-Za-z0-9_/.\-]+)['"]""")
DYN=re.compile(r"""V\.(require|data)\s*\(\s*([^'"\s)][^)]*)\)""")
ASSET=re.compile(r"""['"]((?:assets|data|lib)/[^'"]*)['"]""")
cls={}
for l in open('/tmp/dropin/classes.tsv'):
    k,f=l.rstrip('\n').split('\t'); cls[f]=k
def read(rel):
    return open(os.path.join(MOD,rel),encoding='utf-8',errors='replace').read()
main=read('main.lua').split('\n')
gen3main='\n'.join(main[:85])
seen={}; q=[('main.lua[1-85]',gen3main,None)]
dyn=[];assets=collections.defaultdict(set);missing=set()
while q:
    name,text,parent=q.pop()
    for kind,mod in R.findall(text):
        rel=('lib/' if kind=='require' else 'data/')+mod+'.lua'
        if rel in seen: continue
        if not os.path.exists(os.path.join(MOD,rel)): missing.add((rel,name)); continue
        seen[rel]=name; q.append((rel,read(rel),name))
    for kind,expr in DYN.findall(text): dyn.append((name,kind,expr.strip()[:60]))
    for a in ASSET.findall(text): assets[a].add(name)
print('reachable modules:',len(seen))
c=collections.Counter(cls.get(r,'?') for r in seen); print(dict(c))
with open('/tmp/dropin/gen3_reach.tsv','w') as f:
    for r in sorted(seen): f.write(f'{cls.get(r,"?")}\t{r}\t{seen[r]}\n')
print('missing targets:',sorted(missing)[:20])
print('dynamic requires:'); [print('  ',d) for d in dyn[:40]]
with open('/tmp/dropin/gen3_assets.tsv','w') as f:
    for a in sorted(assets): f.write(a+'\t'+','.join(sorted(assets[a]))[:200]+'\n')
print('asset string refs:',len(assets))
