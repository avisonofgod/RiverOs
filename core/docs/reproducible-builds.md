# RiverOs — Builds reproducibles

## Problema actual

- El build via ImageBuilder depende de un arbol descargado y de FILES
  externos; hasta ahora los ficheros de overlay estaban sueltos en
  imagebuilder/ (inconsistentes con el README).
- Checksums solo MD5; sin manifest ni metadatos de build.

## Solucion en curso (repo)

- Overlay canonico: `configs/files/` (estructura etc/...) — el build falla
  si no existe.
- Perfiles: `configs/profiles/*.config` (PROFILE + PACKAGES + OUTPUT).
- `imagebuilder/build.sh` genera: bin + `SHA256SUMS` (sha256+md5) +
  `openwrt-commit.txt` (version, kernel, profile, fecha, paquetes).
- `imagebuilder/verify.sh`: checksum, secretos, consistencia, formato.
- `openwrt.lock`: fija commit de RiverOs + feeds (PENDIENTE de fijar).

## Pasos hacia el kernel propio (resumen)

1. Tag baseline reproducible (`riveros-imagebuilder-baseline`)
2. Doble build y comparar (sha256sum + diff manifest)
3. Checkout completo de RiverOs (`scripts/checkout-openwrt.sh`)
4. Importar producto (perfiles, package/riveros, overlay) sin tocar kernel
5. Imagen equivalente al ImageBuilder (comparar manifest, DTS, tamano)
6. Extraer kernel config 6.12.94 → `configs/kernel/mt7621-rb750gr3.config`
7. Primer cambio inocuo (banner) y verificar en el artefacto
8. Parches por capas: DTS → MT7530/DSA → NAND/UBI → netfilter → wireguard
9. Siempre 2 imagenes: initramfs-kernel.bin (netboot) + squashfs-sysupgrade
10. Probar por netboot antes de escribir NAND (ver recovery-netboot.md)

## Regla

Cada commit de kernel: `make target/linux/refresh && git diff -- target/linux/`
y probar en bin antes de tocar el router. Sysupgrade PLAIN v6, nunca -v7.
