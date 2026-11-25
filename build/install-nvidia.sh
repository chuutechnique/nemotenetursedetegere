#!/bin/bash
set -euo pipefail
mount --make-rprivate /
r=$PWD/.build/root
repo=https://developer.download.nvidia.com/compute/cuda/repos/debian13/x86_64
curl -fsSL "$repo/cuda-keyring_1.1-1_all.deb" -o "$r/tmp/nvidia-keyring.deb"
mount -t proc proc "$r/proc"
mount --rbind /dev "$r/dev"
saved_dns=$(mktemp -d)
mv "$r/etc/resolv.conf" "$saved_dns/"
trap 'rm -f "$r/etc/resolv.conf"; mv "$saved_dns/resolv.conf" "$r/etc/"; rmdir "$saved_dns"' EXIT
cp -L /etc/resolv.conf "$r/etc/resolv.conf"
guest() {
    chroot "$r" env PATH=/usr/sbin:/usr/bin:/sbin:/bin DEBIAN_FRONTEND=noninteractive "$@"
}

printf "#!/bin/sh\nexit 101\n" > "$r/usr/sbin/policy-rc.d"
chmod +x "$r/usr/sbin/policy-rc.d"
guest dpkg -i /tmp/nvidia-keyring.deb
rm "$r/tmp/nvidia-keyring.deb"
guest apt-get update
kernel=$(basename "$(find "$r/boot" -name 'vmlinuz-*' -print -quit)")
kernel=${kernel#vmlinuz-}
guest apt-get install -y --no-install-recommends "linux-headers-$kernel" nvidia-driver nvidia-kernel-open-dkms
guest modinfo -k "$kernel" -F license nvidia | grep -Fx 'Dual MIT/GPL'
guest modinfo -k "$kernel" -F version nvidia
# Keep Nouveau available for the standard boot entry.
for directory in "$r/etc/modprobe.d" "$r/usr/lib/modprobe.d"; do
    find "$directory" -maxdepth 1 -name '*.conf' -exec sed -i -E '/^[[:space:]]*(blacklist|options|install)[[:space:]]+nouveau([[:space:]]|$)/d' {} +
done
