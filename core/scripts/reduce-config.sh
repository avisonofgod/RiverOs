#!/bin/bash
# reduce-config.sh — reduce un .config validado apagando familias de simbolos
# no usadas por el RB750Gr3 (WLAN/USB/sonido/fs/debug/HID...), conservando el
# contrato de check-config.sh y sus dependencias duras.
# Uso: reduce-config.sh <in.config> <out.config>
set -Eeuo pipefail
IN="$1"; OUT="$2"
cp "$IN" "$OUT"
CUT=0

# Los patrones son familias de simbolos: se anclan a ^CONFIG_<familia> y solo
# cortan en frontera de palabra (_ o fin). Sin anclar, "NET" casaba dentro de
# CONFIG_MAGIC_SYSRQ_SERIAL... y las excepciones tapaban cortes reales.
CUT_FAMILIES='WIRELESS|CFG80211|MAC80211|WEXT|USB|NOP_USB_XCEIV|SOUND|SND|XFS|BTRFS|MSDOS_FS|VFAT_FS|NTFS3|NFS|NFSD|PNFS|CIFS|FUSE|EXT4|F2FS|DEBUG|MAGIC_SYSRQ|PRINTK_TIME|IKCONFIG|MHI_BUS_DEBUG|WWAN_DEBUGFS|LOCK_DEBUGGING|HID|INPUT|DRM|FB|VIDEO|MEDIA|DVB|RC|MMC|W1|REGULATOR|HW_RANDOM|LEDS|RTC|IIO|PWM|KEYBOARD|MOUSE|JOYDEV|EVDEV|MATRIXKMAP'

# Excepciones: contrato de red/boot de check-config.sh + dependencias duras.
KEEP_FAMILIES='NET|INET|PACKET|UNIX|NETDEVICES|ETHERNET|BRIDGE|NET_DSA|NET_SWITCHDEV|MDIO_BUS|MDIO_DEVICE|MDIO_DEVRES|REGMAP|MEDIATEK_GE_PHY|NET_MEDIATEK_SOC|PHYLIB|PHYLINK|FIXED_PHY|MT7530|MT7621_WDT|WATCHDOG|WATCHDOG_CORE|WATCHDOG_HANDLE_BOOT_ENABLED|BLK_DEV_INITRD|INITRAMFS|RD_LZMA|MIPS_RAW_APPENDED_DTB|ZBOOT|BINFMT_ELF|SERIAL_8250|MTD|UBI|SQUASHFS|JFFS2|DEVTMPFS|TMPFS|PROC_FS|SYSFS|KALLSYMS|PRINTK|MODULE|MODULES|FW_LOADER|GPIO|GPIOLIB|PINCTRL|CLK|RESET|DMA|IRQ|TIMER|SMP|MIPS|CPU|SOC_MT7621|RALINK|CC|GCC|LD|AS|LLD|PAHOLE|HAVE|ARCH|SUPPORTS|HAS|CAN|USE|WANT|EXPERT|EMBEDDED|POSIX|TIMERFD|EVENTFD|EPOLL|SIGNALFD|MULTIUSER|NAMESPACES|NET_NS|PID_NS|BPF|CGROUPS|SYSCTL|PREEMPT|NO_HZ|HZ|RCU'

matches() { # $1 = simbolo, $2 = familias
	printf '%s' "$1" | grep -qE "^CONFIG_($2)(_[A-Z0-9_]+)?\$"
}

while IFS= read -r line; do
	sym="${line%%=*}"
	matches "$sym" "$KEEP_FAMILIES" && continue
	matches "$sym" "$CUT_FAMILIES" || continue
	sed -i "s|^${sym}=[ym]\$|# ${sym} is not set|" "$OUT"
	CUT=$((CUT + 1))
done < <(grep -E "^CONFIG_[A-Za-z0-9_]+=[ym]$" "$IN")

Y="$(grep -cE '^CONFIG_[A-Za-z0-9_]+=y$' "$OUT" || true)"
BAD="$(grep -cE '^CONFIG_[A-Za-z0-9_]+=CONFIG_[A-Za-z0-9_]+$' "$OUT" || true)"
echo "simbolos apagados: $CUT"
echo "=y restantes: $Y"
echo "=m restantes: $(grep -cE '^CONFIG_[A-Za-z0-9_]+=m$' "$OUT" || true)"
# gate: un .config reducido con 0 simbolos =y o con valores invalidos es basura
# (asi se colo core/configs/kernel/mt7621-rb750gr3-min.config con 0 =y; canonicos en core/perfiles/)
[ "$BAD" -eq 0 ] || { echo "ERROR: $BAD lineas CONFIG_X=CONFIG_X en $OUT"; exit 1; }
[ "$Y" -gt 100 ] || { echo "ERROR: solo $Y simbolos =y en $OUT (config inservible)"; exit 1; }
