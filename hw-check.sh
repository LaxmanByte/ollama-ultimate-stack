#!/usr/bin/env bash
# Back-compat name from the downloaded draft. Prefer: bash check-hardware.sh
exec "$(cd "$(dirname "$0")" && pwd)/scripts/check-hardware.sh" "$@"
