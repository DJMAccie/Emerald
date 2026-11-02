#!/bin/bash
# Zet de mod (~/Documents/Emerald/mod) en de importer (stadium2-importer) in het echte spel en in de testkopie.
#   tools/install.sh          installeren
#   tools/install.sh --check  alleen controleren of spel en testkopie gelijk zijn aan de bron
# Weigert zolang het spel (of een testrun) draait: het spel schrijft bij afsluiten zijn bestanden terug.
set -eu
E="$HOME/Documents/Emerald"
AS="$HOME/Library/Application Support"
TARGETS=("$AS/pokemon-love2d" "$AS/pokemon-love2d-rseqa")
PAIRS=("mod:BATTLE_ART_VOXEL_FORK" "stadium2-importer:STADIUM2_IMPORTER")
# baseroms/ en colosseum/ zijn lokale ROM-gegevens in de spelmap: nooit kopieren of wissen.
OPTS=(-a --delete --exclude .gitignore --exclude .modkitignore --exclude /docs --exclude /tests --exclude /tools
      --exclude /baseroms --exclude /colosseum --exclude __pycache__
      --include /THIRD_PARTY_NOTICES.md --exclude '*.md' --exclude .DS_Store)
if [ "${1:-}" = "--check" ]; then
  bad=0
  for t in "${TARGETS[@]}"; do
    for p in "${PAIRS[@]}"; do
      n=$(rsync -n -c "${OPTS[@]}" --itemize-changes "$E/${p%%:*}/" "$t/mods/${p#*:}/" | grep -vc '^\.d' || true)
      echo "$(basename "$t") ${p#*:}: $n verschillen"; [ "$n" = 0 ] || bad=1
    done
  done
  exit $bad
fi
if pgrep -f "MacOS/love" >/dev/null; then echo "Het spel (of een testrun) draait: sluit het eerst."; exit 1; fi
for t in "${TARGETS[@]}"; do
  for p in "${PAIRS[@]}"; do
    mkdir -p "$t/mods/${p#*:}"
    rsync "${OPTS[@]}" "$E/${p%%:*}/" "$t/mods/${p#*:}/"
  done
done
"$0" --check && echo "Geinstalleerd: $(git -C "$E" log -1 --format='%h %s')"
