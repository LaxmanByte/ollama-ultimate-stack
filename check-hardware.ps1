#Requires -Version 5.1
<#
.SYNOPSIS
  Ollama Ultimate Stack - hardware diagnostic (Windows native).
.DESCRIPTION
  Runs WITHOUT Docker or bash. Writes .hardware-profile for install.ps1.
  Does not overwrite a custom .env.

  powershell -ExecutionPolicy Bypass -File .\check-hardware.ps1
  Or double-click check-hardware.cmd
#>
$ErrorActionPreference = "Continue"
Set-Location -Path $PSScriptRoot

function Write-Color([string]$Text, [string]$Color = "White") {
    Write-Host $Text -ForegroundColor $Color
}

function Get-NvidiaVramGb {
    if (-not (Get-Command nvidia-smi -ErrorAction SilentlyContinue)) { return $null }
    try {
        $raw = nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>$null
        if (-not $raw) { return $null }
        $line = ($raw | Select-Object -First 1).ToString().Trim()
        $parts = $line -split ",", 2
        $name = $parts[0].Trim()
        $mb = 0
        if ($parts.Count -gt 1) { [void][int]::TryParse(($parts[1] -replace "\s", ""), [ref]$mb) }
        $gb = [math]::Round($mb / 1024.0, 1)
        return @{ Name = $name; VramGB = $gb; VramInt = [int][math]::Round($mb / 1024.0) }
    } catch {
        return $null
    }
}

function Get-RegistryVramGb([string]$GpuName) {
    $key = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
    try {
        foreach ($sub in @(Get-ChildItem $key -ErrorAction SilentlyContinue)) {
            $p = Get-ItemProperty $sub.PSPath -ErrorAction SilentlyContinue
            if (-not $p) { continue }
            $bytes = $p."HardwareInformation.qwMemorySize"
            if ($bytes -and [int64]$bytes -gt 0) {
                $gb = [math]::Round([double]$bytes / 1GB, 1)
                if ($gb -ge 1) {
                    $nm = $GpuName
                    if ($p.DriverDesc) { $nm = [string]$p.DriverDesc }
                    return @{ Name = $nm; VramGB = $gb; VramInt = [int][math]::Round($gb) }
                }
            }
        }
    } catch {}
    return $null
}

function Get-VramFromName([string]$Name) {
    $n = $Name.ToLowerInvariant()
    $map = [ordered]@{
        "rtx 5090" = 32; "rtx 5080" = 16; "rtx 5070 ti" = 16; "rtx 5070" = 12
        "rtx 4090" = 24; "rtx 4080 super" = 16; "rtx 4080" = 16
        "rtx 4070 ti super" = 16; "rtx 4070 ti" = 12; "rtx 4070 super" = 12; "rtx 4070" = 12
        "rtx 4060 ti" = 8; "rtx 4060" = 8
        "rtx 3090 ti" = 24; "rtx 3090" = 24; "rtx 3080 ti" = 12; "rtx 3080" = 10
        "rtx 3070 ti" = 8; "rtx 3070" = 8; "rtx 3060 ti" = 8; "rtx 3060" = 12
        "rtx 2080 ti" = 11; "rtx 2080" = 8; "rtx 2070" = 8; "rtx 2060" = 6
        "gtx 1080 ti" = 11; "gtx 1080" = 8; "gtx 1070" = 8; "gtx 1660" = 6
        "a5000" = 24; "a4000" = 16; "quadro rtx 6000" = 24
    }
    foreach ($k in $map.Keys) {
        if ($n -like "*$k*") { return $map[$k] }
    }
    return 0
}

Write-Host ""
Write-Host "=============================================================================="
Write-Host "  OLLAMA ULTIMATE STACK - HARDWARE DIAGNOSTIC"
Write-Host "=============================================================================="
Write-Host ""

# ---------------------------------------------------------------------------
# OS / CPU / RAM
# ---------------------------------------------------------------------------
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1

$osDetail = "{0} ({1})" -f $os.Caption.Trim(), $os.OSArchitecture
$cpuModel = $cpu.Name.Trim()
$cpuCores = [int]$cpu.NumberOfCores
$cpuThreads = [int]$cpu.NumberOfLogicalProcessors
$ramGb = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
$ramInt = [int][math]::Round($cs.TotalPhysicalMemory / 1GB)
$freeRamGb = [math]::Round(($os.FreePhysicalMemory * 1KB) / 1GB, 1)

# ---------------------------------------------------------------------------
# GPU - nvidia-smi first (honest VRAM). CIM AdapterRAM is often capped at 4GB.
# ---------------------------------------------------------------------------
$gpuName = "None detected"
$gpuVramGb = 0.0
$gpuVramInt = 0
$gpuKind = "none"

$nv = Get-NvidiaVramGb
if ($nv) {
    $gpuName = $nv.Name
    $gpuVramGb = [double]$nv.VramGB
    $gpuVramInt = [int]$nv.VramInt
    $gpuKind = "nvidia"
} else {
    $gpus = @(Get-CimInstance Win32_VideoController | Where-Object { $_.Name -and $_.Name -notmatch "Remote Desktop|Microsoft Basic" })
    if ($gpus.Count -gt 0) {
        $best = $gpus | Select-Object -First 1
        foreach ($g in $gpus) {
            if ($g.Name -match "NVIDIA|GeForce|RTX|GTX|Quadro|AMD|Radeon") { $best = $g; break }
        }
        $gpuName = $best.Name
        if ($gpuName -match "NVIDIA|GeForce|RTX|GTX|Quadro") { $gpuKind = "nvidia" }
        elseif ($gpuName -match "AMD|Radeon") { $gpuKind = "amd" }
        else { $gpuKind = "other" }

        $reg = Get-RegistryVramGb $gpuName
        if ($reg -and $reg.VramInt -gt 0) {
            $gpuVramGb = [double]$reg.VramGB
            $gpuVramInt = [int]$reg.VramInt
            if ($reg.Name) { $gpuName = $reg.Name }
        } else {
            $guess = Get-VramFromName $gpuName
            if ($guess -gt 0) {
                $gpuVramInt = $guess
                $gpuVramGb = [double]$guess
            } else {
                $cimBytes = 0L
                try { $cimBytes = [int64]$best.AdapterRAM } catch { $cimBytes = 0 }
                if ($cimBytes -gt 0) {
                    $cimGb = [math]::Round($cimBytes / 1GB, 1)
                    # CIM often reports 4GB for cards that are larger.
                    if ($cimGb -gt 0 -and $cimGb -lt 5) {
                        $gpuVramGb = $cimGb
                        $gpuVramInt = [int][math]::Round($cimGb)
                    } else {
                        $gpuVramGb = $cimGb
                        $gpuVramInt = [int][math]::Round($cimGb)
                    }
                }
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Disk + Docker (informational)
# ---------------------------------------------------------------------------
$sysDrive = $env:SystemDrive
if (-not $sysDrive) { $sysDrive = "C:" }
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$sysDrive'"
$diskFree = [math]::Round($disk.FreeSpace / 1GB, 1)
$diskInt = [int][math]::Round($disk.FreeSpace / 1GB)

$dockerVer = "Not installed (not required for this check)"
if (Get-Command docker -ErrorAction SilentlyContinue) {
    try { $dockerVer = (docker --version 2>$null) } catch { $dockerVer = "Installed" }
}

$wsl = $false
try {
    $wslOut = wsl --status 2>$null
    if ($LASTEXITCODE -eq 0 -or $wslOut) { $wsl = $true }
} catch {}

$overhead = 4  # Docker Desktop + WSL2 on Windows

# ---------------------------------------------------------------------------
# Profile
# ---------------------------------------------------------------------------
$profileName = "16gb"
if ($ramInt -le 10) { $profileName = "8gb" }
elseif ($ramInt -le 24) { $profileName = "16gb" }
else { $profileName = "32gb" }

if ($gpuKind -eq "nvidia" -and $gpuVramInt -ge 24 -and $ramInt -gt 10) {
    $profileName = "32gb"
}

$profileFile = "profiles/$profileName.env"
$supported = $ramInt -ge 8

function Get-Verdict([string]$Key) {
    $vram = $gpuVramInt
    $ram = $ramInt
    switch ($Key) {
        "embed" {
            if ($ram -ge 4) { return "RUN" } else { return "CRASH" }
        }
        "coder7" {
            if ($ram -ge 8 -or $vram -ge 6) { return "RUN" }
            elseif ($ram -ge 6) { return "SLOW" }
            else { return "CRASH" }
        }
        "r1_8" {
            if ($vram -ge 6 -or $ram -ge 10) { return "RUN" }
            elseif ($ram -ge 8) { return "SLOW" }
            else { return "CRASH" }
        }
        "r1_14" {
            if ($vram -ge 10 -or $ram -ge 32) { return "RUN" }
            elseif ($ram -ge 16) { return "SLOW" }
            else { return "CRASH" }
        }
        "devstral" {
            if ($vram -ge 24 -or $ram -ge 32) { return "RUN" }
            elseif ($gpuKind -eq "nvidia" -and $vram -ge 16 -and $ram -ge 16) { return "SLOW" }
            elseif ($ram -ge 24 -and $vram -lt 8) { return "SLOW" }
            else { return "CRASH" }
        }
        { $_ -in @("coder30", "r1_32") } {
            if ($vram -ge 22 -or $ram -ge 48) { return "RUN" }
            elseif ($ram -ge 32 -or $vram -ge 16) { return "SLOW" }
            else { return "CRASH" }
        }
        default { return "CRASH" }
    }
}

function Get-Note([string]$Key, [string]$Verdict) {
    switch ("$Key`:$Verdict") {
        "embed:RUN" { return "Tiny RAG embedder - always pull this first." }
        "coder7:RUN" { return "Fits. Fast fallback / 8GB primary." }
        "coder7:SLOW" { return "Tight. Close other apps." }
        "coder7:CRASH" { return "Needs ~8GB RAM." }
        "r1_8:RUN" { return "Fits as the 8GB research model." }
        "r1_8:SLOW" { return "Will run if you close other apps." }
        "r1_8:CRASH" { return "Needs ~8GB RAM." }
        "r1_14:RUN" { return "Fits (GPU or 32GB)." }
        "r1_14:SLOW" { return "Risky on 16GB + Docker Desktop - expect swap." }
        "r1_14:CRASH" { return "9GB weights + OS + Docker will not fit." }
        "devstral:RUN" { return "Official floor: RTX 4090 or 32GB RAM." }
        "devstral:SLOW" { return "Possible with offload; first token can take minutes." }
        "devstral:CRASH" { return "Will not fit. 8GB never; 16GB no GPU never." }
        "coder30:RUN" { return "19GB MoE - 24GB VRAM or lots of RAM." }
        "coder30:SLOW" { return "CPU / partial offload. Painfully slow." }
        "coder30:CRASH" { return "Needs ~32GB RAM or 20GB+ VRAM." }
        "r1_32:RUN" { return "20GB weights - 24GB VRAM or 48GB RAM." }
        "r1_32:SLOW" { return "Will thrash on 32GB CPU-only." }
        "r1_32:CRASH" { return "Needs ~32GB+ RAM or 20GB+ VRAM." }
        default { return "" }
    }
}

$vEmbed = Get-Verdict "embed"
$v7 = Get-Verdict "coder7"
$vR18 = Get-Verdict "r1_8"
$vR114 = Get-Verdict "r1_14"
$v24 = Get-Verdict "devstral"
$v30 = Get-Verdict "coder30"
$vR132 = Get-Verdict "r1_32"

$primary = "qwen2.5-coder:7b"
$research = "deepseek-r1:8b"
$fallback = "qwen2.5-coder:3b"
$embedding = "nomic-embed-text"

if ($v30 -eq "RUN") { $primary = "qwen3-coder:30b" }
elseif ($v24 -eq "RUN") { $primary = "devstral:24b" }
elseif ($v7 -ne "CRASH") { $primary = "qwen2.5-coder:7b" }

if ($vR132 -eq "RUN") { $research = "deepseek-r1:32b" }
elseif ($vR114 -eq "RUN") { $research = "deepseek-r1:14b" }
elseif ($vR18 -ne "CRASH") { $research = "deepseek-r1:8b" }

if ($v7 -eq "CRASH") { $fallback = "nomic-embed-text" }

function Write-VerdictCell([string]$Verdict) {
    $c = switch ($Verdict) {
        "RUN" { "Green" }
        "SLOW" { "Yellow" }
        "CRASH" { "Red" }
        default { "White" }
    }
    Write-Host ("{0,-7}" -f $Verdict) -ForegroundColor $c -NoNewline
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
Write-Host "MACHINE FACTS" -ForegroundColor White
Write-Host "------------------------------------------------------------------------------"
Write-Host "  OS:               " -NoNewline; Write-Color $osDetail "Cyan"
Write-Host "  CPU:              " -NoNewline; Write-Color $cpuModel "Cyan"
Write-Host "  CPU cores/threads:" -NoNewline; Write-Color (" {0} / {1}" -f $cpuCores, $cpuThreads) "Cyan"
Write-Host "  Total RAM:        " -NoNewline; Write-Color ("{0} GB" -f $ramGb) "Cyan"
Write-Host "  Available RAM:    " -NoNewline; Write-Color ("{0} GB" -f $freeRamGb) "Cyan"
Write-Host "  GPU:              " -NoNewline; Write-Color $gpuName "Cyan"
if ($gpuVramInt -gt 0) {
    Write-Host "  GPU VRAM:         " -NoNewline; Write-Color ("{0} GB" -f $gpuVramGb) "Cyan"
}
Write-Host ('  Disk free ({0}): ' -f $sysDrive) -NoNewline; Write-Color ("{0} GB" -f $diskFree) "Cyan"
Write-Host "  Docker:           " -NoNewline; Write-Color $dockerVer "Cyan"
Write-Host "  WSL:              " -NoNewline; Write-Color $(if ($wsl) { "Present" } else { "Not detected" }) "Cyan"
Write-Host "  Memory tax:       " -NoNewline
Write-Color ("~{0}GB typical for Windows + Docker Desktop / WSL2" -f $overhead) "Yellow"
Write-Host ""

Write-Host "AUTO PROFILE" -ForegroundColor White
Write-Host "------------------------------------------------------------------------------"
if (-not $supported) {
    Write-Host "  Selected:         " -NoNewline; Write-Color "UNSUPPORTED (<8GB RAM)" "Red"
    Write-Host "  Local chat will be extremely limited. Consider more RAM or a remote session."
} else {
    Write-Host "  Selected:         " -NoNewline; Write-Color ("{0}  ({1})" -f $profileName, $profileFile) "Green"
    Write-Host "  Rule:             <=10GB -> 8gb,  <=24GB -> 16gb,  else 32gb"
    if ($gpuKind -eq "nvidia" -and $gpuVramInt -ge 24) {
        Write-Host "  GPU note:         " -NoNewline; Write-Color "4090-class VRAM - 24B can run in GPU memory" "Green"
    } elseif ($gpuVramInt -lt 8) {
        Write-Host "  GPU note:         " -NoNewline; Write-Color 'VRAM under 8GB (or none) - do not treat 24B as a daily driver' "Yellow"
    }
}
Write-Host ""

Write-Host "MODEL FIT FOR THIS MACHINE" -ForegroundColor White
Write-Host "------------------------------------------------------------------------------"
Write-Host ("  {0,-22} {1,-8} {2,-8} {3}" -f "MODEL", "SIZE", "VERDICT", "NOTE")
Write-Host ("  {0,-22} {1,-8} {2,-8} {3}" -f "----------------------", "--------", "-------", "----")

$rows = @(
    @{ M = "nomic-embed-text"; S = "0.3GB";  K = "embed";    V = $vEmbed }
    @{ M = "qwen2.5-coder:7b"; S = "4.7GB";  K = "coder7";   V = $v7 }
    @{ M = "deepseek-r1:8b";   S = "5.2GB";  K = "r1_8";     V = $vR18 }
    @{ M = "deepseek-r1:14b";  S = "9.0GB";  K = "r1_14";    V = $vR114 }
    @{ M = "devstral:24b";     S = "~14GB";  K = "devstral"; V = $v24 }
    @{ M = "qwen3-coder:30b";  S = "19GB";   K = "coder30";  V = $v30 }
    @{ M = "deepseek-r1:32b";  S = "20GB";   K = "r1_32";    V = $vR132 }
)
foreach ($r in $rows) {
    Write-Host ("  {0,-22} {1,-8} " -f $r.M, $r.S) -NoNewline
    Write-VerdictCell $r.V
    Write-Host (" {0}" -f (Get-Note $r.K $r.V))
}
Write-Host ""
Write-Host '  RUN = fits.  SLOW = CPU swap / offload (usable but painful).  CRASH = will not fit.'
Write-Host ""

Write-Host "RECOMMENDED FOR THIS MACHINE" -ForegroundColor White
Write-Host "------------------------------------------------------------------------------"
Write-Host '  PRIMARY  (coding):    ' -NoNewline; Write-Color $primary "Green"
Write-Host '  RESEARCH (reasoning): ' -NoNewline; Write-Color $research "Green"
Write-Host '  FALLBACK (fast):      ' -NoNewline; Write-Color $fallback "Green"
Write-Host '  EMBEDDING (RAG):      ' -NoNewline; Write-Color $embedding "Green"
Write-Host ""

if ($diskInt -lt 30) {
    Write-Color ("  WARNING: only {0}GB free. You want ~30GB (8GB profile) to ~50GB (32GB profile)." -f $diskFree) "Red"
    Write-Host ""
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Color "  Docker is not installed yet. That is OK - this check does not need it." "Yellow"
    Write-Host "  The installer will set up Docker next."
    Write-Host ""
}

$when = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
$hw = @"
# Generated by check-hardware.ps1 - $when
# Do not commit. install.sh / install.ps1 read this if .env is missing.
PROFILE=$profileName
PROFILE_FILE=$profileFile
SUPPORTED=$(if ($supported) { "1" } else { "0" })
OS_NAME=Windows
OS_DETAIL=$osDetail
CPU_MODEL=$cpuModel
CPU_CORES=$cpuCores
CPU_THREADS=$cpuThreads
RAM_GB=$ramGb
RAM_GB_INT=$ramInt
GPU_NAME=$gpuName
GPU_VRAM_GB=$gpuVramGb
GPU_VRAM_INT=$gpuVramInt
GPU_KIND=$gpuKind
PRIMARY_MODEL=$primary
RESEARCH_MODEL=$research
FALLBACK_MODEL=$fallback
EMBEDDING_MODEL=$embedding
V_DEVSTRAL=$v24
V_R1_14=$vR114
V_CODER7=$v7
"@
Set-Content -Path (Join-Path $PSScriptRoot ".hardware-profile") -Value $hw -Encoding ascii

Write-Host "SAVED" -ForegroundColor White
Write-Host "------------------------------------------------------------------------------"
Write-Host ('  Wrote .hardware-profile (profile {0}, models above).' -f $profileName)
if (Test-Path (Join-Path $PSScriptRoot ".env")) {
    Write-Host '  Existing .env left untouched (custom / previous install).'
} else {
    Write-Host '  No .env yet - install.ps1 will create one from this profile.'
}
Write-Host ""
Write-Host "NEXT" -ForegroundColor White
Write-Host "------------------------------------------------------------------------------"
Write-Host "  Step 3 - install:"
Write-Host "    " -NoNewline; Write-Color "powershell -ExecutionPolicy Bypass -File .\install.ps1" "Cyan"
Write-Host ""
Write-Host '  Optional help (the stack stays free):  support@gridvoxsystems.com'
Write-Host '  Paid remote setup: docs/remote-setup.html  ($249 solo / $449 business)'
Write-Host ""
Write-Host "=============================================================================="
Write-Host "  Diagnostic complete."
Write-Host "=============================================================================="
Write-Host ""

if (-not $supported) { exit 1 }
exit 0
