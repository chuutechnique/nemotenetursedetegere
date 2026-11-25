# nemotenetursedetegere

live image for x86-64 computers, based on debian 13

the system boots from a usb drive, loads the image into ram and opens tor browser in openbox

tor browser is the default browser, while firefox esr is available through super+f and uses the network connection directly

## boot from usb

1. build the iso and its sha-256 file using the instructions below, then run `sha256sum -c *.iso.sha256` inside the folder containing both files
2. in rufus, select the usb drive and iso, click **start** and choose **write in dd image mode**
3. if rufus does not offer that choice, press **alt+i** in the main window to disable iso mode and start writing in dd mode
4. check the selected device carefully, since writing the image erases the usb drive contents
5. restart the computer and select the usb drive from the boot menu
6. the image supports bios and 64-bit uefi, with secure boot disabled for uefi
7. for a geforce rtx 50 series card, select the nvidia entry in grub, while the standard entry uses the default graphics drivers
8. the first browser tab shows the keyboard shortcuts, while the **connect to tor** tab provides the **connect** button
9. if no network route is available, the wi-fi window opens automatically, and super+w opens it again and provides access to **shut down**

dd mode preserves the efi partition included in the image

use a computer with at least 4 gb of ram

the network selector checks for a missing ipv4 or ipv6 route without contacting an external website

a captive portal or a network without internet access may still provide a route, so tor browser reports whether it could establish a connection

the selector supports open networks and personal wi-fi networks with passwords, while adapter compatibility depends on the drivers and firmware included in debian

## session data

the system uses `toram`, a writable layer in ram, disabled swap and physical disks marked as read-only

session history, downloads, changes and wi-fi credentials are discarded at shutdown

this does not erase records kept by websites, routers or internet providers, and does not guarantee protection against memory forensics or firmware records

## build another iso

on an x86-64 linux host, install python 3.11 or later, curl, gnupg, tar with xz support, grub with the `i386-pc` and `x86_64-efi` modules, mtools and util-linux

the build uses user namespaces with `newuidmap`, `newgidmap` and ranges configured in `/etc/subuid` and `/etc/subgid`

run `bash build.sh`

the resulting image and checksum are written to `dist/`, using the stable tor browser release available during the build

the build also installs the isolation components and tools listed below

use a working directory on a linux filesystem that supports unix permissions and ownership

the first build downloads the official debian base and verifies the tor browser signature using the key published by the tor project

## versions

the current version is `v0.2-25.11.2026`, following the pattern `v<major>.<minor>-dd.mm.yyyy`, as defined in the version file at the project root

keep this number for new images until the owner explicitly authorizes a different version

the build rejects other versions until that authorization is incorporated into the code

do not increment the number or change the date automatically

publish new versions only after authorization, keep each iso and its sha-256 file in `releases/<version>/` and preserve download links for previous releases

## changes in v0.2-25.11.2026

tor browser uses `/opt/tor-browser` on the writable ram layer provided by debian live, avoiding another complete installation copy in `/run/user`

the build restores unix ownership and permissions for all overlay files after copies through windows, keeping configuration files protected from writes by other users and scripts executable

the journal remains volatile, with a target of 32 mebibytes and individual files limited to 4 mebibytes

the direct firefox launcher displays a warning before opening and lets the user choose whether to connect the microphone to the session

firefox esr telemetry and studies are disabled through browser policies, while tor browser retains its internal protections

the commands and sockets belonging to the old ip changer have been removed

## applications and tools

`sonic install` and `sonic install list` display the same list

discord, openvpn, tailscale and cowsay remain available

nmap, dig, whois, netcat, curl, jq and exiftool are included through signed debian packages

`sonic install <name>` enables a launcher for the ram session without downloading another copy of its dependencies

use these tools on systems and networks you administer or have permission to test

## isolation

the tor browser, firefox and discord launchers create a dedicated xephyr display and separate filesystem, process, ipc and network namespaces using bubblewrap and slirp4netns

the desktop home directory, desktop d-bus and main display socket are not exposed to these applications

each application keeps its own files in ram

the shared exchange folder inside the home directory is accessible to the applications, so do not place files there that should remain private to one application

copying, pasting and dragging files freely between isolated displays is restricted

all tor windows use one tor browser session with shared cookies and logins, so they are not independent identities

super+t always activates the tor launcher, including when direct firefox is open

audio passes through pcm channels without exposing the desktop pulseaudio control socket to applications

firefox microphone access depends on the option selected in its warning, while discord asks when it starts

the tools also use isolated launchers, with no inbound ports or packet capture and raw socket privileges by default

openvpn, tailscale, the installer and network settings remain trusted session management components and do not use the same application isolation

this model does not provide a separate virtual machine for each application

the kernel, graphics drivers, xephyr, audio and network brokers and desktop remain shared trusted components

gpu access remains available for compatibility

the desktop terminal is trusted, and running a binary directly from `/usr/bin` can bypass the launchers

vulnerabilities in the kernel, drivers or brokers may still compromise isolation, and abusive cpu or ram consumption is not prevented

## ram and traces

`sonic-ram-check --strict` produces a json report covering mounts, the writable layer, the backing files of the squashfs image, swap and disk write protection

it returns an error if a ram check fails or cannot be completed

run it inside the booted live system, since running it in the build environment does not validate the iso

`toram`, `nopersistence`, `noswap` and volatile logs reduce local writes, but do not erase website, provider or router records

the check cannot observe host swap, hibernation or virtual machine snapshots, guarantee immediate physical erasure of ram or rule out firmware records

udev write protection is not a security boundary against root

audio, microphone, wi-fi and nvidia compatibility must be checked on the target hardware

only tor browser uses tor automatically

firefox, discord, installer downloads and tailscale may use direct connections, and a vpn does not provide the same properties as tor

these functions remain available by the owner's decision, and signing into personal accounts links activity to those accounts

## build and validation

the debian base download verifies the amd64 manifest hash and downloaded layer hash

tor browser is verified through its signature

the initial nvidia repository key is retrieved through https without an independently pinned hash in this project

packages and browsers can change between builds, so the same version number does not imply an identical image

always verify the sha-256 of the exact file being used

session updates do not survive a restart, so distribute updated images to retain security fixes

the linux tests in `tests/test_sandbox.py` check file, process and environment separation, the exchange folder, blocked host loopback and abstract sockets, and prevention of application execution when setup fails

run them as an ordinary user with the isolation dependencies installed

they do not replace an independent audit or boot and hardware testing
