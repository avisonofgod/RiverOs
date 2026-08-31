# RiverOs — Hardware RB750Gr3

- SoC: MediaTek MT7621, **mipsel_24kc**, 880 MHz dual
- RAM: 256 MB DDR3
- Flash: 16 MB NAND (MTD/UBI)
- Switch: MT7530 (DSA) — 5 puertos GbE + puerto CPU interno
- RouterBOOT: **6.47.10 (v6)** → sysupgrade **PLAIN** (NO -v7, brick)

## Mapeo de puertos (nombres kernel)

| Nombre kernel | Puerto fisico | Uso |
|---|---|---|
| eth0 | ether1 | Consola / acceso fisico (192.168.5.1) |
| eth1 | ether2 | Libre (configurable por Risp) |
| eth2 | ether3 | Libre |
| eth3 | ether4 | Libre |
| eth4 | ether5 | Libre |
| sw0 | — | Puerto CPU del switch (interno, oculto) |

Rename en boot: `rename-ports` (START=08, antes de network START=20).
PITFALL: renombrar en vivo con netifd corriendo tira la IP — usar UCI+init
y tener IP de respaldo 192.168.10.1/24 en otro puerto antes de tocar.

## Verificacion en el router (kernel-propio)

```sh
ip -br link
cat /proc/mtd          # particiones NAND
ubinfo -a              # UBI volumes
dmesg | grep -Ei 'dsa|mt7530|mt7621|nand|ubi'
ethtool eth0           # verificar cada puerto con cable
```

## MAC

La MAC del dispositivo NO debe usarse como identificador publico en docs.
Para netboot (dhcp-host) se configura en el host de recuperacion, no en el repo.
