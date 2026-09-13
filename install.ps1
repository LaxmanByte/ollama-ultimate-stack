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
Write-Host "Step 1 was clone. Step 2 is the hardware check. Step 3 is this installer."
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
    Write-Host "Hardware profile not found — running diagnostic first (no Docker required)..."
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

$ramGb = Get-HardwareValue "RAM_GB_INT"
if (-not $ramGb) {
    $ramGb = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
}
Write-Host "Detected ~${ramGb}GB RAM"

if (-not (Test-Path ".env")) {
    if ((Get-HardwareValue "SUPPORTED") -eq "0") {
        Write-Host "Hardware check marked this machine UNSUPPORTED (<8GB RAM)."
        Write-Host "The stack will not start. Upgrade RAM, or email barrelaxman@gmail.com for remote setup."
        exit 1
    }
    $profile = Get-HardwareValue "PROFILE_FILE"
    if ($profile) { $profile = $profile -replace "/", "\" }
    if (-not $profile -or -not (Test-Path $profile)) {
        if ([int]$ramGb -le 10) { $profile = "profiles\8gb.env" }
        elseif ([int]$ramGb -le 24) { $profile = "profiles\16gb.env" }
        else { $profile = "profiles\32gb.env" }
    }
    Write-Host "Using $profile (from hardware check)"
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
    Write-Host "Keeping existing .env (custom values not overwritten)."
}

Write-Host ""
Write-Host "Hardware notes:"
Write-Host "  - 8GB cannot run 24B models (use profiles\8gb.env)."
Write-Host "  - 16GB RAM, no GPU: 7B ok, 14B risky, 24B will crash."
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
