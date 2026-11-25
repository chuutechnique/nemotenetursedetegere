#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build
python3 build/download-debian.py
bash fetch-tor.sh
chmod 755 build/xorriso
unshare --map-auto --map-root-user --mount --pid --fork bash build/install-root.sh
unshare --map-auto --map-root-user --mount --pid --fork bash build/install-nvidia.sh
unshare --map-auto --map-root-user --mount --pid --fork bash build/build-openbox.sh
unshare --map-auto --map-root-user --mount --pid --fork bash build/assemble.sh
