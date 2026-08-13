# RiverOs-kernel — Kernel propio recodificado para MikroTik hEX (RB750Gr3)

OS custom minimal para el hEX: kernel Linux propio (mainline 6.12.x) + busybox/
dropbear estáticos + init estilo RiverOs. Sustituye a OpenWrt como capa SO;
NARA (backend ISP Rust) se monta encima opcionalmente (fase 2).
Todo por terminal; API NARA expuesta para frontend externo nativo.

## Hardware
- SoC: MediaTek MT7621 (MIPS 1004Kc, mipsel, 880MHz, 256MB RAM, 16MB NAND)
- Board: MikroTik RouterBOARD hEX RB750Gr3 (rev r4)
- Bootloader: RouterBOOT 6.47.10 (v6 — compatible con kernels ELF)
- Puertos (DSA): ether1=wan (gmac1), ether2-5=lan2-5 (switch mt7530)
- Flash NAND: particiones RouterBoot/bootloader1/hard_config/bootloader2/
  soft_config/bios/firmware(kernel+rootfs+rootfs_data)

## Arquitectura del OS
- kernel: Linux 6.12.x LTS (mainline) configurado para MT7621
- userspace: busybox (estático) + dropbear (estático) + NARA (Rust dinámico musl, fase 2)
- init: script shell mínimo estilo RiverOs (sin systemd, sin procd, sin OpenRC)
  - rename puertos DSA -> ethX (cpu sw0, ether1=eth0..ether5=eth4)
  - consola eth0 = 192.168.99.1/24 (whitelist NARA 8081)
  - dropbear :22 password (rbadmin2026, hash $5$riveros01)
  - hook NARA: si /etc/nara/zpot existe lo arranca (:80 portal, :8081 admin)
- sin gestor de paquetes: binarios estáticos (musl), reproducibles

## Repos/componentes
- kernel: kernel.org linux-6.12.103 (descargado por build.sh, NO commiteado)
- config: config-6.12-mt7621 (base: OpenWrt config-6.12 de ramips/mt7621, GPL)
- dts: mainline arch/mips/boot/dts/ralink/mt7621_mikrotik_routerboard-750gr3.dts
- nara: /root/naram (cross-compile mipsel-unknown-linux-musl)

## Fases
1. [x] Toolchain mipsel: zig cc (linker musl) + gcc-mipsel-linux-gnu (kernel)
2. [x] NARA cross-compilado para mipsel (binario estatico)
3. [ ] Kernel 6.12.103 mt7621: config + DTS + build (vmlinux ELF)
4. [ ] Rootfs RAM: busybox + dropbear + NARA + init (netboot TFTP)
5. [ ] Flash NAND: driver NAND mt7621 + UBI + layout (persistencia)
6. [ ] Servicios: nara.init (arranque + respawn), red, firewall nftables

## Build
    ./build.sh          # descarga kernel, aplica config OpenWrt 25.12.5 (ramips/mt7621),
                        #   cross-compila (MIPS_MT_SMP/MIPS_CM/GIC — allnoconfig manual NO bootea)
    ./build-rootfs.sh   # ensambla initramfs/rootfs con busybox/dropbear/nara
    ./flash.sh          # netboot TFTP (dev) o escritura NAND (prod)
