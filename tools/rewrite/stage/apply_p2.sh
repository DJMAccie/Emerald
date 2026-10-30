#!/bin/zsh
# Copy the P2 spec + lifted own code into ~/Documents/emerald3d and commit.
# Run from the Emerald repo: bash tools/rewrite/stage/apply_p2.sh
set -e
W=/Users/user/Documents/Emerald/tools/rewrite
D=$HOME/Documents/emerald3d
mkdir -p "$D/docs/own/modules" "$D/docs/specs"
cp "$W/own/Gen3Elevation.lua" "$W/own/TerrainLevels.lua" "$W/own/HOLES.md" "$D/docs/own/"
cp "$W/own/modules/"*.lua "$D/docs/own/modules/"
cp "$W/stage/HeightField.md" "$D/docs/specs/HeightField.md"

cat >> "$D/docs/PROVENANCE.md" <<'EOF'
| 2026-10-29 | docs/specs/HeightField.md | spec | rewrite coordinator (Emerald repo) | P2 plan + knowledge rules R-01..R-15, R-33..R-35, R-36 | P2 spec; clean-room: behaviour only, lifted-own inventory attached |
| 2026-10-29 | docs/own/Gen3Elevation.lua | lifted-own | dirty-side lift (Emerald repo, lift_field.py) | our added blocks in the 49 modified files (REWRITE-PLAN §2.3) | 1342 our lines kept verbatim, 76 upstream lines replaced by 17 holes for the implementer; simcheck at the P2 gate |
| 2026-10-29 | docs/own/TerrainLevels.lua | lifted-own | dirty-side lift (Emerald repo, lift_field.py) | same | 350 our lines kept verbatim, 134 upstream lines replaced by 12 holes; simcheck at the P2 gate |
| 2026-10-29 | docs/own/modules/Gen3PinData.lua, Gen3EmeraldShapes, Gen3EmeraldAuto, Gen3TreeStamps, Gen3StairTerraces, Gen3EmeraldTerraces | lifted-own | dirty-side lift (Emerald repo) | our 51 new modules | our own code, copied unchanged; reviewed in simcheck_review_pass1.md (Gen3EmeraldShapes OK on interface, recheck once Gen3TileShape names it) |
EOF

python3 - "$D" <<'PY'
import sys, pathlib
D = pathlib.Path(sys.argv[1])
p = D / "docs/rewrite/M1-PLAN.md"
s = p.read_text()
old = "**P2 — height field.**"
add = """**P2 SPEC AND LIFT READY 2026-10-29.** `docs/specs/HeightField.md` (P2: TerrainLevels + Gen3Elevation,
behaviour of every hole, the small modules, the probe wiring, the gate). The lifted own code is in `docs/own/`:
Gen3Elevation 1342 our lines with 17 holes, TerrainLevels 350 our lines with 12 holes, plus six own modules
(Gen3PinData, Gen3EmeraldShapes, Gen3EmeraldAuto, Gen3TreeStamps, Gen3StairTerraces, Gen3EmeraldTerraces).
Parity rule R-36 (Petya 2026-10-29: "we dont change anything about the look we have now"): P2 adds no pixel;
the gate is the M0 field/class baseline.

"""
assert old in s
s = s.replace(old, add + old, 1)
p.write_text(s)
PY

cd "$D"
git add -A
git commit -q -m "M1 P2: HeightField spec + lifted own field code (TerrainLevels, Gen3Elevation, six data modules); parity rule R-36 recorded" \
  -m "The lift keeps our added blocks verbatim and replaces the upstream-derived lines with 17 + 12 spec holes. No pixels change in P2: the gate is the M0 field/class baseline, and the parity rule (Petya 2026-10-29) says the current look is the target."
git log --oneline -1
