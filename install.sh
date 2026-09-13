#!/usr/bin/env bash
# =============================================================================
# OLLAMA ULTIMATE STACK — one-command installer
# Detects OS, installs Docker if missing, selects a RAM profile, starts stack.
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

chmod +x install.sh update.sh scripts/*.sh 2>/dev/null || true

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

if [ ! -f .env ]; then
    RAM_GB="$(detect_ram_gb)"
    if [ "$RAM_GB" -le 10 ]; then
        PROFILE="profiles/8gb.env"
    elif [ "$RAM_GB" -le 24 ]; then
        PROFILE="profiles/16gb.env"
    else
        PROFILE="profiles/32gb.env"
    fi
    echo "Detected ~${RAM_GB}GB RAM — using $PROFILE"
    {
        echo "# Auto-selected by install.sh (${RAM_GB}GB RAM)"
        echo "OLLAMA_PORT=11434"
        echo "WEBUI_PORT=3000"
        echo "WEBUI_AUTH=false"
        echo "ENABLE_SIGNUP=false"
        echo "WEBUI_SECRET_KEY=change-me-in-env-file"
        echo "WATCHTOWER_POLL_INTERVAL=3600"
        echo "OLLAMA_KEEP_ALIVE=30m"
        cat "$PROFILE"
    } > .env
elif [ ! -s .env ]; then
    cp .env.example .env
fi

echo ""
echo "Hardware notes:"
echo "  - 8GB cannot run 24B models (use profiles/8gb.env)."
echo "  - 16GB default may struggle with Devstral 24B without a GPU."
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
