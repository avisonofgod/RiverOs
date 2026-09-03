# core/perfiles — Variantes de firmware RiverOs (RB750Gr3, kernel 6.12.94)

Cada variante es AUTOCONTENIDA: configs + bin de referencia + contrato del
arbol + comando de build. Comparten el mismo arbol OpenWrt (ver
v33/ARBOL.md) y el mismo core/scripts/build-kernel.sh (parametrizado).

## v33/ — ULTIMO MINIMO FUNCIONAL (produccion)

Kernel 6.12.94 sin dataplane extra (727 =y / 21 =m) + framework OpenWrt
minimo (netifd/procd/uci/dropbear/busybox). Es el UNICO binario validado en
hardware con red estable (2/2 + 1/1 + control 1/1).

- target.config — paquetes (framework)
- kernel.config — config kernel v33 (sin NF_TABLES/sched/PPP)
- bin/riveros-6.12.94-v33-initramfs-kernel.bin — binario FUNCIONAL sha 6c8492de
- bin/SHA256, bin/BUILD.json — verificacion
- ARBOL.md — estado exacto del arbol para reproducir

Build:
./core/scripts/build-kernel.sh [arbol] core/perfiles/v33/target.config core/perfiles/v33/kernel.config
Esperado: sha 6c8492de141d245c4cb6d6426a5bdc8d605b83d38fde9bd020c56c8a459131b3

HALLAZGO 2026-09-03 (CRITICO, en investigacion): el flujo actual de
build-kernel.sh NO reproduce el v33: rebuild = sha 87fefec3 (mismo target/
kernel config, mismo arbol commit 6bad5f2050) y el rebuild NO da red en
hardware (el 6c8492de si, probado mismo dia 3/3). Diferencia = pasos nuevos
del flujo (make defconfig + rm root-ramips + package/compile) y/o files del
device post-PR #1. El bin versionado en bin/ ES el funcional; NO reemplazarlo
con rebuilds hasta resolver la reproducibilidad.

## risp/ — VARIANTE EXPERIMENTAL (v33 + dataplane Risp)

Kernel v33 + dataplane =y builtin (nf_tables/conntrack/sch_htb/ppp/pppoe/
ifb/tun/wg) + paquetes userspace (nftables-nojson, ip-full, tc-full, ppp,
ppp-mod-pppoe, ppp-mod-radius, rp-pppoe-server).

ESTADO 2026-09-03: kernel dataplane VALIDADO en hardware (F2 sha 28200332,
red OK 1/1). Con paquetes userspace EXTRA en el initramfs: 4/4 netboots SIN
red (causa bajo investigacion — los extras rompen el boot de red del
framework; v33 control OK mismo dia).

- kernel.config — v33 + dataplane =y
- target.config — framework + paquetes risp (dnsmasq incluido)
- target-test.config — framework + solo nft/tc/ppp/rp-pppoe (sin dnsmasq)

Build:
./core/scripts/build-kernel.sh [arbol] core/perfiles/risp/target.config core/perfiles/risp/kernel.config
Variante test:
./core/scripts/build-kernel.sh [arbol] core/perfiles/risp/target-test.config core/perfiles/risp/kernel.config

## Historial de bins (shas)

- 6c8492de — v33 FUNCIONAL (produccion)
- 28200332 — risp F2: kernel dataplane =y, framework puro — RED OK (1/1)
- d08962f4 — risp: +libcurl/userspace (build 5) — sin probar (pkg incorrecto)
- 045195da — risp: nft/tc/pppd/dnsmasq userspace — SIN RED (1/1 intento)
- 3e3b4b6b — risp kernel LIMPIO (build 9, sin dnsmasq) — SIN RED
- b37786db — risp kernel config F2 (=m) + test — SIN RED
- dec657c2 — risp verif. SKIP_PKG (build 8) — no netbooteado

## Nota

Los configs auxiliares de trabajo (min/base/uci) viven en core/configs/;
core/perfiles/ contiene las variantes versionadas por perfil (v33 y risp),
cada una con su bin de referencia y contrato de arbol.
