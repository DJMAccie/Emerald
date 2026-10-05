#!/usr/bin/env python3
"""GameCube disc filesystem: list or extract files from a plain .iso/.gcm.
  gciso.py list <iso>
  gciso.py extract <iso> <outdir> [name-substring ...]
"""
import os, struct, sys

def read_fst(f):
    f.seek(0x424); fst_off, fst_sz = struct.unpack('>II', f.read(8))
    f.seek(fst_off); fst = f.read(fst_sz)
    n = struct.unpack('>I', fst[8:12])[0]
    names = fst[n*12:]
    def name(i):
        e = struct.unpack('>I', fst[i*12:i*12+4])[0] & 0xFFFFFF
        return names[e:names.index(b'\0', e)].decode('latin1')
    entries, path = [], []
    stack = []  # (end_index, dirname)
    for i in range(1, n):
        flags = fst[i*12]
        a, b = struct.unpack('>II', fst[i*12+4:i*12+12])
        while stack and i >= stack[-1][0]:
            stack.pop(); path.pop()
        if flags == 1:
            stack.append((b, name(i))); path.append(name(i))
        else:
            entries.append(('/'.join(path + [name(i)]), a, b))
    return entries

def main():
    cmd, iso = sys.argv[1], sys.argv[2]
    with open(iso, 'rb') as f:
        entries = read_fst(f)
        if cmd == 'list':
            for p, off, sz in entries: print(f'{sz:10d} {off:#010x} {p}')
            print(len(entries), 'files', file=sys.stderr)
        elif cmd == 'extract':
            out, subs = sys.argv[3], sys.argv[4:]
            for p, off, sz in entries:
                if subs and not any(s in p for s in subs): continue
                dst = os.path.join(out, p); os.makedirs(os.path.dirname(dst), exist_ok=True)
                f.seek(off)
                with open(dst, 'wb') as o:
                    left = sz
                    while left:
                        chunk = f.read(min(left, 1 << 24)); o.write(chunk); left -= len(chunk)
            print('done', file=sys.stderr)
main()
