# RiverOS — Makefile del repositorio
# Build del kernel: core/scripts/build-kernel.sh (ver core/docs/toolchain.md)
# Verificacion del config: core/scripts/check-config.sh

.PHONY: help check build

help:
	@echo "RiverOS"
	@echo "  make check   -> verifica el .config del kernel (check-config.sh)"
	@echo "  make build   -> compila el kernel (build-kernel.sh)"
	@echo "  Ver core/docs/toolchain.md"

check:
	core/scripts/check-config.sh

build:
	core/scripts/build-kernel.sh
