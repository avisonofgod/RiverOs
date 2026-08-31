# RiverOs — OpenWrt minimizado para MikroTik hEX RB750Gr3

Capa base del sistema (SO): **NETEST / OpenWrt → RiverOs** (kernel básico mejorado).
Contiene SOLO el sistema: imagen ImageBuilder, scripts de red/arranque, configs.
El gestor ISP (binario + código) vive en el repo separado **Risp**.

```
┌─────────────────────────────────────────────┐
│ Risp (gestor ISP)        repo: avisonofgod/Risp │
│   risp :80 portal, :8081 admin               │
│   instala en /etc/risp + /etc/init.d/risp    │
├─────────────────────────────────────────────┤
│ RiverOs (ESTE REPO — capa SO)               │
│   kernel 6.12.94 mejorado (initramfs XZ,    │
│   DSA MT7530, netfilter, wireguard)         │
│   ImageBuilder 25.12.5 → riveros-*.bin      │
│   scripts: riveros-red, dropbear, rename    │
├─────────────────────────────────────────────┤
│ Bootloader RouterBOOT v6 (sysupgrade PLAIN) │
└─────────────────────────────────────────────┘
```

## Hardware

- hEX RB750Gr3, MT7621 (mipsel_24kc), 256MB RAM, 16MB flash NAND
- RouterBOOT 6.47.10 (v6 — sysupgrade PLAIN, NO -v7)
- Switch MT7530 (DSA): 5 puertos Gigabit + puerto CPU interno
- Detalle y verificación: `docs/hardware-rb750gr3.md`

## Identidad RiverOs

- hostname: riveros · console: **ether1 = eth0**, IP 192.168.5.1/24
- pass root: SOLO desarrollo (rbadmin2026) — **CAMBIAR en producción**
  (build con `PROD=1` falla si detecta la credencial por defecto)
- sin LuCI/uhttpd/rpcd · red manual sin netifd (S98riveros-red)

## Nombres de puertos (ethX neutro, nivel kernel)

| Nombre kernel | Puerto físico | Uso |
|---|---|---|
| eth0 | ether1 | Consola / acceso físico (192.168.5.1) |
| eth1..eth4 | ether2..ether5 | Libres (configurables por Risp) |
| sw0 | — | Puerto CPU del switch (interno, oculto) |

Rename en boot: `rename-ports` (START=08, antes de network START=20).
PITFALL: renombrar en vivo con netifd corriendo tira la IP — usar UCI+init,
y tener IP de respaldo (192.168.10.1/24) en otro puerto antes de tocar.

## Red manual (sin UCI/netifd)

- libuci/netifd/ucode = deps DURAS de base-files: NO purgables via apk; purgable: uci (CLI)
- Deshabilitados: network, firewall, odhcpd, uhttpd, rpcd, ucitrack, sysntpd, cron
  (whiteouts en overlay /etc/rc.d)
- Red gestionada por S98riveros-red (script manual ip, SIN netifd):
  renombra cpu port -> sw0, ether1 -> eth0, ip addr 192.168.5.1/24 dev eth0
- dropbear: script manual S95dropbear (sin UCI, key ed25519 en /etc/dropbear)

## Build del bin (ImageBuilder)

```sh
cd imagebuilder-25.12.5          # arbol ImageBuilder 25.12.5 (mt7621)
/path/RiverOs/imagebuilder/build.sh -p netest              # 52 paq
/path/RiverOs/imagebuilder/build.sh -p risp-radius         # 90 paq (+ppp pppoe radius)
FILES=<arbol backend risp> /path/RiverOs/imagebuilder/build.sh -p risp-radius-embebido
```

Salida: `imagebuilder/out/<perfil>.bin` + `SHA256SUMS` + `openwrt-commit.txt`.
Compat wrappers: `build-netest.sh`, `build-risp-radius.sh`, `build-risp-radius-embebido.sh`.
Bins históricos: `/root/netinstall-openwrt/backups/` (GOOD = riveros-GOOD-25.12.5.bin).

## Recuperación / rollback

- Binario funcional: /root/netinstall-openwrt/backups/riveros-GOOD-25.12.5.bin
- restore.sh: netboot initramfs 22.03.3 -> sube GOOD -> sysupgrade -n -> espera 192.168.5.1
- Loader dnsmasq: /root/netinstall-openwrt (dhcp-boot=openwrt-22.03.3-initramfs-kernel.bin)
- Procedimiento completo: `docs/recovery-netboot.md`

## Estructura repo

```
configs/          perfiles de build + overlay canonico + kernel config
  profiles/       netest.config, risp-radius.config, risp-radius-embedded.config
  files/          overlay: etc/{hostname,config/{network,system,dropbear},shadow}
  kernel/         mt7621-rb750gr3.config (PENDIENTE extraer .config real)
  uci/            configs UCI de referencia
package/riveros/  paquetes OpenWrt propios: riveros-red, riveros-dropbear, riveros-portnames
scripts/          init.d de RiverOs + checkout-openwrt.sh
imagebuilder/     build.sh (unificado) + verify.sh + compat wrappers
docs/             architecture, hardware, security, recovery, builds, release
overlay-backup/   snapshots del overlay
openwrt.lock      commit OpenWrt fijado (PENDIENTE de fijar)
VERSION LICENSE Makefile
```

## Relación con Risp

- Risp instala encima de esta base: risp (binario mipsel) en /etc/risp,
  /etc/init.d/risp (procd START=99), symlinks /home/rispm, static/ y templates/.
- El frontend Risp configura ethX (ip-addresses, mwan, vlans, bridges...) usando
  los nombres reales del kernel (eth0..eth4) — ver repo Risp.
