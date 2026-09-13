#!/usr/bin/env bash
# =============================================================================
# Ollama Ultimate Stack — one command for Mac / Linux / WSL (and Git Bash)
# Detects your machine (Intel / Apple Silicon / ARM, RAM, GPU).
# You do not pick an OS or model — hardware check + install run for you.
# Usage:  bash setup.sh
# =============================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo ""
echo "=============================================================================="
echo "  OLLAMA ULTIMATE STACK — SETUP"
echo "=============================================================================="
echo ""
echo "  You do not need to know Windows vs Mac, Intel vs ARM, or which model to pick."
echo "  This script reads your machine and downloads what fits."
echo ""
echo "  Leave this terminal open. First run often takes 15-60 minutes."
echo "  Done when you see: ALL MODELS DOWNLOADED SUCCESSFULLY"
echo ""

# --- Windows (Git Bash / MSYS): hand off to PowerShell ---
if [ -n "${WINDIR:-}" ] || [ "${OSTYPE:-}" = "msys" ] || [ "${OSTYPE:-}" = "cygwin" ] || [ "${OSTYPE:-}" = "win32" ]; then
    if command -v powershell.exe >/dev/null 2>&1; then
        echo "  Detected: Windows — using the Windows setup path"
        echo ""
        exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$ROOT/setup.ps1"
    fi
    if command -v pwsh.exe >/dev/null 2>&1; then
        echo "  Detected: Windows — using PowerShell"
        echo ""
        exec pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$ROOT/setup.ps1"
    fi
    echo "On Windows, double-click setup.cmd (or run setup.ps1 in PowerShell)."
    exit 1
fi

UNAME_S="$(uname -s 2>/dev/null || echo unknown)"
UNAME_M="$(uname -m 2>/dev/null || echo unknown)"
LABEL="$UNAME_S / $UNAME_M"

if [ -n "${WSL_DISTRO_NAME:-}" ] || { [ -f /proc/version ] && grep -qi microsoft /proc/version 2>/dev/null; }; then
    LABEL="WSL ($UNAME_M)"
elif [ "$UNAME_S" = "Darwin" ]; then
    if [ "$UNAME_M" = "arm64" ]; then
        LABEL="macOS Apple Silicon (ARM)"
    else
        LABEL="macOS Intel"
    fi
elif [ "$UNAME_S" = "Linux" ]; then
    case "$UNAME_M" in
        aarch64|arm64) LABEL="Linux ARM" ;;
        *) LABEL="Linux ($UNAME_M)" ;;
    esac
fi

echo "  Detected: $LABEL"
echo ""

echo "------------------------------------------------------------------------------"
echo "  Step 1/2 — Hardware check (no Docker needed)"
echo "------------------------------------------------------------------------------"
echo ""
bash "$ROOT/check-hardware.sh" || true

echo ""
echo "------------------------------------------------------------------------------"
echo "  Step 2/2 — Install Docker (if needed), start Ollama, download models"
echo "------------------------------------------------------------------------------"
echo ""
bash "$ROOT/install.sh"

echo ""
echo "=============================================================================="
echo "  SETUP COMPLETE"
echo "  Open http://localhost:3000 — pick a model — send Hello"
echo "=============================================================================="
echo ""
