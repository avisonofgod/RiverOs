# Auditoria Copilot E2 — 40 hallazgos y fixes aplicados (2026-09-02)

Auditoria SOLO LECTURA de Copilot CLI (resume del hilo E2, --allow-all-paths)
sobre 5 archivos E2: init, udhcpc-default.script, initramfs-nodes.txt,
build-rootfs-e2.sh, build-riveros.sh. 21m28s, AI credits 6.35, ~852k tokens.
Resultado: 40 hallazgos (8 ALTA / 22 MEDIA / 10 BAJA). Los ALTA+MEDIA de alto
valor se aplicaron con patch (edicion la hace Hermes, no Copilot — directiva
Abdias de no gastar tokens de Copilot en writes).

## Confirmaciones tecnicas de Copilot (validan diseno, NO eran bugs)
- WDT MT7621: timeout max efectivo 65s (driver: max_timeout = 0xfffful/1000).
  Abrir /dev/watchdog ACTIVA el WDT si estaba parado (correcto aqui). Write '\n'
  = keepalive valido; 'V' solo importa al CERRAR. Driver detiene y rearranca el
  WDT del bootloader en probe.
- Bridge DSA: NO agregar eth0/sw0 (CPU port) al bridge es CORRECTO — DSA
  programa el switch con tag MTK al unir puertos de usuario; agregar sw0 seria
  bug (loop/iface extra).
- Compresion LZMA del initramfs: correcta para el arbol OpenWrt actual
  (CONFIG_TARGET_INITRAMFS_COMPRESSION_LZMA=y en .config; no contradice sha
  canonico).
- default.script de OpenWrt limpia IP sin bajar la iface (ip -4 addr flush);
  nuestro 'ifconfig X 0.0.0.0 down' en deconfig es riesgoso: udhcpc corre
  deconfig ANTES del primer DHCPDISCOVER y dejar la iface administrativamente
  down puede impedir transmitir en algunas combinaciones busybox/driver.

## Fixes aplicados (init v3 reescrito completo)
- Watchdog feeder con VERIFICACION: `( exec 3>/dev/watchdog 2>>$LOG || { log
  "apertura FALLO"; exit 1; }; while :; do printf '\n' >&3 2>>$LOG || { log
  "write FALLO"; exit 1; }; sleep 10; done ) &` — antes el exec fallaba
  silencioso y /init seguia creyendo WDT alimentado (mknod crea el nodo aunque
  el driver no exista; [ -e ] no prueba usabilidad).
- Mounts criticos con fail: proc/sys `|| fail`; devpts solo WARN (dropbear sin
  pty, red igual anda).
- `ifconfig lo up` (faltaba vs preinit OpenWrt).
- Observabilidad DSA: log si existe master eth0/sw0 antes de esperar puertos
  (ausencia = probe MT7530 fallo, no bug del init).
- Waits: wan 90s; lan2-5 30s c/u (no 5x90=450s secuenciales del peor caso).
- fail() loguea a kmsg cada 30s (antes while sleep 60 mudo) — visible por
  netconsole si esta activo.
- udhcpc: `-x hostname:RiverOs` + supervisor en loop ppal: si el proceso muere
  se relanza (replica resiliencia netifd; antes un fallo transitorio dejaba WAN
  sin IP para siempre).
- dropbear: verifica `-x /usr/sbin/dropbear` + kill -0 a los 2s + relanzado en
  supervision (antes fallo oculto, log "init complete" falso).
- initramfs-nodes.txt: + `nod /dev/watchdog 600 0 0 c 10 130` (determinista con
  DEVTMPFS off; el init conserva mknod redundante por si falta).

## Fixes udhcpc-default.script
- deconfig/bound SIN 'down': `ifconfig $interface 0.0.0.0` (limpia IP sin bajar
  la iface antes del primer DHCPDISCOVER).
- `route del default dev $interface` (antes `route del default $interface`).
- NETMASK default 255.255.255.0 si subnet vacio (antes ifconfig netmask "" = 
  config invalida).
- Primer gw del listado con `${router%% *}` — NO awk (applet no verificado en
  busybox; sin dependencias extra).

## Fixes build-rootfs-e2.sh
- HARD FAIL (exit 1) si faltan busybox/dropbear/ld-musl/libc/libgcc_s/passwd/
  shadow/group/init (antes `|| echo WARN` = imagen "ok" que solo fallaba en
  hardware, p.ej. login root imposible). Todos existen en root-ramips.
- Guard DEST: debe ser ruta ABSOLUTA y != / (rm -rf "$DEST" con relativo podia
  borrar lo que sea relativo al cwd).
- mkdir extra /run (el init crea el pidfile ahi; dependencia oculta entre
  archivos si el rootfs aislado no lo trae).

## Verificacion y netboot final
- Build e6fb9bc3: gate PASS entry=0x80b71000 dtb=1; `diff <(cpio -i --to-stdout
  init < cpio) core/rootfs-riveros/init` = repo == embebido (el codigo auditado
  viaja).
- Netboot e6fb9bc3: count TFTP estable 2+ min SIN re-descarga = FIX WDT
  VALIDADO en hardware (antes: reset ~60s post-boot con re-descarga a .1).
- PERSISTE: probe DSA no-determinista en reboot caliente — wan nunca aparece
  (1 de cada ~3 boots lo logra), init entra en fail loop con kernel vivo.
  Remedy: power-cycle REAL (desenchufar 5-10s), NO reset button. Distinguir de
  bug del init: count TFTP estable + cero DHCP + cero BOOTP nuevos.
