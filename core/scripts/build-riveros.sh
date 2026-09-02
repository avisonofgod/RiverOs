#!/bin/bash
# build-riveros.sh — E1: kernel make DIRECTO con spec capturada de OpenWrt.
# NO toca .config del arbol (generado por OpenWrt); solo re-ejecuta el make
# kernel con el entorno exacto y empaqueta ELF netboot (kernel-bin|append-dtb-elf).
#
# Uso: ./build-riveros.sh [OPENWRT_TREE]   (default: /home/proyectos/openwrt)
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OPENWRT="${1:-/home/proyectos/openwrt}"
K="$OPENWRT/build_dir/target-mipsel_24kc_musl/linux-ramips_mt7621/linux-6.12.94"
STAGING="$OPENWRT/staging_dir"
TC="$(ls -d "$STAGING"/toolchain-mipsel_24kc* | head -1)"
CROSS="$TC/bin/mipsel-openwrt-linux-musl-"
DTB="$OPENWRT/build_dir/target-mipsel_24kc_musl/linux-ramips_mt7621/image-mt7621_mikrotik_routerboard-750gr3.dtb"
OBJ="$CROSS"objcopy
JOBS="$(nproc)"

[ -f "$K/.config" ] || { echo "ERROR: no .config (correr build-kernel.sh primero)" >&2; exit 1; }
[ -f "$DTB" ] || { echo "ERROR: no DTB" >&2; exit 1; }

# spec exacta capturada de OpenWrt (include/kernel.mk + V=99 dry-run, 2026-09-02)
KMAKE_FLAGS=(KCFLAGS="-fmacro-prefix-map=$OPENWRT/build_dir/target-mipsel_24kc_musl=target-mipsel_24kc_musl -fno-caller-saves"
  HOSTCFLAGS="-O2 -I$STAGING/host/include -Wall -Wmissing-prototypes -Wstrict-prototypes"
  CROSS_COMPILE="$CROSS" ARCH="mips" KBUILD_HAVE_NLS=no
  KBUILD_BUILD_USER="" KBUILD_BUILD_HOST=""
  KBUILD_BUILD_TIMESTAMP="Wed Jun 24 23:37:12 2026"
  KBUILD_BUILD_VERSION="0" KBUILD_HOSTLDFLAGS="-L$STAGING/host/lib"
  CONFIG_SHELL="bash" V='' cmd_syscalls=
  CC="${CROSS}gcc" KERNELRELEASE="6.12.94")

echo "== E1.1 SetInitramfs (replica Kernel/SetInitramfs) =="
# OpenWrt deja .config SIN initramfs tras compile normal (SetNoInitramfs);
# install hace SetInitramfs: apunta INITRAMFS_SOURCE al rootfs + borra cpio.
RROOT="$OPENWRT/build_dir/target-mipsel_24kc_musl/root-ramips"
INITRAMFS_EXTRA="$OPENWRT/target/linux/generic/image/initramfs-base-files.txt"
[ -d "$RROOT" ] || { echo "ERROR: no root-ramips (correr build-kernel.sh)" >&2; exit 1; }
cp "$K/.config" "$K/.config.old"
grep -v -e INITRAMFS -e CONFIG_RD_ -e CONFIG_BLK_DEV_INITRD "$K/.config.old" > "$K/.config"
echo 'CONFIG_BLK_DEV_INITRD=y' >> "$K/.config"
echo "CONFIG_INITRAMFS_SOURCE=\"$RROOT $INITRAMFS_EXTRA\"" >> "$K/.config"
echo "# CONFIG_INITRAMFS_PRESERVE_MTIME is not set" >> "$K/.config"
echo "CONFIG_INITRAMFS_ROOT_UID=0" >> "$K/.config"
echo "CONFIG_INITRAMFS_ROOT_GID=0" >> "$K/.config"
echo "CONFIG_INITRAMFS_COMPRESSION_LZMA=y" >> "$K/.config"
echo "# CONFIG_INITRAMFS_COMPRESSION_GZIP is not set" >> "$K/.config"
echo "# CONFIG_INITRAMFS_COMPRESSION_BZIP2 is not set" >> "$K/.config"
echo "# CONFIG_INITRAMFS_COMPRESSION_XZ is not set" >> "$K/.config"
echo "# CONFIG_INITRAMFS_COMPRESSION_LZO is not set" >> "$K/.config"
echo "# CONFIG_INITRAMFS_COMPRESSION_LZ4 is not set" >> "$K/.config"
echo "# CONFIG_INITRAMFS_COMPRESSION_ZSTD is not set" >> "$K/.config"
echo 'CONFIG_RD_LZMA=y' >> "$K/.config"
rm -f "$K/.config.old" "$K/usr/initramfs_data.cpio" "$K/usr/initramfs_data.cpio"*
# reproducibilidad: OpenWrt normaliza mtimes del rootfs con SOURCE_DATE_EPOCH
# (find -execdir touch -hcd) antes de generar el cpio — replica exacta
find "$RROOT" -mindepth 1 -execdir touch -hcd "@${SOURCE_DATE_EPOCH:-1782344232}" {} + 2>/dev/null || true

echo "== E1.2 kernel make directo (vmlinux vmlinuz, initramfs embebido) =="
export STAGING_DIR="$STAGING/target-mipsel_24kc_musl"
export PATH="$TC/bin:$STAGING/host/bin:$PATH"
make -C "$K" "${KMAKE_FLAGS[@]}" olddefconfig 2>&1 | tail -2
make -C "$K" "${KMAKE_FLAGS[@]}" vmlinux vmlinuz 2>&1 | tail -6

echo "== E1.3 ELF netboot (kernel-bin | append-dtb-elf) =="
OUT="$REPO/core/artifacts/riveros-6.12.94-e1-initramfs-kernel.bin"
cp "$K/vmlinuz" "$OUT"
"$OBJ" --set-section-flags=.appended_dtb=alloc,contents \
    --update-section ".appended_dtb=$DTB" "$OUT"
SHA="$(sha256sum "$OUT" | cut -d' ' -f1)"

echo "== E1.4 gate estatico =="
SIZE="$(stat -c %s "$OUT")"
ENTRY="$(readelf -h "$OUT" | awk '/Entry point/{print $4}')"
HAS_DTB="$(readelf -S "$OUT" | grep -c appended_dtb || true)"
MAX=$((0x6aa000))
FAIL=0
[ "$ENTRY" = "0x80b71000" ] || { echo "FAIL entry $ENTRY"; FAIL=1; }
[ "$HAS_DTB" -ge 1 ] || { echo "FAIL sin appended_dtb"; FAIL=1; }
[ "$SIZE" -lt "$MAX" ] || { echo "FAIL size $SIZE >= $MAX"; FAIL=1; }
[ "$FAIL" -eq 0 ] || { echo "build-riveros E1: FALLIDO"; exit 1; }
echo "PASS: entry=$ENTRY dtb=$HAS_DTB size=$SIZE sha=${SHA:0:8}"

echo "== E1.5 comparar con bin OpenWrt =="
OW_BIN="$OPENWRT/bin/targets/ramips/mt7621/riveros-ramips-mt7621-mikrotik_routerboard-750gr3-initramfs-kernel.bin"
if [ -f "$OW_BIN" ]; then
  OW_SHA="$(sha256sum "$OW_BIN" | cut -d' ' -f1)"
  if [ "$SHA" = "$OW_SHA" ]; then
    echo "IDENTICO a OpenWrt bin ($SHA) — pipeline E1 valido"
  else
    echo "DIFERENTE: riveros=$SHA openwrt=$OW_SHA (investigar)"
  fi
fi
echo "artefacto: $OUT"
echo "build-riveros.sh E1: OK"
