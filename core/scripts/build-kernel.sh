#!/bin/bash
# RiverOs build-kernel.sh — compila el kernel 6.12 desde el arbol base
# usando SOLO los archivos del repositorio RiverOs (core + targets + patches).
#
# Flujo (RB750Gr3, netboot): copia configs/parches/files del repo al arbol ->
# prepare -> compile -> install -> initramfs-kernel.bin.
#
# Uso: ./build-kernel.sh [arbol_dir]   (default: ../openwrt)
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"   # raiz del repo
OPENWRT="${1:-$REPO/../openwrt}"

[ -d "$OPENWRT/.git" ] || { echo "ERROR: $OPENWRT no es un arbol RiverOs (usa scripts/checkout-riveros.sh)" >&2; exit 1; }

cd "$OPENWRT"
export FORCE_UNSAFE_CONFIGURE=1

echo "== 1. archivos del repo -> arbol =="
# 1a. .config del target (paquetes del initramfs)
cp "$REPO/core/configs/target-rb750gr3.config" .config
# 1b. kernel config (fuente primaria)
cp "$REPO/core/configs/kernel/mt7621-rb750gr3.config" target/linux/ramips/mt7621/config-6.12
# 1c. parches del kernel (limpiar viejos del arbol para evitar duplicados)
mkdir -p target/linux/ramips/patches-6.12
rm -f target/linux/ramips/patches-6.12/*load-y* target/linux/ramips/patches-6.12/*mt7530* target/linux/ramips/patches-6.12/935-* target/linux/ramips/patches-6.12/936-*
cp "$REPO"/patches/kernel/*.patch target/linux/ramips/patches-6.12/
# 1d. files del device (preinit, network, init.d; shadow se genera en build)
mkdir -p target/linux/ramips/mt7621/base-files
cp -r "$REPO"/targets/mips/devices/mikrotik-rb750gr3/files/* target/linux/ramips/mt7621/base-files/
chmod 0755 target/linux/ramips/mt7621/base-files/lib/preinit/99_red_manual.sh 2>/dev/null || true
chmod 0755 target/linux/ramips/mt7621/base-files/etc/init.d/* 2>/dev/null || true

echo "== 2. target/linux/prepare (config-6.12 + parches) =="
make target/linux/prepare V=s 2>&1 | tee /tmp/riveros-linux-prepare.log | tail -5

echo "== 3. kernel compile =="
make target/linux/compile V=s -j"$(nproc)" 2>&1 | tee /tmp/riveros-linux-compile.log | tail -5

echo "== 4. imagen initramfs (netboot) =="
make target/linux/install V=s -j"$(nproc)" 2>&1 | tail -5

IMG="$(ls -t bin/targets/ramips/mt7621/riveros-*initramfs-kernel.bin 2>/dev/null | head -n1)"
if [ -n "$IMG" ]; then
  echo "== 5. artefacto =="
  ls -lh "$IMG"
  readelf -h "$IMG" | grep Entry || true
else
  echo "WARN: no initramfs-kernel.bin (revisar target/linux/ramips/image/mt7621.mk)"
fi

echo "build-kernel.sh: OK"
