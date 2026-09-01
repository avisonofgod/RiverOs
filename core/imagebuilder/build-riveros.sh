#!/bin/bash
# Compat wrapper: build-riveros.sh -> build.sh -p riveros
exec "$(dirname "$0")/build.sh" -p riveros "$@"
