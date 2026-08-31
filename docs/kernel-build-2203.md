# RiverOs — build 22.03.3 (ruta B: ingeniería inversa del funcional)

Estado: 2026-08-31. Kernel 6.12.94 propio NO arranca por netboot (solapamiento
de descompresión: vmlinux 12.9MB a 0x80001000 pisa el payload en 0x80b73c80).
DECISIÓN: reducir el 22.03.3 funcional (kernel 5.10.161) de a poco.

## Árbol y config

- Árbol: /home/proyectos/openwrt-22.03.3 (clone depth1 v22.03.3)
- .config: target ramips/mt7621 + mikrotik_routerboard-750gr3 + INITRAMFS=y
- Reducción: 86 → 66 → 39 paquetes (quitar luci/firewall/dnsmasq/nf-*/usb-*)

## Parches aplicados (CRÍTICOS)

1. `build_dir/.../linux-5.10.161/arch/mips/boot/compressed/Makefile`
   VMLINUZ_LOAD_ADDRESS := 0x80b71000 (fijo, NO calc_vmlinuz_load_addr)
   - El calc da 0x80a71000 con initramfs reducido (entry rechazado por RouterBOOT)
   - En 5.10 NO existe CONFIG_ZBOOT_LOAD_ADDRESS (símbolo 5.16+)

2. `target/linux/ramips/mt7621/base-files/lib/preinit/99_red_manual.sh`
   - Red manual en PREINIT (brctl/ifconfig + dropbear -R)
   - hook: boot_hook_add initramfs red_manual  ← CRÍTICO
   - NO usar preinit_main: el 70_initramfs_test hace `break` y corta los hooks posteriores

3. `target/linux/ramips/mt7621/base-files/etc/shadow`: root rbadmin2026 ($6$)

4. `target/linux/ramips/mt7621/base-files/etc/config/network` + rc.local: OBSOLETOS
   (el /etc/rc.d/ del initramfs queda VACÍO — los postinst no corren en el build;
   ningún servicio rc.d arranca: ni network ni dropbear)

## Lecciones (pitfalls)

- files/ raíz del árbol NO se copia al rootfs (solo funciona en ImageBuilder).
  Usar target/linux/ramips/mt7621/base-files/
- Puertos DTB 22.03.3: wan=ether1, lan2-lan5=ether2-5 (NO hay lan1)
- IP del servidor 192.168.88.2 choca con wan del router: usar .3
- dnsmasq de netboot se atasca tras horas: reiniciar loader
- enp0s31f6 puede quedar NO-CARRIER (cable) — el "ruido DHCP" 98:e7:43 ES el propio PC
- make check NO existe en OpenWrt (sin suite); verificación = readelf + netboot físico

## Validado

- 86 paq (5.19MB): bootea + red + SSH ✓
- 66 paq (4.58MB): bootea + red + SSH ✓
- 39 paq (4.14MB, 00d493d7): pendiente netboot
- SSH: root@192.168.88.3 rbadmin2026 (cable en ether1=wan)

## Duck.ai

- Límite diario 2026-08-31 20:00. Chat nuevo tras llenarse.
- Herramienta: scripts/bidi_chat_duck.py (click trusted por coordenadas)

## SOLUCION DEL KERNEL 6.12 (2026-08-31)

Load-y 0xffffffff81000000 (16MB) FUE INSUFICIENTE: el vmlinuz (5.17MB con
initramfs) cargado en 0x80b71000 ocupa hasta 0x810A0000 (16.6MB); el destino
de descompresion 0x81000000 queda DENTRO del vmlinuz → solape → kernel sin red.

FIX: load-y = 0xffffffff82000000 (32MB) — parche 935-load-y-mt7621-82000000.patch
Destino 0x82000000 + vmlinux 13.4MB = 0x82D60000 < vmlinuz fin 0x810A0000 ✓
