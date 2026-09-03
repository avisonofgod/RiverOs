#!/bin/bash
# build-rootfs-e2-2203.sh — arma el rootfs E2 via OpenWrt preinit sobre 22.03.3
# Uso: ./build-rootfs-e2-2203.sh <rootfs_dest> [openwrt_tree]
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEST="${1:-/tmp/rootfs-e2-2203}"
OPENWRT="${2:-/home/proyectos/openwrt-22.03.3}"

case "$DEST" in
    /*) ;;
    *) echo "ERROR: DEST debe ser una ruta absoluta (got: $DEST)"; exit 1 ;;
esac
[ "$DEST" = "/" ] && { echo "ERROR: DEST no puede ser /"; exit 1; }

SRC="$OPENWRT/build_dir/target-mipsel_24kc_musl/root-ramips"
[ -d "$SRC" ] || { echo "ERROR: no existe root-ramips en $SRC"; exit 1; }

rm -rf "$DEST"
mkdir -p "$DEST"/{bin,sbin,usr/bin,usr/sbin,etc/dropbear,etc/config,etc/udhcpc,lib/functions,lib/preinit,proc,sys,dev,tmp,run,var/run,var/log,root}

# binarios del rootfs base OpenWrt 22.03.3
cp "$SRC/bin/busybox" "$DEST/bin/" || { echo "ERROR: falta busybox en $SRC"; exit 1; }
cp "$SRC/usr/sbin/dropbear" "$DEST/usr/sbin/" || { echo "ERROR: falta dropbear en $SRC"; exit 1; }

# libs dinamicas musl requeridas por busybox + dropbear
for l in ld-musl-mipsel-sf.so.1 libc.so libgcc_s.so.1; do
  cp -a "$SRC/lib/$l" "$DEST/lib/" || { echo "ERROR: falta lib $l en $SRC"; exit 1; }
done

# /init y hooks del preinit OpenWrt, con el wrapper RiverOs E2
cp "$REPO/core/rootfs-riveros/init" "$DEST/init" || { echo "ERROR: falta init"; exit 1; }
chmod 0755 "$DEST/init"

cp "$SRC/etc/preinit" "$DEST/etc/preinit" || { echo "ERROR: falta etc/preinit"; exit 1; }
chmod 0755 "$DEST/etc/preinit"

cp "$SRC/lib/functions.sh" "$DEST/lib/functions.sh" || { echo "ERROR: falta lib/functions.sh"; exit 1; }
cp "$SRC/lib/functions/preinit.sh" "$DEST/lib/functions/preinit.sh" || { echo "ERROR: falta lib/functions/preinit.sh"; exit 1; }
cp "$SRC/lib/functions/system.sh" "$DEST/lib/functions/system.sh" || { echo "ERROR: falta lib/functions/system.sh"; exit 1; }

for f in 10_indicate_preinit 70_initramfs_test 99_red_manual; do
  cp "$REPO/core/rootfs-riveros/lib/preinit/$f" "$DEST/lib/preinit/$f" || {
    echo "ERROR: falta preinit $f"; exit 1;
  }
done
chmod 0755 "$DEST/lib/preinit/"*

# passwd/shadow/group del rootfs OpenWrt 22.03.3 (login root real)
cp "$REPO/core/rootfs-riveros/banner" "$DEST/etc/banner" 2>/dev/null || echo "WARN sin banner propietario"
cp "$SRC/etc/passwd" "$DEST/etc/passwd" || { echo "ERROR: falta passwd en $SRC"; exit 1; }
cp -a "$SRC/etc/shadow" "$DEST/etc/shadow" || { echo "ERROR: falta shadow en $SRC"; exit 1; }
cp "$SRC/etc/group" "$DEST/etc/group" || { echo "ERROR: falta group en $SRC"; exit 1; }

# script DHCP de RiverOs, compatible con busybox ifconfig
cp "$REPO/core/rootfs-riveros/udhcpc-default.script" "$DEST/etc/udhcpc/default.script" || {
  echo "ERROR: falta udhcpc-default.script"; exit 1; }
chmod 0755 "$DEST/etc/udhcpc/default.script"

# nodos estaticos initramfs requeridos por DEVTMPFS apagado
for f in "$REPO/core/rootfs-riveros/initramfs-nodes.txt" "$SRC/etc/udhcpc.user"; do
  [ -f "$f" ] || echo "WARN: $f no existe"
done

# applets busybox necesarios por el init E2 + preinit
cd "$DEST/bin"
for a in sh ash cat ls mkdir mknod mount umount sleep echo ifconfig brctl udhcpc grep cut sed ps kill reboot poweroff dmesg date route tr; do
  ln -sf busybox "$a" 2>/dev/null || true
done

# enlaces de compatibilidad
ln -sf /bin/busybox "$DEST/usr/bin/udhcpc" 2>/dev/null || true
ln -sf /bin/busybox "$DEST/sbin/brctl" 2>/dev/null || true
ln -sf /bin/busybox "$DEST/sbin/route" 2>/dev/null || true

# /dev requerido por init/preinit (ptmx/kmsg/cargs creados dinamicamente por /init)
mkdir -p "$DEST/dev" "$DEST/proc" "$DEST/sys" "$DEST/tmp" "$DEST/run" "$DEST/var/run" "$DEST/var/log"

# verificacion basica final
[ -x "$DEST/init" ] || { echo "ERROR: /init no ejecutable"; exit 1; }
[ -x "$DEST/etc/preinit" ] || { echo "ERROR: /etc/preinit no ejecutable"; exit 1; }
[ -x "$DEST/bin/busybox" ] || { echo "ERROR: busybox ausente"; exit 1; }

echo "rootfs E2 22.03.3: $(du -sh "$DEST" | cut -f1)"
