#!/bin/bash
set -euo pipefail
mount --make-rprivate /
r=$PWD/.build/root
mkdir -p "$r"
tar -xpf .build/base.tar.gz -C "$r"
mount -t proc proc "$r/proc"
mount --rbind /dev "$r/dev"
rm -f "$r/etc/resolv.conf"
cp -L /etc/resolv.conf "$r/etc/resolv.conf"
sed -i 's/^Components: main$/Components: main non-free-firmware/' "$r/etc/apt/sources.list.d/debian.sources"
printf '#!/bin/sh\nexit 101\n' > "$r/usr/sbin/policy-rc.d"
chmod +x "$r/usr/sbin/policy-rc.d"
chroot "$r" apt-get update
mapfile -t packages < packages.txt
chroot "$r" env PATH=/usr/sbin:/usr/bin:/sbin:/bin DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${packages[@]}"
