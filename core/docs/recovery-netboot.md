# RiverOs — Recuperacion / Rollback (netboot)

## Principio

El initramfs de recuperacion corre en RAM y NO depende de la imagen
instalada. Ante cualquier imagen no arrancable, el RouterBOOT arranca por
Ethernet y se restaura desde ahi.

## Componentes

- Binario estable (netboot kernel): `/root/netinstall-openwrt/pkg/riveros-6.12.94-v20-min.config.bin` (4506f637, kernel 6.12.94 minimo)
- `restore.sh`: netboot initramfs 22.03.3 → sube GOOD → `sysupgrade -n`
- Loader dnsmasq: `/root/netinstall-openwrt` (`dhcp-boot=openwrt-22.03.3-initramfs-kernel.bin`)

## Procedimiento (host Linux aislado)

```sh
# 1. Host de recuperacion, interfaz dedicada (ej: enp3s0)
sudo dnsmasq --no-daemon --port=0 \
  --interface=enp3s0 --bind-interfaces \
  --enable-tftp --tftp-root=/srv/tftp \
  --dhcp-range=192.168.88.50,192.168.88.100,255.255.255.0,1h \
  --dhcp-boot=openwrt-22.03.3-ramips-mt7621-mikrotik_rb750gr3-initramfs-kernel.bin

# 2. Antes de conectar el router
sudo tcpdump -ni enp3s0 'port 67 or port 68 or port 69'

# 3. En el sistema de rescate (RAM)
uname -a; cat /proc/mtd; ip -br link; ip -br addr
dmesg | grep -Ei 'nand|ubi|mt7530|dsa'

# 4. Transferir y verificar
scp riveros-GOOD-25.12.5.bin root@192.168.5.1:/tmp/
ssh root@192.168.5.1 sha256sum /tmp/riveros-GOOD-25.12.5.bin

# 5. Instalar SOLO tras validar (consola fisica disponible)
sysupgrade -T /tmp/riveros-GOOD-25.12.5.bin   # test
sysupgrade -n /tmp/riveros-GOOD-25.12.5.bin   # -n = no conservar config
```

## Checklist rollback (primer kernel propio)

1. Apagar router. 2. Preparar DHCP/TFTP 22.03.3. 3. Etherboot temporal.
4. Arrancar en RAM. 5. Confirmar NAND + red. 6. Escribir imagen estable.
7. Arrancar desde NAND. 8. Restaurar config validada.

No considerar el proyecto terminado hasta ejecutar este rollback con exito.

## Prueba del KERNEL PROPIO por netboot (reversible, sin tocar NAND)

Artefacto: `/root/netinstall-openwrt/pkg/riveros-6.12.94-v20-min.config.bin`
(4506f637, kernel 6.12.94 minimo 957 =y — generado con core/scripts/build-kernel.sh).

1. Backup del dnsmasq: `cp /etc/dnsmasq.conf /root/netinstall-openwrt/backups/`
2. Config temporal `/root/netinstall-openwrt/dnsmasq-riveros.conf`:
   ```
   interface=<INTERFAZ_LAN>   bind-interfaces   port=0
   dhcp-range=192.168.5.10,192.168.5.50,255.255.255.0,12h
   dhcp-boot=riveros-6.12.94-initramfs-kernel.bin
   enable-tftp   tftp-root=/root/netinstall-openwrt
   ```
3. `dnsmasq --test` → `systemctl stop dnsmasq` → `dnsmasq --no-daemon
   --conf-file=/root/netinstall-openwrt/dnsmasq-riveros.conf` (primer plano)
4. Otra consola: `tcpdump -ni <IF> 'udp port 67 or 68 or 69'`
5. RouterBOOT arranca por Ethernet → kernel 6.12.94 + DTB + initramfs en RAM
6. Red del initramfs RiverOs PURO (sin scripts RiverOs): br-lan 192.168.1.1
   (NO eth0/192.168.5.1 — eso es del overlay). Acceso: ping/ssh root@192.168.1.1
   o desde serie: ip link (nombres reales DSA) + ip addr add manual
7. Validar: uname -a (6.12.94), dmesg (mt7621/gmac/mdio/mt7530/dsa/nand/ubi,
   sin oops/panic), cat /proc/mtd, ip -details link, mount (rootfs RAM,
   SIN UBI como raiz), busybox, dropbear, reboot -f (2 arranques = reproducible)
8. Comparar contra GOOD: diff proc-mtd / proc-partitions / ip-link
9. Fin: Ctrl-C en dnsmasq → `systemctl start dnsmasq` (vuelve el 22.03.3)

SOLO tras validar el initramfs en RAM: sysupgrade -T (desde el initramfs
RiverOs) del backups/riveros-PROPIO-6.12.94-sysupgrade.bin → si OK,
sysupgrade -n. NUNCA -v7. fwtool -i para inspeccionar metadatos antes.
