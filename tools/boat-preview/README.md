# Offline boat preview

Shows the mod's Mr. Briney's boat (`Gen3RockSprites.M.boat`) without booting the game: a small
software renderer draws the mesh the mod builds, coloured with the sprite's own texels. Reach for it
when tuning the boat's shape, before spending a QA capture on it; it also catches missing faces (a
hole showed up as the hull's dark bottom seen through the cockpit).

```bash
cd ~/Documents/Emerald
python3 tools/boat-preview/gen_pixels.py 88 > /tmp/pixels.lua
luajit tools/boat-preview/harness.lua ~/Documents/battle-art-notquiteog /tmp/pixels.lua > /tmp/boat_mesh.txt
python3 tools/boat-preview/preview.py        # boat_preview.png: from the stern, the bow, the side, and 75 degrees
```

The pixel dump reads the QA copy's sprite cache and is ROM-derived: never commit it (this directory
only holds the scripts). Rotate the views by editing `views` at the bottom of `preview.py`.
