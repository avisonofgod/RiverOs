# Sesion reduccion v22->v35 + E1 (2026-09-01/02)

## Serie de reduccion (config kernel core/configs/kernel/mt7621-rb750gr3.config)
- base OpenWrt 25.12.5: 985 =y / 848 =m
- v22: WLAN/USB/SOUND/fs/debug off -> 918 =y
- v23: EFI/SCSI/ATA/NVMe/VIRTIO/MLX5/crypto-ARM/CGROUP_RDMA/BPF/IPVS off -> 896 =y
- v24: IPVS/SCTP/ATM/RFKILL/ZRAM/MROUTE off -> 870 =y
- v25: 65 NET_VENDOR_* off (solo MEDIATEK) + AR8216/SFC -> 803 =y (compile 2812s->168s!)
- v26: IPVS schedulers/DSA tags no-MTK/CRYPTO_DEV/BLK_DEV sin HW/IP_SET -> 774 =m
- v27: legacy iptables XT/EBT/IP_NF/IP6_NF + tc qdiscs + NLS/TEAM/I2C_MUX -> 585 =m
- v28: sync post-oldconfig (config repo = config REAL depurado, -2074 lineas ruido) +
      POWER_SUPPLY/THERMAL off -> 776 =y / 467 =m (compile 210s limpio)
- v29: SYSVIPC/USER_NS/KALLSYMS/SENSORS/802154/ATM/SCTP/MHI/QRTR/OVS -> 767 =y / 395 =m
- v30: CGROUP/BPF/NAMESPACES/IPV6/SECCOMP/PERF + NF/XFRM/tuneles/crypto-extra
      (Risp/nft/wg NO importan) -> 743 =y / 231 =m
- v31: cortes Duck.ai diag/QoS + PHYs no-MTK/I2C/fs raros/diag/TPM/W1/SSB/BCMA
      -> 727 =y / 21 =m, bin 4,200,396 B (4.0MB)
- v33 (rebrand initramfs): sha 6c8492de, bin 4,200,220 B — BASE PRINCIPAL VALIDADA

## Metricas de compile (clave: LOAD domina, no simbolos)
- v25 168s (config cambio grande + load bajo) vs v27 3352s (load 10) vs v28 210s
  (load limpio): mismo rango de simbolos -> 16x diferencia por carga del sistema
- Comparar SIEMPRE con load < 2; matar procesos ociosos (fwupd, hermes pts ociosos)

## Rebrand initramfs validado (v33)
Archivos del paquete base-files que PISAN el subtarget (sobrescribir post-install
en root-ramips): etc/banner, etc/device_info, usr/lib/os-release (etc/os-release
es SYMLINK ahi), etc/config/system (hostname). Verificado por SSH: banner RiverOs,
hostname RiverOs (DHCPACK muestra el hostname), dmesg 0 errores.

## Duck.ai hallazgos (2da opinion config v30)
- Prompt pegado MAX ~10KB (24-52KB = Send disabled); NO lee raw.githubusercontent
  (mandar secciones por prompt); modelo Free TRUNCA respuestas largas
- Confirma: NET_VENDOR_* off = ahorro moderado; NO tocar NET_MEDIATEK_SOC/DSA/
  MT7530/MDIO/REGMAP/PHY; =m solo si el .ko esta en initramfs y se carga

## Spec make kernel exacta (capturada V=99, 2026-09-02)
KCFLAGS="-fmacro-prefix-map=<BUILD_DIR>=<notdir> -fno-caller-saves"
HOSTCFLAGS="-O2 -I<staging>/host/include -Wall -Wmissing-prototypes -Wstrict-prototypes"
CROSS_COMPILE=mipsel-openwrt-linux-musl-  ARCH=mips  KBUILD_HAVE_NLS=no
KBUILD_BUILD_USER="" KBUILD_BUILD_HOST=""
KBUILD_BUILD_TIMESTAMP="Wed Jun 24 23:37:12 2026" KBUILD_BUILD_VERSION=0
KBUILD_HOSTLDFLAGS="-L<staging>/host/lib" CONFIG_SHELL=bash V='' cmd_syscalls=
CC=<cross>gcc KERNELRELEASE=6.12.94
+ export STAGING_DIR=<staging>/target-mipsel_24kc_musl + PATH <tc>/bin:<staging>/host/bin
Target: make -C <linux-dir> vmlinux vmlinuz  (NO tocar .config del arbol)

## Pipeline ELF (kernel-bin | append-dtb-elf)
cp vmlinuz out.bin; <objcopy> --set-section-flags=.appended_dtb=alloc,contents
--update-section .appended_dtb=<dtb> out.bin  => sha IDENTICO al bin OpenWrt
