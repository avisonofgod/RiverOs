# E2 v8 cierre sesion 2026-09-02 noche: test A/B d622152f + doc kernel DSA + via A

## Test A/B (watchdog desactivado) — RESULTADO POSITIVO PARCIAL
- init v6 con seccion watchdog COMENTADA (log "watchdog: DESACTIVADO (test
  A/B)"), sha d622152f en pkg. Netboot 19:03:
  - TFTP count 46, carrier PC=1.
  - DHCPDISCOVER -> DHCPACK 192.168.88.146 "RiverOs" (2 ciclos: transacciones
    2672647464 y 690368302) — wan CREADO y cliente DHCP vivo.
  - CONFIRMA la correlacion feed-watchdog: 2/2 boots SIN feed hacen DHCP; 6/6
    CON feed no crearon wan. Causa raiz de los boots "sin red" = feed WDT.
- PROBLEMA RESIDUAL (aun sin resolver al cierre): el router NO respondia ARP en
  .146 (ip neigh FAILED) ni en .1 (INCOMPLETE) con cable en ether1 carrier=1 —
  DHCPACK externo NO prueba que el bound aplico la IP. Posibles causas (sin
  log del router no se discrimino): default.script no corrio el bound /
  ifconfig wan fallo post-ACK / GMAC parcial (TX broadcast DHCP OK, unicast no)
  / el cable se movio a ether2 a mitad del ciclo (el usuario movio el cable
  para el diagnostico br-lan y el carrier en ether2 era 0 = switch LAN no
  operativo en ese boot).
- Switch LAN (MT7530): ether2 sin carrier en el boot d622152f => lan2-5 no
  linkearon (probe del switch no completo aunque gmac1/wan si). En v33 (mismo
  kernel/DTB) TODO funciono: br-lan eth0 lan2-5 lo wan (SSH OK).

## Cirugia / ing inversa con controles (tecnica Abdias)
- CONTROL VALIDO = bin de /root/netinstall-openwrt/versiones/funcionales/
  (netboot validado). v33-6c8492de netbooteado 18:50 -> DHCPACK .146 + SSH OK +
  netdevs completos => ROUTER SANO, kernel 6.12.94 NO es el problema, DTB
  IDENTICO al E2 (sha 59f682ee del .appended_dtb extraido con el objcopy de la
  toolchain: mipsel-openwrt-linux-musl-objcopy; el objcopy nativo x86 falla
  "Unable to recognise the format").
- CONTROL INVALIDO aprendido: el bin 22.03.3 copiado de
  /home/proyectos/openwrt-22.03.3/bin/... (6f28e406) NUNCA habia sido
  netbooteado -> fallo sin DHCP y NO probo nada. Usar solo bins funcionales
  validados como control.

## Documentacion kernel DSA (docs.kernel.org/networking/dsa/configuration.html)
- "The user interfaces depend on the conduit interface being up in order for
  them to send or receive traffic. ... when a DSA user interface is brought up,
  the conduit interface is automatically brought up. when the conduit interface
  is brought down, all DSA user interfaces are automatically brought down."
- El conduit (CPU port eth0 en RB750Gr3) se abre automaticamente al abrir un
  puerto DSA (kernel >= v5.12). Implicacion E2: si lan2-5 existen y el init los
  abre (ifconfig up), el conduit se abre solo; si lan2-5 no existen (switch no
  registro), no hay nada que abrir. wan = gmac1 + ethphy0 (phy dedicado, NO
  DSA) es independiente del conduit — por eso wan pudo hacer DHCP sin el switch.
- openwrt.org bloquea bots (Anubis); docs.kernel.org SI es accesible por curl
  (las paginas .html se pueden limpiar con sed 's/<[^>]*>//g').

## Duck.ai agotado (patron)
- 3 intentos bidi_newchat_duck.py el mismo dia: SENT pero poll final len=143
  (solo header UI, respuesta nunca llego). Releer con bidi_read_duck.py tras
  45-60s tampoco trajo respuesta. No es "duck.ai roto" (funciono en sesiones
  previas): es limite free/sesion agotada del dia. Fallback: groq-ask.sh de la
  skill second-opinion, o fuentes directas por curl (docs.kernel.org).

## Replanteo recomendado (via A, NO ejecutado al cierre)
- En vez de seguir puliendo el init standalone (replica pobre de netifd), usar
  el mecanismo DOCUMENTADO que v33 ejecuta: rootfs minimo con base-files preinit
  (/etc/preinit + lib/preinit/*.sh: 02_sysinfo, 30_failsafe_wait,
  70_initramfs_test, 99_10_run_init + lib/functions/{preinit,functions,system}
  .sh) + NUESTRO /init PID1 que monta lo basico, exporta INITRAMFS=1 PREINIT=1
  y ejecuta /etc/preinit DIRECTAMENTE (sin switch_root a procd). 70_initramfs_
  test ve INITRAMFS -> corre los hooks de la cadena initramfs (ahi va un hook
  99_red_manual RiverOs que arma la red: espera DSA, br-lan lan2-5, wan) ->
  preinit_ip_deconfig -> break -> vuelve al init (dropbear + loop). Sin procd/
  netifd/uci, pero la red la arma el preinit probado en este HW.
- Detalle del mecanismo: references/openwrt-initramfs-preinit-boot-mecanismo.md
  (fuente local: package/base-files/files/etc/preinit + lib/preinit/*.sh).

## Instrumentacion pendiente (Copilot, sin consola serie)
- Log por fases a un canal externo: init arranco / WDT (no) / wan encontrada /
  bridge / udhcpc / bound; si wan no existe, emitir por eth0 si existe.
- Tras el bound leer: /tmp/udhcpc.log, ifconfig wan, /proc/net/dev,
  /proc/net/route; /sys/kernel/debug/devices_deferred + dmesg | grep -Ei
  'defer|probe|mtk|mt7530|dsa|mdio|phy' distingue "probe fallo" de "open/DMA".
