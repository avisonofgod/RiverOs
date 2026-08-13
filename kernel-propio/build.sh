#!/bin/bash
# build.sh — kernel NARA-OS para MikroTik hEX (RB750Gr3)
# Uso: ./build.sh [menuconfig]
set -e
cd "$(dirname "$0")"

KVER=6.12.103
KSRC=linux-$KVER
TARBALL=$KSRC.tar.xz
URL=https://cdn.kernel.org/pub/linux/kernel/v6.x/$TARBALL
SHA256_EXPECTED=f143aaade8877ba5616e788b4482576db28481bcf557ef537f4fcc3938fc3176
CROSS=mipsel-linux-gnu-
DTB=arch/mips/boot/dts/ralink/mt7621_mikrotik_routerboard-750gr3.dtb

# Verificar toolchain cross antes de nada
command -v ${CROSS}gcc >/dev/null 2>&1 || { echo "FALTA toolchain ${CROSS}gcc"; exit 1; }

[ -d "$KSRC" ] || {
    echo "==> descargando $URL"
    curl -sL -o "$TARBALL" "$URL"
    echo "$SHA256_EXPECTED  $TARBALL" | sha256sum -c - 2>/dev/null || \
        echo "WARN: checksum no verificado (actualizar SHA256_EXPECTED)"
    tar xJf "$TARBALL"
}

cd "$KSRC"

echo "==> allnoconfig + config NARA-OS (minimal)"
make ARCH=mips CROSS_COMPILE=$CROSS allnoconfig >/dev/null 2>&1 || true

# Plataforma ralink + SoC MT7621
scripts/config --enable RALINK
scripts/config --disable SOC_RT305X --enable SOC_MT7621
# DTB appended al ELF (choice; para MT7621 no hay builtin)
# ELF_APPENDED_DTB: objcopy --update-section .appended_dtb=<dtb> embebe el DTB
# dentro del segmento LOAD (RouterBOOT lo carga). RAW no sirve con ELF.
scripts/config --disable MIPS_NO_APPENDED_DTB --enable MIPS_ELF_APPENDED_DTB --disable MIPS_RAW_APPENDED_DTB
# initramfs (rootfs embebido, comprimido xz — mas pequeno que gzip)
scripts/config --set-str INITRAMFS_SOURCE "/root/proyectos/nara-os/repo/rootfs"
scripts/config --enable INITRAMFS_COMPRESSION_XZ
# core (NET debe ir ANTES que INET/NETDEVICES: allnoconfig apaga NET)
for s in BLK_DEV_INITRD DEVTMPFS DEVTMPFS_MOUNT TMPFS PROC_FS SYSFS \
    NET PACKET UNIX INET \
    NETDEVICES ETHERNET \
    NET_DSA NET_DSA_MT7530 NET_DSA_MT7530_MDIO PHYLINK NET_SWITCHDEV \
    NET_VENDOR_MEDIATEK NET_MEDIATEK_SOC; do
    scripts/config --enable "$s"
done
# minimizar tamano: -Os (no -O2)
scripts/config --disable CC_OPTIMIZE_FOR_PERFORMANCE --enable CC_OPTIMIZE_FOR_SIZE

make ARCH=mips CROSS_COMPILE=$CROSS olddefconfig >/dev/null 2>&1 || true

# KALLSYMS tiene default y y no es visible sin EXPERT: habilitar EXPERT hace que
# el "is not set" del .config se respete en olddefconfig (si no, lo revive a y)
scripts/config --enable EXPERT
scripts/config --disable KALLSYMS
make ARCH=mips CROSS_COMPILE=$CROSS olddefconfig >/dev/null 2>&1 || true
# EXPERT desbloquea cientos de simbolos (infla el kernel): apagarlo de nuevo
scripts/config --disable EXPERT
make ARCH=mips CROSS_COMPILE=$CROSS olddefconfig >/dev/null 2>&1 || true
# verificar que KALLSYMS sigue off tras re-validar sin EXPERT
scripts/config --disable KALLSYMS
make ARCH=mips CROSS_COMPILE=$CROSS olddefconfig >/dev/null 2>&1 || true

if [ "$1" = "menuconfig" ]; then
    make ARCH=mips CROSS_COMPILE=$CROSS menuconfig
fi

echo "==> compilando vmlinux (ELF) + dtbs"
# load-y: linkear a zona ALTA (0x80b71000) como OpenWrt 22.03.3 — el RouterBOOT
# netboot solo ejecuta kernels cargados en esa zona (mainline default 0x80001000
# zona baja NO arranca). load-y override via linea de comando.
make ARCH=mips CROSS_COMPILE=$CROSS load-y=0xffffffff80b71000 -j$(nproc) vmlinux dtbs 2>&1 | tail -8

echo "==> DTB dentro del ELF (netboot)"
# objcopy --update-section reemplaza el buffer .appended_dtb (1MB) con el DTB real
# dentro del segmento LOAD — el cat al final NO llega a RAM con RouterBOOT.
ls -la vmlinux $DTB
mipsel-linux-gnu-strip vmlinux 2>/dev/null || true
mipsel-linux-gnu-objcopy --update-section .appended_dtb=$DTB vmlinux
# ENTRY: el ELF apunta a kernel_entry (.ref.text, +4MB, zona ALTA) que RouterBOOT
# no ejecuta (limite 0x80b81000). Con BOOT_RAW + fill removido (head.S #if 0),
# __kernel_entry queda en la base EXACTA 0x80b71000 y hace 'j kernel_entry'
# (como OpenWrt 22.03.3: entry = LOAD base).
mipsel-linux-gnu-objcopy --set-start 0x80b71000 vmlinux
cat vmlinux > ../naraos-vmlinux
ls -la ../naraos-vmlinux
echo "KERNEL OK: ../naraos-vmlinux ($(stat -c%s ../naraos-vmlinux) bytes)"
