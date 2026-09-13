#!/usr/bin/env bash
# Convenience wrapper — Windows users should run check-hardware.ps1 instead.
exec "$(cd "$(dirname "$0")" && pwd)/scripts/check-hardware.sh" "$@"
