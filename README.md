# RiverOs — OpenWrt minimizado para MikroTik hEX RB750Gr3

Capa base del sistema (SO): **NETEST / OpenWrt → RiverOs** (kernel básico mejorado).
Contiene SOLO el sistema: imagen ImageBuilder, scripts de red/arranque, configs.
El gestor ISP (binario + código) vive en el repo separado **NARA-MIPS** (avisonofgod/Nara-Mips).

```
┌─────────────────────────────────────────────┐
│ NARA-MIPS (gestor ISP)   repo: Nara-Mips    │
│   zpot :80 portal, :8081 admin              │
│   instala en /etc/nara + /etc/init.d/nara   │
├─────────────────────────────────────────────┤
│ RiverOs (ESTE REPO — capa SO)               │
│   kernel 6.12.94 mejorado (initramfs XZ,    │
│   DSA MT7530, netfilter, wireguard)         │
│   ImageBuilder 25.12.5 → riveros-NETEST.bin │
│   scripts: riveros-red, dropbear, rename    │
├─────────────────────────────────────────────┤
│ Bootloader RouterBOOT v6 (sysupgrade PLAIN) │
└─────────────────────────────────────────────┘
```

## Hardware
- hEX RB750Gr3, MT7621 (mipsel_24kc), 256MB RAM, 16MB flash NAND
- RouterBOOT 6.47.10 (v6 — sysupgrade PLAIN, NO -v7)
- MAC: DC:2C:6E:7B:2A:76
- Switch MT7530 (DSA): 5 puertos Gigabit + puerto CPU interno

## Identidad RiverOs
- hostname: riveros
- console: **ether1 = eth0**, IP 192.168.5.1/24, DHCP .100-.249 (si dnsmasq activo)
- pass root: rbadmin2026 (CAMBIAR en producción)
- sin LuCI/uhttpd/rpcd (eliminados via apk del)
- 52 paquetes (bin NETEST) / 84 paquetes (bin NARA-BASE, + nft/tc/wg/dnsmasq)

## Nombres de puertos (ethX neutro, nivel kernel)
Los puertos se renombran a una forma neutra (sin wan/lan — los puertos son solo
puertos, cada cliente los configura desde NARA):

| Nombre kernel | Puerto físico | Uso |
|---|---|---|
| eth0 | ether1 | Consola / acceso físico (192.168.5.1) |
| eth1 | ether2 | Libre (configurable) |
| eth2 | ether3 | Libre (configurable) |
| eth3 | ether4 | Libre (configurable) |
| eth4 | ether5 | Libre (configurable) |
| sw0 | — | Puerto CPU del switch (interno, oculto) |

Rename en boot: `scripts/rename-ports` → `/etc/init.d/rename-ports` (START=08,
antes de network START=20). PITFALL: renombrar en vivo con netifd corriendo tira
la IP de la interfaz — usar UCI + init, y tener IP de respaldo (192.168.10.1/24)
en otro puerto antes de tocar.

## Red manual (sin UCI/netifd)
- libuci/netifd/ucode = deps DURAS de base-files: NO purgables via apk; purgable: uci (CLI)
- Deshabilitados: network, firewall, odhcpd, uhttpd, rpcd, ucitrack, sysntpd, cron
  (whiteouts en overlay /etc/rc.d)
- Red gestionada por S98riveros-red (script manual ip, SIN netifd):
  - renombra cpu port -> sw0, ether1 -> eth0
  - ip addr 192.168.5.1/24 dev eth0
- dropbear: script manual S95dropbear (sin UCI, key ed25519 en /etc/dropbear)

## Build del bin (ImageBuilder)
```sh
cd imagebuilder
./build-netest.sh        # 52 paq: riveros-NETEST-25.12.5.bin (md5 fdb90695)
# variante NARA-BASE (84 paq, + dnsmasq nftables tc wireguard):
#   ajustar PACKAGES en build-netest.sh → riveros-NARA-BASE-25.12.5.bin (md5 d4bf6c76)
# variante NARA-RADIUS (90 paq, + ppp pppoe radius): build-nara-radius.sh
# variante NARA-RADIUS-EMBEBIDO (backend zpot+static+templates en la imagen):
#   build-nara-radius-embebido.sh (md5 9b1e4406) — sysupgrade deja NARA completo
```
Bins: `/root/netinstall-openwrt/backups/`

## Recuperacion / rollback
- Binario funcional: /root/netinstall-openwrt/backups/riveros-GOOD-25.12.5.bin
- restore.sh: netboot initramfs 22.03.3 -> sube GOOD -> sysupgrade -n -> espera 192.168.5.1
- Loader dnsmasq: /root/netinstall-openwrt (dhcp-boot=openwrt-22.03.3-initramfs-kernel.bin)
- Backups: /root/netinstall-openwrt/backups/

## Kernel propio (rama kernel-propio)
RiverOs-kernel: kernel mainline 6.12.103 cross mipsel + busybox/dropbear estaticos
+ init estilo RiverOs (ver kernel-propio/README.md). Sustituye a OpenWrt como
capa SO; validado con verify-kernel-image.sh (18/18 PASS, vmlinux 5.58MiB).
- build.sh: allnoconfig + scripts/config, load-y 0x80b71000, DTB appended
  objcopy, set-start entry, -Os, KALLSYMS off, initramfs XZ
- rootfs/init: rename DSA->ethX, consola eth0=192.168.99.1/24, dropbear :22,
  hook NARA (/etc/nara/zpot -> :80/:8081)
- Estado: compilado + verificado; netboot TFTP en hardware PENDIENTE

## Estructura repo
- scripts/    init.d de RiverOs (riveros-red, dropbear-manual, rename-ports)
- configs/    configs UCI de referencia
- overlay-backup/  snapshots del overlay
- imagebuilder/    build-netest.sh + files/ (hostname, network, shadow, dropbear, system)

## Relacion con NARA-MIPS
- NARA-MIPS instala encima de esta base: zpot (binario mipsel) en /etc/nara,
  /etc/init.d/nara (procd START=99), symlinks /home/naram, static/ y templates/.
- El frontend NARA configura ethX (ip-addresses, mwan, vlans, bridges...) usando
  los nombres reales del kernel (eth0..eth4) — ver repo Nara-Mips.
