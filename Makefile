# RiverOs — Makefile raiz (orquestador de build/verificacion)
# Objetivo: convertir el repo en una capa reproducible sobre OpenWrt.
#
# Comandos:
#   make build          -> build del perfil por defecto (netest)
#   make build PROFILE=risp-radius   -> otro perfil
#   make verify         -> verifica artefactos (sha256, manifest, secretos)
#   make tree           -> checkout completo de OpenWrt (openwrt.lock)
#   make help

SHELL := /bin/bash
PROFILE ?= netest
REPO := $(CURDIR)

.PHONY: help build verify tree

help:
	@echo "RiverOs targets:"
	@echo "  make build PROFILE=<netest|risp-radius|risp-radius-embedded>"
	@echo "  make verify   — checksum + secretos + consistencia"
	@echo "  make tree     — checkout OpenWrt completo (requiere openwrt.lock fijado)"

build:
	cd imagebuilder && ./build.sh -p $(PROFILE)

verify:
	cd imagebuilder && ./verify.sh

tree:
	cd scripts && ./checkout-openwrt.sh
