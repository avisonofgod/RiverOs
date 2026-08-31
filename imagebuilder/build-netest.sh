#!/bin/bash
# Compat wrapper: build-netest.sh -> build.sh -p netest
exec "$(dirname "$0")/build.sh" -p netest "$@"
