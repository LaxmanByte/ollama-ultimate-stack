#Requires -Version 5.1
<#
.SYNOPSIS
  One entry for every Windows PC - no OS or model choices required.
.DESCRIPTION
  Runs the hardware diagnostic, then the full installer (Docker + Ollama + models).
  Detects RAM / GPU and picks models that fit. Works on Intel and ARM Windows.
#>
$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot
Get-ChildItem -LiteralPath $PSScriptRoot -Recurse -File -ErrorAction SilentlyContinue |
    Unblock-File -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=============================================================================="
Write-Host "  OLLAMA ULTIMATE STACK - SETUP"
Write-Host "=============================================================================="
Write-Host ""
Write-Host "  You do not need to know Windows vs Mac, Intel vs ARM, or which model to pick."
Write-Host "  This script reads your machine and downloads what fits."
Write-Host ""
Write-Host "  Leave this window open. First run often takes 15-60 minutes."
Write-Host "  Done when you see: ALL MODELS DOWNLOADED SUCCESSFULLY"
Write-Host ""

$arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
$os = (Get-CimInstance Win32_OperatingSystem).Caption.Trim()
Write-Host "  Detected: $os ($arch)"
Write-Host ""

$check = Join-Path $PSScriptRoot "check-hardware.ps1"
$install = Join-Path $PSScriptRoot "install.ps1"

if (-not (Test-Path $check)) {
    Write-Host "ERROR: check-hardware.ps1 missing. Re-clone the repo."
    exit 1
}
if (-not (Test-Path $install)) {
    Write-Host "ERROR: install.ps1 missing. Re-clone the repo."
    exit 1
}

Write-Host "------------------------------------------------------------------------------"
Write-Host "  Step 1/2 - Hardware check (no Docker needed)"
Write-Host "------------------------------------------------------------------------------"
Write-Host ""
& $check
$checkCode = $LASTEXITCODE

Write-Host ""
Write-Host "------------------------------------------------------------------------------"
Write-Host "  Step 2/2 - Install Docker (if needed), start Ollama, download models"
Write-Host "------------------------------------------------------------------------------"
Write-Host ""
& $install
$installCode = $LASTEXITCODE

if ($installCode -ne 0) {
    Write-Host ""
    Write-Host "Setup did not finish. Common fixes:"
    Write-Host "  - Start Docker Desktop, wait until the engine is running, then double-click setup.cmd again"
    Write-Host "  - Check internet, then: docker compose run --rm model-puller"
    Write-Host "  - Email support@gridvoxsystems.com"
    exit $installCode
}

if ($checkCode -ne 0) {
    Write-Host ""
    Write-Host "Hardware check reported limits, but install finished. Use the models that fit."
}

Write-Host ""
Write-Host "=============================================================================="
Write-Host "  SETUP COMPLETE"
Write-Host "  Open http://localhost:3000 - pick a model - send Hello"
Write-Host "=============================================================================="
Write-Host ""
