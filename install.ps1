#Requires -Version 5.1
<#
.SYNOPSIS
  One-command installer for Ollama Ultimate Stack on Windows.
.DESCRIPTION
  Installs Docker Desktop via winget if missing, selects a RAM profile,
  starts compose, and follows model-download logs.
#>
$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

Write-Host ""
Write-Host "=============================================================================="
Write-Host "  OLLAMA ULTIMATE STACK — WINDOWS INSTALLER"
Write-Host "=============================================================================="
Write-Host ""

function Test-DockerReady {
    try {
        docker info 2>$null | Out-Null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Docker not found. Installing Docker Desktop with winget..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install -e --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
        Write-Host ""
        Write-Host "Start Docker Desktop from the Start menu, wait until it is running, then re-run:"
        Write-Host "  powershell -ExecutionPolicy Bypass -File .\install.ps1"
        exit 1
    }
    Write-Host "Install Docker Desktop from https://www.docker.com/products/docker-desktop then re-run."
    exit 1
}

if (-not (Test-DockerReady)) {
    Write-Host "Docker is installed but the engine is not running."
    Write-Host "Start Docker Desktop, wait for 'Engine running', then re-run this script."
    exit 1
}

Write-Host "Docker: $(docker --version)"
docker compose version | Out-Host

New-Item -ItemType Directory -Force -Path "projects", "uploads", "scripts" | Out-Null

$ramGb = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
Write-Host "Detected ~${ramGb}GB RAM"
if (-not (Test-Path ".env")) {
    if ($ramGb -le 10) { $profile = "profiles\8gb.env" }
    elseif ($ramGb -le 24) { $profile = "profiles\16gb.env" }
    else { $profile = "profiles\32gb.env" }
    Write-Host "Detected ~${ramGb}GB RAM — using $profile"
    $header = @"
# Auto-selected by install.ps1 (${ramGb}GB RAM)
OLLAMA_PORT=11434
WEBUI_PORT=3000
WEBUI_AUTH=false
ENABLE_SIGNUP=false
WEBUI_SECRET_KEY=change-me-in-env-file
WATCHTOWER_POLL_INTERVAL=3600
OLLAMA_KEEP_ALIVE=30m
"@
    $header + "`n" + (Get-Content $profile -Raw) | Set-Content -Path ".env" -Encoding ascii
}

Write-Host ""
Write-Host "Hardware notes:"
Write-Host "  - 8GB cannot run 24B models (use profiles\8gb.env)."
Write-Host "  - 16GB default may struggle with Devstral 24B without a GPU."
Write-Host "  - Devstral 24B really wants ~32GB RAM or a 4090-class GPU."
Write-Host ""

if (Select-String -Path ".env" -Pattern "WEBUI_SECRET_KEY=change-me-in-env-file" -Quiet) {
    $bytes = New-Object byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $secret = -join ($bytes | ForEach-Object { $_.ToString("x2") })
    (Get-Content .env) -replace "WEBUI_SECRET_KEY=change-me-in-env-file", "WEBUI_SECRET_KEY=$secret" |
        Set-Content .env -Encoding ascii
    Write-Host "Generated WEBUI_SECRET_KEY"
}

$composeArgs = @("-f", "docker-compose.yml")
if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
    Write-Host "NVIDIA GPU detected — enabling docker-compose.gpu.yml"
    $composeArgs += @("-f", "docker-compose.gpu.yml")
    if (-not (Select-String -Path ".env" -Pattern "^COMPOSE_FILE=" -Quiet)) {
        Add-Content .env "COMPOSE_FILE=docker-compose.yml:docker-compose.gpu.yml"
    }
}

Write-Host ""
Write-Host "Starting stack (first run downloads images + models; 15-60 minutes)..."
Write-Host ""

docker compose @composeArgs up -d
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Monitoring model downloads (Ctrl+C stops the log follow; containers keep running)..."
Write-Host ""
docker compose @composeArgs logs -f model-puller

Write-Host ""
Write-Host "Installation complete."
Write-Host "  WebUI:  http://localhost:3000"
Write-Host "  API:    http://localhost:11434"
Write-Host ""
Write-Host "On other machines after you push changes:  .\update.ps1"
Write-Host ""
