#!/usr/bin/env python3
"""Run the Blender addon's Blender-free phases (extract, route, parse, describe)
on a PKX/DAT/FSYS file and summarise the resulting IR scene. Audited: pure
parsing, no network/subprocess; StubLogger avoids temp-file logs."""
import os, sys
from unittest import mock
# The addon package __init__ imports its Blender phases; stub bpy/mathutils so
# the Blender-free phases import headlessly.
for _m in ('bpy', 'mathutils', 'bpy.types', 'bpy.props'):
    sys.modules.setdefault(_m, mock.MagicMock())
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'addon'))
from importer.phases.extract.extract import extract_dat
from importer.phases.route.route import route_sections
from importer.phases.parse.parse import parse_sections
from importer.phases.describe.describe import describe_scene
from shared.helpers.logger import StubLogger

def load(path, filename=None):
    raw = open(path, 'rb').read()
    filename = filename or os.path.basename(path)
    logger = StubLogger()
    options = {"ik_hack": True, "verbose": False, "max_frame": 1000000000,
               "section_names": [], "filepath": path}
    out = []
    for dat_bytes, meta in extract_dat(raw, filename, options=options):
        if not dat_bytes: continue
        section_map = route_sections(dat_bytes, game=None, logger=logger)
        sections = parse_sections(dat_bytes, section_map, options, logger=logger)
        options["pkx_header"] = meta.pkx_header
        out.append((meta, describe_scene(sections, options, logger=logger)))
    return out

if __name__ == '__main__':
    for meta, scene in load(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None):
        print('entry', meta.filename, 'shiny', meta.shiny_params is not None, 'pkxHeader', meta.pkx_header is not None)
        for m in scene.models:
            print('model', m.name, 'bones', len(m.bones), 'meshes', len(m.meshes),
                  'boneAnims', len(m.bone_animations), 'fields', [k for k,v in vars(m).items() if isinstance(v,list) and v and k not in ('bones','meshes','bone_animations')])
            for b in m.bones[:6]: print('  bone', b.name, b.parent_index, [round(x,3) for x in b.position])
            for me in m.meshes[:8]:
                print('  mesh', me.name, 'verts', len(me.vertices), 'faces', len(me.faces), 'uv', len(me.uv_layers),
                      'skin', me.bone_weights and me.bone_weights.type, 'tex', me.material and [(t.image.name,t.image.width,t.image.height) for t in me.material.texture_layers])
            for a in m.bone_animations[:40]:
                fr = max((k.frame for t in a.tracks for ch in (t.rotation+t.location+t.scale) for k in ch), default=0)
                print('  anim', getattr(a,'name',None), 'tracks', len(a.tracks), 'lastFrame', fr)
