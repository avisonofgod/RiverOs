#!/bin/bash
# RiverOs bin NARA-RADIUS: ImageBuilder 25.12.5 mt7621, 84+ paq
# = NARA-BASE (dnsmasq nftables tc wireguard) + ppp + pppoe + RADIUS (ppp-mod-radius)
# Uso: cd imagebuilder-25.12.5 && FILES=<repo>/imagebuilder bash build-nara-radius.sh
set -e
FILES_DIR="${FILES:?FILES=ruta a imagebuilder/ del repo}"
make image PROFILE=mikrotik_routerboard-750gr3 FILES="$FILES_DIR" PACKAGES="base-files busybox dropbear fstools kmod-gpio-button-hotplug kmod-leds-gpio libc libgcc libuci logd mtd netifd procd ubus ubusd ubox uci urandom-seed urngd kmod-usb3 dnsmasq nftables tc-tiny wireguard-tools kmod-wireguard ppp ppp-mod-pppoe ppp-mod-radius rp-pppoe-server -firewall4 -nftables-json -kmod-nft-offload -wpad-basic-mbedtls -odhcpd-ipv6only -odhcp6c -ca-bundle -uclient-fetch -libustream-mbedtls -procd-ujail -procd-seccomp -kmod-mt7615-firmware -kmod-crypto-hw-eip93 -uboot-envtools -kmod-mt7603 -kmod-mt76 -kmod-mt76-core"
