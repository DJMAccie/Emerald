"""Read Pokemon Colosseum's disc: .iso/.gcm or Dolphin .ciso, the FST file table,
FSYS archives (LZSS) and the PKX models inside them (through the add-on's
Blender-free phases in addon/)."""
import os, struct, sys
from unittest import mock

GAME_IDS = ('GC6E', 'GC6P', 'GC6J')   # Colosseum USA / Europe / Japan


class Disc:
    def __init__(self, path):
        self.f = open(path, 'rb')
        head = self.f.read(0x8000)
        self.blocks = None
        if head[:4] == b'CISO':
            size = struct.unpack('<I', head[4:8])[0]
            index, n = [], 0
            for present in head[8:]:
                index.append(n if present else None)
                n += 1 if present else 0
            self.blocks = (size, index)
        self.id = self.read(0, 4).decode('latin1')

    def read(self, off, n):
        if not self.blocks:
            self.f.seek(off)
            return self.f.read(n)
        size, index = self.blocks
        out = bytearray()
        while n > 0:
            b, inner = divmod(off, size)
            take = min(n, size - inner)
            slot = index[b] if b < len(index) else None
            if slot is None:
                out += bytes(take)
            else:
                self.f.seek(0x8000 + slot * size + inner)
                out += self.f.read(take)
            off += take; n -= take
        return bytes(out)

    def files(self):
        """basename -> (offset, size) for every file on the disc."""
        fst_off, fst_size = struct.unpack('>II', self.read(0x424, 8))
        fst = self.read(fst_off, fst_size)
        count = struct.unpack('>I', fst[8:12])[0]
        names = fst[count * 12:]
        out = {}
        for i in range(1, count):
            if fst[i * 12] == 1: continue   # directory
            name_off = struct.unpack('>I', fst[i * 12:i * 12 + 4])[0] & 0xFFFFFF
            off, size = struct.unpack('>II', fst[i * 12 + 4:i * 12 + 12])
            out[names[name_off:names.index(b'\0', name_off)].decode('latin1')] = (off, size)
        return out


def lzss(data):
    n = struct.unpack('>I', data[4:8])[0]
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
            c1, c2 = src[i], src[i + 1]; i += 2
            pos = c1 | ((c2 & 0xF0) << 4)
            for k in range((c2 & 0x0F) + 3):
                c = buf[(pos + k) & 4095]
                out.append(c); buf[r] = c; r = (r + 1) & 4095
    assert len(out) == n, (len(out), n)
    return bytes(out)


def fsys_first(d):
    """The first entry of an FSYS archive, decompressed (a pkx_*.fsys holds one model)."""
    assert d[:4] == b'FSYS'
    ptr_tab = struct.unpack('>I', d[0x40:0x44])[0]
    e = struct.unpack('>I', d[ptr_tab:ptr_tab + 4])[0]
    _, off, size, flags = struct.unpack('>IIII', d[e:e + 16])
    csize = struct.unpack('>I', d[e + 0x14:e + 0x18])[0]
    blob = d[off:off + (csize if flags & 0x80000000 else size)]
    return lzss(blob) if blob[:4] == b'LZSS' else blob


# The add-on's package __init__ files import Blender; stub it so the
# Blender-free phases import headlessly.
for _m in ('bpy', 'mathutils', 'bpy.types', 'bpy.props'):
    sys.modules.setdefault(_m, mock.MagicMock())
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'addon'))
from importer.phases.extract.extract import extract_dat
from importer.phases.route.route import route_sections
from importer.phases.parse.parse import parse_sections
from importer.phases.describe.describe import describe_scene
from shared.helpers.logger import StubLogger


def load_pkx(raw, name):
    """PKX bytes -> [(container metadata, IR scene)]."""
    logger = StubLogger()
    options = {"ik_hack": True, "verbose": False, "max_frame": 1000000000,
               "section_names": [], "filepath": name + '.pkx'}
    out = []
    for dat_bytes, meta in extract_dat(raw, name + '.pkx', options=options):
        if not dat_bytes: continue
        sections = parse_sections(dat_bytes, route_sections(dat_bytes, game=None, logger=logger), options, logger=logger)
        options["pkx_header"] = meta.pkx_header
        out.append((meta, describe_scene(sections, options, logger=logger)))
    return out
