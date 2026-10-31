#!/bin/bash
# play_rewrite.command: play the clean rewrite (EMERALD_3D from ~/Documents/emerald3d) in its own QA copy.
# Double-click in Finder, or run it from a terminal. Identity pokemon-love2d-rseqa-rw: cloned once from the main
# QA copy (saves included), then only its mods are refreshed on every launch, so your saves there persist.
# Never touches the real game, its mods or the main QA copy. The old BATTLE_ART_VOXEL_FORK is removed from this
# copy only. Options match the play setup: zoom -2, tilt 2, windowed.
set -u
SRC=${EMERALD3D_SRC:-$HOME/Documents/emerald3d-clouds}   # combined main (followers, wild spawner, flyers); emerald3d itself sits on an old branch
AS="$HOME/Library/Application Support"; MAIN="$AS/pokemon-love2d-rseqa"; ID=pokemon-love2d-rseqa-rw; QI="$AS/$ID"
[ -f "$SRC/manifest.json" ] || { echo "no rewrite at $SRC"; exit 2; }
for p in $(pgrep -x love); do ps eww -p $p 2>/dev/null | grep -q "POKEPORT_IDENTITY=$ID\( \|$\)" && { echo "already running (pid $p)"; exit 0; }; done
if [ ! -d "$QI" ]; then cp -Rc "$MAIN" "$QI" 2>/dev/null || cp -R "$MAIN" "$QI"; cp "$MAIN/options.lua" "$QI/options.lua"; fi
[ -f "$SRC/assets/flyers/manifest.lua" ] || { echo "no assets/flyers in $SRC (Pokemon sprites would fall back to a placeholder bird)"; exit 2; }
rm -rf "$QI/mods/BATTLE_ART_VOXEL_FORK"
# the rewrite has its own wild spawner; the old overworld_wild_spawns mod would double-spawn, so park it (never deleted)
if [ -d "$QI/mods/overworld_wild_spawns" ]; then B="$QI/mods-backup-$(date +%Y%m%d)"; mkdir -p "$B"; mv "$QI/mods/overworld_wild_spawns" "$B/"; fi
mkdir -p "$QI/mods/EMERALD_3D"
rsync -a --delete --exclude '.git/' --exclude 'docs/' --exclude 'tests/' --exclude 'tools/' "$SRC/" "$QI/mods/EMERALD_3D/"
QI="$QI" python3 - <<'PY'
import os,re
p=os.environ["QI"]+"/options.lua";s=open(p,'rb').read()
s=re.sub(rb"\n  zoom = -?\d+,",b"\n  zoom = -2,",s,count=1)
s=re.sub(rb'videoMode = "\w+",',b'videoMode = "windowed",',s,count=1)
s=re.sub(rb"pipelines = \{[^}]*\},",b"pipelines = { emerald3d = 1 },",s,count=1)
s=re.sub(rb"\n  tilt = \d+,",b"\n  tilt = 2,",s,count=1)
open(p,'wb').write(s)
PY
U="$AS/pokemon-love2d/updates"; PAY=$(ls -t "$U"/gen1recomp-*.love 2>/dev/null | head -1)
[ -n "$PAY" ] && { mkdir -p "$QI/updates"; cmp -s "$PAY" "$QI/updates/$(basename "$PAY")" || cp "$PAY" "$QI/updates/"; }
cd ~/Documents/gen1recomp || exit 1
echo "starting the rewrite ($ID); log: /tmp/play_rewrite.log (keep this window open while you play)"
POKEPORT_IDENTITY=$ID POKEPORT_GAME=emerald exec /Applications/gen1recomp.app/Contents/MacOS/love . > /tmp/play_rewrite.log 2>&1
