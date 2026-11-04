#!/bin/bash
# Double-click: make the Hoenn battle models from your own Pokemon Colosseum disc image.
cd "$(dirname "$0")" && python3 make_hoenn_models.py "$@"
read -r -p "Press Enter to close."
