# RiverOS — reproducibilidad

El build del kernel es deterministico: mismo arbol + mismo .config ->
mismo binario (verificado: v3/v4 sha identico 80faf834).

Flujo reproducible:
1. checkout-riveros.sh (obtiene el arbol base, tag v25.12.5)
2. build-kernel.sh (config-6.12 del repo -> prepare -> compile -> install)
3. check-config.sh (valida el .config: red + contrato RouterBOOT)

Snapshots de configs validados: docs/archive/configs/
Verificacion sin netboot: readelf (entry 0x80b71000, .appended_dtb) +
initramfs (rootfs: preinit, dropbear, release RiverOs).
