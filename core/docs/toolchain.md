# RiverOS — toolchain (compilador)

RiverOS compila para MIPS (mipsel_24kc — el SoC MT7621). El compilador se
obtiene del arbol base (core/scripts/checkout-riveros.sh) y se construye con:

    ./scripts/feeds update -a && ./scripts/feeds install -a
    make tools/install -j8
    make toolchain/install -j8

Toolchain resultante (MIPS):
    staging_dir/toolchain-mipsel_24kc_gcc-14.3.0_musl/bin/mipsel-openwrt-linux-gcc

Para el kernel:

    make target/linux/prepare V=s
    make target/linux/compile -j8 V=s
    make target/linux/install -j8 V=s

Compilar kernel directamente con el toolchain:
    make -C <kernel> ARCH=mips CROSS_COMPILE=mipsel-openwrt-linux-musl- olddefconfig

Configuracion minima (fragmentos):
    targets/mips/common/mips-base.config
    targets/mips/mt7621/mt7621-base.config
    targets/mips/devices/mikrotik-rb750gr3/config/{hardware,netboot,release,debug}.config

Verificacion del config: core/scripts/check-config.sh
