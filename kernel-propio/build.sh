#!/bin/bash
# build.sh — kernel RiverOs-kernel para MikroTik hEX (RB750Gr3)
# ESTRATEGIA 2026-08: allnoconfig + enables minimos, PERO con SMP/CM/GIC
# (sin ellos el kernel paniquea antes del init: interAptiv dual-core).
# Consola en eth0 (primer puerto tras rename), dropbear :22.
set -u
CROSS=mipsel-linux-gnu-
K=linux-6.12.103
U=$(nproc)
SHA256_EXPECTED=f143aaade8877ba5616e788b4482576db28481bcf557ef537f4fcc3938fc3176
TAR=linux-6.12.103.tar.xz

cd "$(dirname "$0")"

if [ ! -d "$K" ]; then
    if [ ! -f "$TAR" ]; then
        echo "==> descargando linux 6.12.103"
        curl -fSL -o "$TAR" https://cdn.kernel.org/pub/linux/kernel/v6.x/$TAR || exit 1
    fi
    echo "==> verificando SHA256 del tarball"
    echo "$SHA256_EXPECTED  $TAR" | sha256sum -c - || exit 1
    tar xJf "$TAR" || exit 1
fi

cd "$K"

echo "==> allnoconfig + config RiverOs-kernel (minimal)"
make ARCH=mips CROSS_COMPILE=$CROSS allnoconfig >/dev/null 2>&1

# --- plataforma MT7621 (imprescindible: sin SMP/CM/GIC paniquea antes de init) ---
# LOAD zona alta: override CLI load-y (CONFIG_PHYSICAL_START requiere CRASH_DUMP)
for s in SOC_MT7621 RALINK MIPS_MT_SMP MIPS_CM MIPS_GIC MIPS_GIC_IRQ \
    CPU_MIPS32_R2 MIPS_CPU_IRQ CEVT_R4K CSRC_R4K GENERIC_CLOCKEVENTS \
    MIPS_CMDLINE_FROM_DTB MIPS_ELF_APPENDED_DTB USE_OF OF_GPIO \
    CLK_MT7621 PINCTRL_MT7621 PINCTRL_RALINK RESET_CONTROLLER MFD_SYSCON \
    POWER_RESET POWER_RESET_GPIO GPIOLIB GPIO_CDEV; do
    scripts/config --enable $s
done

# --- initramfs embebido (gzip) ---
scripts/config --set-str INITRAMFS_SOURCE "$(cd "$(dirname "$0")/.." && pwd)/rootfs"
for s in BLK_DEV_INITRD RD_GZIP RD_XZ INITRAMFS_COMPRESSION_GZIP INITRAMFS_COMPRESSION; do
    scripts/config --enable $s
done
scripts/config --disable INITRAMFS_COMPRESSION_XZ INITRAMFS_COMPRESSION_LZMA \
    INITRAMFS_COMPRESSION_BZIP2 INITRAMFS_COMPRESSION_LZO INITRAMFS_COMPRESSION_LZ4 \
    INITRAMFS_COMPRESSION_ZSTD

# --- consola serial (RB750Gr3 UART ns16550a, ttyS0) ---
for s in SERIAL_8250 SERIAL_8250_CONSOLE SERIAL_CORE_CONSOLE SERIAL_EARLYCON \
    SERIAL_8250_MT7621; do
    scripts/config --enable $s
done

# --- red: DSA MT7530 + eth mediatek (consola eth0 por ether1) ---
for s in NET PACKET UNIX INET NETDEVICES ETHERNET NET_VENDOR_MEDIATEK \
    NET_MEDIATEK_SOC NET_SWITCHDEV PHYLINK PHYLIB MDIO_BUS MDIO_DEVRES \
    NET_DSA NET_DSA_MT7530 NET_DSA_MT7530_MDIO NET_DSA_TAG_MTK; do
    scripts/config --enable $s
done

# --- LEDs diag: OFF (ahorro ~15KB; el init usa led_blink solo si existe /sys/class/leds)
# --- GPIO_CDEV: off (no se usa en initramfs)
for s in NEW_LEDS LEDS_CLASS LEDS_GPIO GPIO_CDEV; do
    scripts/config --disable $s
done

make ARCH=mips CROSS_COMPILE=$CROSS olddefconfig >/dev/null 2>&1 || true

# --- reducir tamano (DESPUES del olddefconfig, sin otro olddefconfig despues:
#     si no, los revive; KALLSYMS/WIRELESS/WLAN lo demostraron) ---
# -Os (config OpenWrt base usa -O2; ahorro ~300-500KB en MIPS)
scripts/config --disable CC_OPTIMIZE_FOR_PERFORMANCE
scripts/config --enable CC_OPTIMIZE_FOR_SIZE
# serial 8250 OFF: consola RiverOs es por RED (SSH eth0), no serial; ahorro ~50KB
for s in SERIAL_8250 SERIAL_8250_CONSOLE SERIAL_CORE_CONSOLE SERIAL_EARLYCON \
    SERIAL_8250_MT7621 PHY_MT7621_PCI SPI_MT7621 PHY_MTK_TPHY; do
    scripts/config --disable $s
done
for s in KALLSYMS WIRELESS WLAN CFG80211 MAC80211 NETFILTER IPV6 BRIDGE VLAN_8021Q \
    NET_SCHED NET_CLS_INET USB MMC WATCHDOG RTC_CLASS SOUND INPUT HWMON PCI I2C \
    MTD BLK_DEV REGULATOR CGROUPS NAMESPACES MODULES DEBUG_INFO \
    NET_VENDOR_INTEL NET_VENDOR_ATHEROS NET_VENDOR_BROADCOM NET_VENDOR_REALTEK \
    NET_VENDOR_MARVELL NET_VENDOR_SIS NET_VENDOR_VIA NET_VENDOR_ALACRITECH \
    NET_VENDOR_AMD NET_VENDOR_ARC NET_VENDOR_CAVIUM NET_VENDOR_CIRRUS \
    NET_VENDOR_CORTINA NET_VENDOR_DAVICOM NET_VENDOR_DEC NET_VENDOR_DLINK \
    NET_VENDOR_EMULEX NET_VENDOR_GOOGLE NET_VENDOR_HISILICON NET_VENDOR_HP \
    NET_VENDOR_IBM NET_VENDOR_LANTIQ NET_VENDOR_MICREL NET_VENDOR_MICROCHIP \
    NET_VENDOR_MICROSEMI NET_VENDOR_MYRI NET_VENDOR_NATSEMI NET_VENDOR_NETRONOME \
    NET_VENDOR_NI NET_VENDOR_NOKIA NET_VENDOR_PENSANDO NET_VENDOR_QLOGIC \
    NET_VENDOR_QUALCOMM NET_VENDOR_RENESAS NET_VENDOR_ROCKER NET_VENDOR_SAMSUNG \
    NET_VENDOR_SEEQ NET_VENDOR_SOLARFLARE NET_VENDOR_STMICRO NET_VENDOR_SUN \
    NET_VENDOR_SYNOPSYS NET_VENDOR_TEHUTI NET_VENDOR_TI NET_VENDOR_VERTEXCOM \
    NET_VENDOR_WIZNET NET_VENDOR_XILINX NET_VENDOR_FREESCALE; do
    scripts/config --disable $s
done
# KALLSYMS final (visible con EXPERT; si va otro olddefconfig despues se revive)
scripts/config --enable EXPERT
scripts/config --disable KALLSYMS

echo "==> build vmlinux ($U jobs, load-y zona alta 0x80b71000)"
make ARCH=mips CROSS_COMPILE=$CROSS load-y=0xffffffff80b71000 -j$U vmlinux >/dev/null 2>&1 || {
    echo "ERROR: make vmlinux fallo"; exit 1; }

echo "==> DTB + append al ELF (entry=LOAD+0x400, seccion .appended_dtb)"
make ARCH=mips CROSS_COMPILE=$CROSS load-y=0xffffffff80b71000 dtbs >/dev/null 2>&1 || exit 1
DTB=arch/mips/boot/dts/ralink/mt7621_mikrotik_routerboard-750gr3.dtb
# entry = LOAD base + 0x400 (__kernel_entry con BOOT_RAW); RouterBOOT exige <=0x80b81000
mipsel-linux-gnu-objcopy --set-start=0x80b71400 \
    --update-section .appended_dtb=$DTB vmlinux ../naraos-vmlinux || exit 1
mipsel-linux-gnu-strip ../naraos-vmlinux 2>/dev/null || true

echo "OK: ../naraos-vmlinux ($(stat -c%s ../naraos-vmlinux) bytes)"
