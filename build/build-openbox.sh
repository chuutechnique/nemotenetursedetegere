#!/bin/bash
set -euo pipefail
mount --make-rprivate /
r=$PWD/.build/root
mount -t proc proc "$r/proc"
mount --rbind /dev "$r/dev"
mount -t tmpfs tmpfs "$r/run"
mkdir "$r/run/NetworkManager"
cp -L /etc/resolv.conf "$r/run/NetworkManager/resolv.conf"
guest() {
    chroot "$r" env PATH=/usr/sbin:/usr/bin:/sbin:/bin DEBIAN_FRONTEND=noninteractive "$@"
}
guest apt-get install -y --no-install-recommends libxkbcommon-x11-0 bubblewrap slirp4netns xvfb x11-utils iptables pulseaudio-utils nmap bind9-dnsutils whois netcat-openbsd curl jq libimage-exiftool-perl pkg-config libstartup-notification0-dev libxrender-dev libglib2.0-dev libxml2-dev libxt-dev libxinerama-dev libxrandr-dev libpango1.0-dev libx11-dev libimlib2-dev libxcursor-dev librsvg2-dev libxi-dev
src=$(mktemp -d "$r/tmp/openbox.XXXXXX")
trap 'rm -rf "$src"' EXIT
curl -fsSL https://deb.debian.org/debian/pool/main/o/openbox/openbox_3.6.1.orig.tar.gz -o "$src/source.tar.gz"
printf '%s  %s\n' 8b4ac0760018c77c0044fab06a4f0c510ba87eae934d9983b10878483bde7ef7 "$src/source.tar.gz" | sha256sum -c
tar -xzf "$src/source.tar.gz" -C "$src" --strip-components=1
patch -d "$src" -p1 < build/openbox-window-policy.patch
patch -d "$src" -p1 < build/openbox-single-desktop.patch
guest sh -c 'cd "$1"; ./configure --prefix=/usr --sysconfdir=/etc --disable-shared; make -j4 openbox/openbox; install -m755 openbox/openbox /usr/bin/openbox' sh "${src#"$r"}"
