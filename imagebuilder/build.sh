#!/bin/bash
# RiverOs build.sh — build unificado via ImageBuilder (perfiles en configs/profiles)
#
# Uso (dentro del arbol ImageBuilder 25.12.5):
#   /path/RiverOs/imagebuilder/build.sh -p netest
#   /path/RiverOs/imagebuilder/build.sh -p risp-radius
#   FILES=<arbol backend risp> /path/RiverOs/imagebuilder/build.sh -p risp-radius-embebido
#
# Opciones:
#   PROD=1   -> falla si detecta credencial por defecto en el overlay (release)
#   BACKUP_DIR=/ruta -> copia el bin + SHA256SUMS al directorio de backups
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="netest"
PROD="${PROD:-0}"

while getopts "p:h" o; do
  case "$o" in
    p) PROFILE="$OPTARG" ;;
    h) sed -n '2,8p' "$0"; exit 0 ;;
    *) exit 2 ;;
  esac
done

PROFILE_FILE="$REPO/configs/profiles/$PROFILE.config"
[ -f "$PROFILE_FILE" ] || { echo "ERROR: perfil no existe: $PROFILE_FILE" >&2; exit 1; }
# shellcheck source=/dev/null
source "$PROFILE_FILE"

# Overlay por defecto: configs/files (estructura etc/...)
FILES_DIR="${FILES:-$REPO/configs/files}"
[ -d "$FILES_DIR/etc" ] || { echo "ERROR: falta overlay $FILES_DIR/etc" >&2; exit 1; }

# Check de seguridad: credencial por defecto en imagen de release
if [ "$PROD" = "1" ]; then
  if grep -RniE 'rbadmin2026' "$FILES_DIR" 2>/dev/null; then
    echo "ERROR: credencial por defecto detectada en el overlay (PROD=1)" >&2
    exit 1
  fi
  echo "[build] PROD=1: check de credenciales OK"
fi

echo "[build] perfil=$PROFILE output=$OUTPUT"
echo "[build] FILES=$FILES_DIR"

make image PROFILE="$PROFILE" FILES="$FILES_DIR" PACKAGES="$PACKAGES"

BIN="$(ls -1t bin/targets/ramips/mt7621/*squashfs-sysupgrade.bin 2>/dev/null | head -1 || true)"
if [ -n "$BIN" ]; then
  echo "[build] artefacto: $BIN"
  DEST="$REPO/imagebuilder/out/$OUTPUT"
  mkdir -p "$REPO/imagebuilder/out"
  cp "$BIN" "$DEST"
  ( cd "$REPO/imagebuilder/out" && sha256sum "$OUTPUT" > SHA256SUMS && md5sum "$OUTPUT" >> SHA256SUMS )
  # metadatos de build
  {
    echo "openwrt_version=$(cat "$REPO/VERSION" 2>/dev/null || echo unknown)"
    echo "kernel_release=$(grep -E '^KERNEL_VERSION' "$REPO/openwrt.lock" 2>/dev/null | cut -d= -f2 || echo 6.12.94)"
    echo "profile=$PROFILE"
    echo "built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "packages=$PACKAGES"
  } > "$REPO/imagebuilder/out/openwrt-commit.txt"
  cat "$REPO/imagebuilder/out/SHA256SUMS"
  if [ -n "${BACKUP_DIR:-}" ]; then
    mkdir -p "$BACKUP_DIR"
    cp "$DEST" "$REPO/imagebuilder/out/SHA256SUMS" "$REPO/imagebuilder/out/openwrt-commit.txt" "$BACKUP_DIR/"
    echo "[build] copiado a $BACKUP_DIR"
  fi
else
  echo "WARN: no se encontro sysupgrade bin; revisa bin/targets/ramips/mt7621/" >&2
fi
