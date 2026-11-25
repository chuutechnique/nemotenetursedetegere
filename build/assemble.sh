#!/bin/bash
set -euo pipefail
version=$(<VERSION)
[[ $version == v0.2-25.11.2026 ]] || { echo "VERSION must remain v0.2-25.11.2026 until an explicit version change is authorized." >&2; exit 1; }
mount --make-rprivate /
r=$PWD/.build/root
iso=$PWD/.build/iso
mkdir -p "$iso/boot/grub" "$iso/live" dist
mount -t proc proc "$r/proc"
mount --rbind /dev "$r/dev"

guest() {
    chroot "$r" env PATH=/usr/sbin:/usr/bin:/sbin:/bin DEBIAN_FRONTEND=noninteractive "$@"
}

cp -a overlay/. "$r/"
# NTFS/ZIP backups do not preserve Unix modes. Restore safe defaults for every
# overlay file, not just executable scripts, before creating the live image.
python3 - "$r" <<'PY'
from pathlib import Path
import os
import sys

root = Path(sys.argv[1])
for source in Path("overlay").rglob("*"):
    if source.is_symlink():
        continue
    target = root / source.relative_to("overlay")
    os.chown(target, 0, 0)
    target.chmod(0o755 if source.is_dir() else 0o644)
PY
python3 - "$r/usr/local/share/sonic-os/start.html" "$version" <<'PY'
from pathlib import Path
import re
import sys

page = Path(sys.argv[1])
text, count = re.subn(r'<p class="version">[^<]*</p>',
                      '<p class="version">' + sys.argv[2] + '</p>', page.read_text())
if count != 1:
    raise SystemExit("Expected exactly one version label in start.html")
page.write_text(text)
PY
sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="nemoTeneturSeDetegere"/; s/^NAME=.*/NAME="nemoTeneturSeDetegere"/' "$r/usr/lib/os-release"
printf "en_US.UTF-8 UTF-8\n" > "$r/etc/locale.gen"
guest locale-gen
printf 'LANG=en_US.UTF-8\n' > "$r/etc/default/locale"
id_file="$r/etc/passwd"
for old_user in navegador sonic; do
    if grep -q "^${old_user}:" "$id_file"; then
        guest usermod -l nemo -d /home/nemo -m "$old_user"
        guest groupmod -n nemo "$old_user"
        break
    fi
done
if ! grep -q '^nemo:' "$id_file"; then
    guest useradd -m -s /bin/bash nemo
fi
guest sh -c 'cp -a /etc/skel/. /home/nemo/; chown -R nemo:nemo /home/nemo; chmod 700 /home/nemo'
rm -rf "$r/opt/tor-browser"
mkdir -p "$r/opt/tor-browser"
tar --extract --xz --file=.build/tor-browser.tar.xz --directory="$r/opt/tor-browser" --strip-components=1 --no-same-owner
chmod -R a+rX "$r/opt/tor-browser"
# The single live user can update the browser/profile in the RAM-backed root
# overlay. The SquashFS lower layer remains immutable between boots.
guest chown -R nemo:nemo /opt/tor-browser
# Recover executable permissions even when the source was backed up on Windows.
find "$r/usr/local/bin" -maxdepth 1 -type f -exec chmod 755 {} +
chmod 755 "$r/etc/skel/.xinitrc" "$r/etc/skel/.config/openbox/autostart"
for tool in nmap dig whois netcat curl jq exiftool; do
    ln -sfn sonic "$r/usr/local/bin/$tool"
done
guest systemctl enable NetworkManager.service sonic-nvidia.service
guest systemctl mask openvpn.service dkms.service swap.target apt-daily.timer apt-daily-upgrade.timer fstrim.timer systemd-pstore.service hibernate.target suspend-then-hibernate.target hybrid-sleep.target getty@tty2.service getty@tty3.service getty@tty4.service getty@tty5.service getty@tty6.service
guest apt-get clean
chmod 1777 "$r/tmp"
if compgen -G "$r/boot/initrd.img-*" > /dev/null; then
    guest update-initramfs -u -k all
else
    guest update-initramfs -c -k all
fi
rm -f "$r/usr/sbin/policy-rc.d" "$r/var/lib/dbus/machine-id" "$r/etc/resolv.conf"
: > "$r/etc/machine-id"
ln -s /run/NetworkManager/resolv.conf "$r/etc/resolv.conf"
rm -f "$r"/var/log/*.log "$r"/var/lib/apt/lists/*_Packages* "$r"/var/lib/NetworkManager/secret_key
rm -f "$r/var/lib/systemd/random-seed"
cp "$r"/boot/vmlinuz-* "$iso/live/vmlinuz"
cp "$r"/boot/initrd.img-* "$iso/live/initrd.img"
cat > "$iso/boot/grub/grub.cfg" <<'GRUB'
set default=0
set timeout=8
menuentry "nemoTeneturSeDetegere" {
    linux /live/vmlinuz boot=live toram union=overlay nopersistence noswap noresume systemd.gpt_auto=no rd.systemd.gpt_auto=no module_blacklist=nvidia,nvidia_modeset,nvidia_drm,nvidia_uvm loglevel=7 systemd.show_status=1
    initrd /live/initrd.img
}
menuentry "nemoTeneturSeDetegere (NVIDIA)" {
    linux /live/vmlinuz boot=live toram union=overlay nopersistence noswap noresume systemd.gpt_auto=no rd.systemd.gpt_auto=no sonic.nvidia=1 module_blacklist=nouveau nvidia_drm.modeset=1 nvidia_drm.fbdev=1 loglevel=7 systemd.show_status=1
    initrd /live/initrd.img
}
GRUB
umount -l "$r/dev"
umount "$r/proc"
"$r/lib64/ld-linux-x86-64.so.2" --library-path "$r/usr/lib/x86_64-linux-gnu" \
    "$r/usr/bin/mksquashfs" "$r" "$iso/live/filesystem.squashfs" \
    -noappend -comp zstd -processors 4 -mem 512M -wildcards -e boot usr/src var/lib/dkms \
    "usr/bin/apt*" "usr/bin/dpkg*" usr/bin/dh_dkms usr/sbin/dkms usr/lib/apt \
    etc/apt etc/dpkg var/lib/apt var/cache/apt var/cache/debconf var/lib/dpkg
export DEBIAN_ROOT="$r"
name="nemoTeneturSeDetegere-$version-amd64.iso"
grub-mkrescue --xorriso="$PWD/build/xorriso" -o "dist/$name.tmp" "$iso" -volid NEMO
mv "dist/$name.tmp" "dist/$name"
(cd dist && sha256sum "$name" > "$name.sha256")
