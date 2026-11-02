#!/usr/bin/env python3
"""Genius Sonority FSYS archive (Pokemon Colosseum/XD): list / extract entries,
decoding the LZSS containers.  fsys.py list <fsys> | extract <fsys> <outdir>"""
import os, struct, sys

def lzss(data):
    n, comp = struct.unpack('>II', data[4:12])
    src, out = data[16:], bytearray()
    buf = bytearray(4096); r = 4096 - 18
    i, flags = 0, 0
    while len(out) < n and i < len(src):
        flags >>= 1
        if not (flags & 0x100):
            flags = src[i] | 0xFF00; i += 1
        if flags & 1:
            c = src[i]; i += 1
            out.append(c); buf[r] = c; r = (r + 1) & 4095
        else:
            c1, c2 = src[i], src[i+1]; i += 2
            pos = c1 | ((c2 & 0xF0) << 4); ln = (c2 & 0x0F) + 3
            for k in range(ln):
                c = buf[(pos + k) & 4095]
                out.append(c); buf[r] = c; r = (r + 1) & 4095
    assert len(out) == n, (len(out), n)
    return bytes(out)

def entries(d):
    assert d[:4] == b'FSYS'
    count = struct.unpack('>I', d[0x0C:0x10])[0]
    ptr_tab = struct.unpack('>I', d[0x40:0x44])[0]
    out = []
    for k in range(count):
        e = struct.unpack('>I', d[ptr_tab + 4*k: ptr_tab + 4*k + 4])[0]
        ident, off, size, flags = struct.unpack('>IIII', d[e:e+16])
        csize = struct.unpack('>I', d[e+0x14:e+0x18])[0]
        ftype = struct.unpack('>I', d[e+0x20:e+0x24])[0]
        name_off = struct.unpack('>I', d[e+0x24:e+0x28])[0]
        name = d[name_off:d.index(b'\0', name_off)].decode('latin1') if name_off else f'file{k}'
        out.append(dict(ident=ident, off=off, size=size, flags=flags, csize=csize, ftype=ftype, name=name))
    return out

def payload(d, e):
    blob = d[e['off']: e['off'] + (e['csize'] if e['flags'] & 0x80000000 else e['size'])]
    return lzss(blob) if blob[:4] == b'LZSS' else blob

if __name__ == '__main__':
    cmd, path = sys.argv[1], sys.argv[2]
    d = open(path, 'rb').read()
    for e in entries(d):
        if cmd == 'list':
            print(f"{e['name']:24s} type={e['ftype']:#04x} id={e['ident']:#010x} size={e['size']:#x} comp={e['csize']:#x} flags={e['flags']:#x}")
        else:
            os.makedirs(sys.argv[3], exist_ok=True)
            with open(os.path.join(sys.argv[3], f"{e['name']}.{e['ftype']:02x}"), 'wb') as o: o.write(payload(d, e))
