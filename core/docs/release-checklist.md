# RiverOs — Release checklist

## Antes de flashear un bin

- [x] Arquitectura mipsel_24kc confirmada (MT7621)
- [x] `core/scripts/check-config.sh` OK (16 simbolos)
- [ ] Bin copiado a backups con nombre GOOD
- [ ] restore.sh + loader dnsmasq operativos
- [ ] backup + export de la config actual del router
- [ ] OK explicito del usuario (R0)

## Antes de release (produccion)

- [ ] PROD=1 en build (falla si detecta rbadmin2026)
- [ ] Password por defecto eliminada / provisioning activo
- [ ] Ruleset nftables base (gestion-only) presente
- [ ] SHA256SUMS publicado (no solo MD5)
- [ ] openwrt-commit.txt con version exacta de RiverOs + kernel
- [ ] Manifest de paquetes guardado
- [ ] Rollback probado de punta a punta

## Tabla de variantes

| Variante | Paquetes | Uso | Recomendacion |
|---|---|---|---|
| riveros | 52 | Pruebas de imagen | Desarrollo |

Bins historicos (md5): RiverOs fdb90695, RISP-BASE d4bf6c76,
RISP-RADIUS-EMBEBIDO 9b1e4406.
