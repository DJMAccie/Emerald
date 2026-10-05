# What pret/pokeemerald gives us (checked 2026-10-05)

`https://github.com/pret/pokeemerald` — the matching decompilation. Read for **constants and
semantics only**: it is MIT-licensed code, and it carries no ROM art (that comes from the user's own
ROM), so nothing ROM-derived enters this repo by consulting it.

## It confirms the elevation work — the names, from the cartridge's own source

`include/global.fieldmap.h`:

```c
// Map grid blocks consist of a 10 bit metatile id, a 2 bit collision value, and a 4 bit elevation value
#define MAPGRID_METATILE_ID_MASK 0x03FF  // Bits 0-9
#define MAPGRID_COLLISION_MASK   0x0C00  // Bits 10-11
#define MAPGRID_ELEVATION_MASK   0xF000  // Bits 12-15

enum {
    ELEVATION_TRANSITION = 0,
    ELEVATION_SURF = 1,
    ELEVATION_DEFAULT = 3,
    ELEVATION_MULTI_LEVEL = 15,
    ELEVATION_INVALID = 0xFFFF
};
```

This is an independent confirmation of every value the elevation implementation was built on, which
had been derived by measurement:

| Our measurement | Decomp name |
|---|---|
| nibble at bits 12-15 (`math.floor(word/4096)%16`) | `MAPGRID_ELEVATION_SHIFT 12`, mask `0xF000` |
| collision at bits 10-11 | `MAPGRID_COLLISION_SHIFT 10`, mask `0x0C00` |
| metatile id in bits 0-9 | `MAPGRID_METATILE_ID_MASK 0x03FF` |
| `e3` is ground | `ELEVATION_DEFAULT = 3` |
| `e1` is water ("keep water at sea level") | `ELEVATION_SURF = 1` |
| `e0` is the transition/connector layer | `ELEVATION_TRANSITION = 0` |
| `e15` behaved oddly (Fortree) | `ELEVATION_MULTI_LEVEL = 15` — **a sentinel, not 12 courses** |

**Consequences for the shipped elevation work:**
- Pinning walkable `elev >= 3` and treating `e1` as sea level 0 are both exactly right.
- `MAX_STEP=3` clamping `e15` is justified by the name: `ELEVATION_MULTI_LEVEL` is a marker, not a
  height. Fortree's 0/16/48 is a defensible read of it, and this is the citation for it.
- The elevator/stairs reading still stands: we could not find a matching data structure for
  "walkable e0 run between two levels" (`mbElevation` does not exist in this repo), so the
  `climb` heuristic remains the pragmatic answer.

## Landmark graphics ids — no more hunting

`include/constants/event_objects.h` gives every object graphics id by name:

```c
#define OBJ_EVENT_GFX_TRUCK      94    // confirmed: the Littleroot pillar IS the truck
#define OBJ_EVENT_GFX_CABLE_CAR 114
#define OBJ_EVENT_GFX_SS_TIDAL  140
#define OBJ_EVENT_GFX_SUBMARINE_SHADOW 141
```

So the landmarks the plan wanted to hunt one by one can be enumerated straight from this header
(boats, cable car, ferry, rocket and the rest), each with a name — and that name is also what the
model builder can key on.

## Other things worth mining later

- `include/constants/metatile_behaviors.h` — authoritative behaviour constants. We currently use
  magic numbers (`0x60` door, `0x69` animated door, `0x0C` MOUNTAIN_TOP, `0x2A`/`0x1D0` stairs,
  `0x38-0x3F` jumps). Replacing those with the named constants would make the shape tables
  self-documenting and much harder to get wrong.
- `include/constants/metatile_labels.h` — human names per metatile, useful when a tile misbehaves.
- `data/layouts/*/map.bin` — the layouts themselves, i.e. a second opinion on any layout we read
  from the engine's extraction.
