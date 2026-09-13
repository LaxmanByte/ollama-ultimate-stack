#!/usr/bin/env bash
# =============================================================================
# Update this machine from GitHub, then refresh Docker images and recreate.
# Preserves local .env (hardware / ports / secrets).
# Usage: bash update.sh
# =============================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo ""
echo "=============================================================================="
echo "  OLLAMA ULTIMATE STACK — UPDATE"
echo "=============================================================================="
echo ""

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    echo "Docker is not running. Start Docker, then re-run."
    exit 1
fi

ENV_BACKUP=""
if [ -f .env ]; then
    ENV_BACKUP="$(mktemp)"
    cp .env "$ENV_BACKUP"
    echo "Preserved local .env"
fi

if [ -d .git ]; then
    if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
        echo "Fetching stack files from origin..."
        git fetch origin
        git pull --ff-only
    else
        echo "No git upstream configured — updating images only."
        echo "On a clone of the GitHub repo, run: git remote -v"
    fi
else
    echo "Not a git checkout — updating Docker images only."
    echo "To receive compose/script changes: clone https://github.com/LaxmanByte/ollama-ultimate-stack.git"
fi

if [ -n "$ENV_BACKUP" ] && [ -f "$ENV_BACKUP" ]; then
    cp "$ENV_BACKUP" .env
    rm -f "$ENV_BACKUP"
    echo "Restored local .env"
fi

chmod +x install.sh update.sh scripts/*.sh 2>/dev/null || true

COMPOSE_ARGS=(-f docker-compose.yml)
if [ -f .env ] && grep -q "docker-compose.gpu.yml" .env 2>/dev/null; then
    COMPOSE_ARGS+=(-f docker-compose.gpu.yml)
elif command -v nvidia-smi >/dev/null 2>&1 && [ -f docker-compose.gpu.yml ]; then
    COMPOSE_ARGS+=(-f docker-compose.gpu.yml)
fi

echo "Pulling container images..."
docker compose "${COMPOSE_ARGS[@]}" pull

echo "Recreating services..."
docker compose "${COMPOSE_ARGS[@]}" up -d

echo ""
echo "Update complete. WebUI: http://localhost:${WEBUI_PORT:-3000}"
echo "Image-only auto-updates: set COMPOSE_PROFILES=auto-update in .env, then re-run this script."
echo ""
