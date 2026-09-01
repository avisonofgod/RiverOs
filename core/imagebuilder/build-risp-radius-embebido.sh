#!/bin/bash
# Compat wrapper: build-risp-radius-embebido.sh -> build.sh -p risp-radius-embebido
# Requiere FILES=<arbol files con backend risp> (ver configs/profiles/risp-radius-embedded.config)
exec "$(dirname "$0")/build.sh" -p risp-radius-embebido "$@"
