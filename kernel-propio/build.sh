#!/bin/bash
# build.sh — kernel RiverOs-kernel para MikroTik hEX (RB750Gr3)
# REESCRITO 2026-08: base = config de OpenWrt 25.12.5 (ramips/mt7621), el
# que SÍ arranca en este hardware. allnoconfig + subset manual ROMPIA el
# boot (faltaban MIPS_MT_SMP/MIPS_CM/timers -> panic antes del init).
# RiverOs = kernel Linux propio; NARA (zpot) = backend panel, repo separado.
#
# Requiere: toolchain mipsel-linux-gnu (CROSS), tar.xz del kernel en $KSRC
set -e
KVER=6.12.103
KSRC=linux-$KVER
TARBALL=$KSRC.tar.xz
URL=https://cdn.kernel.org/pub/linux/kernel/v6.x/$TARBALL
SHA256_EXPECTED=f143aaade8877ba5616e788b4482576db28481bcf557ef537f4fcc3938fc3176
CROSS=mipsel-linux-gnu-
DTB=arch/mips/boot/dts/ralink/mt7621_mikrotik_routerboard-750gr3.dtb
OUT=../naraos-vmlinux

[ -d "$KSRC" ] || {
    echo "==> descargando $URL"
    curl -sL -o "$TARBALL" "$URL"
    echo "$SHA256_EXPECTED  $TARBALL" | sha256sum -c - 2>/dev/null || \
        echo "WARN: checksum no verificado (actualizar SHA256_EXPECTED)"
    tar xJf "$TARBALL"
}

cd "$KSRC"

echo "==> base: config OpenWrt 25.12.5 ramips/mt7621"
cp ../config-6.12-mt7621 .config

# initramfs (rootfs embebido, xz) — OpenWrt no usa initramfs, esto es RiverOs
scripts/config --set-str INITRAMFS_SOURCE "$(cd "$(dirname "$0")/.." && pwd)/rootfs"
scripts/config --enable INITRAMFS_COMPRESSION_XZ
scripts/config --enable BLK_DEV_INITRD

# DTB appended al ELF (RouterBOOT carga ELF y lee el DTB del segmento LOAD)
scripts/config --disable MIPS_NO_APPENDED_DTB --enable MIPS_ELF_APPENDED_DTB --disable MIPS_RAW_APPENDED_DTB

# --- reducir tamano (netboot limite ~5.48MiB; config OpenWrt completo da 7.4MB) ---
# EXPERT hace visible KALLSYMS; el ULTIMO --disable KALLSYMS NO debe ir seguido
# de olddefconfig (lo revierte). QUITAR antes de KALLSYMS no sirve: make vmlinux
# corre syncconfig que lo revive si EXPERT=off.
scripts/config --enable EXPERT
scripts/config --disable KALLSYMS
# drivers no usados por RiverOs (inflaban el vmlinux)
scripts/config --disable INPUT --disable HWMON --disable PCI --disable I2C

make ARCH=mips CROSS_COMPILE=$CROSS olddefconfig >/dev/null 2>&1 || true
scripts/config --disable KALLSYMS

echo "==> build vmlinux (8 jobs)"
make ARCH=mips CROSS_COMPILE=$CROSS -j8 vmlinux >/dev/null 2>&1 || \
    make ARCH=mips CROSS_COMPILE=$CROSS vmlinux

echo "==> DTB + append al ELF (entry=LOAD, seccion .appended_dtb)"
make ARCH=mips CROSS_COMPILE=$CROSS mt7621_mikrotik_routerboard-750gr3.dtb
mipsel-linux-gnu-objcopy \
    --set-start=0x80b71000 \
    --update-section .appended_dtb="arch/mips/boot/dts/ralink/mt7621_mikrotik_routerboard-750gr3.dtb" \
    vmlinux "$OUT"
ls -la "$OUT"
echo "OK: $OUT ($(stat -c%s "$OUT") bytes)"
