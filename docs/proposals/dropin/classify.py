import os,subprocess,sys,collections
SRC=os.path.expanduser('~/Documents/battle-art-notquiteog')
MOD=os.path.expanduser('~/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK')
base={}
out=subprocess.run(['git','-C',SRC,'ls-tree','-r','03882a9'],capture_output=True,text=True).stdout
for l in out.splitlines():
    meta,path=l.split('\t',1); base[path]=meta.split()[2]
files=[]
for root,ds,fs in os.walk(MOD,followlinks=True):
    for f in fs:
        p=os.path.join(root,f); files.append(os.path.relpath(p,MOD))
hashes=subprocess.run(['git','hash-object','--stdin-paths'],input='\n'.join(os.path.join(MOD,f) for f in files),capture_output=True,text=True,cwd=SRC).stdout.split()
cls=collections.defaultdict(list)
for f,h in zip(files,hashes):
    if f not in base: cls['new'].append(f)
    elif base[f]==h: cls['same'].append(f)
    else: cls['modified'].append(f)
def top(f):
    parts=f.split('/'); return '/'.join(parts[:2]) if len(parts)>2 else parts[0]
for k in ('same','modified','new'):
    c=collections.Counter(top(f) for f in cls[k])
    print(f'== {k}: {len(cls[k])}'); 
    for t,n in c.most_common(30): print(f'  {n:6d} {t}')
open('/tmp/dropin/classes.tsv','w').write(''.join(f'{k}\t{f}\n' for k in cls for f in sorted(cls[k])))
print('base files',len(base),'installed files',len(files))
