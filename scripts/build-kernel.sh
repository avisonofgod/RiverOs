#!/bin/bash
# RiverOs build-kernel.sh — compila el kernel 6.12 desde fuente en el arbol
# OpenWrt completo (v25.12.0, openwrt.lock), con la config real de RiverOs.
#
# Flujo segun Duck.ai (fase 2b/3): feeds -> defconfig -> prepare ->
# kernel config-6.12 -> compile. Genera vmlinux/vmlinuz/DTB y luego
# initramfs-kernel.bin para netboot.
#
# Uso: ./build-kernel.sh [openwrt_dir]   (default: ../openwrt)
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENWRT="${1:-$REPO/../openwrt}"
LOCK="$REPO/openwrt.lock"

[ -d "$OPENWRT/.git" ] || { echo "ERROR: $OPENWRT no es un arbol OpenWrt (usa scripts/checkout-openwrt.sh)" >&2; exit 1; }

COMMIT="$(grep -E '^OPENWRT_COMMIT=' "$LOCK" | cut -d= -f2)"
cd "$OPENWRT"

echo "== 1. feeds =="
./scripts/feeds update -a
./scripts/feeds install -a

echo "== 2. .config de target (RiverOs netest) =="
cp "$REPO/configs/profiles/rb750gr3.openwrt.config" .config
make defconfig

echo "== 3. KERNEL_PATCHVER (debe coincidir con 6.12.94 del IB) =="
grep -nE 'KERNEL_PATCHVER|LINUX_VERSION' include/kernel-version.mk target/linux/ramips/Makefile 2>/dev/null || true

echo "== 4. inyectar kernel config real ANTES de prepare -> config-6.12 =="
cp "$REPO/configs/kernel/mt7621-rb750gr3.config" target/linux/ramips/mt7621/config-6.12

echo "== 5. target/linux/prepare (aplica config-6.12 + parches) =="
make target/linux/prepare V=s 2>&1 | tee /tmp/openwrt-linux-prepare.log | tail -5

echo "== 5b. PRUEBA DECISIVA: diff config vs build_dir/.config =="
KDIR="$(find "$PWD/build_dir" -path '*/linux-6.12.94' -type d | head -n1)"
if [ -n "$KDIR" ] && [ -f "$KDIR/.config" ]; then
  if diff -u "$REPO/configs/kernel/mt7621-rb750gr3.config" "$KDIR/.config" > /tmp/kernel-config.diff; then
    echo "OK: config EXACTA (sin diferencias)"
  else
    echo "WARN: diferencias en config (ver /tmp/kernel-config.diff, primeras 40):"
    head -40 /tmp/kernel-config.diff || true
  fi
else
  echo "WARN: no encontre $KDIR/.config — revisar prepare"
fi

echo "== 6. kernel compile =="
make target/linux/compile V=s -j"$(nproc)"

echo "== 7. artefactos =="
find build_dir bin/targets -type f \( -name 'vmlinux*' -o -name '*dtb*' \) -print 2>/dev/null | head -20

echo "== 8. imagen initramfs netboot =="
make image PROFILE="mikrotik_routerboard-750gr3" CONFIG_TARGET_ROOTFS_INITRAMFS=y V=s 2>&1 | tail -8
ls -lh bin/targets/ramips/mt7621/*mikrotik_routerboard-750gr3-initramfs-kernel.bin 2>/dev/null || echo "WARN: no initramfs-kernel.bin (revisar target/linux/ramips/image/mt7621.mk)"

echo "== 9. verificar version del kernel compilado =="
strings "$(find build_dir -name vmlinuz -path '*ramips*' -print -quit 2>/dev/null)" 2>/dev/null | grep -m1 'Linux version' || true
echo "build-kernel.sh: OK"
