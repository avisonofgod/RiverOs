#!/bin/bash
# build.sh — kernel RiverOs-kernel para MikroTik hEX (RB750Gr3)
# ESTRATEGIA 2026-08-13 (v2): base = config OpenWrt COMPLETO (la unica que
# bootea en este hardware; allnoconfig paniquea antes del init aun con
# SMP/CM/GIC/CPS) + red como MODULOS .ko en initramfs (kernel puro chico).
# LIMITE REAL: RouterBOOT acepto 6.66MiB con entry 0x80b71000 (1 TFTP);
# los rechazos de 5.55/5.58 eran por entry 0x80b71400, NO por tamano.
set -e
cd "$(dirname "$0")"
K=linux-6.12.103
CROSS=mipsel-linux-gnu-
U=$(nproc)

echo "==> config: base OpenWrt (config-6.12-mt7621) + olddefconfig"
make -C $K ARCH=mips CROSS_COMPILE=$CROSS clean >/dev/null 2>&1
cp config-6.12-mt7621 $K/.config

cd $K

# --- plataforma MT7621 (refuerzo explicito; el config OpenWrt ya la trae) ---
for s in SOC_MT7621 RALINK MIPS_MT_SMP MIPS_MT MIPS_CM MIPS_CPS MIPS_CPC MIPS_GIC \
    MIPS_GIC_IRQ SMP SMP_UP MIPS_MT_FPAFF SYS_SUPPORTS_SMP SYS_SUPPORTS_MULTITHREADING \
    CLK_MT7621 COMMON_CLK PINCTRL PINCTRL_MT7621 PINCTRL_RALINK PINCTRL_MTK_MTMIPS \
    RESET_CONTROLLER MFD_SYSCON POWER_RESET POWER_RESET_GPIO GPIOLIB GPIO_MT7621 \
    NVMEM TIMER_PROBE TIMER_OF GENERIC_CLOCKEVENTS CLKSRC_MIPS_GIC CEVT_R4K CSRC_R4K \
    EARLY_PRINTK OF OF_FLATTREE OF_EARLY_FLATTREE USE_OF IRQCHIP IRQ_DOMAIN \
    CPU_MIPS32_R2 CPU_MIPS32 SYS_HAS_CPU_MIPS32_R2 SYS_SUPPORTS_LITTLE_ENDIAN \
    CPU_LITTLE_ENDIAN CPU_SUPPORTS_32BIT_KERNEL SYS_SUPPORTS_32BIT_KERNEL \
    BOOT_RAW BINFMT_ELF BINFMT_SCRIPT \
    PRINTK PROC_FS SYSFS TMPFS DEVTMPFS SHMEM BUG MULTIUSER FUTEX EPOLL \
    EXPERT; do
    scripts/config --enable $s
done

# --- consola serial (ttyS0) ---
for s in TTY SERIAL_8250 SERIAL_8250_CONSOLE SERIAL_CORE_CONSOLE SERIAL_EARLYCON; do
    scripts/config --enable $s
done

# --- RED core =y; drivers =m (.ko en initramfs) ---
for s in NET PACKET UNIX INET NETDEVICES ETHERNET MODULES MODULE_UNLOAD; do
    scripts/config --enable $s
done
for s in NET_DSA NET_DSA_MT7530 NET_DSA_MT7530_MDIO NET_MEDIATEK_SOC \
    PHYLINK PHYLIB MDIO_DEVICE MDIO_BUS \
    MEDIATEK_GE_PHY PCS_MTK_LYNXI; do
    scripts/config --module $s
done
# NET_VENDOR_MEDIATEK es BOOL (--module no aplica; debe ir --enable)
scripts/config --enable NET_VENDOR_MEDIATEK

echo "==> olddefconfig (config completo tipo OpenWrt)"
make ARCH=mips CROSS_COMPILE=$CROSS olddefconfig >/dev/null 2>&1

# --- initramfs + DTB + tamano DESPUES del olddefconfig (sin otro olddefconfig) ---
scripts/config --enable BLK_DEV_INITRD
scripts/config --enable INITRAMFS_COMPRESSION_GZIP
scripts/config --enable RD_GZIP
scripts/config --set-str INITRAMFS_SOURCE "$(cd .. && pwd)/rootfs"
scripts/config --enable CC_OPTIMIZE_FOR_SIZE
scripts/config --enable LD_DEAD_CODE_DATA_ELIMINATION
scripts/config --disable KALLSYMS
scripts/config --enable ELF_APPENDED_DTB
scripts/config --disable MIPS_RAW_APPENDED_DTB
scripts/config --enable MIPS_ELF_APPENDED_DTB

# --- reducir tamano: bloques no usados (POST-olddefconfig, no correr otro) ---
for s in WIRELESS WLAN CFG80211 MAC80211 MT76 MT7603 MT7615 MT7915 \
    USB PCI I2C INPUT HWMON RTC_CLASS WATCHDOG SOUND REGULATOR CGROUPS \
    NAMESPACES MTD BLK_DEV MMC NETFILTER IPV6 BRIDGE VLAN_8021Q \
    NET_SCHED NET_CLS NFC CAN BLUETOOTH BPF BPF_SYSCALL KPROBES FTRACE PERF_EVENTS \
    STACKTRACE DEBUG_KERNEL DEBUG_INFO DEBUG_FS GDB_SCRIPTS IKCONFIG \
    GPIO_CDEV NEW_LEDS LEDS_CLASS LEDS_GPIO \
    INPUT_KEYBOARD INPUT_MOUSE MOUSE_PS2 MOUSE_PS2_ALPS MOUSE_PS2_BYD \
    MOUSE_PS2_CYPRESS MOUSE_PS2_FOCALTECH MOUSE_PS2_LOGIPS2PP \
    MOUSE_PS2_SYNAPTICS MOUSE_PS2_TRACKPOINT \
    SCSI_MOD BLOCK_LEGACY_AUTOLOAD PCI_DRIVERS_GENERIC; do
    scripts/config --disable $s
done

# NET_VENDOR_*: el config OpenWrt trae ~40 vendors (cada uno = driver ethernet).
# Solo MEDIATEK es necesario (mtk_eth); los demas inflan el kernel.
for s in $(grep -oE "^CONFIG_NET_VENDOR_[A-Z0-9_]+=y" .config | sed 's/^CONFIG_//;s/=y//'); do
    [ "$s" = "NET_VENDOR_MEDIATEK" ] || scripts/config --disable $s
done

# --- vmlinux PRIMERO (genera Module.symvers; sin el, modpost: undefined) ---
echo "==> build vmlinux (load-y 0x80b71000, sin .notes)"
make ARCH=mips CROSS_COMPILE=$CROSS load-y=0xffffffff80b71000 KBUILD_LDFLAGS="-z max-page-size=0x10000" -j$U vmlinux >/dev/null 2>&1 || {
    echo "ERROR: make vmlinux fallo"; exit 1; }

# --- modulos: .ko al rootfs (strip) ---
echo "==> modulos: make modules + copiar .ko al rootfs"
make ARCH=mips CROSS_COMPILE=$CROSS -j$U modules >/dev/null 2>&1 || {
    echo "ERROR: make modules fallo"; exit 1; }
rm -rf ../rootfs/lib/modules
mkdir -p ../rootfs/lib/modules
find . -name "*.ko" | grep -E "dsa|mt7530|mtk_eth|mediatek|mdio|phylink|phy|pcs" | \
    grep -v selftests | \
    while read -r m; do
        cp "$m" ../rootfs/lib/modules/ 2>/dev/null
        ${CROSS}strip --strip-unneeded ../rootfs/lib/modules/$(basename "$m") 2>/dev/null
    done
echo "modulos en rootfs: $(ls ../rootfs/lib/modules/ | wc -l) ($(du -sh ../rootfs/lib/modules/ | cut -f1))"

# --- re-link vmlinux (initramfs con .ko): make incremental NO relinkea ---
# el thin archive (ar rcsT) es normal en 6.12; regenerar TODO en serial
rm -f usr/initramfs_data.o usr/initramfs_data.cpio usr/initramfs_inc_data \
      usr/built-in.a vmlinux
echo "==> re-link vmlinux (initramfs con .ko)"
make ARCH=mips CROSS_COMPILE=$CROSS usr/initramfs_data.o >/dev/null 2>&1 || {
    echo "ERROR: make initramfs_data.o fallo"; exit 1; }
make ARCH=mips CROSS_COMPILE=$CROSS load-y=0xffffffff80b71000 KBUILD_LDFLAGS="-z max-page-size=0x10000" -j1 vmlinux >/dev/null 2>&1 || {
    echo "ERROR: make vmlinux (re-link) fallo"; exit 1; }

echo "==> dtbs + objcopy (entry=LOAD base 0x80b71000, sin .notes)"
make ARCH=mips CROSS_COMPILE=$CROSS dtbs >/dev/null 2>&1 || true
DTB=arch/mips/boot/dts/ralink/mt7621_mikrotik_routerboard-750gr3.dtb
mipsel-linux-gnu-objcopy \
    --set-start=0x80b71000 \
    --update-section .appended_dtb=$DTB \
    --remove-section .notes \
    vmlinux ../naraos-vmlinux 2>&1 || {
    echo "ERROR: objcopy fallo"; exit 1; }

SIZE=$(stat -c%s ../naraos-vmlinux)
echo "==> OK: $SIZE B ($(echo "scale=2; $SIZE/1048576" | bc) MiB) entry 0x80b71000"
