#!/usr/bin/env python3
"""Tests for tools/ledger.py (run with python3 -I)."""
import contextlib
import copy
import io
import json
import os
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import ledger


def write_json(path, obj):
    with open(path, 'w') as f:
        json.dump(obj, f)


def read_json(path):
    with open(path) as f:
        return json.load(f)


def sample_fixture():
    maps = [
        {'id': 'EM_TEST_TOWN', 'kind': 'town_city', 'w': 20, 'h': 20},
        {'id': 'EM_TEST_ROUTE', 'kind': 'route', 'w': 40, 'h': 20},
        {'id': 'EM_TEST_CAVE', 'kind': 'cave', 'w': 16, 'h': 16},
        {'id': 'EM_TEST_ROOM', 'kind': 'interior', 'w': 10, 'h': 10},
        {'id': 'EM_TEST_BASE', 'kind': 'secret_base', 'w': 8, 'h': 8},
    ]
    status = {
        'seed_note': 'unit-test seed',
        'defaults': {
            'town_city': {'Terrain': 'modelled', 'Buildings': 'modelled', 'Props': 'modelled'},
            'route': {'Terrain': 'modelled', 'Buildings': 'modelled', 'Props': 'modelled'},
            'water_route': {'Terrain': 'modelled', 'Buildings': 'none', 'Props': 'modelled'},
            'cave': {'Shell': 'modelled', 'Furniture': 'modelled'},
            'interior': {'Shell': 'modelled', 'Furniture': 'modelled'},
            'secret_base': {'Shell': 'none', 'Furniture': 'none'},
            'underwater': {'Shell': 'none', 'Furniture': 'none'},
        },
        'maps': {
            'EM_TEST_ROUTE': {'Buildings': 'wip'},
        },
        'signed_off': {},
    }
    faults = [
        {
            'id': 'F001',
            'map': 'EM_TEST_TOWN',
            'area': 'Terrain',
            'tier': 1,
            'class': 'ledges',
            'cell': '10,12',
            'text': 'Ledge does not drop',
            'status': 'open',
        },
        {
            'id': 'F002',
            'map': 'EM_TEST_ROUTE',
            'area': 'Buildings',
            'tier': 2,
            'class': 'seams',
            'cell': '5,5',
            'text': 'Resolved seam',
            'status': 'fixed',
        },
    ]
    audits = {
        'items': [
            {
                'name': 'Stairs: flat / reversed / cliff jumps (2 outdoor maps)',
                'value': '0 / 0 / 0',
                'target': '0 / 0 / 0',
                'asof': '2026-10-20',
                'source': 'unit test',
            },
            {
                'name': 'Slowest map to 3D',
                'value': '0.50 s',
                'target': 'under 1 s',
                'asof': '2026-10-20',
                'source': 'unit test',
            },
        ]
    }
    return maps, status, faults, audits


class TestLedger(unittest.TestCase):
    def test_pct_weights(self):
        self.assertEqual(ledger.pct([]), 0.0)
        self.assertAlmostEqual(ledger.pct(['none']), 0.0)
        self.assertAlmostEqual(ledger.pct(['wip']), 50.0)
        self.assertAlmostEqual(ledger.pct(['modelled']), 60.0)
        self.assertAlmostEqual(ledger.pct(['faults']), 75.0)
        self.assertAlmostEqual(ledger.pct(['done']), 100.0)
        self.assertAlmostEqual(ledger.pct(['none', 'wip', 'modelled', 'faults', 'done']), 57.0)

    def test_effective_fault_promotion_and_fixed_ignored(self):
        maps, status, faults, _ = sample_fixture()
        eff, open_by, errors = ledger.effective(maps, status, faults)
        self.assertEqual(errors, [])
        # Open fault on modelled Terrain -> promoted to 'faults'
        self.assertEqual(eff['EM_TEST_TOWN']['Terrain'], 'faults')
        self.assertEqual(eff['EM_TEST_TOWN']['Buildings'], 'modelled')
        # Fixed fault on wip Buildings -> stays 'wip'
        self.assertEqual(eff['EM_TEST_ROUTE']['Buildings'], 'wip')
        self.assertEqual(list(open_by.keys()), [('EM_TEST_TOWN', 'Terrain')])
        # Indoor/cave maps use Shell + Furniture
        self.assertEqual(set(eff['EM_TEST_CAVE'].keys()), {'Shell', 'Furniture'})
        self.assertEqual(eff['EM_TEST_BASE']['Shell'], 'none')

    def test_effective_done_requires_signoff_and_no_open_faults(self):
        maps, status, faults, _ = sample_fixture()
        # 1. 'done' without signed_off -> error
        status['maps']['EM_TEST_CAVE'] = {'Shell': 'done'}
        _, _, errors = ledger.effective(maps, status, faults)
        self.assertTrue(any('not signed off by the user' in e for e in errors), errors)

        # 2. 'done' with signed_off and no open fault -> valid
        status['signed_off']['EM_TEST_CAVE'] = '2026-10-20'
        eff, _, errors = ledger.effective(maps, status, faults)
        self.assertEqual(errors, [])
        self.assertEqual(eff['EM_TEST_CAVE']['Shell'], 'done')

        # 3. 'done' with signed_off AND an open fault -> error
        faults.append({
            'id': 'F003',
            'map': 'EM_TEST_CAVE',
            'area': 'Shell',
            'tier': 2,
            'class': 'seams',
            'cell': '1,1',
            'text': 'Wall seam',
            'status': 'open',
        })
        _, _, errors = ledger.effective(maps, status, faults)
        self.assertTrue(any('is done but has open faults' in e for e in errors), errors)

    def test_effective_unknown_map_in_faults(self):
        maps, status, faults, _ = sample_fixture()
        faults.append({
            'id': 'F999',
            'map': 'EM_BOGUS_MAP',
            'area': 'Terrain',
            'tier': 1,
            'class': 'rock',
            'cell': '0,0',
            'text': 'Unknown map fault',
            'status': 'open',
        })
        _, _, errors = ledger.effective(maps, status, faults)
        self.assertIn('fault F999: unknown map EM_BOGUS_MAP', errors)

    def test_render_sections_and_indoor_filtering(self):
        maps, status, faults, audits = sample_fixture()
        text, errors = ledger.render(maps, status, faults, audits)
        self.assertEqual(errors, [])
        self.assertIn('# Emerald 3D coverage ledger', text)
        self.assertIn('12 map-areas in 5 maps; 1 open faults, 1 of them tier 1', text)
        self.assertIn('| EM_TEST_TOWN | 🟧 | 🟨 | 🟨 | 1 |', text)
        # No indoor map differs from group default or has an open fault -> (none)
        self.assertIn('| (none) | | | | |', text)

        # Add an open fault to EM_TEST_ROOM -> appears in indoor table
        faults.append({
            'id': 'F004',
            'map': 'EM_TEST_ROOM',
            'area': 'Shell',
            'tier': 2,
            'class': 'first-person',
            'cell': '',
            'text': 'Plain wall',
            'status': 'open',
        })
        text2, errors2 = ledger.render(maps, status, faults, audits)
        self.assertEqual(errors2, [])
        self.assertIn('| EM_TEST_ROOM | Interiors | 🟧 | 🟨 | 1 |', text2)

    def test_audit_from_partial_guard_and_gate_updates(self):
        _, _, _, audits = sample_fixture()
        res = {
            'run_id': '20261020-120000',
            'date': '2026-10-20',
            'scope': 'subset',
            'mod_hash': 'deadbeef1234',
            'gates': {
                'stairs': {
                    'status': 'pass',
                    'metrics': {
                        'maps': 5,
                        'flat': 0,
                        'reversed': 0,
                        'cliff_jumps': 0,
                        'ledges_checked': 20,
                        'ledges_bad': 0,
                    },
                },
                'load': {
                    'status': 'incomplete',
                    'metrics': {},
                },
            },
        }
        with tempfile.TemporaryDirectory() as tmp:
            res_path = os.path.join(tmp, 'results.json')
            aud_path = os.path.join(tmp, 'audits.json')
            write_json(res_path, res)
            write_json(aud_path, copy.deepcopy(audits))

            orig_led = ledger.LED
            try:
                ledger.LED = tmp
                out_buf, err_buf = io.StringIO(), io.StringIO()
                with contextlib.redirect_stdout(out_buf), contextlib.redirect_stderr(err_buf):
                    rc = ledger.audit_from(res_path, aud_path, force=False)
                    self.assertEqual(rc, 2)
                    rc2 = ledger.audit_from(res_path, aud_path, force=True)
                    self.assertEqual(rc2, 0)
            finally:
                ledger.LED = orig_led

            updated = read_json(aud_path)['items']
            by_prefix = {it['name'].split(':')[0]: it for it in updated}
            self.assertEqual(by_prefix['Stairs']['value'], '0 / 0 / 0')
            self.assertIn('deadbeef1234', by_prefix['Stairs']['source'])
            self.assertTrue(any(it['name'].startswith('Ledges that do not drop') for it in updated))
            slow = next(it for it in updated if it['name'] == 'Slowest map to 3D')
            self.assertEqual(slow['value'], '0.50 s')

    def test_write_and_check_roundtrip_in_tempdir(self):
        maps, status, faults, audits = sample_fixture()
        with tempfile.TemporaryDirectory() as tmp:
            write_json(os.path.join(tmp, 'maps.json'), maps)
            write_json(os.path.join(tmp, 'status.json'), status)
            write_json(os.path.join(tmp, 'faults.json'), faults)
            write_json(os.path.join(tmp, 'audits.json'), audits)
            out_md = os.path.join(tmp, 'LEDGER.md')

            orig_led, orig_out, orig_argv = ledger.LED, ledger.OUT, sys.argv
            try:
                ledger.LED = tmp
                ledger.OUT = out_md
                out_buf, err_buf = io.StringIO(), io.StringIO()
                with contextlib.redirect_stdout(out_buf), contextlib.redirect_stderr(err_buf):
                    sys.argv = ['ledger.py', '--write']
                    self.assertEqual(ledger.main(), 0)
                    self.assertTrue(os.path.exists(out_md))

                    sys.argv = ['ledger.py', '--check']
                    self.assertEqual(ledger.main(), 0)

                    with open(out_md, 'a') as f:
                        f.write('\nstale line\n')
                    self.assertEqual(ledger.main(), 1)
            finally:
                ledger.LED, ledger.OUT, sys.argv = orig_led, orig_out, orig_argv

    def test_live_repo_ledger_data_has_no_errors(self):
        maps = ledger.load('maps.json')
        status = ledger.load('status.json')
        faults = ledger.load('faults.json')
        audits = ledger.load('audits.json')
        eff, _, errors = ledger.effective(maps, status, faults)
        self.assertEqual(errors, [])
        self.assertEqual(len(maps), 515)
        self.assertEqual(sum(len(r) for r in eff.values()), 1098)
        text, render_errors = ledger.render(maps, status, faults, audits)
        self.assertEqual(render_errors, [])
        self.assertTrue(text.startswith('# Emerald 3D coverage ledger\n'))


if __name__ == '__main__':
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(TestLedger)
    res = unittest.TextTestRunner(verbosity=0).run(suite)
    if not res.wasSuccessful():
        print('FAIL ledger_test: %d failed, %d errors' % (len(res.failures), len(res.errors)))
        sys.exit(1)
    print('PASS ledger_test: %d/%d checks passed' % (res.testsRun, res.testsRun))
