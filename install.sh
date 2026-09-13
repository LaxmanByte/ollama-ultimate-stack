#!/usr/bin/env bash
# =============================================================================
# OLLAMA ULTIMATE STACK — one-command installer
# Detects OS, runs check-hardware if needed, installs Docker if missing,
# selects a RAM profile, starts stack. Does not overwrite a custom .env.
# Usage: bash install.sh
# =============================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo ""
echo "=============================================================================="
echo "  OLLAMA ULTIMATE STACK — INSTALLER"
echo "=============================================================================="
echo ""

OS="unknown"
if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
    OS="wsl"
elif [ "$(uname -s)" = "Linux" ]; then
    OS="linux"
elif [ "$(uname -s)" = "Darwin" ]; then
    OS="mac"
elif [ "${OSTYPE:-}" = "msys" ] || [ "${OSTYPE:-}" = "cygwin" ] || [ "${OSTYPE:-}" = "win32" ]; then
    OS="windows"
fi

echo "Detected OS: $OS"
echo ""
echo "Step 1 was clone. Step 2 is the hardware check. Step 3 is this installer."
echo ""

run_hardware_check() {
    if [ -x "$ROOT/scripts/check-hardware.sh" ] || [ -f "$ROOT/scripts/check-hardware.sh" ]; then
        bash "$ROOT/scripts/check-hardware.sh"
        return $?
    fi
    if [ -f "$ROOT/check-hardware.sh" ]; then
        bash "$ROOT/check-hardware.sh"
        return $?
    fi
    return 0
}

if [ ! -f .hardware-profile ]; then
    echo "Hardware profile not found — running diagnostic first (no Docker required)..."
    echo ""
    run_hardware_check || true
    echo ""
fi

hw_get() {
    local key="$1"
    [ -f .hardware-profile ] || return 0
    awk -F= -v k="$key" '$1==k {sub(/^[^=]+=/,""); print; exit}' .hardware-profile
}

echo ""

install_docker_linux() {
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
    fi

    if command -v apt-get >/dev/null 2>&1; then
        curl -fsSL https://get.docker.com | sh
        sudo usermod -aG docker "${USER}" || true
        sudo systemctl enable --now docker || true
        echo "Docker installed. If 'permission denied' on the socket, log out and back in."
        return
    fi

    if command -v dnf >/dev/null 2>&1; then
        sudo dnf -y install dnf-plugins-core
        curl -fsSL https://get.docker.com | sh
        sudo usermod -aG docker "${USER}" || true
        sudo systemctl enable --now docker || true
        return
    fi

    echo "Install Docker from https://docs.docker.com/engine/install/ then re-run."
    exit 1
}

if command -v docker >/dev/null 2>&1; then
    echo "Docker is already installed: $(docker --version)"
else
    echo "Docker not found. Installing..."
    case "$OS" in
        linux|wsl)
            install_docker_linux
            ;;
        mac)
            if command -v brew >/dev/null 2>&1; then
                brew install --cask docker
                echo "Start Docker Desktop, wait until it is running, then re-run: bash install.sh"
            else
                echo "Install Docker Desktop from https://www.docker.com/products/docker-desktop then re-run."
            fi
            exit 1
            ;;
        windows)
            echo "On Windows use PowerShell:  .\\install.ps1"
            echo "Or install Docker Desktop and re-run this script from Git Bash / WSL."
            exit 1
            ;;
        *)
            echo "Install Docker Desktop or Docker Engine, then re-run."
            exit 1
            ;;
    esac
fi

if ! docker compose version >/dev/null 2>&1; then
    echo "Docker Compose plugin is missing. Install docker-compose-plugin and re-run."
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "Docker is installed but the daemon is not running."
    echo "Start Docker Desktop / 'sudo service docker start', then re-run."
    exit 1
fi

echo "Docker Compose: $(docker compose version)"
echo ""

mkdir -p projects uploads scripts

chmod +x install.sh update.sh check-hardware.sh scripts/*.sh 2>/dev/null || true

detect_ram_gb() {
    if [ -f /proc/meminfo ]; then
        awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo
        return
    fi
    if command -v sysctl >/dev/null 2>&1; then
        MEM="$(sysctl -n hw.memsize 2>/dev/null || true)"
        if [ -n "$MEM" ]; then
            echo $((MEM / 1024 / 1024 / 1024))
            return
        fi
    fi
    echo 16
}

apply_hw_model_overrides() {
    [ -f .hardware-profile ] || return 0
    local primary research fallback embedding
    primary="$(hw_get PRIMARY_MODEL)"
    research="$(hw_get RESEARCH_MODEL)"
    fallback="$(hw_get FALLBACK_MODEL)"
    embedding="$(hw_get EMBEDDING_MODEL)"
    tmp="$(mktemp)"
    awk -v p="$primary" -v r="$research" -v f="$fallback" -v e="$embedding" '
        BEGIN { done_p=0; done_r=0; done_f=0; done_e=0 }
        /^PRIMARY_MODEL=/ { if (p != "") { print "PRIMARY_MODEL=" p; done_p=1; next } }
        /^RESEARCH_MODEL=/ { if (r != "") { print "RESEARCH_MODEL=" r; done_r=1; next } }
        /^FALLBACK_MODEL=/ { if (f != "") { print "FALLBACK_MODEL=" f; done_f=1; next } }
        /^EMBEDDING_MODEL=/ { if (e != "") { print "EMBEDDING_MODEL=" e; done_e=1; next } }
        { print }
        END {
            if (p != "" && !done_p) print "PRIMARY_MODEL=" p
            if (r != "" && !done_r) print "RESEARCH_MODEL=" r
            if (f != "" && !done_f) print "FALLBACK_MODEL=" f
            if (e != "" && !done_e) print "EMBEDDING_MODEL=" e
        }
    ' .env > "$tmp"
    mv "$tmp" .env
}

if [ ! -f .env ]; then
    HW_SUPPORTED="$(hw_get SUPPORTED)"
    if [ "$HW_SUPPORTED" = "0" ]; then
        echo "Hardware check marked this machine UNSUPPORTED (<8GB RAM)."
        echo "The stack will not start. Upgrade RAM, or email barrelaxman@gmail.com for remote setup."
        exit 1
    fi

    PROFILE="$(hw_get PROFILE_FILE)"
    RAM_GB="$(hw_get RAM_GB_INT)"
    if [ -z "$PROFILE" ] || [ ! -f "$PROFILE" ]; then
        RAM_GB="$(detect_ram_gb)"
        if [ "$RAM_GB" -le 10 ]; then
            PROFILE="profiles/8gb.env"
        elif [ "$RAM_GB" -le 24 ]; then
            PROFILE="profiles/16gb.env"
        else
            PROFILE="profiles/32gb.env"
        fi
    fi
    echo "Using $PROFILE (detected ~${RAM_GB:-?}GB RAM from hardware check)"
    {
        echo "# Auto-selected by check-hardware + install.sh (${RAM_GB:-?}GB RAM)"
        echo "OLLAMA_PORT=11434"
        echo "WEBUI_PORT=3000"
        echo "WEBUI_AUTH=false"
        echo "ENABLE_SIGNUP=false"
        echo "WEBUI_SECRET_KEY=change-me-in-env-file"
        echo "WATCHTOWER_POLL_INTERVAL=3600"
        echo "OLLAMA_KEEP_ALIVE=30m"
        cat "$PROFILE"
    } > .env
    apply_hw_model_overrides
    echo "Primary model for this machine: $(hw_get PRIMARY_MODEL)"
elif [ ! -s .env ]; then
    cp .env.example .env
else
    echo "Keeping existing .env (custom values not overwritten)."
fi

echo ""
echo "Hardware notes:"
echo "  - 8GB cannot run 24B models (use profiles/8gb.env)."
echo "  - 16GB RAM, no GPU: 7B ok, 14B risky, 24B will crash."
echo "  - Devstral 24B really wants ~32GB RAM or a 4090-class GPU."
echo ""

if grep -q "WEBUI_SECRET_KEY=change-me-in-env-file" .env 2>/dev/null; then
    SECRET="$(openssl rand -hex 32 2>/dev/null || python3 -c 'import secrets; print(secrets.token_hex(32))' 2>/dev/null || date +%s)"
    tmp="$(mktemp)"
    sed "s/WEBUI_SECRET_KEY=change-me-in-env-file/WEBUI_SECRET_KEY=${SECRET}/" .env > "$tmp"
    mv "$tmp" .env
    echo "Generated WEBUI_SECRET_KEY"
fi

COMPOSE_ARGS=(-f docker-compose.yml)
if command -v nvidia-smi >/dev/null 2>&1 && [ -f docker-compose.gpu.yml ]; then
    echo "NVIDIA GPU detected — enabling docker-compose.gpu.yml"
    COMPOSE_ARGS+=(-f docker-compose.gpu.yml)
    if grep -q "^COMPOSE_FILE=" .env 2>/dev/null; then
        :
    else
        echo "COMPOSE_FILE=docker-compose.yml:docker-compose.gpu.yml" >> .env
    fi
fi

echo ""
echo "Starting stack (first run downloads images + models; 15-60 minutes)..."
echo ""

docker compose "${COMPOSE_ARGS[@]}" up -d

echo ""
echo "Monitoring model downloads (Ctrl+C stops the log follow; containers keep running)..."
echo ""

docker compose "${COMPOSE_ARGS[@]}" logs -f model-puller || true

echo ""
echo "Installation complete."
echo "  WebUI:  http://localhost:${WEBUI_PORT:-3000}"
echo "  API:    http://localhost:${OLLAMA_PORT:-11434}"
echo ""
echo "On other machines after you push changes:  bash update.sh"
echo ""
