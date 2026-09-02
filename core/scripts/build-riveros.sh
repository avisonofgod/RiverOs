#!/bin/bash
# build-riveros.sh — E1: pipeline kernel PROPIO (sin OpenWrt image system)
# kernel make directo -> vmlinuz -> objcopy .appended_dtb -> ELF netboot.
# Replica exacta de: KERNEL := kernel-bin | append-dtb-elf (Device/MikroTik).
#
# Uso: ./build-riveros.sh [OPENWRT_TREE]   (default: /home/proyectos/openwrt)
# Requiere arbol ya preparado por build-kernel.sh (config kernel + initramfs cpio).
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OPENWRT="${1:-/home/proyectos/openwrt}"
K="$OPENWRT/build_dir/target-mipsel_24kc_musl/linux-ramips_mt7621/linux-6.12.94"
STAGING="$OPENWRT/staging_dir"
OBJ="$(ls "$STAGING"/toolchain-mipsel_24kc*/bin/mipsel-openwrt-linux-musl-objcopy 2>/dev/null | head -1)"
DTB_DIR="$OPENWRT/build_dir/target-mipsel_24kc_musl/linux-ramips_mt7621"
DTB="$DTB_DIR/image-mt7621_mikrotik_routerboard-750gr3.dtb"
CROSS_DIR="$(dirname "$OBJ")"
CROSS_PREFIX="mipsel-openwrt-linux-musl-"
JOBS="$(nproc)"

[ -f "$K/vmlinuz" ] || { echo "ERROR: no vmlinuz en $K (correr build-kernel.sh primero)" >&2; exit 1; }
[ -f "$DTB" ] || { echo "ERROR: no DTB $DTB" >&2; exit 1; }

echo "== E1.1 config kernel del repo -> arbol =="
cp "$REPO/core/configs/kernel/mt7621-rb750gr3.config" "$K/.config"
make -C "$K" ARCH=mips CROSS_COMPILE="$CROSS_DIR/$CROSS_PREFIX" olddefconfig 2>&1 | tail -2

echo "== E1.2 kernel compile directo (vmlinuz) =="
make -C "$K" ARCH=mips CROSS_COMPILE="$CROSS_DIR/$CROSS_PREFIX" -j"$JOBS" vmlinuz 2>&1 | tail -5

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
grep -q "^CONFIG_MT7621_WDT=y" "$K/.config" || { echo "FAIL WDT"; FAIL=1; }
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
