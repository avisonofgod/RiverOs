#!/bin/bash
# check-config.sh — comprobacion automatica del .config del kernel RiverOS
#
# Uso:
#   check-config.sh [ruta_al_.config]   (default: config del build activo)
#   check-config.sh --fragments         (combina los fragmentos del repo y los
#                                        valida: base mips + mt7621 + hardware
#                                        + netboot; es el contrato de perfiles)
set -Eeuo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEV="$REPO/targets/mips/devices/mikrotik-rb750gr3/config"
TMP=""

if [ "${1:-}" = "--fragments" ]; then
  TMP="$(mktemp)"
  trap 'rm -f "$TMP"' EXIT
  cat "$REPO/targets/mips/common/mips-base.config" \
      "$REPO/targets/mips/mt7621/mt7621-base.config" \
      "$DEV/hardware.config" "$DEV/netboot.config" "$DEV/release.config" > "$TMP"
  C="$TMP"
else
  C="${1:-/home/proyectos/openwrt/build_dir/target-mipsel_24kc_musl/linux-ramips_mt7621/linux-6.12.94/.config}"
fi
[ -f "$C" ] || { echo "NO .config: $C"; exit 1; }
FAIL=0
check() {
  if grep -q "^$1=y" "$C"; then
    echo "OK  $1"
  else
    echo "FALTA $1"
    FAIL=1
  fi
}
check_val() {
  if grep -q "^$1=$2\$" "$C"; then
    echo "OK  $1=$2"
  else
    echo "FALTA $1=$2"
    FAIL=1
  fi
}
echo "=== RiverOS kernel check ($C) ==="
# sanidad del archivo: un valor tristate solo puede ser y/m/n. Lineas del tipo
# CONFIG_X=CONFIG_X (config danado por sed) hacen que kconfig las descarte en
# silencio y el kernel salga sin esos drivers.
BAD="$(grep -cE '^CONFIG_[A-Za-z0-9_]+=CONFIG_[A-Za-z0-9_]+$' "$C" || true)"
if [ "$BAD" -gt 0 ]; then
  echo "DANADO: $BAD lineas 'CONFIG_X=CONFIG_X' (valor invalido)"
  FAIL=1
fi
# red (contrato RB750Gr3)
check CONFIG_NET
check CONFIG_INET
check CONFIG_PACKET
check CONFIG_NETDEVICES
check CONFIG_BRIDGE
check CONFIG_NET_DSA
# sin el tag MTK los puertos de usuario del MT7530 no pasan trafico
check CONFIG_NET_DSA_TAG_MTK
check CONFIG_NET_DSA_MT7530
check CONFIG_NET_DSA_MT7530_MDIO
check CONFIG_MDIO_BUS
check CONFIG_PHYLINK
check CONFIG_REGMAP
check CONFIG_REGMAP_MMIO
check CONFIG_MEDIATEK_GE_PHY
check CONFIG_NET_MEDIATEK_SOC
# boot (contrato RouterBOOT)
check CONFIG_BLK_DEV_INITRD
check CONFIG_MIPS_RAW_APPENDED_DTB
check CONFIG_BINFMT_ELF
check_val CONFIG_ZBOOT_LOAD_ADDRESS 0x80b71000
# consola/hw
check CONFIG_SERIAL_8250
check CONFIG_SERIAL_8250_CONSOLE
check CONFIG_MT7621_WDT
# el WDT lo mantiene el kernel; el init NO lo alimenta (ERRORES-RED-E2 ERROR 2)
check CONFIG_WATCHDOG_HANDLE_BOOT_ENABLED
if [ "$FAIL" -eq 0 ]; then echo "=== CONFIG OK ==="; else echo "=== FALTAN SIMBOLOS ==="; fi
exit "$FAIL"
