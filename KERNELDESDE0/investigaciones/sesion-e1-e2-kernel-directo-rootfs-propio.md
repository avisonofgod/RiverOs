# E1/E2 — kernel make directo + rootfs RiverOs propio (sesion 2026-09-02)

Contexto: Abdias quiere kernel base minimo (727 =y/21 =m) como PLANTILLA MAESTRA
y despues arbol de build propio (camino 2: build-riveros.sh sin OpenWrt image
system). Risp/no importa; WAN+SSH para chequeo si.

## E1 VALIDADO (kernel make directo, netboot PASS)

- Pipeline ELF = cp vmlinuz + objcopy .appended_dtb -> sha IDENTICO a OpenWrt
  cuando el vmlinuz es el mismo (kernel-bin | append-dtb-elf replica 1:1)
- E1 v4 produjo 52a8f0e5 (4.2MB) netboot PASS (uname "Linux RiverOs 6.12.94"),
  +9KB vs 6c8492de OpenWrt: NO byte-identico por cpio order/mtimes, funcional
- commits: d7e825e (E1), d36e1d8 (chmod), 4b692b2 (spec v2), 0c36d5c (SetInitramfs
  v3), 2154502 (touch mtimes v4)

### Spec kernel make (capturada make target/linux/compile V=99)
```
make -C <K> KCFLAGS="-fmacro-prefix-map=<openwrt>/build_dir/target-mipsel_24kc_musl=target-mipsel_24kc_musl -fno-caller-saves" \
 HOSTCFLAGS="-O2 -I<openwrt>/staging_dir/host/include -Wall -Wmissing-prototypes -Wstrict-prototypes" \
 CROSS_COMPILE="<tc>/bin/mipsel-openwrt-linux-musl-" ARCH="mips" KBUILD_HAVE_NLS=no \
 KBUILD_BUILD_USER="" KBUILD_BUILD_HOST="" KBUILD_BUILD_TIMESTAMP="Wed Jun 24 23:37:12 2026" \
 KBUILD_BUILD_VERSION="0" KBUILD_HOSTLDFLAGS="-L<openwrt>/staging_dir/host/lib" \
 CONFIG_SHELL="bash" V='' cmd_syscalls= CC="<tc>/bin/mipsel-openwrt-linux-musl-gcc" KERNELRELEASE="6.12.94" \
 vmlinux vmlinuz
export STAGING_DIR=<openwrt>/staging_dir/target-mipsel_24kc_musl
```
- SetInitramfs replica (kernel-defaults.mk): grep -v INITRAMFS/RD_/BLK_DEV_INITRD
  del .config.old -> .config; anadir INITRAMFS_SOURCE="<rootfs> <nodes.txt>",
  COMPRESSION_LZMA, RD_LZMA, UID/GID=0; rm usr/initramfs_data.cpio*; touch mtimes
  rootfs con SOURCE_DATE_EPOCH (1782344232) antes del make

### PITFALLS E1
- Fragment config-6.12 del repo != .config completo: cp-arlo al kernel build rompe
  selects (642-691 =y) y el initramfs falla. Recuperacion que FUNCIONO:
  `cp <K>/.config.set <K>/.config` (.config.set = config completo con todos los
  selects, ~912 =y, generado por OpenWrt). `rm .config + make target/linux/compile`
  FALLA con "No rule to make target .../.config" si existe el stamp .configured;
  make target/linux/prepare NO regenera. Verificar sano: build-kernel.sh debe
  reproducir sha canonico 6c8492de
- SINTOMA de .config corrupto: kernel compila y gate PASS, pero el router NO
  levanta red ni netconsole (0 bytes) aunque el init este bien — depurar el
  config ANTES de culpar al init
- make target/linux/compile V=99 para capturar spec DEJA INITRAMFS_SOURCE vacio
  (SetNoInitramfs) — el siguiente build debe re-SetInitramfs
- vmlinuz sin initramfs ~2.86MB; con root-ramips ~4.2MB: tamano delata estado

## E2 EN CURSO (rootfs propio, init directo NO levanto red)

- build-rootfs-e2.sh: rootfs ~9-11 archivos/1.6-2.2MB desde root-ramips de OpenWrt
  (busybox, dropbear, brctl/ip SOLO si applet existe, libs musl, /init, configs)
- PITFALL: busybox OpenWrt NO trae applet `ip` — /sbin/ip y /usr/sbin/brctl son
  symlinks a busybox; solo funcionan los applets compilados (ifconfig, brctl,
  udhcpc SI). strings -a busybox | grep -x "ip" = vacio => no usar ip en /init
- init-debug escalera: debug (solo mounts+loop) NO panico (TFTP estable) ->
  debug2 (+red ifconfig/brctl) tampoco panic -> el kernel VIVE; el problema NO es
  panic del init sino que la RED no levanta (wan .3/.1 sin ARP, udhcpc sin DISCOVER)
- MIX (rootfs OpenWrt completo + mi /init) tampoco levanto red: interfaces DSA las
  crea netifd/hotplug del framework OpenWrt; init directo no basta. hipotesis:
  usar preinit OpenWrt (sh, sin procd) + 99_red_manual RiverOs
- CONFIRMACION con kernel SANO (82aaaf0f, reproduce canonico 6c8492de): el fallo
  NO es kernel corrupto — es el /init directo. Anatomia del sistema FUNCIONAL
  (inspeccion por SSH al bin que SI bootea, .145):
  * /init OpenWrt: mount tmpfs /new_root + cp -pr + exec switch_root /sbin/init
    (procd PID1) -> netifd -> udhcpc
  * udhcpc real: `udhcpc -p /var/run/udhcpc-wan.pid -s /lib/netifd/dhcp.script
    -f -t 0 -i wan -x hostname:RiverOs -x 0x3d:...`
  * /etc/config/network: br-lan bridge ports lan2-lan5 = 192.168.1.1/24 static;
    wan = DHCP. Interfaces reales: br-lan eth0 lan2 lan3 lan4 lan5 lo wan
  * /lib/preinit tiene 99_red_manual.sh (RiverOs) + 70_initramfs_test
  * dropbear -R corre 2 veces (una del preinit failsafe, otra del boot)
- PROXIMA OPCION (init-debug6, sha 7341d559, pending netboot): replicar EXACTO
  el udhcpc funcional (con -s /lib/netifd/dhcp.script) en el init directo en
  vez de IP fija ifconfig; dropbear -R -p 22. Log del loader (DHCPDISCOVER/
  REQUEST de dc:2c:6e:7b:2a:76) como testigo — sin LED (prohibido por Abdias)
- WORKFLOW (directiva Abdias, 2026-09-02): ante fallo de boot sin consola NO
  iterar debug ciego con netconsole/LED — netbootear el bin FUNCIONAL, entrar
  por SSH, documentar como levanta la red real (/init, procs, config/network,
  dhcp.script, /sys/class/net) y RECIEN ahi adaptar el init propio
- CONFIG_DEVTMPFS falta en config minimo: mount devtmpfs falla; usar
  initramfs-nodes.txt con device nodes en el cpio

## netconsole debug (sin consola serie)
- Config: NETCONSOLE=y + DYNAMIC=y + CONFIGFS_FS=y (sed .config, rebuild)
- /init: mkdir -p /sys/kernel/config ANTES de mount configfs (pitfall: mount sobre
  dir inexistente falla con 2>/dev/null silencioso)
- PC escucha: nc -u -l -p 6666 > /tmp/router-boot.log ANTES del power-cycle
- Panic loop detector: contador "tftp: sent" del dnsmasq.log creciendo = kernel
  panica y RouterBOOT re-descarga; estable = kernel vivo

## Versionado
- versiones/funcionales/v34e1-52a8f0e5/ = E1 (bin + config + SHA256)
- pkg/ sirve nombre FIJO riveros-6.12.94-initramfs-kernel.bin
