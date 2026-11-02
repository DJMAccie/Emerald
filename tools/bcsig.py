# usage: bcsig.py file.lua -> prints normalized bytecode listing (no line numbers, no chunk names)
import re,subprocess,sys
out=subprocess.run(['luajit','-bl',sys.argv[1]],capture_output=True,text=True)
if out.returncode: print('COMPILE ERROR',out.stderr); sys.exit(0)
for l in out.stdout.splitlines():
    if l.startswith('-- BYTECODE --'): print('-- BYTECODE --'); continue
    l=re.sub(r'^(\d{4}) ( |=>)\s*','\\1 ',l)   # drop nothing important, normalise spacing
    l=re.sub(r';\s*\S+\.lua:\d+\s*$','; FN',l)
    print(l)
