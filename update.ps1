#Requires -Version 5.1
<#
.SYNOPSIS
  Pull stack files from GitHub and refresh Docker images on this machine.
  Preserves local .env.
#>
$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

Write-Host ""
Write-Host "=============================================================================="
Write-Host "  OLLAMA ULTIMATE STACK — UPDATE"
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

if (-not (Test-DockerReady)) {
    Write-Host "Docker is not running. Start Docker Desktop, then re-run."
    exit 1
}

$envBackup = $null
if (Test-Path ".env") {
    $envBackup = [System.IO.Path]::GetTempFileName()
    Copy-Item ".env" $envBackup -Force
    Write-Host "Preserved local .env"
}

if (Test-Path ".git") {
    git fetch origin
    if ($LASTEXITCODE -eq 0) {
        git pull --ff-only
    } else {
        Write-Host "No git upstream — updating images only."
    }
} else {
    Write-Host "Not a git checkout — updating Docker images only."
    Write-Host "To receive compose/script changes: clone https://github.com/LaxmanByte/ollama-ultimate-stack.git"
}

if ($envBackup -and (Test-Path $envBackup)) {
    Copy-Item $envBackup ".env" -Force
    Remove-Item $envBackup -Force
    Write-Host "Restored local .env"
}

$composeArgs = @("-f", "docker-compose.yml")
if ((Test-Path ".env") -and (Select-String -Path ".env" -Pattern "docker-compose.gpu.yml" -Quiet)) {
    $composeArgs += @("-f", "docker-compose.gpu.yml")
} elseif (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
    $composeArgs += @("-f", "docker-compose.gpu.yml")
}

Write-Host "Pulling container images..."
docker compose @composeArgs pull
Write-Host "Recreating services..."
docker compose @composeArgs up -d

Write-Host ""
Write-Host "Update complete. WebUI: http://localhost:3000"
Write-Host ""
