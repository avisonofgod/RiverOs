# DTB chosen debug -> boots E2 colgados (2026-09-02)

Causa raiz de los boots E2 "sin DHCP / count TFTP estable / PC sin carrier"
que se atribuyeron a init colgado o probe DSA no-determinista.

## Cadena de evidencia (como se diagnostico)
1. Boot A (bin 8b7ad014, 15:44): DHCPDISCOVER->ACK "RiverOs" .145 OK ~15s, WDT
   reset ~22s despues (sin fix WDT aun) -> TFTP re-descarga a .1.
2. Boots B/C/D: descarga OK, 0 DHCP, count TFTP estable 2+ min, ping/SSH
   muertos, ultimo evento del dnsmasq.log = solo la descarga TFTP.
3. Sonda fisica: `cat /sys/class/net/enp0s31f6/carrier` = 0 con el router
   colgado -> el PHY de wan (gmac1+ethphy0, ether1; el PC esta ahi, NO en el
   MT7530) no tiene link. carrier 0 = problema de red/probe; NO init corriendo
   sin red (en ese caso el PHY wan podria linkear igual).
4. Descubrimiento: el .dts del arbol tenia chosen bootargs DEBUG del 2026-09-02
   (`git diff target/linux/ramips/dts/mt7621_mikrotik_routerboard-750gr3.dts`
   muestra SOLO el chosen anadido) y el .dtb del staging (image-*.dtb, mtime
   13:33) fue REGENERADO con ese chosen:
   `dtc -I dtb -O dts <dtb> | grep -A3 chosen` -> bootargs presente.
5. Mecanismo: bootargs `ip=192.168.88.3::192.168.88.2:255.255.255.0::wan:none`
   hace que ipconfig del kernel (autoconfig) ESPERE a la iface wan ANTES de
   ejecutar /init. Si wan no aparece (probe mtk_eth/gmac1/PHY fallo o tardo),
   ipconfig se cuelga esperando y /init JAMAS corre. El WDT no resetea porque
   el driver MT7621_WDT detuvo el WDT del RouterBOOT en su probe y nadie abre
   /dev/watchdog (solo /init lo abriria). Por eso count TFTP estable SIN que el
   init este vivo.
6. Boot A funciono porque en ESE boot wan aparecio rapido -> ipconfig paso ->
   /init corrio -> DHCP.

## Fix aplicado
- `cd /home/proyectos/openwrt && git checkout target/linux/ramips/dts/mt7621_mikrotik_routerboard-750gr3.dts`
  (revertir el chosen; el diff era solo ese bloque)
- Regenerar el DTB del staging: `make target/linux/compile` (background+notify,
  ~5-7 min; toca el dts primero)
- Verificar DTB limpio: `dtc -I dtb -O dts <build_dir>/.../image-mt7621_mikrotik_routerboard-750gr3.dtb | grep -c bootargs` == 0
- Rebuild E2 + cp a pkg/ + sha (el init v4 ya espera wan 600s con log periodico)

## Lecciones
- Un chosen/bootargs debug REGENERADO en el .dtb del staging es PERSISTENTE:
  contamina todos los builds (build-riveros.sh usa ese .dtb tal cual). Revertir
  el .dts no basta; hay que regenerar el .dtb.
- ipconfig colgado (con ip= en bootargs) es INDISTINGUIBLE por telemetria TFTP
  de un init colgado: en ambos count TFTP estable + 0 DHCP. La diferencia: con
  ipconfig colgado el init NUNCA corrio (nadie alimenta WDT pero el driver lo
  detuvo en probe); con init colgado el init SI corre (alimenta WDT si el fix
  esta). Sin consola, distinguirlos requiere el DTB check o netconsole.
- Verificar el chosen del .dtb REAL antes de cada netboot de validacion:
  `dtc -I dtb -O dts <dtb> | grep bootargs`.
