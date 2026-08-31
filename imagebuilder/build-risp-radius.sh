#!/bin/bash
# Compat wrapper: build-risp-radius.sh -> build.sh -p risp-radius
exec "$(dirname "$0")/build.sh" -p risp-radius "$@"
