# RiverOs — Seguridad

## Estado actual (riesgos conocidos)

- **Credencial por defecto**: el overlay `configs/files/etc/shadow` y el
  README contienen la pass dev `rbadmin2026`. Regla: NUNCA en produccion.
  El build con `PROD=1` falla si la detecta. Proximamente: provisionar
  password/key en el primer arranque y eliminar la pass del repo.
- **Sin firewall base**: Risp levanta chains NAT/nftables; mientras tanto el
  router no tiene reglas de emergencia. Plan: ruleset nftables minimo que
  arranque antes de Risp (solo gestion desde eth0, bloquear resto).

## Reglas duras

1. Backup + export ANTES de flashear (restore.sh + netboot 22.03.3).
2. Verificar arquitectura (mipsel_24kc) antes de elegir .bin/.npk —
   uno equivocado BRICKEA. En RB750Gr3: sysupgrade PLAIN v6.
3. Tras instalar: cambiar password de inmediato (o deshabilitar pass auth).
4. NUNCA incluir claves privadas ni host keys compartidas en Git.
5. `verify.sh` comprueba secretos en configs/files, scripts y package.

## Plan de endurecimiento

- [ ] Quitar rbadmin2026 del repo; shadow sin pass + provisioning
- [ ] Ruleset nftables base (gestion-only) en imagen
- [ ] dropbear: solo key auth (PasswordAuth off) tras bootstrap
- [ ] SHA256SUMS + firma/verificacion antes de sysupgrade
- [ ] Escaner de secretos automatico (pre-commit / CI)

## Comando de auditoria rapida

```sh
grep -RniE 'rbadmin|BEGIN (RSA|EC|OPENSSH) PRIVATE KEY|password|passwd' \
  configs/ scripts/ package/ docs/ README.md
```
