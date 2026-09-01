#!/bin/bash
# reduce-config.sh — reduce el config v21 validado (985=y) aplicando cortes
# Duck WLAN/USB/SOUND/fs/debug, conservando los 16 simbolos criticos de
# check-config.sh + deps duras (MTD/initramfs/boot). Objetivo: ~957=y o menos.
# Uso: reduce-config.sh <in.config> <out.config>
set -Eeuo pipefail
IN="$1"; OUT="$2"
cp "$IN" "$OUT"
CUT=0

# categorias de corte (regex sobre nombre de simbolo)
CUT_RE='CONFIG_(WIRELESS|CFG80211|MAC80211|WEXT|USB|NOP_USB_XCEIV|SOUND|SND_|XFS|BTRFS|MSDOS_FS|VFAT_FS|NTFS3|NFS|NFSD|PNFS|CIFS|FUSE|EXT4|F2FS|DEBUG_|MAGIC_SYSRQ|PRINTK_TIME|IKCONFIG|MHI_BUS_DEBUG|WWAN_DEBUGFS|LOCK_DEBUGGING|HID|INPUT|DRM|FB_|VIDEO_|MEDIA|DVB|RC_|MMC|W1_|REGULATOR|HW_RANDOM|LEDS_|RTC|IIO|PWM|KEYBOARD|MOUSE|JOYDEV|EVDEV|MATRIXKMAP)'

# excepciones: simbolos criticos que NO se tocan (check-config.sh + deps)
KEEP_RE='CONFIG_(NET|INET|NETDEVICES|NET_DSA|MDIO_BUS|REGMAP|MEDIATEK_GE_PHY|NET_MEDIATEK_SOC|BLK_DEV_INITRD|MIPS_RAW_APPENDED_DTB|BINFMT_ELF|SERIAL_8250|MEDIATEK_WATCHDOG|WATCHDOG|MTD|UBI|SQUASHFS|JFFS2|DEVTMPFS|TMPFS|PROC_FS|SYSFS|KALLSYMS|PRINTK|MODULE|FW_LOADER|PHYLIB|PHYLINK|NET_MEDIATEK|MT7530|DSA|GPIO|PINCTRL|CLK|RESET|DMA|IRQ|TIMER|R4K|CSRC|SMP|MIPS|CPU_|SOC_|RALINK|MT7621|ZBOOT|RD_LZMA|INITRAMFS|CC_|GCC|LD_|AS_|LLD|PAHOLE|HAVE_|ARCH_|SUPPORTS|HAS_|CAN_|USE_|WANT_|KEEP_|BROKEN|EXPERT|EMBEDDED|POSIX|TIMERFD|EVENTFD|EPOLL|SIGNALFD|ANON|MULTIUSER|NAMESPACES|PID_NS|NET_NS|UNIX|PACKET|BPF|CGROUP|TASKS|CFS|SYSCTL|STRICT|DEFAULT|OPTIMIZE|INLINE|RWSEM|MUTEX|SPINLOCK|QUEUED|PREEMPT|NO_HZ|HZ_|RCU|SMP)'

while IFS= read -r line; do
    sym="${line%%=*}"
    # saltar excepciones
    if echo "$sym" | grep -qE "$KEEP_RE"; then continue; fi
    if echo "$sym" | grep -qE "$CUT_RE"; then
        if grep -qE "^${sym}=[ym]$" "$OUT"; then
            sed -i "s|^${sym}=[ym]$|# ${sym} is not set|" "$OUT"
            CUT=$((CUT+1))
        fi
    fi
done < <(grep -E "^CONFIG_[A-Za-z0-9_]+=[ym]$" "$OUT")

echo "simbolos apagados: $CUT"
echo "=y restantes: $(grep -cE '^CONFIG_[A-Za-z0-9_]+=y$' "$OUT")"
echo "=m restantes: $(grep -cE '^CONFIG_[A-Za-z0-9_]+=m$' "$OUT")"
