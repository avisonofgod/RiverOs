#!/bin/bash
# RiverOs build-kernel.sh — compila el kernel 6.12 desde el arbol base
#
# Flujo validado (RB750Gr3, netboot): config-6.12 del repo -> prepare ->
# compile -> install -> initramfs-kernel.bin.
#
# Uso: ./build-kernel.sh [arbol_dir]   (default: ../openwrt)
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENWRT="${1:-$REPO/../openwrt}"

[ -d "$OPENWRT/.git" ] || { echo "ERROR: $OPENWRT no es un arbol RiverOs (usa scripts/checkout-riveros.sh)" >&2; exit 1; }

cd "$OPENWRT"
export FORCE_UNSAFE_CONFIGURE=1

echo "== 1. kernel config (fuente primaria del repo) =="
cp "$REPO/configs/kernel/mt7621-rb750gr3.config" target/linux/ramips/mt7621/config-6.12

echo "== 2. target/linux/prepare (aplica config-6.12 + parches) =="
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
