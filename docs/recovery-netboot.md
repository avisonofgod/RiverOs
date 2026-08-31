# RiverOs — Recuperacion / Rollback (netboot)

## Principio

El initramfs de recuperacion corre en RAM y NO depende de la imagen
instalada. Ante cualquier imagen no arrancable, el RouterBOOT arranca por
Ethernet y se restaura desde ahi.

## Componentes

- Binario estable: `/root/netinstall-openwrt/backups/riveros-GOOD-25.12.5.bin`
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
