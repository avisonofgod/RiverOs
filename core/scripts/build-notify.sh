#!/bin/bash
# build-notify.sh — lanza una compilacion en BACKGROUND y avisa al terminar.
#
# Motivo: las builds de RiverOs (toolchain + kernel 6.12.94) duran horas; nadie
# (humano o IA) debe quedarse esperando en primer plano. Este wrapper corre el
# comando con nohup, deja log + status en disco y dispara una notificacion.
#
# Uso:
#   ./build-notify.sh                       # corre core/scripts/build-kernel.sh
#   ./build-notify.sh -- ./build-kernel.sh /ruta/arbol
#   RIVEROS_NOTIFY_CMD='curl -s -X POST ...' ./build-notify.sh
#   ./build-notify.sh --wait                # ademas espera y devuelve el rc
#
# Estado (RIVEROS_BUILD_DIR, default /tmp/riveros-builds):
#   <id>.log     salida completa
#   <id>.status  RUNNING <pid> | DONE 0 | FAIL <rc>
#   latest.log / latest.status  symlinks a la ultima corrida
#
# Notificacion: $RIVEROS_NOTIFY_CMD si esta definido (recibe el resumen por
# stdin y como $1); si no, notify-send / wall / echo, lo que exista.
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${RIVEROS_BUILD_DIR:-/tmp/riveros-builds}"
WAIT=0

ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --wait) WAIT=1; shift;;
    --) shift; ARGS=("$@"); break;;
    -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 0;;
    *) ARGS=("$@"); break;;
  esac
done
[ "${#ARGS[@]}" -gt 0 ] || ARGS=("$REPO/core/scripts/build-kernel.sh")

mkdir -p "$OUT_DIR"
ID="build-$(date +%Y%m%d-%H%M%S)"
LOG="$OUT_DIR/$ID.log"
STATUS="$OUT_DIR/$ID.status"
ln -sfn "$LOG" "$OUT_DIR/latest.log"
ln -sfn "$STATUS" "$OUT_DIR/latest.status"

notify() { # $1 = resumen de una linea
  local msg="$1"
  if [ -n "${RIVEROS_NOTIFY_CMD:-}" ]; then
    printf '%s\n' "$msg" | sh -c "$RIVEROS_NOTIFY_CMD \"\$0\"" "$msg" || true
  elif command -v notify-send >/dev/null 2>&1; then
    notify-send "RiverOs build" "$msg" || true
  elif command -v wall >/dev/null 2>&1; then
    printf '%s\n' "$msg" | wall || true
  else
    printf '%s\n' "$msg"
  fi
}
export -f notify

runner() {
  local rc=0
  "${ARGS[@]}" >>"$LOG" 2>&1 || rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "DONE 0" > "$STATUS"
    notify "RiverOs build OK ($ID) — $(grep -m1 '^PASS:' "$LOG" || echo 'sin gate')"
  else
    echo "FAIL $rc" > "$STATUS"
    notify "RiverOs build FALLO rc=$rc ($ID) — $(grep -m1 -iE 'error|FAIL' "$LOG" | tail -1)"
  fi
  return "$rc"
}

runner &
BG=$!
echo "RUNNING $BG" > "$STATUS"
echo "[build-notify] id=$ID pid=$BG"
echo "[build-notify] log:    $LOG"
echo "[build-notify] status: $STATUS  (RUNNING/DONE/FAIL)"
echo "[build-notify] seguir: tail -f $OUT_DIR/latest.log"

if [ "$WAIT" -eq 1 ]; then
  wait "$BG"
else
  disown "$BG" 2>/dev/null || true
fi
