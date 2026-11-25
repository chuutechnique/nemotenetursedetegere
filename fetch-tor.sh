#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build
work=$(mktemp -d "$PWD/.build/tor.XXXXXX")
trap 'rm -rf "$work"' EXIT
export GNUPGHOME="$work"
fingerprint=EF6E286DDA85EA2A4BA7DE684E2C6E8793298290
curl -fsSL "https://keys.openpgp.org/vks/v1/by-fingerprint/$fingerprint" -o "$work/key"
gpg --batch --import "$work/key"
gpg --batch --export "$fingerprint" > "$work/keyring"
curl -fsSL https://aus1.torproject.org/torbrowser/update_3/release/download-linux-x86_64.json > "$work/release.json"
mapfile -t urls < <(python3 - "$work/release.json" <<'PY'
import json, sys
with open(sys.argv[1]) as file:
    release = json.load(file)
for field in ("binary", "sig"):
    print(release[field])
PY
)
curl -fsSL "${urls[0]}" -o "$work/browser.tar.xz"
curl -fsSL "${urls[1]}" -o "$work/browser.tar.xz.asc"
gpgv --keyring "$work/keyring" "$work/browser.tar.xz.asc" "$work/browser.tar.xz"
mv "$work/browser.tar.xz" .build/tor-browser.tar.xz
