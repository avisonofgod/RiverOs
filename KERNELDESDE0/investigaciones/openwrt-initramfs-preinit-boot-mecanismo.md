# Boot initramfs OpenWrt — mecanismo real (investigado 2026-09-02, Duck.ai + fuentes locales)

Contexto: depurar por que un /init RiverOs standalone no levantaba la red DSA en
RB750Gr3 mientras el binario funcional (rootfs OpenWrt completo) si. La respuesta
no estaba en el init: estaba en la ARQUITECTURA de boot OpenWrt. Este doc es el
mapa para E2 (rootfs RiverOs propio).

Fuente local primaria (leer antes de teorizar):
- package/base-files/files/etc/preinit
- package/base-files/files/lib/functions/preinit.sh (boot_hook_*)
- package/base-files/files/lib/preinit/*.sh (orden 00..99)
- target/linux/generic/other-files/init (el /init del initramfs)

openwrt.org BLOQUEA bots (Anubis, "Access Denied"). Duck.ai (second-opinion skill)
si funciona como canal de investigacion; pedirle el mecanismo con nombres de
archivo exactos y contrastar contra el arbol local.

## Secuencia de boot initramfs (kernel 6.x, procd)

1. Kernel monta initramfs como / y ejecuta /init (other-files/init):
   `export INITRAMFS=1`; `mount -t tmpfs tmpfs /new_root`; `cp -pr` directorios
   minimos; `exec switch_root /new_root /sbin/init`.
2. /sbin/init = procd (paquete procd). Deteccion de initramfs = variable
   `INITRAMFS=1` (NO un mount). procd fase inicial: monta proc/sys/dev,
   exporta `PREINIT=1`, ejecuta `/etc/preinit` como hijo.
3. /etc/preinit: primera linea `[ -z "$PREINIT" ] && exec /sbin/init` protege de
   ejecucion accidental. Con PREINIT=1 continua: source functions.sh/preinit.sh/
   system.sh, inicializa 5 cadenas de hooks:
   `preinit_essential, preinit_main, failsafe, initramfs, preinit_mount_root`,
   luego `. /lib/preinit/*` (registra funciones con boot_hook_add) y ejecuta
   `boot_run_hook preinit_essential` + `boot_run_hook preinit_main`.
4. boot_hook_* : init/run/run_hook con listas en variables exportadas; el orden
   real NO es el alfabetico del nombre (boot_hook_add antepone segun splice).
5. Dentro de preinit_main, hooks tipicos en orden funcional: consola/devs,
   failsafe wait, `70_initramfs_test`, preinit_mount_root, mount root real,
   restore config, `99_10_run_init`.
6. 70_initramfs_test: si `INITRAMFS` no vacio -> `boot_run_hook initramfs` (aqui
   corre 99_red_manual.sh = red temprana provisional) -> `preinit_ip_deconfig`
   (limpia la IP provisional) -> `break` (corta el bucle de hooks de preinit_main;
   NO se ejecutan los hooks posteriores: mount_root, 99_10_run_init).
7. CLAVE (lo que se malentendia): el break NO mata procd. Termina /etc/preinit;
   procd inicial sigue vivo como PID1 y arranca el procd DEFINITIVO -> lee
   /etc/inittab -> `::sysinit:/etc/init.d/rcS S boot` -> servicios /etc/rc.d/S*
   (S40network) -> netifd+udhcpc.
8. Por eso el binario funcional (.145) tenia netifd+udhcpc: NO era 99_red_manual,
   era el boot COMPLETO de OpenWrt sobre initramfs. 99_red solo da red temprana
   que luego preinit_ip_deconfig limpia y netifd reconfigura.
9. 99_10_run_init en esta rama solo hace preinit_ip_deconfig; el mount del root
   real lo hacen hooks anteriores (80_mount_root). En initramfs se queda en RAM.

Flujo completo flash: kernel -> procd -> PREINIT=1 -> /etc/preinit ->
preinit_main -> mount squashfs+overlay -> fin preinit -> procd definitivo ->
inittab/rcS -> servicios.
Flujo initramfs OpenWrt: kernel -> /init -> INITRAMFS=1 -> switch_root procd ->
preinit -> 70_initramfs_test -> hooks initramfs (99_red) -> break -> procd
definitivo -> rcS -> netifd (todo en RAM).
Initramfs standalone minimo: kernel -> /init propio -> mounts -> mdev -s ->
espera interfaces DSA -> bridge + WAN -> udhcpc -> dropbear -> wait PID1.

## Por que un /init standalone con ifconfig/udhcpc FALLA en DSA MT7621

El kernel/driver DSA crea los puertos (lan2..lan5, wan) y netdevices SOLO; NO
crea br-lan ni decide agrupaciones: eso es userspace (netifd via
/etc/config/network + ubus + netlink). netifd aporta: espera de netdevices,
hotplug, reintentos, renombrado, bridge/VLAN/rutas/DHCP.

Fallos tipicos del init manual (todos vistos en sesion E2):
- driver DSA aun registrando puertos cuando corre ifconfig; usar espera con
  LOOP hasta `[ -d /sys/class/net/wan ]` (no sleep fijo)
- falta `mount -t sysfs`, `mdev -s` o device nodes en /dev (si no hay
  CONFIG_DEVTMPFS=y en el config minimo, el init DEBE tolerarlo y usar nodos
  estaticos del initramfs-nodes.txt)
- esperar carrier: `while [ "$(cat /sys/class/net/wan/carrier 2>/dev/null)" != 1 ]`
- nombre de interfaz incorrecto (revisar /proc/net/dev y /sys/class/net reales)
- busybox OpenWrt NO trae applet `ip` NI `mdev` (verificado: tabla = brctl, echo,
  ifconfig, mount, sleep, udhcpc, wait). /sbin/ip es symlink a busybox que solo
  funciona si el applet esta compilado. Usar ifconfig+brctl, o busybox propio
  con ip+mdev si el rootfs lo permite

## udhcpc: dos scripts distintos

- `/lib/netifd/dhcp.script` (OpenWrt): notifica a netifd/ubus; SIN netifd vivo
  no aplica la IP. Replicarlo en init directo = DHCPACK en el loader pero wan
  sin IP (visto en DBG6).
- `/usr/share/udhcpc/default.script` (busybox): aplica IP/ruta/resolv.conf solo,
  sin netifd. El correcto para init standalone. (DBG6b/7 con el: no emitio
  DISCOVER de forma confiable = problema de timing DSA/carrier, no del script.)

## Diagnosticos que funcionaron

- Inspeccionar el sistema FUNCIONAL por SSH (netboot del bin que si bootea) y
  documentar /init, ps (procd/netifd/udhcpc/dropbear), /etc/config/network,
  /sys/class/net. Eso dio la anatomia real (directiva Abdias: NO debug ciego).
- /etc/preinit + lib/preinit/*.sh del arbol = documentacion autoritativa local.
- Escalera de aislamiento: /init cada vez mas minimo (solo mounts+loop; +red;
  +dropbear) sobre rootfs COMPLETO (que si bootea) para separar bug-de-init vs
  bug-de-rootfs-minimo (plantillas init-debug* en core/rootfs-riveros/).
