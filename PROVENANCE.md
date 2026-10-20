# Provenance and licence status

Written 2026-10-20, before the repository becomes public. Keep this file accurate: it is the
thing a reviewer will read before diffing anything.

## What this repository is

Tooling for **Emerald 3D**, a 2.5D/3D voxel mod for Pokémon Emerald on the gen1recomp engine:
shape baking, the coverage ledger, QA capture drivers, the headless engine harness and the
offline audits. It contains **no game assets, no ROM data, no screenshots and no builds**.
Working notes and handoffs live in a separate private repository.

## The mod's lineage

Emerald 3D started as a fork of [notquiteog/DramaticShapeVoxelMod](https://github.com/notquiteog/DramaticShapeVoxelMod),
which is itself a fork of [absol89/DramaticShapeVoxelMod](https://github.com/absol89/DramaticShapeVoxelMod),
which in turn forks [TeJota1337/DramaticShapeVoxelMod](https://github.com/TeJota1337/DramaticShapeVoxelMod).

**None of those repositories declares a licence.** GitHub reports `license: null` for all three,
none contains a LICENSE file, and notquiteog's README states: *"No licence is declared for the
rest of that chain, so no redistribution terms are granted and none are claimed here."*

That means: the upstream base is **all rights reserved**, and no licence is granted over it by
this project or by anyone else. Nothing in this repository re-licenses any upstream code.

## What is this project's own work

The Emerald/Hoenn support is original to this project, written between 5 and 20 October 2026
(657 commits in the working repository): the Gen 3 scene, terrain, elevation, buildings and
battle-model pipeline, the 123 baked building models (~147,000 lines of generated geometry
data), the tooling, and the QA/ledger system.

It was written on a 30 September 2026 snapshot of the upstream mod, at which point upstream had
no Hoenn support (an 851-line `Gen3Scene` stub and no buildings). Upstream has since written its
own, independent, Emerald implementation; this project has never merged upstream commits made
after that snapshot.

## What is not claimed

No licence is declared for this repository yet. Until one is, default copyright applies to
everything here.

The mod, when it is published, will ship as its own mod folder that **requires the upstream mod
to be installed separately**; this project will not redistribute upstream files.

## Third-party code used by the mod (not vendored here)

- Voxel Ascendant weather (`lib/Weather.lua`, adapted) — MIT, Roxas2712/DramaticShape.
- AMD FidelityFX Super Resolution 1 headers — MIT, Advanced Micro Devices, Inc.
- DRAMALESS_SHAPE input fixes — MIT, artyrambles.
- Emerald 3DS night-lamp constants and method — MIT, Zallax and Emerald 3DS contributors;
  reimplemented in Lua, no 3DS source, art or ROM data copied.

Full notices live in the mod's `THIRD_PARTY_NOTICES.md`.

## If you are an upstream author

If you want something here removed or licensed differently, open an issue or email
<contact@petyabouianov.com>. Removal requests from the upstream chain will be honoured.
