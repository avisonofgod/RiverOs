#!/bin/bash
# build-riveros-2203.sh — E2 kernel directo sobre OpenWrt 22.03.3
# Uso: ./build-riveros-2203.sh [OPENWRT_TREE] [ROOTFS_DIR] [NODES_FILE]
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OPENWRT="${1:-/home/proyectos/openwrt-22.03.3}"
ROOTFS_SRC="${2:-$OPENWRT/build_dir/target-mipsel_24kc_musl/root-ramips}"
NODES_FILE="${3:-$REPO/core/rootfs-riveros/initramfs-nodes.txt}"

case "$ROOTFS_SRC" in
  /*) ;;
  *) ROOTFS_SRC="$REPO/$ROOTFS_SRC" ;;
esac
case "$NODES_FILE" in
  /*) ;;
  *) NODES_FILE="$REPO/$NODES_FILE" ;;
esac

K="$OPENWRT/build_dir/target-mipsel_24kc_musl/linux-ramips_mt7621/linux-5.10.161"
STAGING="$OPENWRT/staging_dir"
TC="$(ls -d "$STAGING"/toolchain-mipsel_24kc* 2>/dev/null | head -1)"
[ -n "$TC" ] || { echo "ERROR: toolchain 22.03.3 no encontrado en $STAGING"; exit 1; }
CROSS="$TC/bin/mipsel-openwrt-linux-musl-"
DTB="$OPENWRT/build_dir/target-mipsel_24kc_musl/linux-ramips_mt7621/image-mt7621_mikrotik_routerboard-750gr3.dtb"
OBJ="$CROSS"objcopy
JOBS="$(nproc)"

[ -f "$K/.config.set" ] || { echo "ERROR: no existe $K/.config.set"; exit 1; }
[ -f "$DTB" ] || { echo "ERROR: no existe DTB $DTB"; exit 1; }
[ -d "$ROOTFS_SRC" ] || { echo "ERROR: no existe rootfs $ROOTFS_SRC"; exit 1; }
[ -f "$NODES_FILE" ] || { echo "ERROR: no existe nodes file $NODES_FILE"; exit 1; }

# Usamos la config de kernel del arbol 22.03.3; preservamos .config.set para reproducibilidad.
cp "$K/.config.set" "$K/.config"

# Especificacion aproximada del build del kernel OpenWrt 22.03.3 para mt7621.
KMAKE_FLAGS=(
  KCFLAGS="-fmacro-prefix-map=$OPENWRT/build_dir/target-mipsel_24kc_musl=target-mipsel_24kc_musl -fno-caller-saves"
  HOSTCFLAGS="-O2 -I$STAGING/host/include -Wall -Wmissing-prototypes -Wstrict-prototypes"
  CROSS_COMPILE="$CROSS" ARCH="mips" KBUILD_HAVE_NLS=no
  KBUILD_BUILD_USER="" KBUILD_BUILD_HOST=""
  KBUILD_BUILD_TIMESTAMP="Wed Jun 24 23:37:12 2026"
  KBUILD_BUILD_VERSION="0" KBUILD_HOSTLDFLAGS="-L$STAGING/host/lib"
  CONFIG_SHELL="bash" V='' cmd_syscalls=
  CC="${CROSS}gcc" KERNELRELEASE="5.10.161"
)

export STAGING_DIR="$STAGING/target-mipsel_24kc_musl"
export PATH="$TC/bin:$STAGING/host/bin:$PATH"

# SetInitramfs equivalente a OpenWrt: apuntamos INITRAMFS_SOURCE al rootfs + nodos estaticos
cp "$K/.config" "$K/.config.old"
grep -v -e INITRAMFS -e CONFIG_RD_ -e CONFIG_BLK_DEV_INITRD "$K/.config.old" > "$K/.config"
cat >> "$K/.config" <<'EOF'
CONFIG_BLK_DEV_INITRD=y
CONFIG_INITRAMFS_SOURCE="/tmp/rootfs-e2-2203 /home/proyectos/RiverOs/core/rootfs-riveros/initramfs-nodes.txt"
# CONFIG_INITRAMFS_PRESERVE_MTIME is not set
CONFIG_INITRAMFS_ROOT_UID=0
CONFIG_INITRAMFS_ROOT_GID=0
CONFIG_INITRAMFS_COMPRESSION_LZMA=y
# CONFIG_INITRAMFS_COMPRESSION_GZIP is not set
# CONFIG_INITRAMFS_COMPRESSION_BZIP2 is not set
# CONFIG_INITRAMFS_COMPRESSION_XZ is not set
# CONFIG_INITRAMFS_COMPRESSION_LZO is not set
# CONFIG_INITRAMFS_COMPRESSION_LZ4 is not set
# CONFIG_INITRAMFS_COMPRESSION_ZSTD is not set
CONFIG_RD_LZMA=y
EOF

# Reemplazamos la ruta literal en el .config con la ruta exacta del rootfs y nodos recibidos.
python3 - "$K/.config" "$ROOTFS_SRC" "$NODES_FILE" <<'PY'
import sys
path = sys.argv[1]
rootfs = sys.argv[2]
nodes = sys.argv[3]
with open(path, 'r', encoding='utf-8', errors='surrogateescape') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if line.startswith('CONFIG_INITRAMFS_SOURCE='):
        lines[i] = f'CONFIG_INITRAMFS_SOURCE="{rootfs} {nodes}"\n'
        break
else:
    lines.append(f'CONFIG_INITRAMFS_SOURCE="{rootfs} {nodes}"\n')
with open(path, 'w', encoding='utf-8') as f:
    f.write(''.join(lines))
PY

rm -f "$K/usr/initramfs_data.cpio" "$K/usr/initramfs_data.cpio.*"

find "$ROOTFS_SRC" -mindepth 1 -execdir touch -hcd "@${SOURCE_DATE_EPOCH:-1782344232}" {} + 2>/dev/null || true

# build del kernel / vmlinuz
make -C "$K" "${KMAKE_FLAGS[@]}" olddefconfig 2>&1 | tail -n 20
make -C "$K" -j"$JOBS" "${KMAKE_FLAGS[@]}" vmlinux vmlinuz 2>&1 | tail -n 20

OUT="$REPO/core/artifacts/riveros-5.10.161-e2-initramfs-kernel.bin"
mkdir -p "$(dirname "$OUT")"
cp "$K/vmlinuz" "$OUT"
"$OBJ" --set-section-flags=.appended_dtb=alloc,contents --update-section ".appended_dtb=$DTB" "$OUT"

ENTRY="$(readelf -h "$OUT" | awk '/Entry point/{print $4}')"
HAS_DTB="$(readelf -S "$OUT" | grep -c appended_dtb || true)"
SIZE="$(stat -c %s "$OUT")"
HASH="$(sha256sum "$OUT" | cut -d' ' -f1)"
MAX=$((0x6aa000))
FAIL=0
[ "$ENTRY" = "0x80b71000" ] || { echo "FAIL entry $ENTRY"; FAIL=1; }
[ "$HAS_DTB" -ge 1 ] || { echo "FAIL sin appended_dtb"; FAIL=1; }
[ "$SIZE" -lt "$MAX" ] || { echo "FAIL size $SIZE >= $MAX"; FAIL=1; }
if [ "$FAIL" -ne 0 ]; then
  echo "build-riveros-2203.sh FALLIDO"
  exit 1
fi

echo "PASS: entry=$ENTRY dtb=$HAS_DTB size=$SIZE sha=${HASH:0:12}"

echo "== CPIO initramfs == "
if [ -f "$K/usr/initramfs_data.cpio" ]; then
  echo "cpio existe: $K/usr/initramfs_data.cpio"
  cpio -it < "$K/usr/initramfs_data.cpio" 2>/dev/null | grep -E '(^etc/preinit$|^lib/preinit/99_red_manual$|^lib/functions/preinit.sh$)' || {
    echo "WARN: cpio no contiene los artefactos esperados";
  }
else
  echo "WARN: no existe $K/usr/initramfs_data.cpio (make probablemente no lo generó aún)"
fi

echo "artefacto: $OUT"
