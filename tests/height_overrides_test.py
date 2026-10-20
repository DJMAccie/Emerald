#!/usr/bin/env python3
"""Tests for tools/elevation/height_overrides.py (run with python3 -I)."""
import contextlib
import io
import json
import os
import shutil
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'elevation'))
import height_overrides as ho

SAMPLE_LUA = """\
-- GENERATED header comment
return {rise=12,
 EM_MAP_A={pins={{1,2,0}},
  stairs={{3,4}}},
 -- comment inside EM_MAP_A
 EM_MAP_B={on=true,rise=16,pins={{5,6,1}},
  stairs={}},
}
"""


def write_text(path, text):
    with open(path, 'w') as f:
        f.write(text)


def write_json(path, obj):
    with open(path, 'w') as f:
        json.dump(obj, f)


class TestHeightOverrides(unittest.TestCase):
    def test_parse_extracts_rows_and_inline_comments(self):
        rows = ho.parse(SAMPLE_LUA)
        self.assertEqual(list(rows.keys()), ['EM_MAP_A', 'EM_MAP_B'])
        self.assertEqual(rows['EM_MAP_A'], [
            ' EM_MAP_A={pins={{1,2,0}},',
            '  stairs={{3,4}}},',
            ' -- comment inside EM_MAP_A',
        ])
        self.assertEqual(rows['EM_MAP_B'], [
            ' EM_MAP_B={on=true,rise=16,pins={{5,6,1}},',
            '  stairs={}},',
        ])

    def test_apply_replaces_in_order_drops_and_appends(self):
        gen_rows = {
            'EM_FIRST': [' EM_FIRST={pins={},', '  stairs={}},'],
            'EM_DROP_ME': [' EM_DROP_ME={pins={},', '  stairs={}},'],
            'EM_KEEP': [' EM_KEEP={pins={{1,1,1}},', '  stairs={}},'],
        }
        overrides = {
            'EM_FIRST': {
                'row': [' EM_FIRST={pins={{9,9,2}},', '  stairs={{1,2}}},'],
                'why': 'custom pin for first map',
            },
            'EM_DROP_ME': {
                'drop': True,
                'why': 'not in installed',
            },
            'EM_ADDED': {
                'row': [' EM_ADDED={on=true,pins={{2,3,1}},stairs={}},'],
                'why': 'hand-added map',
            },
        }
        with tempfile.TemporaryDirectory() as tmp:
            ov_path = os.path.join(tmp, 'height_overrides.json')
            write_json(ov_path, overrides)
            orig_path = ho.PATH
            try:
                ho.PATH = ov_path
                out = ho.apply(gen_rows)
            finally:
                ho.PATH = orig_path

        # Order preserved: EM_FIRST (replaced), EM_DROP_ME (dropped), EM_KEEP (unchanged), EM_ADDED (appended)
        self.assertEqual(list(out.keys()), ['EM_FIRST', 'EM_KEEP', 'EM_ADDED'])
        self.assertEqual(out['EM_FIRST'], overrides['EM_FIRST']['row'])
        self.assertEqual(out['EM_KEEP'], gen_rows['EM_KEEP'])
        self.assertEqual(out['EM_ADDED'], overrides['EM_ADDED']['row'])

    def test_snapshot_records_diff_and_preserves_custom_why(self):
        gen_lua = (
            'return {rise=12,\n'
            ' EM_SAME={pins={{1,1,0}},stairs={}},\n'
            ' EM_CHANGED={pins={{2,2,1}},stairs={}},\n'
            ' EM_ONLY_GEN={pins={{3,3,1}},stairs={}},\n'
            '}\n'
        )
        inst_lua = (
            'return {rise=12,\n'
            ' EM_SAME={pins={{1,1,0}},stairs={}},\n'
            ' EM_CHANGED={pins={{2,2,9}},stairs={{4,5}}},\n'
            ' EM_ONLY_INST={pins={{7,7,2}},stairs={}},\n'
            '}\n'
        )
        with tempfile.TemporaryDirectory() as tmp:
            gen_p = os.path.join(tmp, 'gen.lua')
            inst_p = os.path.join(tmp, 'inst.lua')
            ov_p = os.path.join(tmp, 'overrides.json')
            write_text(gen_p, gen_lua)
            write_text(inst_p, inst_lua)
            write_json(ov_p, {'EM_CHANGED': {'row': [], 'why': 'hand-tuned reason kept'}})

            orig_path, orig_inst = ho.PATH, ho.INSTALLED
            try:
                ho.PATH = ov_p
                ho.INSTALLED = inst_p
                buf = io.StringIO()
                with contextlib.redirect_stdout(buf):
                    ho.snapshot(gen_p)
                with open(ov_p) as f:
                    saved = json.load(f)
            finally:
                ho.PATH, ho.INSTALLED = orig_path, orig_inst

        self.assertNotIn('EM_SAME', saved)
        self.assertEqual(saved['EM_CHANGED']['row'], [' EM_CHANGED={pins={{2,2,9}},stairs={{4,5}}},'])
        self.assertEqual(saved['EM_CHANGED']['why'], 'hand-tuned reason kept')
        self.assertEqual(saved['EM_ONLY_INST']['row'], [' EM_ONLY_INST={pins={{7,7,2}},stairs={}},'])
        self.assertTrue(saved['EM_ONLY_GEN'].get('drop'))

    @unittest.skipUnless(shutil.which('luajit'), 'luajit required for semantic check')
    def test_check_semantic_comparison_via_luajit(self):
        lua_a = (
            'return {rise=12,\n'
            ' EM_A={pins={{1,2,16/12}},stairs={{3,4}}},\n'
            ' EM_B={on=true,pins={},stairs={}},\n'
            '}\n'
        )
        # Reordered keys and equivalent arithmetic 4/3 == 16/12 -> IDENTICAL
        lua_b_same = (
            'return {\n'
            ' EM_B={stairs={},pins={},on=true},\n'
            ' EM_A={stairs={{3,4}},pins={{1,2,4/3}}},\n'
            ' rise=12,\n'
            '}\n'
        )
        lua_b_diff = (
            'return {rise=12,\n'
            ' EM_A={pins={{1,2,99}},stairs={{3,4}}},\n'
            ' EM_B={on=true,pins={},stairs={}},\n'
            '}\n'
        )
        with tempfile.TemporaryDirectory() as tmp:
            pa = os.path.join(tmp, 'a.lua')
            pb_same = os.path.join(tmp, 'b_same.lua')
            pb_diff = os.path.join(tmp, 'b_diff.lua')
            write_text(pa, lua_a)
            write_text(pb_same, lua_b_same)
            write_text(pb_diff, lua_b_diff)

            orig_inst = ho.INSTALLED
            try:
                ho.INSTALLED = pa
                buf1 = io.StringIO()
                with contextlib.redirect_stdout(buf1):
                    rc1 = ho.check(pb_same)
                self.assertEqual(rc1, 0)
                self.assertEqual(buf1.getvalue().strip(), 'IDENTICAL')

                buf2 = io.StringIO()
                with contextlib.redirect_stdout(buf2):
                    rc2 = ho.check(pb_diff)
                self.assertEqual(rc2, 1)
                self.assertIn('DIFFERENT at EM_A', buf2.getvalue().strip())
            finally:
                ho.INSTALLED = orig_inst

    def test_live_overrides_json_entries_valid_and_installed_matches(self):
        with open(ho.PATH) as f:
            ov = json.load(f)
        self.assertGreaterEqual(len(ov), 12)
        for mp, entry in ov.items():
            self.assertTrue(mp.startswith('EM_'), mp)
            self.assertTrue(entry.get('why'), '%s missing why' % mp)
            self.assertTrue('row' in entry or entry.get('drop') is True, mp)
            if 'row' in entry:
                self.assertTrue(entry['row'][0].startswith(' %s={' % mp), entry['row'][0])

        # Verify all override rows parse as valid Lua and match INSTALLED if present
        if shutil.which('luajit') and os.path.exists(ho.INSTALLED):
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                rc = ho.check(ho.INSTALLED)
            self.assertEqual(rc, 0)
            self.assertEqual(buf.getvalue().strip(), 'IDENTICAL')


if __name__ == '__main__':
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(TestHeightOverrides)
    res = unittest.TextTestRunner(verbosity=0).run(suite)
    if not res.wasSuccessful():
        print('FAIL height_overrides_test: %d failed, %d errors' % (len(res.failures), len(res.errors)))
        sys.exit(1)
    print('PASS height_overrides_test: %d/%d checks passed' % (res.testsRun, res.testsRun))
