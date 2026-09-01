# RiverOs — Makefile raiz (orquestador de build/verificacion)
# Objetivo: convertir el repo en una capa reproducible sobre RiverOs.
#
# Comandos:
#   make build          -> build del perfil por defecto (netest)
#   make build PROFILE=risp-radius   -> otro perfil
#   make verify         -> verifica artefactos (sha256, manifest, secretos)
#   make tree           -> checkout completo de RiverOs (openwrt.lock)
#   make help

SHELL := /bin/bash
PROFILE ?= netest
IB_DIR ?= /root/netinstall-openwrt/imagebuilder-25.12.5
CLEAN_LOCAL_FILES ?= 0
REPO := $(CURDIR)

.PHONY: help build verify tree

help:
	@echo "RiverOs targets:"
	@echo "  make build PROFILE=<netest|risp-radius|risp-radius-embedded>"
	@echo "    IB_DIR=<arbol ImageBuilder> CLEAN_LOCAL_FILES=1 (si el IB tiene files/ local)"
	@echo "  make verify   — checksum + secretos + consistencia"
	@echo "  make tree     — checkout RiverOs completo (usa openwrt.lock)"

build:
	cd $(IB_DIR) && CLEAN_LOCAL_FILES=$(CLEAN_LOCAL_FILES) $(REPO)/imagebuilder/build.sh -p $(PROFILE)

verify:
	cd $(REPO) && ./imagebuilder/verify.sh

tree:
	cd $(REPO) && ./scripts/checkout-openwrt.sh
