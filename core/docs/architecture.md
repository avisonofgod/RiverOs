# RiverOs — Arquitectura

## Capas

```
┌─────────────────────────────────────────────┐
│ Risp (gestor ISP)        repo: avisonofgod/Risp │
│   risp :80 portal, :8081 admin               │
│   instala en /etc/risp + /etc/init.d/risp    │
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

1. [x] ImageBuilder → bins NETEST / RISP-BASE / RISP-RADIUS / EMBEBIDO
2. [~] Repo estructurado (configs/profiles, package/riveros, build.sh)
3. [ ] openwrt.lock fijado (commit RiverOs 25.12.5)
4. [ ] Imagen equivalente desde checkout completo de RiverOs
5. [ ] Kernel config 6.12.94 extraida a configs/kernel/
6. [ ] Parches versionados (DTS → MT7530 → NAND → nft → wg)
7. [ ] Initramfs RiverOs por netboot probado + rollback documentado

Ver `docs/reproducible-builds.md` para el detalle de cada paso.
