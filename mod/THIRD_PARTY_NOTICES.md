# Third-party code

`assets/shaders/fsr1/ffx_a.h` and `ffx_fsr1.h` are the AMD FidelityFX Super Resolution 1 reference headers, from [GPUOpen-Effects/FidelityFX-FSR](https://github.com/GPUOpen-Effects/FidelityFX-FSR/tree/a21ffb8f6c13233ba336352bdff293894c706575/ffx-fsr), revision `a21ffb8f6c13233ba336352bdff293894c706575`. Copyright (c) 2021 Advanced Micro Devices, Inc.; additional notices appear in the headers. Distributed under the MIT license printed in both files.

The headers are unchanged. `lib/SpatialUpscale.lua` supplies texture callbacks, GLSL 330 packing/bitfield compatibility and unsigned setup literals, canvas management and quality options. It uses the full-precision EASU and RCAS algorithms. It does not implement AMD temporal upscaling, frame generation or NVIDIA DLSS.

## Emerald 3DS street lamps

`lib/Gen3Lamp.lua` reimplements, in Lua, the night lamps of the [Emerald 3DS dual-screen port](https://github.com/ZallaxDev/pokeemerald-3Ds-dualscreen) (`3ds_port/src/voxel/voxel_sign.c`, `ctr_voxel.c`), revision `b98cc23b8c8a607363504a866d2b562f7c532fb2`, by Zallax and Emerald 3DS contributors: the lantern test and glass quads on the lamp head (flat colour 255,191,107 at alpha 220 x strength, front and back) and the ground pool of light (radius 1.75 cells, falloff (1 - r^2)^2, ground-height quads). The constants and the method follow that project; the code is written for this mod's scene and effect pass, and no 3DS source, art or ROM data is copied.

`data/gen3_relief.lua` (read by `lib/Gen3Relief.lua`) was counted with a Python port of the same project's relief method (`3ds_port/scripts/voxel_terraces.py`, `gen_voxel_relief.py`, `voxel_mesh_builder.c` EmitRelief/EmitCliffWalls, same revision): terraces, levels and ledge berms per map. No 3DS code, art or ROM data is copied.

Original licence (`LICENSE-PORT.md`, which covers only the port's own code):

```text
MIT License

Copyright (c) 2026 Zallax and Emerald 3DS contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
