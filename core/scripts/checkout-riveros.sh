#!/bin/bash
# RiverOs checkout-riveros.sh — obtiene el arbol base del kernel/toolchain
#
# Uso: ./checkout-riveros.sh [destino]   (destino por defecto: ../openwrt)
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${1:-$REPO/../openwrt}"
TAG="v25.12.5"

if [ -d "$DEST/.git" ]; then
  echo "[checkout] actualizando $DEST"
  git -C "$DEST" fetch --all --tags
else
  echo "[checkout] clonando arbol base en $DEST"
  git clone https://github.com/openwrt/openwrt.git "$DEST"
fi

git -C "$DEST" checkout "$TAG"
echo "[checkout] OK: $(git -C "$DEST" rev-parse --short HEAD)"
echo "[checkout] siguiente: ./scripts/feeds update -a && ./scripts/feeds install -a"
