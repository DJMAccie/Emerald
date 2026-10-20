#!/usr/bin/env python3
"""Tests for tools/heights_compare.py (run with python3 -I)."""
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, 'tools', 'heights_compare.py')

SAMPLE_DUMP_1 = """\
EM_OLDALE_TOWN 10 10 001 ground coll=0 prop=nil col=- base=0 stairs=0 sdir=- ladder=0 ledge=0 rail=0 bridge=0 door=0 elev=3 ldrop=-
EM_OLDALE_TOWN 10 11 001 ground coll=0 prop=nil col=- base=0 stairs=0 sdir=- ladder=0 ledge=0 rail=0 bridge=0 door=0 elev=3 ldrop=-
EM_ROUTE124 40 -2 170 water coll=nil prop=nil col=- base=0 stairs=0 sdir=- ladder=0 ledge=0 rail=0 bridge=0 door=0 elev=0 ldrop=-
EM_RUSTBORO_CITY 21 32 020 ground coll=0 prop=nil col=- base=16 stairs=0 sdir=- ladder=0 ledge=0 rail=0 bridge=0 door=0 elev=3 ldrop=-
"""

# Differs from SAMPLE_DUMP_1 in:
# - EM_OLDALE_TOWN 10 11: base=0 -> base=8
# - EM_ROUTE124 40 -2: tile 170 -> 171
SAMPLE_DUMP_2 = """\
EM_OLDALE_TOWN 10 10 001 ground coll=0 prop=nil col=- base=0 stairs=0 sdir=- ladder=0 ledge=0 rail=0 bridge=0 door=0 elev=3 ldrop=-
EM_OLDALE_TOWN 10 11 001 ground coll=0 prop=nil col=- base=8 stairs=0 sdir=- ladder=0 ledge=0 rail=0 bridge=0 door=0 elev=3 ldrop=-
EM_ROUTE124 40 -2 171 water coll=nil prop=nil col=- base=0 stairs=0 sdir=- ladder=0 ledge=0 rail=0 bridge=0 door=0 elev=0 ldrop=-
EM_RUSTBORO_CITY 21 32 020 ground coll=0 prop=nil col=- base=16 stairs=0 sdir=- ladder=0 ledge=0 rail=0 bridge=0 door=0 elev=3 ldrop=-
"""


def write_text(path, text):
    with open(path, 'w') as f:
        f.write(text)


def read_text(path):
    with open(path) as f:
        return f.read()


def run_hc(*args):
    return subprocess.run(
        [sys.executable, '-I', SCRIPT, *args],
        capture_output=True,
        text=True,
    )


class TestHeightsCompare(unittest.TestCase):
    def test_flips_identical_dumps(self):
        with tempfile.TemporaryDirectory() as tmp:
            r1 = os.path.join(tmp, 'run1.txt')
            r2 = os.path.join(tmp, 'run2.txt')
            flips = os.path.join(tmp, 'flips.txt')
            write_text(r1, SAMPLE_DUMP_1)
            write_text(r2, SAMPLE_DUMP_1)

            res = run_hc('flips', r1, r2, flips)
            self.assertEqual(res.returncode, 0, res.stderr)
            self.assertIn('cells 4 unstable 0 maps affected 0 {}', res.stdout)
            self.assertEqual(read_text(flips), '')

    def test_flips_detects_unstable_cells_and_fields(self):
        with tempfile.TemporaryDirectory() as tmp:
            r1 = os.path.join(tmp, 'run1.txt')
            r2 = os.path.join(tmp, 'run2.txt')
            flips = os.path.join(tmp, 'flips.txt')
            write_text(r1, SAMPLE_DUMP_1)
            write_text(r2, SAMPLE_DUMP_2)

            res = run_hc('flips', r1, r2, flips)
            self.assertEqual(res.returncode, 0, res.stderr)
            self.assertIn('cells 4 unstable 2 maps affected 2', res.stdout)
            self.assertIn("'base': 1", res.stdout)
            self.assertIn("'tile': 1", res.stdout)
            lines = read_text(flips).splitlines()
            self.assertEqual(lines, [
                'EM_OLDALE_TOWN 10 11',
                'EM_ROUTE124 40 -2',
            ])

    def test_flips_shape_and_missing_cell(self):
        with tempfile.TemporaryDirectory() as tmp:
            r1 = os.path.join(tmp, 'run1.txt')
            r2 = os.path.join(tmp, 'run2.txt')
            flips = os.path.join(tmp, 'flips.txt')
            write_text(r1, 'EM_OLDALE_TOWN 1 2 001 ground coll=0\n')
            write_text(
                r2,
                'EM_OLDALE_TOWN 1 2 001 ground coll=0 extra=1\n'
                'EM_OLDALE_TOWN 1 3 001 ground coll=0\n',
            )

            res = run_hc('flips', r1, r2, flips)
            self.assertEqual(res.returncode, 0, res.stderr)
            self.assertIn("'shape': 1", res.stdout)
            self.assertEqual(read_text(flips).splitlines(), [
                'EM_OLDALE_TOWN 1 2',
                'EM_OLDALE_TOWN 1 3',
            ])

    def test_diff_passes_when_identical_or_masked_by_flips(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = os.path.join(tmp, 'base.txt')
            new = os.path.join(tmp, 'new.txt')
            flips = os.path.join(tmp, 'flips.txt')
            write_text(base, SAMPLE_DUMP_1)
            write_text(new, SAMPLE_DUMP_2)
            run_hc('flips', base, new, flips)

            res = run_hc('diff', base, new, flips)
            self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
            self.assertIn('differing cells outside the unstable list: 0 in 0 maps', res.stdout)

    def test_diff_fails_when_cell_outside_flips_differs(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = os.path.join(tmp, 'base.txt')
            new = os.path.join(tmp, 'new.txt')
            flips = os.path.join(tmp, 'flips.txt')
            write_text(base, SAMPLE_DUMP_1)
            write_text(new, SAMPLE_DUMP_2)
            # Only mask EM_ROUTE124 40 -2; leave EM_OLDALE_TOWN 10 11 unmasked
            write_text(flips, 'EM_ROUTE124 40 -2\n')

            res = run_hc('diff', base, new, flips)
            self.assertEqual(res.returncode, 1)
            self.assertIn('differing cells outside the unstable list: 1 in 1 maps', res.stdout)
            self.assertIn('EM_OLDALE_TOWN 1', res.stdout)
            self.assertIn("('EM_OLDALE_TOWN', 10, 11)", res.stdout)


if __name__ == '__main__':
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(TestHeightsCompare)
    res = unittest.TextTestRunner(verbosity=0).run(suite)
    if not res.wasSuccessful():
        print('FAIL heights_compare_test: %d failed, %d errors' % (len(res.failures), len(res.errors)))
        sys.exit(1)
    print('PASS heights_compare_test: %d/%d checks passed' % (res.testsRun, res.testsRun))
