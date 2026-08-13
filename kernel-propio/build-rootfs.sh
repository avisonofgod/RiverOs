#!/bin/bash
# build-rootfs.sh — rootfs NARA-OS (busybox + dropbear + NARA, estaticos)
# Ensambla $OUT/ y genera initramfs cpio.gz para el kernel
set -e
cd "$(dirname "$0")"

CROSS=/home/toolchains/mipsel-linux-musl-cross/bin/mipsel-linux-musl-
OUT=rootfs
BB_VER=1.37.0
DB_VER=2026.94
NARA_BIN=/root/naram/target/mipsel-unknown-linux-musl/release/zpot

mkdir -p "$OUT"
echo "==> busybox $BB_VER (cross static)"
[ -d busybox-$BB_VER ] || {
    curl -sL -o busybox.tar.bz2 "https://busybox.net/downloads/busybox-$BB_VER.tar.bz2"
    tar xjf busybox.tar.bz2
}
make -C busybox-$BB_VER CROSS_COMPILE=$CROSS CONFIG_STATIC=y allnoconfig >/dev/null 2>&1 || true
# Config minima: solo applets que usa init + shell util (sed sobre .config)
cd busybox-$BB_VER
for s in ASH ASH_BUILTIN_ECHO ASH_BUILTIN_PRINTF ASH_BUILTIN_TEST SH_IS_ASH \
    MOUNT UMOUNT IP IP_BRIDGE BRCTL UDHCPC CAT LS MKDIR ECHO GREP SLEEP \
    UNAME DMESG PS KILL RMDIR RM CP MV TOUCH WC SEQ HEAD TAIL LN \
    FEATURE_IP_ADDRESS FEATURE_IP_LINK FEATURE_IP_ROUTE LFS; do
    sed -i "s/^# CONFIG_$s is not set/CONFIG_$s=y/" .config
done
sed -i 's/^CONFIG_FEATURE_VERBOSE_CP_MESSAGE=y/# CONFIG_FEATURE_VERBOSE_CP_MESSAGE is not set/' .config
cd ..
sed -i 's/CONFIG_SHA1_HWACCEL=y/CONFIG_SHA1_HWACCEL=n/; s/CONFIG_SHA256_HWACCEL=y/CONFIG_SHA256_HWACCEL=n/' busybox-$BB_VER/.config 2>/dev/null || true
make -C busybox-$BB_VER CROSS_COMPILE=$CROSS CONFIG_STATIC=y -j$(nproc) busybox 2>&1 | tail -3

echo "==> dropbear $DB_VER (cross static, bundled libtom)"
[ -d dropbear-$DB_VER ] || {
    curl -sL -o dropbear.tar.bz2 "https://matt.ucc.asn.au/dropbear/releases/dropbear-$DB_VER.tar.bz2"
    tar xjf dropbear.tar.bz2
}
( cd dropbear-$DB_VER && \
  [ -f Makefile ] || PATH=/home/toolchains/mipsel-linux-musl-cross/bin:$PATH \
      ./configure --host=mipsel-linux-musl --disable-zlib --enable-static \
      --enable-bundled-libtom --disable-pam >/dev/null 2>&1; \
  PATH=/home/toolchains/mipsel-linux-musl-cross/bin:$PATH \
      make -j$(nproc) PROGRAMS="dropbear dropbearkey" >/dev/null 2>&1 ) || true

echo "==> ensamblando $OUT/"
# Capturar init ANTES del rm (rootfs/init es la fuente versionada y $OUT la
# misma ruta — borrarla antes del cp la destruye)
INIT_SRC="$(cat "$OUT/init")"
rm -rf "$OUT/bin" "$OUT/sbin" "$OUT/etc" "$OUT/init"
mkdir -p "$OUT/bin" "$OUT/sbin" "$OUT/etc" "$OUT/proc" "$OUT/sys" "$OUT/dev" "$OUT/tmp" "$OUT/root" "$OUT/run"
cp busybox-$BB_VER/busybox "$OUT/bin/busybox"
# Symlinks de applets que usa init (multi-call busybox requiere argv0=applet).
# Sin ellos: "ip: not found" en el boot. sh es obligatorio (shebang #!/bin/sh).
for a in sh ash mount umount ip ln mkdir cat sleep echo grep uname dmesg ps \
    kill rm cp mv touch wc seq head tail; do
    ln -sf busybox "$OUT/bin/$a"
done
cp dropbear-$DB_VER/dropbear "$OUT/sbin/dropbear"
cp dropbear-$DB_VER/dropbearkey "$OUT/sbin/dropbearkey"
# NARA backend se agrega en fase 2 (binario 6.4MB; ahora kernel minimal SSH-first)

# Identidad + password (mismo hash que produccion RiverOs rbadmin2026)
cat > "$OUT/etc/passwd" <<'PASS'
root:$5$riveros01$zQIUyyRBojnfXFDnJQ8f0BSiWbYNPXCh0/4xLuFiDg1:0:0:root:/root:/bin/sh
PASS
cat > "$OUT/etc/group" <<'GRP'
root:x:0:root
GRP
chmod 644 "$OUT/etc/passwd" "$OUT/etc/group"

printf '%s\n' "$INIT_SRC" > "$OUT/init"
chmod +x "$OUT/init"

echo "==> initramfs cpio.gz"
( cd "$OUT" && find . | cpio -o -H newc 2>/dev/null | gzip -9 > ../initramfs.cpio.gz )
ls -la initramfs.cpio.gz
echo "ROOTFS OK: initramfs.cpio.gz ($(stat -c%s initramfs.cpio.gz) bytes)"
