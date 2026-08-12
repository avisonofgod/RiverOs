# RiverOs — OpenWrt minimizado para MikroTik hEX RB750Gr3

Base: OpenWrt 25.12.5 (ramips/mt7621), kernel 6.12.94, sysupgrade PLAIN (RouterBOOT v6).

## Hardware
- hEX RB750Gr3, MT7621 (mipsel/mmips), 256MB RAM, 16MB flash NAND
- RouterBOOT 6.47.10 (v6 — sysupgrade PLAIN, NO -v7)
- MAC: DC:2C:6E:7B:2A:76
- Puertos DSA: ether1=wan, ether2-5=lan2-5 (device names 'wan','lan2-5'; NO eth0-4)

## Identidad RiverOs
- hostname: riveros
- console: puerto ether1 (device 'wan' DSA, renombrado a eth0 por riveros-red)
- IP: 192.168.5.1/24, DHCP .100-.249 (si dnsmasq activo)
- pass root: rbadmin2026 (CAMBIAR en producción)
- sin LuCI/uhttpd/rpcd (eliminados via apk del)
- 79 paquetes

## Eliminacion de UCI (en curso)
- libuci/netifd/ucode = deps DURAS de base-files: NO purgables via apk
- Purgable: uci (CLI) + dnsmasq
- Deshabilitados: network, firewall, odhcpd, uhttpd, rpcd, ucitrack, sysntpd, cron
  (whiteouts en overlay /etc/rc.d — los symlinks S* viven en squashfs rom)
- Red gestionada por S98riveros-red (script manual ip, SIN netifd):
  - renombra eth0(cpu port)->cpu0, wan->eth0
  - ip addr 192.168.5.1/24 dev eth0
- dropbear: script manual S95dropbear (sin UCI, key ed25519 en /etc/dropbear)

## Recuperacion / rollback
- Binario funcional: /root/netinstall-openwrt/backups/riveros-GOOD-25.12.5.bin
  (md5 4bc5a67379ba83646d6ccb91df13c78f, 6685300 bytes)
- restore.sh: netboot initramfs 22.03.3 -> sube GOOD -> sysupgrade -n -> espera 192.168.5.1
- Loader dnsmasq: /root/netinstall-openwrt (dhcp-boot=openwrt-22.03.3-initramfs-kernel.bin)
- Backups: /root/netinstall-openwrt/backups/

## Estructura repo
- scripts/    init.d de RiverOs (riveros-red, dropbear-manual)
- configs/    configs UCI de referencia
- overlay-backup/  snapshots del overlay
