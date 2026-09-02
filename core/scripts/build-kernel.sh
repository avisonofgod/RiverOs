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
# re-empaquetar initramfs con files/ del subtarget (base-files): package/install
# reinstala los archivos en el rootfs; limpiar vmlinux-initramfs fuerza rebuild del cpio
make package/install V=s -j"$(nproc)" 2>&1 | tail -3
# rebrand post-install: banner/os-release/device_info los genera el PAQUETE base-files
# y pisan al subtarget; sobrescribir en root-ramips (os-release = symlink a usr/lib/os-release)
RROOT="$OPENWRT/build_dir/target-mipsel_24kc_musl/root-ramips"
[ -f "$REPO/targets/mips/devices/mikrotik-rb750gr3/files/etc/banner" ] && cp "$REPO/targets/mips/devices/mikrotik-rb750gr3/files/etc/banner" "$RROOT/etc/banner"
[ -f "$REPO/targets/mips/devices/mikrotik-rb750gr3/files/etc/device_info" ] && cp "$REPO/targets/mips/devices/mikrotik-rb750gr3/files/etc/device_info" "$RROOT/etc/device_info"
[ -f "$REPO/targets/mips/devices/mikrotik-rb750gr3/files/etc/os-release" ] && cp "$REPO/targets/mips/devices/mikrotik-rb750gr3/files/etc/os-release" "$RROOT/usr/lib/os-release"
[ -f "$REPO/targets/mips/devices/mikrotik-rb750gr3/files/etc/config/system" ] && cp "$REPO/targets/mips/devices/mikrotik-rb750gr3/files/etc/config/system" "$RROOT/etc/config/system"
rm -f "$OPENWRT/build_dir/target-mipsel_24kc_musl/linux-ramips_mt7621/linux-6.12.94/usr/initramfs_data.cpio" \
      "$OPENWRT/build_dir/target-mipsel_24kc_musl/linux-ramips_mt7621/linux-6.12.94/usr/initramfs_data.o"
make target/linux/install V=s -j"$(nproc)" 2>&1 | tail -5

IMG="$(ls -t bin/targets/ramips/mt7621/riveros-*initramfs-kernel.bin 2>/dev/null | head -n1)"
if [ -z "$IMG" ]; then
  echo "ERROR: no initramfs-kernel.bin (revisar target/linux/ramips/image/mt7621.mk)" >&2
  exit 1
fi

echo "== 5. artefacto =="
ls -lh "$IMG"

echo "== 6. revision estatica (PASS gate) =="
SIZE="$(stat -c %s "$IMG")"
ENTRY="$(readelf -h "$IMG" | awk '/Entry point/{print $4}')"
HAS_DTB="$(readelf -S "$IMG" | grep -c appended_dtb || true)"
SHA="$(sha256sum "$IMG" | cut -d' ' -f1)"
MAX=$((0x6aa000))
FAIL=0
[ "$ENTRY" = "0x80b71000" ] || { echo "FAIL: entry $ENTRY (esperado 0x80b71000)"; FAIL=1; }
[ "$HAS_DTB" -ge 1 ] || { echo "FAIL: sin seccion .appended_dtb"; FAIL=1; }
[ "$SIZE" -lt "$MAX" ] || { echo "FAIL: tamano $SIZE >= $MAX (6.66MiB)"; FAIL=1; }
grep -q "^CONFIG_MT7621_WDT=y" target/linux/ramips/mt7621/config-6.12 || { echo "FAIL: MT7621_WDT no esta en y"; FAIL=1; }
[ "$FAIL" -eq 0 ] || { echo "build-kernel.sh: REVISION FALLIDA, no se sirve a pkg"; exit 1; }
echo "PASS: entry=$ENTRY dtb=$HAS_DTB size=$SIZE max=$MAX sha=$SHA"

echo "== 7. servir a pkg (netboot listo) =="
PKG_DIR="${PKG_DIR:-/root/netinstall-openwrt/pkg}"
[ -d "$PKG_DIR" ] || { echo "ERROR: $PKG_DIR no existe"; exit 1; }
rm -f "$PKG_DIR"/*.bin "$PKG_DIR"/*.sha256 2>/dev/null || true
cp "$IMG" "$PKG_DIR/riveros-6.12.94-initramfs-kernel.bin"
sha256sum "$PKG_DIR/riveros-6.12.94-initramfs-kernel.bin" > "$PKG_DIR/riveros-6.12.94-initramfs-kernel.bin.sha256"
ls -lh "$PKG_DIR/"
echo "NETBOOT LISTO: pkg/riveros-6.12.94-initramfs-kernel.bin sha=$SHA"
echo "-> reiniciar loader (loader-riveros.sh) para servir el bin fresco"

echo "== 8. manifest BUILD.json =="
CFG_SHA="$(sha256sum "$REPO/core/configs/kernel/mt7621-rb750gr3.config" | cut -d' ' -f1)"
CPIO="$OPENWRT/build_dir/target-mipsel_24kc_musl/linux-ramips_mt7621/linux-6.12.94/usr/initramfs_data.cpio"
CPIO_FILES="$(cpio -it < "$CPIO" 2>/dev/null | wc -l)"
CPIO_APPS="$(cpio -it < "$CPIO" 2>/dev/null | grep -cE '^sbin/|^usr/sbin/' || true)"
PKG_LIST="$(grep -oE '^CONFIG_DEFAULT_[a-z0-9-]+=y' "$REPO/core/configs/target-rb750gr3.config" | sed 's/CONFIG_DEFAULT_//;s/=y//' | tr '\n' ' ')"
TC_VER="$(ls "$OPENWRT/staging_dir/toolchain-mipsel_24kc"*/ 2>/dev/null | head -1)"
OUT="$REPO/core/artifacts/BUILD-latest.json"
mkdir -p "$REPO/core/artifacts"
cat > "$OUT" <<EOF
{
  "version": "${SHA:0:8}",
  "fecha": "$(date -Is)",
  "kernel": "6.12.94",
  "bin": "$IMG",
  "bin_sha256": "$SHA",
  "bin_bytes": "$SIZE",
  "config_sha256": "$CFG_SHA",
  "symbols": {"y": $(grep -cE '^CONFIG_[A-Za-z0-9_]+=y$' "$REPO/core/configs/kernel/mt7621-rb750gr3.config"), "m": $(grep -cE '^CONFIG_[A-Za-z0-9_]+=m$' "$REPO/core/configs/kernel/mt7621-rb750gr3.config")},
  "initramfs_cpio_files": $CPIO_FILES,
  "initramfs_apps": $CPIO_APPS,
  "target_packages_default": "$PKG_LIST",
  "toolchain": "$TC_VER",
  "entry": "$ENTRY",
  "max_bytes": $MAX
}
EOF
cp "$OUT" "$REPO/core/artifacts/BUILD-$SHA.json"
echo "manifest: $OUT ($(stat -c %s "$OUT") B)"

echo "build-kernel.sh: OK"
