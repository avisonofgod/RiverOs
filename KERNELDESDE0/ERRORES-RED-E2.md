# ERRORES-RED-E2.md — Bitacora de errores, red y kernel desde cero (RB750Gr3)

Fecha: 2026-09-02/03. Hardware: MikroTik RB750Gr3, MT7621 (mipsel_24kc,
880MHz, 2 nucleos), 256MB RAM, 16MB NAND, RouterBOOT v6, MAC dc:2c:6e:7b:2a:76.
Red: switch DSA MT7530 (puertos wan + lan2-5; eth0 = conduit/master, NO agregar
a bridge). Netboot: RouterBOOT -> BOOTP/TFTP (loader dnsmasq 192.168.88.2/24,
BOOTFILE fijo riveros-6.12.94-initramfs-kernel.bin, cliente .145-.148).

## ERROR 1 — PROBE ETHERNET NO-DETERMINISTA (causa raiz, SIN RESOLVER)

Sintoma: al netbootear, el kernel arranca pero el bloque ethernet
(MT7530/mtk_soc_eth) no aparece: sin eth0, sin puertos DSA, sin red.
Frecuencia: reboot caliente ~85-90% falla (10 pruebas E2: solo 2 con wan OK;
mismo dia v33 framework: 2/2 OK).
No es el rootfs: mismo kernel casi identico (v33: 727=y/21=m vs E2 .config 912=y;
los 21 =m identicos; 187 =y extra = NET_VENDOR_* codigo muerto inofensivo).
Intento userspace: esperas de netdev hasta 600s, reintentos, eth0-conduit UP
primero (secuencia kernel.org) -> NO resuelve. netifd tolera (espera infinita +
hotplug cuando el netdev aparece); init standalone no.
Pregunta abierta para Devin: fix en driver/DTB del probe (reset switch/MDIO/
timing/deferred probe) o config; verificar cold boot en flash (nunca probado).

## ERROR 2 — WATCHDOG MT7621 en netboot

RouterBOOT deja el watchdog MT7621 activo (~65s real). Sin procd nadie lo
alimenta -> reset ~60s (parecia "re-descarga TFTP").
Fix aplicado: init alimenta /dev/watchdog (c 10 130) con fd abierto + newline
cada 10s, SIN magic close (desactivaria WDT).
Hallazgo CRITICO: si el DRIVER mt7621_wdt hace probe (CONFIG_MT7621_WDT=y) y se
alimenta via kernel -> detiene el WDT del bootloader DURANTE el probe =
6/6 boots SIN red. Sin alimentar en probe: 2/2 DHCP OK. Regla: NO alimentar
WDT en init (dejarlo al bootloader; HANDLE_BOOT=y).
Evidencia: sesion-e2-v7-control-correlacion-watchdog-2026-09-02.md

## ERROR 3 — UDHCPC APPLET FALTANTE (fallo oculto)

build-rootfs-e2.sh nunca creaba el symlink/applet udhcpc en busybox -> /init
lanzaba binario inexistente en background = sin DHCPDISCOVER silencioso.
Fix: crear applet; validar applets contra CONFIG_BUSYBOX_DEFAULT_* del .config
OpenWrt (strings NO fiable: hostname no compilado; TR=y restaurado).

## ERROR 4 — SERVidor netboot sin IP (falso negativo)

El netboot del usuario era CORRECTO pero el server estaba roto: la IP
192.168.88.2/24 ya no estaba en enp0s31f6; dnsmasq vivo (pid) en :67/:69 pero
sin IP no respondia BOOTP. Restaurar: ip addr replace 192.168.88.2/24 dev
enp0s31f6. Leccion: verificar IP antes de cada ronda.

## ERROR 5 — ORDEN DSA: eth0 (conduit) UP primero

Fuente: duck.ai + kernel.org (DSA docs): eth0 master DEBE estar UP antes que
los puertos DSA (lan2-5/wan). Aplicado a 99_red_manual + init (pipelines 6.12 y
5.10). Mejora real pero INSUFICIENTE (no arregla el probe no-determinista).

## ERROR 6 — DTBs / chosen / bootargs

Variantes de DTB con chosen/bootargs (ip=... ipconfig) colgaban el boot
(espera de red en init antes de tiempo). Detalle:
dtb-chosen-ipconfig-boots-colgados-2026-09-02.md

## ERRORES DE PIPELINE/BUILD (2026-09-03, kernel risp)

- build-kernel.sh no compilaba los paquetes del target config (solo instalaba
  ipks existentes): fix agregando make package/compile (paso 3b).
- kmod-sched del target rompia package/compile (sch_*.ko =m auto-agregados
  piden libcrc32c.ko que no se provee con LIBCRC32C=y): fix quitando kmod-sched
  (tc solo requiere kmod-sched-core) y pasando WIREGUARD/LIBCRC32C a =y.
- curl fallaba "missing libcurl.so.4": el .config se copiaba SIN make defconfig
  (las DEPENDS tipo libcurl nunca se materializaban): fix agregando
  make defconfig tras el cp del target config.

## BUILD KERNEL: NUMEROS CLAVE

- Gate E1: entry 0x80b71000, seccion .appended_dtb, size < 0x6aa000 (6.66MiB),
  CONFIG_MT7621_WDT=y. Fallo de gate = no se sirve a pkg.
- Shas 2026-09-02 (E2): 8b7ad014 (3,459,988B) -> a238e502 -> 2fd2c0c7 ->
  e6fb9bc3 -> 1e40cbfb (via A 6.12, 3,467,500B) -> 5.10: 62ce43e9 (3,336,672B)
  -> bb3a7b03 -> 8f2f68c6 -> f2e4701b (3,336,960B). v33 = 6c8492de141d...
  (4.2MB, el funcional). Risp F2 = 28200332 (4.3MB, dataplane =y validado).
- v33: 727 =y / 21 =m. .config.set 912 =y. Reduccion: NET_VENDOR_* off =
  compile 16x menor.

## HERRAMIENTAS / ENTORNO (para reproducir)

- Arbol OpenWrt: /home/proyectos/openwrt (NETEST, kernel 6.12.94)
  y /home/proyectos/openwrt-22.03.3 (kernel 5.10.161, gcc-11.2).
- Loader netboot: /root/netinstall-openwrt/ (dnsmasq, log, loader-riveros.sh,
  pkg/, versiones/funcionales/v33-6c8492de/).
- SSH al router netbooteado: sshpass -p $ROUTER_PASS (credenciales .env);
  cliente DHCP aparece como .145-.148 hostname RiverOs.
- Netboot = recurso escaso: 1 push por ronda; router se conecta con PUSH
  (power normal = beep loop). No pedir power-cycles repetidos.
