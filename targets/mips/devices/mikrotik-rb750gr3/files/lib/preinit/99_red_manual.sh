#!/bin/sh
# RiverOs 6.12 — red manual en PREINIT (hook initramfs) + dropbear
# Puertos DTB RB750Gr3: wan=ether1, lan2-lan5=ether2-5
#
# wan y br-lan NO pueden compartir /24: con 192.168.88.3 en wan y 192.168.88.1
# en br-lan la ruta conectada del /24 sale por una sola de las dos y el router
# deja de responder ARP en la otra (sintoma: DHCPACK/IP visible pero
# 'ip neigh FAILED'). El rescate por netboot vive en 192.168.88.0/24 (loader
# .2), asi que br-lan se queda en un /24 propio.
LAN_IP=192.168.10.1
WAN_IP=192.168.88.3
NETMASK=255.255.255.0

red_manual() {
	local p
	[ -n "$INITRAMFS" ] || return 0
	sleep 1
	ifconfig lo up 2>/dev/null
	mkdir -p /etc/dropbear 2>/dev/null
	# conduit/master DSA arriba antes que los puertos de usuario
	for p in eth0 sw0; do
		[ -d "/sys/class/net/$p" ] && ifconfig "$p" up 2>/dev/null
	done
	# br-lan (lan2-5): solo con los puertos que el probe del MT7530 creo
	brctl addbr br-lan 2>/dev/null
	for p in lan2 lan3 lan4 lan5; do
		[ -d "/sys/class/net/$p" ] || continue
		ifconfig "$p" up 2>/dev/null
		brctl addif br-lan "$p" 2>/dev/null
	done
	ifconfig br-lan "$LAN_IP" netmask "$NETMASK" up 2>/dev/null
	# wan (ether1) — red del loader netboot
	if [ -d /sys/class/net/wan ]; then
		ifconfig wan "$WAN_IP" netmask "$NETMASK" up 2>/dev/null
	fi
	# dropbear (hostkey generada -R)
	/usr/sbin/dropbear -R 2>/dev/null
}
boot_hook_add initramfs red_manual
