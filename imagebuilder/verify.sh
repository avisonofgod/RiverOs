#!/bin/bash
# RiverOs verify.sh — verificacion de artefactos y consistencia del repo
# Uso: ./verify.sh [BIN]   (BIN por defecto: imagebuilder/out/*.bin mas reciente)
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

BIN="${1:-$(ls -1t imagebuilder/out/*.bin 2>/dev/null | head -1 || true)}"
# resolver rutas relativas contra la raiz del repo
[ -f "$BIN" ] || [ -f "$REPO/$BIN" ] && BIN="$REPO/$BIN"
[ -n "$BIN" ] && [ -f "$BIN" ] || { echo "ERROR: bin no encontrado: $BIN" >&2; exit 1; }

fail=0

echo "== 1. Checksum =="
(cd "$(dirname "$BIN")" && sha256sum -c SHA256SUMS 2>/dev/null || { echo "FALLO sha256" >&2; fail=1; })

echo "== 2. Secretos en overlay (rbadmin2026 / claves privadas) =="
if grep -RniE 'rbadmin2026|BEGIN (RSA|EC|OPENSSH) PRIVATE KEY' configs/files/ scripts/ package/ 2>/dev/null; then
  echo "FALLO: secreto/credencial por defecto en el repo" >&2; fail=1
else
  echo "OK: sin secretos en configs/files scripts package"
fi

echo "== 3. Consistencia overlay (README dice files/, debe existir) =="
if [ -d configs/files/etc ]; then
  echo "OK: configs/files/etc existe"
else
  echo "FALLO: falta configs/files/etc" >&2; fail=1
fi

echo "== 4. Manifest del bin (si hay imagebuilder dir) =="
[ -f imagebuilder/out/openwrt-commit.txt ] && cat imagebuilder/out/openwrt-commit.txt || echo "sin openwrt-commit.txt (build pendiente)"

echo "== 5. Formato del bin (squashfs valido) =="
if command -v unsquashfs >/dev/null 2>&1 && unsquashfs -s "$BIN" >/dev/null 2>&1; then
  echo "OK: squashfs valido -> $(unsquashfs -s "$BIN" 2>/dev/null | head -2 | tr '\n' ' ')"
elif file "$BIN" | grep -qiE 'MIPS|squashfs|data|yaffs|ubi|firmware'; then
  echo "OK (file): $(file -b "$BIN" | cut -c1-80)"
else
  echo "FALLO: formato inesperado: $(file -b "$BIN" | cut -c1-80)" >&2; fail=1
fi

[ "$fail" = "0" ] && echo "VERIFY: OK" || { echo "VERIFY: FALLO"; exit 1; }
