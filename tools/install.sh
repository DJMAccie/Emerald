#!/bin/bash
# Zet de mod (~/Documents/Emerald/mod) in het echte spel en in de testkopie.
#   tools/install.sh          installeren
#   tools/install.sh --check  alleen controleren of spel en testkopie gelijk zijn aan de bron
# Weigert zolang het spel (of een testrun) draait: het spel schrijft bij afsluiten zijn bestanden terug.
set -eu
E="$HOME/Documents/Emerald"
AS="$HOME/Library/Application Support"
TARGETS=("$AS/pokemon-love2d" "$AS/pokemon-love2d-rseqa")
OPTS=(-a --delete --exclude .gitignore --exclude /docs --exclude /tests --exclude /tools
      --include /THIRD_PARTY_NOTICES.md --exclude '*.md' --exclude .DS_Store)
if [ "${1:-}" = "--check" ]; then
  bad=0
  for t in "${TARGETS[@]}"; do
    n=$(rsync -n "${OPTS[@]}" --itemize-changes "$E/mod/" "$t/mods/BATTLE_ART_VOXEL_FORK/" | grep -vc '^\.d' || true)
    echo "$(basename "$t"): $n verschillen"; [ "$n" = 0 ] || bad=1
  done
  exit $bad
fi
if pgrep -f "MacOS/love" >/dev/null; then echo "Het spel (of een testrun) draait: sluit het eerst."; exit 1; fi
for t in "${TARGETS[@]}"; do
  mkdir -p "$t/mods/BATTLE_ART_VOXEL_FORK"
  rsync "${OPTS[@]}" "$E/mod/" "$t/mods/BATTLE_ART_VOXEL_FORK/"
done
"$0" --check && echo "Geinstalleerd: $(git -C "$E/mod" log -1 --format='%h %s')"
