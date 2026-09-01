#!/bin/bash
# RiverOs checkout-openwrt.sh — checkout completo de RiverOs fijado por openwrt.lock
#
# Requisitos: openwrt.lock con OPENWRT_COMMIT fijado (ver openwrt.lock).
# Uso: ./checkout-openwrt.sh [destino]   (destino por defecto: ../openwrt)
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${1:-$REPO/../openwrt}"
LOCK="$REPO/openwrt.lock"

COMMIT="$(grep -E '^OPENWRT_COMMIT=' "$LOCK" 2>/dev/null | cut -d= -f2 || true)"
if [ -z "$COMMIT" ] || [ "$COMMIT" = "<sha256 del tag v25.12.5>" ]; then
  echo "ERROR: OPENWRT_COMMIT no fijado en $LOCK (ver instrucciones)" >&2
  exit 1
fi

if [ -d "$DEST/.git" ]; then
  echo "[checkout] actualizando $DEST"
  git -C "$DEST" fetch --all --tags
else
  echo "[checkout] clonando RiverOs en $DEST"
  git clone https://github.com/openwrt/openwrt.git "$DEST"
fi

git -C "$DEST" checkout "$COMMIT"
echo "[checkout] OK: $(git -C "$DEST" rev-parse --short HEAD)"
echo "[checkout] siguiente: ./scripts/feeds update -a && ./scripts/feeds install -a"
