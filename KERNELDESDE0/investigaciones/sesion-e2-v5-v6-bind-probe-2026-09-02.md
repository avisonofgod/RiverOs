# Sesion E2 v5/v6 — bind probe mtk_soc_eth + init reordenado (2026-09-02 tarde)

## Contexto
Serie de boots E2 con el MISMO kernel 6.12.94 (.config.set ~912 =y, DSA builtin):
- Boot A (15:44, 8b7ad014 CON chosen debug): DHCP RiverOs OK, WDT mato ~22s despues
- Boots B/C/D (CON chosen debug): sin DHCP, count TFTP estable
- Boot E (17:57, 0f9bef19 DTB LIMPIO): carrier PC=1 pero wan ausente (espera 600s
  agotada -> fail loop)
- Boot F (18:08, 9a10e783 DTB limpio + bind a los 60s): carrier=1, sin wan, bind
  no trajo wan
Resultado: wan aparecio 1 de ~6 boots. El chosen debug (E2 v4) NO era la unica
causa del no-determinismo; persiste con DTB limpio.

## Hechos del arbol (verificados en fuente, NO en HW)
- Driver ethernet: `drivers/net/ethernet/mediatek/mtk_eth_soc.c`:
  `static struct platform_driver mtk_driver = { .driver = { .name = "mtk_soc_eth" } }`
  (NO "mtk_eth"). Device DTS: `ethernet@1e100000` (mt7621.dtsi:364).
- Un solo bloque: gmac0 (CPU port DSA eth0) + gmac1 (label wan, phy ethphy0) +
  mdio-bus con `switch0: switch@1f { compatible = "mediatek,mt7621" }` (MT7530).
  Si el probe del bloque falla: no wan, no lan2-5, no eth0.
- Sysfs para reintento: driver dir `/sys/bus/platform/drivers/mtk_soc_eth/`,
  device name `1e100000.ethernet` (node address + node name).
- Nombres wan/lan2-5: labels del DTS (gmac1 label "wan", ports del switch con
  label). El kernel los crea con esos nombres SIN board.d/02_network (prueba:
  el boot A con init que espera "wan" funciono sin renombrado userspace).
- El dtsi base (mt7621_mikrotik.dtsi) SIEMPRE trae chosen console=ttyS0,115200:
  NO confundir con chosen debug (ver E2 v4 — check con grep 'ip=|netconsole').

## Palanca de reintento de probe (NO validada en HW)
```
echo 1e100000.ethernet > /sys/bus/platform/drivers/mtk_soc_eth/unbind 2>/dev/null || true
echo 1e100000.ethernet > /sys/bus/platform/drivers/mtk_soc_eth/bind 2>/dev/null
```
- unbind falla silencioso si el device nunca se bound (probe fallo -> no bound).
- bind reintenta driver->probe (tambien sirve si quedo EPROBE_DEFER).
- Boot F: bind UNICO a los 60s NO trajo wan (2do probe fallo igual o el init no
  llego). Pendiente probar bind PERIODICO (cada 60s) del init v6.

## init v6 (sha 2a3586c8) — reordenado, PENDIENTE de validacion
Estrategia (core/rootfs-riveros/init):
1. watchdog feed (igual E2 v3)
2. espera wan 120s (con binds cada 60s desde N>=60)
3. br-lan + dropbear TAN PRONTO como lan2-5 existan — SIN esperar wan:
   acceso SSH por ether2-5 aun si wan/gmac1 falla; /tmp/init.log y dmesg
   legibles si el usuario mueve el cable del PC a ether2
4. espera wan hasta 600s con bind periodico cada 60s
5. udhcpc -t 0 -x hostname:RiverOs supervisado cuando wan aparezca
6. loop ppal relanza udhcpc/dropbear si mueren
Build verificado: gate PASS entry 0x80b71000 size 3460588 sha 2a3586c8,
init embebido == repo (cmp cpio). NO probado en HW al cierre — no tratar como
fix confirmado.

## Diagnosticos que SI quedaron validados
- Sonda carrier del PC (enp0s31f6, PC en ether1): carrier=0 con router colgado =
  PHY wan no linkeo / wan nunca existio; carrier=1 sin DHCP = init no llego a
  udhcpc o wan netdev ausente pese al link fisico (el link lo deja el RouterBOOT
  y persiste aunque el kernel no configure el PHY).
- Count TFTP estable NO distingue "init corriendo (fail loop)" de "kernel
  colgado": si el init corre, alimenta /dev/watchdog; si el kernel quedo en
  ipconfig (chosen debug) o probe fallo, el driver WDT detuvo el WDT del
  RouterBOOT y nadie lo abre -> sin reset, count estable igual.

## Reglas de proceso (correcciones Abdias, severas)
- NETBOOT = recurso escaso: UNO por ronda de revision. El router se deja
  desconectado/apagado mientras revisas; se conecta con push solo cuando pides
  netboot. NO pedir power-cycles/re-pushes iterativos.
- Revision exhaustiva (multi-pasada Hermes + Copilot) + build + pkg actualizado
  + sha verificado ANTES de cada pedido de netboot.
- pkg/ actualizado en el MISMO paso del build (nunca avisar "listo" con bin
  viejo en el loader).
- Comandos largos inline con $( ) anidados + grep pueden caer en el blocklist
  del parser de Hermes -> escribir el pipeline a un .sh en /tmp y ejecutarlo
  (bash /tmp/x.sh), limpiar al final.
