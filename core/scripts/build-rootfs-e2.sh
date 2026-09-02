#!/bin/bash
# build-rootfs-e2.sh — arma rootfs RiverOs E2 (sin procd/netifd/uci/apk)
# Uso: ./build-rootfs-e2.sh <rootfs_dest> [openwrt_tree]
set -Eeuo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEST="${1:-/tmp/rootfs-e2}"
OPENWRT="${2:-/home/proyectos/openwrt}"
SRC="$OPENWRT/build_dir/target-mipsel_24kc_musl/root-ramips"

[ -d "$SRC" ] || { echo "ERROR: no root-ramips en $SRC"; exit 1; }
rm -rf "$DEST"
mkdir -p "$DEST"/{bin,sbin,usr/sbin,etc/dropbear,etc/config,lib,proc,sys,dev,tmp,var/run,var/log,root}

# binarios (ya compilados por toolchain RiverOs/OpenWrt — GPL, mismos que redistribuimos)
cp "$SRC/bin/busybox" "$DEST/bin/"
cp "$SRC/usr/sbin/dropbear" "$DEST/usr/sbin/"
cp "$SRC/usr/sbin/brctl" "$DEST/usr/sbin/brctl" 2>/dev/null || echo "WARN sin brctl"
cp "$SRC/sbin/ip" "$DEST/sbin/ip" 2>/dev/null || echo "WARN sin ip"

# libs dinamicas (musl)
for l in ld-musl-mipsel-sf.so.1 libc.so libgcc_s.so.1; do
  cp -a "$SRC/lib/$l" "$DEST/lib/" 2>/dev/null || echo "WARN lib $l no encontrada"
done

# nuestro /init
cp "$REPO/core/rootfs-riveros/init" "$DEST/init"
chmod 0755 "$DEST/init"

# config minima: banner propio RiverOs + passwd/shadow/group REALES del rootfs
# (login root = mismo que netboot v33 usa via .env — verificado SSH)
cp "$REPO/core/rootfs-riveros/banner" "$DEST/etc/banner" 2>/dev/null || echo "WARN sin banner"
cp "$SRC/etc/passwd" "$DEST/etc/passwd" 2>/dev/null || echo "WARN sin passwd real"
cp -a "$SRC/etc/shadow" "$DEST/etc/shadow" 2>/dev/null || echo "WARN sin shadow real"
cp "$SRC/etc/group" "$DEST/etc/group" 2>/dev/null || echo "WARN sin group real"

# applets busybox esenciales (symlinks)
cd "$DEST/bin"
for a in sh ash cat ls mkdir mknod mount umount sleep echo ifconfig brctl grep cut sed ps kill reboot poweroff dmesg; do
  ln -sf busybox "$a"
done

echo "rootfs E2: $(du -sh "$DEST" | cut -f1) — archivos: $(find "$DEST" -type f | wc -l)"
