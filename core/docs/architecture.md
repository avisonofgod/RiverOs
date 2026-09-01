# RiverOs — Arquitectura

## Capas

```
┌─────────────────────────────────────────────┐
│ Risp (gestor ISP)        repo: avisonofgod/Risp │
├─────────────────────────────────────────────┤
│ RiverOs (ESTE REPO — capa SO)               │
│   kernel 6.12.94 mejorado (initramfs XZ,    │
│   DSA MT7530, netfilter, wireguard)         │
│   ImageBuilder 25.12.5 → riveros-*.bin      │
│   scripts: riveros-red, dropbear, rename    │
├─────────────────────────────────────────────┤
│ Bootloader RouterBOOT v6 (sysupgrade PLAIN) │
└─────────────────────────────────────────────┘
```

## Decisiones clave

- **Red manual sin netifd**: libuci/netifd/ucode son deps duras de
  base-files (no purgables via apk; uci CLI sí es purgable). Deshabilitados:
  network, firewall, odhcpd, uhttpd, rpcd, ucitrack, sysntpd, cron
  (whiteouts en overlay /etc/rc.d).
- **Nombres neutros ethX**: los puertos son solo puertos; Risp los configura.
- **RouterBOOT v6** → sysupgrade **PLAIN** (nunca -v7).

## Estado de madurez (hoja de ruta kernel-propio)

1. [x] ImageBuilder → bins RiverOs / RISP-BASE / RISP-RADIUS / EMBEBIDO
2. [x] Repo estructurado (core + targets + patches)
3. [x] Arbol base tag v25.12.5 (checkout-riveros.sh)
4. [ ] Imagen equivalente desde checkout completo de RiverOs
5. [ ] Kernel config 6.12.94 extraida a configs/kernel/
6. [ ] Parches versionados (DTS → MT7530 → NAND → nft → wg)
7. [ ] Initramfs RiverOs por netboot probado + rollback documentado

Ver `docs/reproducible-builds.md` para el detalle de cada paso.
