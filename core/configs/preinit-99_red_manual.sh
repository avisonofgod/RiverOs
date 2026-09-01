#!/bin/sh
# RiverOs 22.03.3 — red manual en PREINIT (no depende de /etc/rc.d/ vacio)
# Puertos DTB: wan=ether1, lan2-lan5=ether2-5
red_manual() {
	[ -n "$INITRAMFS" ] || return 0
	sleep 1
	ifconfig lo up 2>/dev/null
	brctl addbr br-lan 2>/dev/null
	for p in lan2 lan3 lan4 lan5; do
		ifconfig $p up 2>/dev/null
		brctl addif br-lan $p 2>/dev/null
	done
	ifconfig br-lan 192.168.88.1 netmask 255.255.255.0 up 2>/dev/null
	ifconfig wan up 2>/dev/null
	ifconfig wan 192.168.88.3 netmask 255.255.255.0 up 2>/dev/null
	/usr/sbin/dropbear -R 2>/dev/null
}
boot_hook_add initramfs red_manual
