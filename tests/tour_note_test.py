#!/usr/bin/env python3
"""Tests for tools/tour_note.sh in dry-run mode (DRY=1, run with python3 -I)."""
import json
import os
import subprocess
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, 'tools', 'tour_note.sh')
FAULTS_PATH = os.path.join(ROOT, 'docs', 'ledger', 'faults.json')
LEDGER_PATH = os.path.join(ROOT, 'docs', 'LEDGER.md')


def read_bytes(path):
    with open(path, 'rb') as f:
        return f.read()


def run_dry(*args):
    env = os.environ.copy()
    env['DRY'] = '1'
    return subprocess.run(
        [SCRIPT, *args],
        env=env,
        capture_output=True,
        text=True,
    )


class TestTourNoteDryRun(unittest.TestCase):
    def setUp(self):
        self.faults_before = read_bytes(FAULTS_PATH)
        self.ledger_before = read_bytes(LEDGER_PATH)
        faults = json.loads(self.faults_before.decode('utf-8'))
        self.expected_next_id = 'F%03d' % (max([int(f['id'][1:]) for f in faults] or [0]) + 1)
        self.open_fault = next(f for f in faults if f.get('status') == 'open' and f.get('cell') and ',' in f['cell'])

    def tearDown(self):
        # Guarantee dry-run tests never mutate tracked files
        self.assertEqual(read_bytes(FAULTS_PATH), self.faults_before, 'faults.json was modified during DRY=1 test')
        self.assertEqual(read_bytes(LEDGER_PATH), self.ledger_before, 'LEDGER.md was modified during DRY=1 test')

    def test_valid_dry_run_defaults(self):
        res = run_dry('EM_OLDALE_TOWN  10,10  h0  cam4/0', 'seams', 'dry run default check')
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(
            res.stdout.strip(),
            '%s EM_OLDALE_TOWN 10,10 tier 1 seams - dry run default check' % self.expected_next_id,
        )

    def test_valid_dry_run_custom_tier_area_and_negative_coords(self):
        res = run_dry('  EM_SLATEPORT_CITY -3,14 h16 cam7/90', 'props', 'harbour edge check', '2', 'Props')
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(
            res.stdout.strip(),
            '%s EM_SLATEPORT_CITY -3,14 tier 2 props - harbour edge check' % self.expected_next_id,
        )

    def test_missing_args_prints_usage_and_exits_2(self):
        res = run_dry('EM_OLDALE_TOWN 10,10')
        self.assertEqual(res.returncode, 2)
        self.assertIn('tools/tour_note.sh "<tour label>"', res.stdout)

    def test_malformed_label_rejected(self):
        res = run_dry('OLDALE_TOWN 10,10', 'seams', 'missing EM_ prefix')
        self.assertNotEqual(res.returncode, 0)
        self.assertIn('label must start with MAP_ID x,y', res.stderr)

    def test_unknown_map_rejected(self):
        res = run_dry('EM_NO_SUCH_MAP_99 10,10 h0 cam4/0', 'seams', 'bad map')
        self.assertNotEqual(res.returncode, 0)
        self.assertIn('unknown map EM_NO_SUCH_MAP_99', res.stderr)

    def test_duplicate_open_fault_rejected_and_different_class_allowed(self):
        f = self.open_fault
        label = '%s  %s  h0  cam4/0' % (f['map'], f['cell'])
        # Same map, cell, and class as an open fault -> rejected
        dup = run_dry(label, f['class'], 'duplicate fault')
        self.assertNotEqual(dup.returncode, 0)
        self.assertIn('already logged as ' + f['id'], dup.stderr)

        # Same map and cell, but a different class -> allowed
        diff_cls = run_dry(label, f['class'] + '-other', 'different class at same cell')
        self.assertEqual(diff_cls.returncode, 0, diff_cls.stderr)
        self.assertIn(self.expected_next_id, diff_cls.stdout)


if __name__ == '__main__':
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(TestTourNoteDryRun)
    res = unittest.TextTestRunner(verbosity=0).run(suite)
    if not res.wasSuccessful():
        print('FAIL tour_note_test: %d failed, %d errors' % (len(res.failures), len(res.errors)))
        sys.exit(1)
    print('PASS tour_note_test: %d/%d checks passed' % (res.testsRun, res.testsRun))
