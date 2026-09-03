# KERNELDESDE0 — RiverOs: kernel propio desde cero + problema red E2

Material consolidado para auditoria externa (Devin/IA) del trabajo de kernel
desde fuente y del problema de RED E2 en MikroTik RB750Gr3.

## Contexto

RiverOs = OpenWrt 25.12.5 minimizado para RB750Gr3 (SoC MediaTek MT7621,
mipsel_24kc, 256MB RAM, 16MB NAND, RouterBOOT v6, switch DSA MT7530,
5 puertos GbE: wan + lan2-5, eth0 = conduit/master DSA).
Kernel base funcional: 6.12.94 propio (config v33: 727 =y / 21 =m, sha 6c8492de)
— el UNICO binario funcional estable hasta ahora.
Repo: https://github.com/avisonofgod/RiverOs (rama master + kernel-propio)

## Que es E2 (cronica)

Intento de firmware SIN framework OpenWrt: kernel propio + rootfs con init
standalone (busybox + ip + udhcpc), probado en netboot RouterBOOT (TFTP).
OBJETIVO original: todo-en-RAM sin uci/procd/netifd.
RESULTADO: DESCARTADO como firmware — red wan solo 2/10 boots. Con framework
(procd+netifd): 2/2. Causa: probe del bloque ethernet MT7530/mtk_soc_eth
NO-DETERMINISTA en reboot caliente (~85-90% falla); netifd lo tolera
(espera netdevs + hotplug), init standalone NO puede replicarlo.
Conclusion: el framework (netifd) es REQUISITO para red confiable en este
hardware, o hay que resolver el probe del driver (tema abierto, ver abajo).

## Rutas clave en el repo

- core/scripts/build-kernel.sh         — build kernel 6.12.94 + initramfs + gate
- core/scripts/build-rootfs-e2.sh      — pipeline E2 (6.12, standalone)
- core/scripts/build-rootfs-e2-2203.sh — pipeline E2 kernel 5.10.161 (arbol 22.03.3)
- core/scripts/build-riveros-2203.sh   — orquesta E2 5.10
- core/rootfs-riveros/init             — init standalone/via A (reescrito N veces)
- core/rootfs-riveros/lib/preinit/     — 10_indicate_preinit, 70_initramfs_test, 99_red_manual
- core/rootfs-riveros/initramfs-nodes.txt — nodos /dev (watchdog, ptmx)
- core/configs/kernel/mt7621-rb750gr3.config — config kernel v33 (727/21)
- core/configs/kernel/mt7621-rb750gr3-risp.config — v33 + dataplane =y (nft/ppp/htb/ifb/tun/wg)
- core/configs/target-rb750gr3.config  — target v33 (42 paquetes)
- core/configs/target-rb750gr3-risp.config — target risp (dataplane userspace)
- targets/mips/devices/mikrotik-rb750gr3/files/ — base-files (network, init.d, preinit)
- patches/kernel/                      — parches kernel propios
- core/docs/                           — arquitectura, hardware, kernel-build, netboot
- KERNELDESDE0/investigaciones/        — cronica completa sesiones E1/E2 v1-v9 (ESTA carpeta)

## Errores de red E2 documentados (resumen)

1. PROBE DSA NO-DETERMINISTA (causa raiz): ethernet ausente ~85-90% en reboot
   caliente; sin fix userspace conocido. detalle: investigaciones/sesion-e2-v8-*.md
2. WATCHDOG MT7621: RouterBOOT deja WDT activo (~65s); init standalone debe
   alimentarlo (fd + newline cada 10s, sin magic close). Alimentar via
   mt7621_wdt detiene el WDT del bootloader en probe -> NO alimentar en probe.
   detalle: investigaciones/sesion-e2-v7-*.md
3. UDHCPC APPLET: build-rootfs-e2.sh nunca creaba applet udhcpc -> /init lanzaba
   binario inexistente = fallo oculto sin DHCPDISCOVER.
4. IP LOADER PERDIDA: servidor netboot sin IP 192.168.88.2/24 en enp0s31f6 =
   dnsmasq vivo pero sin responder BOOTP (falso negativo). Restaurar:
   ip addr replace 192.168.88.2/24 dev enp0s31f6
5. ETH0-CONDUIT UP: eth0 (master DSA) debe estar UP antes que puertos DSA
   (secuencia kernel.org); aplicado a 99_red_manual + init, insuficiente.
6. DTBs/CHOSEN: variantes con chosen/bootargs ip= colgaban (ver investigaciones/).

## Dudas / faltantes / pendientes para Devin

- POR QUE falla el probe MT7530/mtk_soc_eth en reboot caliente (~85-90%) y
  existe fix de driver/DTB (reset del switch, MDIO, timing) — el fix de
  userspace no existe; netifd solo lo tolera. Si se arregla el probe, el
  firmware sin framework (E2) es viable.
- Verificar si en cold boot (flash, power real) el probe es determinista
  (nunca probado: E2 solo se probo via netboot = reboot caliente).
- Revision de core/rootfs-riveros/init + lib/preinit/99_red_manual.sh
  (correccion de red manual sin netifd).
- El E2 quedo SIN commitear (usuario: "no sirve como firmware") — este
  KERNELDESDE0 lo documenta; los archivos core/rootfs-riveros + scripts 2203
  se commitean junto con esta carpeta para que queden trazables.

## Como ayudar (pedido)

1. Auditar la causa raiz del probe DSA (items arriba) con propuesta concreta
   (parche kernel/DTB o config) y plan de verificacion en hardware.
2. Revisar init/preinit standalone: errores, orden, faltantes.
3. Evaluar si el enfoque E2 (sin framework) tiene sentido con el probe resuelto.
