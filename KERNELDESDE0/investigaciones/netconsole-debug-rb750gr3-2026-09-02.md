# Debug netconsole RB750Gr3 — experimentos 2026-09-02 (E2 rootfs propio)

Contexto: E2 = rootfs RiverOs propio (sin procd/netifd/uci) con /init PID1 directo.
El /init completo (red manual ifconfig/brctl + dropbear) causaba panic loop;
init-debug minimo (mounts + loop) NO panica -> bug esta en red/dropbear del init.
Sin consola serie (J1 no usar) -> netconsole al PC.

## Hechos de hardware/operacion confirmados
- RB750Gr3 netboot = PUSH boton reset al encender (power-cycle normal = beep
  loop, NO descarga). Usuario confirma: "REINICIO NORMAL HACE BEEP LOOP,
  NETBOOT(PUSH) NO"
- Panic loop kernel = contador "tftp: sent" en dnsmasq.log creciendo sin parar.
  Count estable tras 1 send = kernel vivo (init corriendo aunque sin red/ping)
- build-riveros.sh escribe SIEMPRE en
  core/artifacts/riveros-6.12.94-e1-initramfs-kernel.bin (mismo nombre para
  E1/E2/debug): verificar sha256sum, NUNCA confiar en el nombre de archivo

## configfs netconsole (funciona si iface tiene IP+link)
Config kernel build (sed sobre .config del arbol):
  CONFIG_NETCONSOLE=y, CONFIG_NETCONSOLE_DYNAMIC=y, CONFIG_CONFIGFS_FS=y
En /init tras dar IP:
  mkdir -p /sys/kernel/config
  mount -t configfs configfs /sys/kernel/config
  mkdir -p /sys/kernel/config/netconsole/target1
  echo <PC-MAC> > remote_mac      # PC MAC: cat /sys/class/net/enp0s31f6/address
  echo <PC-IP>  > remote_ip       # 192.168.88.2
  echo 6666      > remote_port
  echo <iface>  > dev_name        # eth0 (CPU port MT7530) o wan
  echo 1         > enabled
PC: timeout 600 nc -u -l -p 6666 > /tmp/router-boot.log  (antes del power-cycle)
Pitfalls:
- mkdir -p /sys/kernel/config ANTES del mount (mount sobre dir inexistente
  falla silencioso con 2>/dev/null)
- Si la iface no tiene IP/link cuando habilitas -> 0 bytes. Loguear
  local_ip despues de enabled.
- Solo se capturan mensajes POSTERIORES al enabled; loguear cada paso a
  /dev/kmsg (mounts ok, interfaces listadas, dev_name, enabled, local_ip)
- Primer intento configfs sobre wan: 1 byte (senal minima) = wan sin link
  completo; iteracion final: eth0 192.168.88.3 (CPU port, siempre existe) +
  br-lan .1 + wan .4, netconsole dev_name=eth0

## netconsole via cmdline DTB (FALLO — no usar)
Agregar al DTS chosen/bootargs:
  ip=192.168.88.3::192.168.88.2:255.255.255.0::eth0:none
  netconsole=6666@192.168.88.3/eth0,6666@192.168.88.2/<PC-MAC>
Requisito: CONFIG_IP_PNP=y en kernel.
Resultado: 0 bytes. Causa: ipconfig corre ANTES del probe DSA/MT7530, eth0 no
tiene IP cuando netconsole arranca -> nunca envia. Usar configfs desde /init
en su lugar. Revertir el DTS (quitar chosen) tras probar.

## Escalera de aislamiento de bug de /init (plantillas init-debug* en
core/rootfs-riveros/)
1. init-debug: solo mount proc/sysfs + mkdir + loop -> NO panica (kernel/initramfs OK)
2. + red manual (ifconfig/brctl wan .3 br-lan .1) -> sin ping (DSA no lista o
   iface con otro nombre); udhcpc sin DHCPDISCOVER
3. + dropbear -> panic loop (si dropbear es la causa, quitar y reintentar)
4. Sobre rootfs COMPLETO OpenWrt (que SI bootea via preinit) para separar
   bug-de-init vs bug-de-rootfs-minimo
