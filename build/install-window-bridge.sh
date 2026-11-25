#!/bin/bash
set -euo pipefail
mount --make-rprivate /
r=$PWD/.build/root
mount -t proc proc "$r/proc"
mount --rbind /dev "$r/dev"
mount -t tmpfs tmpfs "$r/run"
mkdir -p "$r/run/NetworkManager"
cp -L /etc/resolv.conf "$r/run/NetworkManager/resolv.conf"
key=$(mktemp)
trap 'rm -f "$key"' EXIT
curl -fsSL https://xpra.org/xpra.asc -o "$key"
gpg --batch --show-keys --with-colons "$key" | grep -q '^fpr:::::::::B4993B57323148E37977E5D873254CAD17978FAF:'
install -m644 "$key" "$r/usr/share/keyrings/xpra.asc"
cat > "$r/etc/apt/sources.list.d/xpra.sources" <<'REPO'
Types: deb
URIs: https://xpra.org
Suites: trixie
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/xpra.asc
REPO
cat > "$r/etc/apt/preferences.d/xpra" <<'PIN'
Package: *
Pin: origin xpra.org
Pin-Priority: 100
PIN
chroot "$r" apt-get update
chroot "$r" env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends xpra-server xpra-client-gtk3 xpra-x11
if chroot "$r" dpkg-query -W -f='${Status}' xserver-xephyr 2>/dev/null | grep -q 'install ok installed'; then
    chroot "$r" env DEBIAN_FRONTEND=noninteractive apt-get purge -y xserver-xephyr
fi
chroot "$r" systemctl mask xpra.service xpra.socket
rm -f "$r/etc/xpra/ssl/key.pem" "$r/etc/xpra/ssl/cert.pem" "$r/etc/xpra/ssl/ssl-cert.pem"
chroot "$r" apt-get clean
