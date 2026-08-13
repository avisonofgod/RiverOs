#!/bin/bash
# RiverOs bin NARA-RADIUS-EMBEBIDO: ImageBuilder 25.12.5 mt7621, 90 paq
# = NARA-RADIUS (dnsmasq nftables tc wireguard ppp pppoe radius) + backend
#   NARA embebido en la imagen (zpot + static + templates + init.d + symlinks)
# Flujo: flash base NETEST -> sysupgrade a este bin = NARA completo, sin
# reinstalar backend. Consola eth0=192.168.99.1 tras rename-ports (S08).
# Uso: cd imagebuilder-25.12.5 && FILES=<arbol files con backend> bash build-nara-radius-embebido.sh
# FILES esperado (estructura):
#   etc/config/{network,dropbear,system} etc/hostname etc/shadow
#   etc/nara/{zpot,static/,templates/}
#   etc/init.d/{nara,rename-ports} etc/rc.d/{S99nara,S08rename-ports}
#   usr/lib/libc.so.1 -> /lib/libc.so   home/naram -> /etc/nara
set -e
FILES_DIR="${FILES:?FILES=ruta al arbol files/}"
make image PROFILE=mikrotik_routerboard-750gr3 FILES="$FILES_DIR" PACKAGES="base-files busybox dropbear fstools kmod-gpio-button-hotplug kmod-leds-gpio libc libgcc libuci logd mtd netifd procd ubus ubusd ubox uci urandom-seed urngd kmod-usb3 dnsmasq nftables kmod-nft-nat tc-tiny wireguard-tools kmod-wireguard ppp ppp-mod-pppoe ppp-mod-radius rp-pppoe-server -firewall4 -nftables-json -kmod-nft-offload -wpad-basic-mbedtls -odhcpd-ipv6only -odhcp6c -ca-bundle -uclient-fetch -libustream-mbedtls -procd-ujail -procd-seccomp -kmod-mt7615-firmware -kmod-crypto-hw-eip93 -uboot-envtools -kmod-mt7603 -kmod-mt76 -kmod-mt76-core"
