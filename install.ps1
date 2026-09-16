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
Write-Host "  OLLAMA ULTIMATE STACK - WINDOWS INSTALLER"
Write-Host "=============================================================================="
Write-Host ""
Write-Host "Detected this Windows PC automatically. You do not pick an OS or model."
Write-Host ""
Write-Host "Hardware profile first, then Docker + models. Leave this window open."
Write-Host ""

function Get-HardwareValue([string]$Key) {
    $path = Join-Path $PSScriptRoot ".hardware-profile"
    if (-not (Test-Path $path)) { return "" }
    foreach ($line in Get-Content $path) {
        if ($line -match "^$([regex]::Escape($Key))=(.*)$") { return $Matches[1] }
    }
    return ""
}

function Invoke-HardwareCheck {
    $checker = Join-Path $PSScriptRoot "check-hardware.ps1"
    if (Test-Path $checker) {
        & $checker
        return $LASTEXITCODE
    }
    $alt = Join-Path $PSScriptRoot "scripts\check-hardware.ps1"
    if (Test-Path $alt) {
        & $alt
        return $LASTEXITCODE
    }
    return 0
}

if (-not (Test-Path (Join-Path $PSScriptRoot ".hardware-profile"))) {
    Write-Host 'Hardware profile not found - running diagnostic first (no Docker required)...'
    Write-Host ""
    [void](Invoke-HardwareCheck)
    Write-Host ""
}

function Set-EnvModelOverrides {
    if (-not (Test-Path ".hardware-profile")) { return }
    $map = @{
        "PRIMARY_MODEL" = (Get-HardwareValue "PRIMARY_MODEL")
        "RESEARCH_MODEL" = (Get-HardwareValue "RESEARCH_MODEL")
        "FALLBACK_MODEL" = (Get-HardwareValue "FALLBACK_MODEL")
        "EMBEDDING_MODEL" = (Get-HardwareValue "EMBEDDING_MODEL")
    }
    $lines = Get-Content ".env"
    $seen = @{ PRIMARY_MODEL = $false; RESEARCH_MODEL = $false; FALLBACK_MODEL = $false; EMBEDDING_MODEL = $false }
    $out = foreach ($line in $lines) {
        $hit = $false
        foreach ($k in $map.Keys) {
            if ($line -match "^$k=" -and $map[$k]) {
                "$k=$($map[$k])"
                $seen[$k] = $true
                $hit = $true
                break
            }
        }
        if (-not $hit) { $line }
    }
    foreach ($k in $map.Keys) {
        if (-not $seen[$k] -and $map[$k]) { $out += "$k=$($map[$k])" }
    }
    $out | Set-Content ".env" -Encoding ascii
}

function Test-DockerReady {
    cmd /c "docker info >nul 2>&1"
    return $LASTEXITCODE -eq 0
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Docker not found. Installing Docker Desktop with winget..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install -e --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
        Write-Host ""
        Write-Host "Start Docker Desktop from the Start menu, wait until it says Engine running, then double-click install.cmd"
        exit 1
    }
    Write-Host "Install Docker Desktop from https://www.docker.com/products/docker-desktop then re-run."
    exit 1
}

if (-not (Test-DockerReady)) {
    Write-Host "Docker is installed but the engine is not ready yet. Waiting..."
    $ready = $false
    for ($i = 1; $i -le 30; $i++) {
        if (Test-DockerReady) { $ready = $true; break }
        Write-Host "  Waiting for Docker engine... ($i/30)"
        Start-Sleep -Seconds 2
    }
    if (-not $ready) {
        Write-Host "Docker is installed but the engine is not running."
        Write-Host "Start Docker Desktop, wait for 'Engine running', then double-click install.cmd"
        exit 1
    }
}

Write-Host "Docker: $(docker --version)"
docker compose version | Out-Host

New-Item -ItemType Directory -Force -Path "projects", "uploads", "scripts" | Out-Null

$ramGb = Get-HardwareValue "RAM_GB_INT"
if (-not $ramGb) {
    $ramGb = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
}
Write-Host "Detected ~${ramGb}GB RAM"

if (-not (Test-Path ".env")) {
    if ((Get-HardwareValue "SUPPORTED") -eq "0") {
        Write-Host 'Hardware check marked this machine UNSUPPORTED (<8GB RAM).'
        Write-Host "The stack will not start. Upgrade RAM, or email support@gridvoxsystems.com for remote setup."
        exit 1
    }
    $profile = Get-HardwareValue "PROFILE_FILE"
    if ($profile) { $profile = $profile -replace "/", "\" }
    if (-not $profile -or -not (Test-Path $profile)) {
        if ([int]$ramGb -le 10) { $profile = "profiles\8gb.env" }
        elseif ([int]$ramGb -le 24) { $profile = "profiles\16gb.env" }
        else { $profile = "profiles\32gb.env" }
    }
    Write-Host "Using $profile" '(from hardware check)'
    $header = @"
# Auto-selected by check-hardware + install.ps1 (${ramGb}GB RAM)
OLLAMA_PORT=11434
WEBUI_PORT=3000
WEBUI_AUTH=false
ENABLE_SIGNUP=false
WEBUI_SECRET_KEY=change-me-in-env-file
WATCHTOWER_POLL_INTERVAL=3600
OLLAMA_KEEP_ALIVE=30m
"@
    $header + "`n" + (Get-Content $profile -Raw) | Set-Content -Path ".env" -Encoding ascii
    Set-EnvModelOverrides
    $picked = Get-HardwareValue "PRIMARY_MODEL"
    if ($picked) { Write-Host "Primary model for this machine: $picked" }
} else {
    Write-Host 'Keeping existing .env (custom values not overwritten).'
}

Write-Host ""
Write-Host "Hardware notes:"
Write-Host '  - 8GB cannot run 24B models (use profiles\8gb.env).'
Write-Host '  - 16GB RAM, no NVIDIA: 3B is fast, 7B is ok, 14B/24B will crawl or crash.'
Write-Host '  - Devstral 24B really wants ~32GB RAM or a 4090-class GPU.'
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
    Write-Host "NVIDIA GPU detected - enabling docker-compose.gpu.yml"
    $composeArgs += @("-f", "docker-compose.gpu.yml")
    if (-not (Select-String -Path ".env" -Pattern "^COMPOSE_FILE=" -Quiet)) {
        Add-Content .env "COMPOSE_FILE=docker-compose.yml:docker-compose.gpu.yml"
    }
}

Write-Host ""
Write-Host 'Starting Ollama + Open WebUI...'
Write-Host ""

docker compose @composeArgs up -d ollama open-webui
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (Select-String -Path ".env" -Pattern "^COMPOSE_PROFILES=.*auto-update" -Quiet) {
    docker compose @composeArgs --profile auto-update up -d watchtower | Out-Host
}

Write-Host ""
Write-Host 'Downloading models now. Leave this window open.'
Write-Host 'Finished means you see: ALL MODELS DOWNLOADED SUCCESSFULLY'
Write-Host 'First run is typically 15-60 minutes depending on your internet.'
Write-Host ""

cmd /c "docker rm -f ollama-model-puller >nul 2>&1"

docker compose @composeArgs run --rm --name ollama-model-puller model-puller
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Model download did not finish cleanly."
    Write-Host "Check your internet, then re-run ONLY the download:"
    Write-Host "  docker compose run --rm model-puller"
    exit $LASTEXITCODE
}

$webPort = "3000"
$apiPort = "11434"
Get-Content ".env" | ForEach-Object {
    if ($_ -match "^WEBUI_PORT=(.*)$") { $webPort = $Matches[1] }
    if ($_ -match "^OLLAMA_PORT=(.*)$") { $apiPort = $Matches[1] }
}

Write-Host ""
Write-Host "Installation complete. Models are on disk. Chat is ready."
Write-Host "  WebUI:  http://localhost:$webPort"
Write-Host "  API:    http://localhost:$apiPort"
Write-Host ""
Write-Host "Open the WebUI URL, pick a model in the dropdown, and send a message."
Write-Host "Later updates:  .\update.ps1"
Write-Host ""
