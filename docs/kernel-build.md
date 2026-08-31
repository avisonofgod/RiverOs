# RiverOs — Compilacion del kernel propio (desde fuente)

Objetivo: compilar el kernel 6.12.94 desde el codigo fuente en el arbol
OpenWrt completo (commit 4da53ef, v25.12.0), con la config real de RiverOs.
Orientacion: Duck.ai (2026-08-30, chats kernel-cero y fase2).

## Decision

Camino B (arbol OpenWrt completo) — legitimo "kernel propio desde fuente":
compilas el codigo, versionas config, anades parches, produces vmlinux/
modulos/DTB. NO es vanilla kernel.org (proyecto posterior), NO es Buildroot.

## Flujo (scripts/build-kernel.sh)

1. git clone openwrt + checkout 4da53ef (scripts/checkout-openwrt.sh)
2. ./scripts/feeds update -a && install -a
3. cp configs/profiles/rb750gr3.openwrt.config .config && make defconfig
   (simbolos: CONFIG_TARGET_ramips=y, CONFIG_TARGET_ramips_mt7621=y,
    CONFIG_TARGET_ramips_mt7621_DEVICE_mikrotik_rb750gr3=y)
4. make target/linux/prepare V=s
5. cp configs/kernel/mt7621-rb750gr3.config -> target/linux/ramips/mt7621/config-6.12
   (mecanismo canonico de OpenWrt; NO savedefconfig para reproduccion exacta)
6. make target/linux/compile V=s -j
7. make image PROFILE=mikrotik_rb750gr3 CONFIG_TARGET_ROOTFS_INITRAMFS=y V=s
   -> bin/targets/ramips/mt7621/*mikrotik_rb750gr3-initramfs-kernel.bin

## Initramfs netboot

- CONFIG_TARGET_ROOTFS_INITRAMFS=y (OpenWrt genera el cpio; NO tocar
  CONFIG_INITRAMFS_SOURCE)
- Kernel: CONFIG_BLK_DEV_INITRD=y, CONFIG_DEVTMPFS=y, CONFIG_DEVTMPFS_MOUNT=y
- RouterBOOT recibe el nombre por DHCP filename (dhcp-boot), no requiere
  renombrar a uImage/fitImage: riveros-mikrotik_rb750gr3-initramfs-kernel.bin
- Probar SIEMPRE en RAM (netboot) antes de tocar NAND

## Verificacion de version

- KERNEL_PATCHVER en include/kernel-version.mk del checkout DEBE ser 6.12.94
  (o adaptar config si difiere del IB 25.12.5)
- Prueba decisiva: diff configs/kernel/mt7621-rb750gr3.config vs
  build_dir/target-*/linux-ramips_mt7621/linux-*/.config (tras olddefconfig)

## Checklist

- [ ] openwrt.lock commit 4da53ef
- [ ] feeds instalados
- [ ] make defconfig sin errores de simbolos
- [ ] KERNEL_PATCHVER coincide con IB
- [ ] config-6.12 = .config real extraido
- [ ] target/linux/compile OK -> vmlinux/vmlinuz/DTB
- [ ] initramfs-kernel.bin generado (plain, NUNCA -v7)
- [ ] netboot probado en RAM antes de sysupgrade
