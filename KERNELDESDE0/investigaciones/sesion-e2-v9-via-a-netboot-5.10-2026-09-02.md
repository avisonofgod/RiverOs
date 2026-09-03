# Sesion E2 v9 2026-09-02 noche — via A (preinit) netboot fallido, decision kernel 5.10

## Test A/B confirmado (19:03, sha d622152f — init v6 con watchdog COMENTADO)
- Resultado: DHCPDISCOVER -> DHCPACK 192.168.88.146 "RiverOs" x2 (transacciones
  690368302, 2672647464). Count TFTP estable 46 (sin WDT reset). El PC con
  carrier=1.
- => CAUSA RAIZ confirmada: el feed del watchdog en /init (mknod c 10 130 +
  subshell fd3 write '\n' cada 10s) impedia la red. 6/6 boots con feed sin red,
  2/2 sin feed con DHCP. Mecanismo sin establecer (registros WDT TMR* en
  0x1e000100 vs ETHSYS_* del ethernet no colisionan segun analisis de codigo de
  Copilot; probable interaccion temporal/estado, no colision de registros).
- Residuo del boot A/B: wan hizo DHCP pero NO respondio ARP (.146 FAILED en ip
  neigh; .1 INCOMPLETE); switch LAN sin carrier en ether2 (carrier=0 al mover el
  cable). Lectura: inicializacion PARCIAL del bloque ethernet — gmac1/wan vivo
  para broadcast DHCP, MT7530/DMA no completo para unicast/LAN. default.script
  validado localmente (comandos bien formados: NETMASK 255.255.255.0, GW
  ${router%% *}, route add default gw X dev wan). Sin /tmp/udhcpc.log accesible
  no se distinguio bound-fallido de driver-parcial.

## Copilot CLI como agente de construccion (flujo que funciono)
- Abdias autorizo edicion directa de Copilot: `copilot --resume=<id> -p
  "$(cat prompt.txt)" --allow-all-paths --allow-all-tools` (pty, background,
  notify). Copilot edito core/rootfs-riveros + core/scripts y corrio el build
  local. Costo alto (AI credits 16.65, 4h18m en el analisis 2203) — usar para
  construcciones/analisis grandes, Hermes para ediciones puntuales.
- Backup previo a /tmp/e2-viaA-backup/ antes de dar permisos de edicion.

## Via A construida por Copilot (sha 1e40cbfb, gate PASS)
- Arquitectura: init PID1 (core/rootfs-riveros/init) monta proc/sys/devpts,
  exporta INITRAMFS=1 PREINIT=1, ejecuta /etc/preinit del base-files (NO
  switch_root a procd). /etc/preinit: 70_initramfs_test (INITRAMFS=1) ->
  boot_run_hook initramfs -> 99_red_manual (espera wan+lan2-5 90s, ifconfig up
  provisional) -> preinit_ip_deconfig -> break -> retorno al init -> br-lan +
  udhcpc -t 0 + dropbear. SIN feed watchdog.
- Archivos: core/rootfs-riveros/lib/preinit/{10_indicate_preinit,
  70_initramfs_test,99_red_manual}. El 10_indicate_preinit propio redefine
  preinit_ip_deconfig con ifconfig (sin applet ip): `[ -n "$pi_ifname" ] ||
  return 0` — pi_ifname nunca se setea (falta 02_sysinfo) => no limpia la red
  provisional.
- build-rootfs-e2.sh ahora copia del root-ramips: etc/preinit,
  lib/functions.sh, lib/functions/preinit.sh, lib/functions/system.sh +
  passwd/shadow/group, y del repo los hooks. Hard-fail si falta algo. Rootfs
  1.6M/17 archivos.
- cpio verificado: etc/preinit, lib/functions.sh, lib/functions/preinit.sh,
  lib/functions/system.sh, lib/preinit/{10,70,99} dentro del bin.

## Netboot via A (20:02, sha 1e40cbfb) — FALLIDO
- Count TFTP 47 estable, sin DHCP a los 4 min, carrier=1. Igual que los E2
  standalone. => el rootfs/preinit NO es la causa. El probe del ethernet/DSA
  del kernel 6.12.94 + RouterBOOT es NO DETERMINISTA (~80-90% de boots sin wan)
  independiente del rootfs: v33 rootfs completo = 1/1 (18:50 SSH OK), E2
  (standalone + via A) = wan/DHCP solo 2/9. Sin fix userspace (binds cada 60s,
  waits 600s, DTB limpio, preinit — nada lo cambia).

## Documentacion del funcionamiento correcto (docs.kernel.org DSA)
- https://docs.kernel.org/networking/dsa/configuration.html: los puertos DSA
  dependen del conduit (CPU port) UP; desde v5.12 abrir un puerto DSA sube el
  conduit automaticamente; bajar el conduit baja todos los puertos. netifd
  aporta la secuencia de activacion/reintentos (RTM_SETLINK -> ndo_open ->
  mtk_open -> DMA) que un init standalone replica mal. El rootfs NO cambia el
  probe builtin pero SI puede afectar ventanas de deferred probe y activacion.
- duck.ai agotado (3 intentos, respuesta vacia — solo header UI); fallback:
  curl docs.kernel.org (sin Anubis) + groq-ask.sh.

## Decision final (Abdias "ADELANTE USA COPILOT")
- Validar el rootfs E2 sobre kernel 5.10.161 (arbol openwrt-22.03.3), el kernel
  que el proyecto valido CONSISTENTE con red. El 6.12.94 queda como issue de
  kernel separado (probe mtk_eth/mt7530 post-RouterBOOT; candidatos: reset del
  switch/PHY sequencing, comparar contra 5.10).
- Datos del arbol 22.03.3: K=$OPENWRT22/build_dir/target-mipsel_24kc_musl/
  linux-ramips_mt7621/linux-5.10.161 (.config.set existe), DTB image-*, TC
  staging_dir/toolchain-mipsel_24kc_gcc-11.2.0_musl, root-ramips con preinit,
  INITRAMFS_COMPRESSION_LZMA=y, entry ELF 0x80b71000.
- Copilot construia core/scripts/build-riveros-2203.sh + build-rootfs-e2-2203.sh
  al cierre de sesion — PENDIENTE de resultado, NO validado.
