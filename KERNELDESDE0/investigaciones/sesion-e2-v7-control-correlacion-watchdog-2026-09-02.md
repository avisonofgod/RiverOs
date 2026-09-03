# Sesion E2 v7: control v33 OK + correlacion feed-watchdog (2026-09-02 cierre)

## Contexto
7 boots E2 (kernel 6.12.94, .config.set sano, DTB limpio) en un dia:
- Boot A (15:44, sha 8b7ad014, SIN feed watchdog): DHCPDISCOVER->DHCPACK .145
  "RiverOs" OK (unico exito E2 del dia). Init: fix udhcpc symlink, sin WDT.
- Boots B-G (a238e502, 2fd2c0c7, e6fb9bc3, 0f9bef19, 9a10e783, 2a3586c8, todos
  CON feed watchdog en /init): NINGUNO dio red (sin wan, sin lan2-5, sin DHCP).
  Power real en C/D/E/F/G (desconexion previa al push).

## Cirugia de control (separar variables)
1. Control 22.03.3 del arbol (openwrt-22.03.3/bin/..., sha 6f28e406): FALLO sin
   DHCP. PERO era un build NUNCA netbooteado -> control INVALIDO, no probo nada.
   Leccion: control = bin YA validado por netboot (versiones/funcionales/).
2. Control v33-6c8492de (versiones/funcionales/v33-6c8492de/, canonico que booteo
   el 2 sep 02:46): DHCPACK .146 "RiverOs" + SSH OK + netdevs completos
   (br-lan eth0 lan2 lan3 lan4 lan5 lo wan) + kernel 6.12.94.
   => ROUTER/HW SANO. Kernel 6.12.94 NO es el problema. Diferencia = rootfs E2.

## Descarte por ing inversa (datos locales, sin netboot)
- Configs kernel: 5.10.161 (22.03.3) y 6.12.94 tienen drivers de red =y builtin
  (NET_MEDIATEK_SOC, NET_DSA, NET_DSA_MT7530, MEDIATEK_GE_PHY, MDIO_BUS,
  PHYLIB, NET_SWITCHDEV). Hipotesis "kmods tarde vs builtin temprano" DESCARTADA.
- DTB: extraer .appended_dtb con objcopy de toolchain
  (TC/bin/mipsel-openwrt-linux-musl-objcopy; objcopy nativo x86 falla con
  "Unable to recognise the format" en ELF MIPS). v33 vs E2 = sha IDENTICOS
  (59f682ee, 12803 B). DTB no es la diferencia.
- Drivers =y en ambos configs + DTB identico + kernel 6.12.94 OK en v33 =>
  queda el rootfs/initramfs E2 como variable.

## Correlacion 100%: feed watchdog <-> fallos
- 8b7ad014 (sin seccion watchdog): boot A red OK (power real).
- 6 bins CON feed (mknod c 10 130 + subshell fd3 write '\n' cada 10s):
  6/6 fallos sin red.
- El feed se anadio por la hipotesis "RouterBOOT deja WDT activo ~60s y nadie lo
  alimenta" (patron: boot A murio ~22s post-DHCP con TFTP re-descarga a .1).
  REVISION: ese reset pudo ser un push del usuario, no WDT; y el driver
  mt7621_wdt DETIENE el WDT del bootloader en su probe (boot B sin feed vivio
  8+ min sin re-descarga => sin abrir /dev/watchdog el WDT no corre).
- Mecanismo del feed rompiendo el ethernet: NO establecido. Hipotesis: el
  open/start del WDT (registros del sysc 0x1e0000xx, compartido con
  resets/clocks del ethernet MT7621) interfiere con el probe mdio/mtk_eth.

## Test A/B (estado al cierre: PENDIENTE netboot, NO es fix confirmado)
- init v6 con seccion watchdog COMENTADA (log "watchdog: DESACTIVADO (test A/B)")
  -> sha d622152f en pkg (gate PASS, cpio verificado).
- Si d622152f da red: causa raiz = feed watchdog; retirarlo del init y
  documentar el mecanismo.
- Si d622152f falla: el feed no era la causa; el no-determinismo del probe
  mtk_soc_eth sigue abierto (siguientes pasos posibles: bind periodico ya en el
  init, kernel 5.10 con rootfs E2, u obtener dmesg por consola/netconsole
  imposible cuando todo el ethernet esta muerto).

## Datos de arbol (driver ethernet MT7621)
- Platform driver: mtk_soc_eth (NO mtk_eth), device 1e100000.ethernet.
- Un solo bloque: gmac0 (CPU eth0 DSA) + gmac1 (=wan, phy ethphy0) + mdio-bus
  con switch0 MT7530 (switch@1f, compatible mediatek,mt7621).
- Si el probe del bloque falla: no wan, no lan, no eth0. Nombres wan/lan2-5 via
  label del DTS (sin board.d el kernel los crea igual).
- Reintento userspace: echo 1e100000.ethernet > .../mtk_soc_eth/unbind (|| true)
  + .../bind (reintenta probe). NO validado (boot F con bind unico a los 60s no
  trajo wan).

## Sondas sin consola usadas
- carrier del PC (enp0s31f6): 0 con router "colgado" + chosen debug = PHY wan no
  linkeo/ipconfig; 1 sin DHCP = init no llego a udhcpc o wan netdev ausente
  (link fisico del RouterBOOT persiste aunque mtk_soc_eth no probe).
- count "tftp: sent" estable = kernel vivo sin panic; no distingue init
  fail-loop de kernel colgado (WDT parado por driver si nadie abre el nodo).
