# RiverOS

Sistema operativo embebido mínimo para hardware MikroTik (y futuras variantes),
construido sobre el árbol RiverOs. Jerarquía:

```
RiverOS Core                  <- fuente del sistema (no instalable)
├── core/
│   ├── configs/              <- configs base y perfiles (debug/netboot/release)
│   ├── docs/                 <- documentación técnica
│   ├── scripts/              <- scripts de compilación e init.d
│   └── imagebuilder/         <- builds ImageBuilder
└── targets/
    └── mips/
        ├── common/           <- común a MIPS
        ├── mt7621/           <- kernel/config del SoC MT7621
        └── devices/
            └── mikrotik-rb750gr3/   <- imagen específica RB750Gr3
                ├── files/           <- preinit (red manual), shadow
                ├── kernel-min-6.12.config
                ├── kernel-full-6.12.config.bak
                └── docs/

patches/                       <- parches locales documentados
    ├── 0001-dsa-mt7530-select-regmap-mmio.patch   (bug backport RiverOs)
    └── 935-load-y-mt7621-82000000.patch           (contrato RouterBOOT)
```

## RiverOS-MIPS (firmware mínimo arrancable)
- Kernel Linux 6.12.94 (RiverOs 25.12-NETEST) para MT7621
- Device Tree RB750Gr3 (wan=ether1, lan2-5=ether2-5)
- Initramfs con preinit (red manual + dropbear)
- Contrato RouterBOOT v6: entry 0x80b71000 + MIPS_RAW_APPENDED_DTB=y
  + load-y 0xffffffff82000000 (anti-solape de descompresión)

## RiverOS-MIPS-RB750Gr3 (imagen)
- Bin: riveros-6.12.94-v18 (4.39MB) — netboot BOOTP/TFTP
- 42 paquetes (userspace mínimo: base-files, busybox, dropbear, procd...)
- Red: wan 192.168.88.3 (preinit) o DHCP; br-lan 192.168.88.1 (lan2-5)
- SSH: dropbear, root/rbadmin2026 (CAMBIAR en producción)

## Estado
- [x] 22.03.3 minimal (33 paq) validado por netboot (base de referencia)
- [x] Kernel 6.12.94 propio arranca por netboot (red + SSH)
- [x] Kernel mínimo (config reducido ~465 =y desde ~1100)
- [ ] Validar v18 (MT7530 MMIO + REGMAP)
- [ ] Kernel release (sin debug) + perfiles

## Perfiles de configuracion (targets/mips/devices/mikrotik-rb750gr3/config/)

Fragmentos (fuente primaria — combinados generan el .config):
- hardware.config — red DSA/MT7530 + UART + WDT del RB750Gr3
- netboot.config  — initramfs + entry 0x80b71000 + RAW_DTB
- release.config  — minimo de produccion
- debug.config    — tracing + symbols

Base compartida: targets/mips/common/mips-base.config y
targets/mips/mt7621/mt7621-base.config.

Comprobacion automatica del config: core/scripts/check-config.sh
(verifica red + contrato RouterBOOT + consola).

Snapshots completos generados: docs/archive/configs/
