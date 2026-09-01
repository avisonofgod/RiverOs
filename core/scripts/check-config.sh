#!/bin/bash
# check-config.sh — comprobacion automatica del .config del kernel RiverOS
# Uso: check-config.sh [ruta_al_.config]  (default: config del build activo)
C="${1:-/home/proyectos/openwrt/build_dir/target-mipsel_24kc_musl/linux-ramips_mt7621/linux-6.12.94/.config}"
[ -f "$C" ] || { echo "NO .config: $C"; exit 1; }
FAIL=0
check() { grep -q "^$1=y" "$C" && echo "OK  $1" || { echo "FALTA $1"; FAIL=1; }; }
echo "=== RiverOS kernel check ($C) ==="
# red (contrato RB750Gr3)
check CONFIG_NET
check CONFIG_INET
check CONFIG_NETDEVICES
check CONFIG_NET_DSA
check CONFIG_NET_DSA_MT7530
check CONFIG_MDIO_BUS
check CONFIG_REGMAP
check CONFIG_REGMAP_MMIO
check CONFIG_MEDIATEK_GE_PHY
check CONFIG_NET_MEDIATEK_SOC
# boot (contrato RouterBOOT)
check CONFIG_BLK_DEV_INITRD
check CONFIG_MIPS_RAW_APPENDED_DTB
check CONFIG_BINFMT_ELF
# consola/hw
check CONFIG_SERIAL_8250
check CONFIG_SERIAL_8250_CONSOLE
check CONFIG_MEDIATEK_WATCHDOG
echo "=== $([ $FAIL -eq 0 ] && echo 'CONFIG OK' || echo 'FALTAN SIMBOLOS') ==="
exit $FAIL
