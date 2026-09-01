# RiverOs — Arquitectura

## Capas

```
┌─────────────────────────────────────────────┐
│ Risp (gestor ISP)        repo: avisonofgod/Risp │
├─────────────────────────────────────────────┤
│ RiverOs (ESTE REPO — capa SO)               │
│   kernel 6.12.94 minimo (netboot directo:   │
│   entry 0x80b71000, load-y 32MB, RAW_DTB)   │
│   initramfs: preinit (red manual) + dropbear│
│   targets/ por arquitectura                 │
├─────────────────────────────────────────────┤
│ Bootloader RouterBOOT v6 (sysupgrade PLAIN) │
└─────────────────────────────────────────────┘
```

## Decisiones clave

- **Red manual en preinit** (hook `initramfs`): br-lan (lan2-5, .1) + wan (.3),
  dropbear -R. El netifd aplica la config estatica (network del device).
- **Contrato RouterBOOT**: entry 0x80b71000 exacto (VMLINUZ_LOAD_ADDRESS),
  MIPS_RAW_APPENDED_DTB=y, load-y 0xffffffff82000000 (anti-solape de
  descompresion).
- **Kernel minimo**: solo drivers del hardware (MT7621, DSA MT7530,
  Ethernet, UART, WDT, GPIO) + initramfs; sin WLAN/USB/SOUND/fs/debug.
- **Nombres de puertos**: wan=ether1, lan2-lan5=ether2-5 (DTB del device).

## Estado de madurez (hoja de ruta kernel-propio)

1. [x] Kernel 6.12.94 propio arranca por netboot (v19/v20 validados con SSH)
2. [x] Repo estructurado (core + targets + patches)
3. [x] Arbol base tag v25.12.5 (checkout-riveros.sh)
4. [x] Kernel config MIN-V2 (1002 =y + red) en configs/kernel/
5. [x] Parches versionados (patches/kernel/: 0001 REGMAP_MMIO, 0935 load-y)
6. [x] build-kernel.sh reproduce el binario desde el repo (clon + build)
7. [ ] Initramfs por netboot con red estatica validado (netifd vs preinit)

Ver `docs/toolchain.md` (compilador) y `docs/kernel-build.md` (flujo).
