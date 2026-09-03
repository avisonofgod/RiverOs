# ARBOL.md — Contrato del arbol OpenWrt para RiverOs (v33)

Para RECREAR el v33 funcional (sha 6c8492de) se necesita el arbol OpenWrt
en un estado EXACTO. Este archivo es ese contrato. El arbol completo NO vive
en el repo (varios GB): se clona y se deja en el estado documentado aqui.

## Estado del arbol (verificado 2026-09-03)

- Remote: https://github.com/openwrt/openwrt.git
- COMMIT: 6bad5f205030b2c2636491f4eaf36c22f14a5d9b
  ("kernel: bump 6.12 to 6.12.94") — el que produce kernel 6.12.94
- Rama local del repo de trabajo: riveros-openwrt-6.1 (apunta a ese commit)
- Ruta local tipica: /home/proyectos/openwrt (o ../openwrt relativo al repo)
- NO usar 4da53efc2f (v25.12.0, kernel 6.12 sin bump) para v33

## Modificaciones locales del arbol (fuera del commit)

1. target/linux/ramips/image/mt7621.mk — Device/MikroTik:
   DEVICE_PACKAGES := kmod-usb3 -uboot-envtools  ->  -kmod-usb3 -uboot-envtools
   (quita kmod-usb3 del device; aplicado 2026-08-31, presente en el v33)

## Que copia build-kernel.sh al arbol en cada build (no versionar)

- .config (target config del perfil) + make defconfig
- target/linux/ramips/mt7621/config-6.12 (kernel config del perfil)
- target/linux/ramips/patches-6.12/0001-*.patch y 0935-*.patch (del repo)
- target/linux/ramips/mt7621/base-files/ (files del device: network,
  preinit 99_red_manual.sh, init.d rename-ports/riveros-red/dropbear-manual,
  banner, os-release, device_info, shadow, config/)

## Recrear el arbol desde cero

1. git clone https://github.com/openwrt/openwrt.git (o scripts/checkout-riveros.sh)
2. git checkout 6bad5f205030b2c2636491f4eaf36c22f14a5d9b
3. Aplicar el diff de mt7621.mk (ver abajo)
4. ./scripts/feeds update -a && ./scripts/feeds install -a
5. Ejecutar core/scripts/build-kernel.sh con los configs del perfil (ver README.md)

Patch mt7621.mk:
--- a/target/linux/ramips/image/mt7621.mk
+++ b/target/linux/ramips/image/mt7621.mk
@@ -2227,7 +2227,7 @@ define Device/MikroTik
   DEVICE_VENDOR := MikroTik
   IMAGE_SIZE := 16128k
-  DEVICE_PACKAGES := kmod-usb3 -uboot-envtools
+  DEVICE_PACKAGES := -kmod-usb3 -uboot-envtools
   KERNEL_NAME := vmlinuz
   KERNEL := kernel-bin | append-dtb-elf
