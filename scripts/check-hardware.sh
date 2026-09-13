#!/usr/bin/env bash
# =============================================================================
# Ollama Ultimate Stack — hardware diagnostic (Linux / macOS / WSL)
# Runs WITHOUT Docker. Writes .hardware-profile for install.sh.
# Does not overwrite a custom .env.
# Usage: bash scripts/check-hardware.sh
#        bash check-hardware.sh
# =============================================================================

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ ! -f "$ROOT/docker-compose.yml" ] && [ -f "$(cd "$(dirname "$0")" && pwd)/docker-compose.yml" ]; then
    ROOT="$(cd "$(dirname "$0")" && pwd)"
fi
cd "$ROOT"

if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; NC=''
fi

echo ""
echo "=============================================================================="
echo "  OLLAMA ULTIMATE STACK — HARDWARE DIAGNOSTIC"
echo "=============================================================================="
echo ""

# ---------------------------------------------------------------------------
# Detect OS
# ---------------------------------------------------------------------------
OS_NAME="unknown"
OS_DETAIL=""
IS_WSL=0
IS_APPLE=0
IS_UNIFIED=0

UNAME_S="$(uname -s 2>/dev/null || echo unknown)"
UNAME_M="$(uname -m 2>/dev/null || echo unknown)"

if [ -n "${WSL_DISTRO_NAME:-}" ] || { [ -f /proc/version ] && grep -qi microsoft /proc/version 2>/dev/null; }; then
    OS_NAME="WSL"
    IS_WSL=1
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_DETAIL="${PRETTY_NAME:-Linux} (WSL)"
    else
        OS_DETAIL="Linux (WSL)"
    fi
elif [ "$UNAME_S" = "Linux" ]; then
    OS_NAME="Linux"
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_DETAIL="${PRETTY_NAME:-Linux}"
    else
        OS_DETAIL="Linux"
    fi
elif [ "$UNAME_S" = "Darwin" ]; then
    OS_NAME="macOS"
    OS_DETAIL="macOS $(sw_vers -productVersion 2>/dev/null || echo unknown)"
    if sysctl -n machdep.cpu.brand_string 2>/dev/null | grep -qi "Apple"; then
        IS_APPLE=1
        IS_UNIFIED=1
    fi
    if [ "$UNAME_M" = "arm64" ]; then
        IS_APPLE=1
        IS_UNIFIED=1
    fi
else
    OS_NAME="$UNAME_S"
    OS_DETAIL="$UNAME_S $UNAME_M"
fi

# ---------------------------------------------------------------------------
# CPU
# ---------------------------------------------------------------------------
CPU_MODEL="unknown"
CPU_CORES="?"
CPU_THREADS="?"

if [ -f /proc/cpuinfo ]; then
    CPU_MODEL="$(awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo 2>/dev/null || echo unknown)"
    CPU_THREADS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || echo '?')"
    CPU_CORES="$(awk '/^cpu cores/ {print $4; exit}' /proc/cpuinfo 2>/dev/null || echo "$CPU_THREADS")"
elif command -v sysctl >/dev/null 2>&1; then
    CPU_MODEL="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo unknown)"
    CPU_THREADS="$(sysctl -n hw.ncpu 2>/dev/null || echo '?')"
    CPU_CORES="$(sysctl -n hw.physicalcpu 2>/dev/null || echo "$CPU_THREADS")"
fi

# ---------------------------------------------------------------------------
# RAM (GB)
# ---------------------------------------------------------------------------
RAM_GB="0"
RAM_INT=0
FREE_RAM_GB="unknown"

if [ -f /proc/meminfo ]; then
    RAM_GB="$(awk '/MemTotal/ {printf "%.1f", $2/1024/1024}' /proc/meminfo)"
    RAM_INT="$(awk '/MemTotal/ {printf "%d", int($2/1024/1024 + 0.5)}' /proc/meminfo)"
    FREE_RAM_GB="$(awk '/MemAvailable/ {printf "%.1f", $2/1024/1024}' /proc/meminfo)"
elif command -v sysctl >/dev/null 2>&1; then
    MEM_BYTES="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
    RAM_GB="$(awk -v b="$MEM_BYTES" 'BEGIN {printf "%.1f", b/1024/1024/1024}')"
    RAM_INT="$(awk -v b="$MEM_BYTES" 'BEGIN {printf "%d", int(b/1024/1024/1024 + 0.5)}')"
fi

# ---------------------------------------------------------------------------
# GPU + VRAM
# ---------------------------------------------------------------------------
GPU_NAME="None detected"
GPU_VRAM_GB="0"
GPU_VRAM_INT=0
GPU_KIND="none"

if command -v nvidia-smi >/dev/null 2>&1; then
    GPU_LINE="$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 || true)"
    if [ -n "$GPU_LINE" ]; then
        GPU_NAME="$(echo "$GPU_LINE" | awk -F',' '{gsub(/^ +| +$/,"",$1); print $1}')"
        GPU_VRAM_INT="$(echo "$GPU_LINE" | awk -F',' '{v=$2; gsub(/ /,"",v); printf "%d", int(v/1024 + 0.5)}')"
        GPU_VRAM_GB="$(echo "$GPU_LINE" | awk -F',' '{v=$2; gsub(/ /,"",v); printf "%.1f", v/1024}')"
        GPU_KIND="nvidia"
    fi
fi

if [ "$GPU_KIND" = "none" ] && [ "$OS_NAME" = "macOS" ]; then
    PROF="$(system_profiler SPDisplaysDataType 2>/dev/null || true)"
    CHIP="$(echo "$PROF" | awk -F': ' '/Chipset Model/ {print $2; exit}')"
    if [ -n "$CHIP" ]; then
        GPU_NAME="$CHIP"
    elif [ "$IS_APPLE" = 1 ]; then
        GPU_NAME="Apple Silicon (unified memory)"
    fi
    if [ "$IS_UNIFIED" = 1 ]; then
        GPU_VRAM_GB="$RAM_GB"
        GPU_VRAM_INT="$RAM_INT"
        GPU_KIND="apple_unified"
    fi
fi

if [ "$GPU_KIND" = "none" ] && command -v lspci >/dev/null 2>&1; then
    if lspci 2>/dev/null | grep -qi "vga.*amd\|vga.*ati\|display.*amd"; then
        GPU_NAME="$(lspci 2>/dev/null | grep -i 'vga\|3d\|display' | head -1 | sed 's/.*: //')"
        GPU_KIND="amd"
    elif lspci 2>/dev/null | grep -qi "vga\|3d\|display"; then
        GPU_NAME="$(lspci 2>/dev/null | grep -i 'vga\|3d\|display' | head -1 | sed 's/.*: //')"
        GPU_KIND="other"
    fi
fi

# ---------------------------------------------------------------------------
# Disk + Docker (informational; checker does not require Docker)
# ---------------------------------------------------------------------------
DISK_FREE_GB="$(df -k . 2>/dev/null | awk 'NR==2 {printf "%.1f", $4/1024/1024}')"
DISK_INT="$(df -k . 2>/dev/null | awk 'NR==2 {printf "%d", int($4/1024/1024 + 0.5)}')"
[ -z "$DISK_INT" ] && DISK_INT=0

DOCKER_VER="Not installed (not required for this check)"
if command -v docker >/dev/null 2>&1; then
    DOCKER_VER="$(docker --version 2>/dev/null || echo Installed)"
fi

# Overhead: Windows/WSL Docker Desktop + WSL VM is the tax that kills 16GB boxes.
OVERHEAD=1
if [ "$IS_WSL" = 1 ]; then
    OVERHEAD=4
elif [ "$OS_NAME" = "macOS" ]; then
    OVERHEAD=3
fi

# ---------------------------------------------------------------------------
# Profile: <=10GB → 8gb, <=24GB → 16gb, else 32gb
# GPU-aware: 24GB+ VRAM (4090-class) can use 32gb if RAM > 10
# ---------------------------------------------------------------------------
PROFILE="16gb"
if [ "$RAM_INT" -le 10 ]; then
    PROFILE="8gb"
elif [ "$RAM_INT" -le 24 ]; then
    PROFILE="16gb"
else
    PROFILE="32gb"
fi

if [ "$GPU_KIND" = "nvidia" ] && [ "$GPU_VRAM_INT" -ge 24 ] && [ "$RAM_INT" -gt 10 ]; then
    PROFILE="32gb"
fi

PROFILE_FILE="profiles/${PROFILE}.env"
SUPPORTED=1
if [ "$RAM_INT" -lt 8 ]; then
    SUPPORTED=0
fi

# ---------------------------------------------------------------------------
# Verdicts — official / library weights (Q4 default)
#   nomic-embed-text     0.3GB   ollama.com/library/nomic-embed-text
#   qwen2.5-coder:7b     4.7GB   ollama.com/library/qwen2.5-coder:7b
#   deepseek-r1:8b       5.2GB   ollama.com/library/deepseek-r1
#   deepseek-r1:14b      9.0GB   ollama.com/library/deepseek-r1
#   devstral:24b        ~14GB    Mistral: RTX 4090 or 32GB Mac
#   qwen3-coder:30b     19GB     ollama.com/library/qwen3-coder:30b
#   deepseek-r1:32b     20GB     ollama.com/library/deepseek-r1
# ---------------------------------------------------------------------------
# Returns RUN / SLOW / CRASH for a named stack model.
verdict_for() {
    local key="$1"
    local vram="$GPU_VRAM_INT"
    local ram="$RAM_INT"
    local unified="$IS_UNIFIED"
    local kind="$GPU_KIND"

    case "$key" in
        embed)
            if [ "$ram" -ge 4 ]; then echo RUN; else echo CRASH; fi
            ;;
        coder7)
            if [ "$ram" -ge 8 ] || [ "$vram" -ge 6 ]; then echo RUN
            elif [ "$ram" -ge 6 ]; then echo SLOW
            else echo CRASH; fi
            ;;
        r1_8)
            if [ "$vram" -ge 6 ] || [ "$ram" -ge 10 ]; then echo RUN
            elif [ "$ram" -ge 8 ]; then echo SLOW
            else echo CRASH; fi
            ;;
        r1_14)
            if [ "$vram" -ge 10 ] || [ "$ram" -ge 32 ] || { [ "$unified" = 1 ] && [ "$ram" -ge 24 ]; }; then echo RUN
            elif [ "$ram" -ge 16 ]; then echo SLOW
            else echo CRASH; fi
            ;;
        devstral)
            # Honest: 8GB never; 16GB no GPU = crash; 32GB or 4090-class = run.
            # VRAM < 8 never recommend 24B as a runner.
            if [ "$vram" -ge 24 ] || [ "$ram" -ge 32 ] || { [ "$unified" = 1 ] && [ "$ram" -ge 32 ]; }; then echo RUN
            elif [ "$kind" = "nvidia" ] && [ "$vram" -ge 16 ] && [ "$ram" -ge 16 ]; then echo SLOW
            elif [ "$ram" -ge 24 ] && [ "$vram" -lt 8 ]; then echo SLOW
            else echo CRASH; fi
            ;;
        coder30|r1_32)
            if [ "$vram" -ge 22 ] || [ "$ram" -ge 48 ]; then echo RUN
            elif [ "$ram" -ge 32 ] || [ "$vram" -ge 16 ]; then echo SLOW
            else echo CRASH; fi
            ;;
        *)
            echo CRASH
            ;;
    esac
}

note_for() {
    local key="$1" verdict="$2"
    case "$key:$verdict" in
        embed:RUN) echo "Tiny RAG embedder — always pull this first." ;;
        coder7:RUN) echo "Fits. Fast fallback / 8GB primary." ;;
        coder7:SLOW) echo "Tight. Close other apps." ;;
        coder7:CRASH) echo "Needs ~8GB RAM." ;;
        r1_8:RUN) echo "Fits as the 8GB research model." ;;
        r1_8:SLOW) echo "Will run if you close other apps." ;;
        r1_8:CRASH) echo "Needs ~8GB RAM." ;;
        r1_14:RUN) echo "Fits (GPU or 32GB)." ;;
        r1_14:SLOW) echo "Risky on 16GB + Docker — expect swap." ;;
        r1_14:CRASH) echo "9GB weights + OS + Docker will not fit." ;;
        devstral:RUN) echo "Official floor: RTX 4090 or 32GB (Mac unified / RAM)." ;;
        devstral:SLOW) echo "Possible with offload; first token can take minutes." ;;
        devstral:CRASH) echo "Will not fit. 8GB never; 16GB no GPU never." ;;
        coder30:RUN) echo "19GB MoE — 24GB VRAM or lots of RAM." ;;
        coder30:SLOW) echo "CPU / partial offload. Painfully slow." ;;
        coder30:CRASH) echo "Needs ~32GB RAM or 20GB+ VRAM." ;;
        r1_32:RUN) echo "20GB weights — 24GB VRAM or 48GB RAM." ;;
        r1_32:SLOW) echo "Will thrash on 32GB CPU-only." ;;
        r1_32:CRASH) echo "Needs ~32GB+ RAM or 20GB+ VRAM." ;;
        *) echo "" ;;
    esac
}

V_EMBED="$(verdict_for embed)"
V_7B="$(verdict_for coder7)"
V_R18="$(verdict_for r1_8)"
V_R114="$(verdict_for r1_14)"
V_24B="$(verdict_for devstral)"
V_30B="$(verdict_for coder30)"
V_R132="$(verdict_for r1_32)"

# Recommended roles for THIS machine (never pick CRASH; skip 24B if VRAM < 8 unless 32GB/unified)
PRIMARY="qwen2.5-coder:7b"
RESEARCH="deepseek-r1:8b"
FALLBACK="qwen2.5-coder:7b"
EMBEDDING="nomic-embed-text"

pick_primary() {
    if [ "$V_30B" = "RUN" ]; then
        PRIMARY="qwen3-coder:30b"
        return
    fi
    if [ "$V_24B" = "RUN" ]; then
        PRIMARY="devstral:24b"
        return
    fi
    if [ "$V_7B" != "CRASH" ]; then
        PRIMARY="qwen2.5-coder:7b"
        return
    fi
    PRIMARY="qwen2.5-coder:7b"
}

pick_research() {
    if [ "$V_R132" = "RUN" ]; then
        RESEARCH="deepseek-r1:32b"
        return
    fi
    if [ "$V_R114" = "RUN" ]; then
        RESEARCH="deepseek-r1:14b"
        return
    fi
    if [ "$V_R114" = "SLOW" ] && [ "$RAM_INT" -ge 16 ]; then
        RESEARCH="deepseek-r1:14b"
        return
    fi
    if [ "$V_R18" != "CRASH" ]; then
        RESEARCH="deepseek-r1:8b"
        return
    fi
    RESEARCH="deepseek-r1:8b"
}

pick_primary
pick_research
if [ "$V_7B" = "CRASH" ]; then
    FALLBACK="nomic-embed-text"
fi

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
echo "${BOLD}MACHINE FACTS${NC}"
echo "------------------------------------------------------------------------------"
echo "  OS:              ${CYAN}${OS_DETAIL}${NC}"
echo "  Arch:            ${CYAN}${UNAME_M}${NC}"
echo "  CPU:             ${CYAN}${CPU_MODEL}${NC}"
echo "  CPU cores/threads:${CYAN} ${CPU_CORES} / ${CPU_THREADS}${NC}"
echo "  Total RAM:       ${CYAN}${RAM_GB} GB${NC}"
echo "  Available RAM:   ${CYAN}${FREE_RAM_GB} GB${NC}"
echo "  GPU:             ${CYAN}${GPU_NAME}${NC}"
if [ "$GPU_KIND" = "apple_unified" ]; then
    echo "  GPU memory:      ${CYAN}unified with system RAM (${RAM_GB} GB)${NC}"
elif [ "$GPU_VRAM_INT" -gt 0 ] && [ "$GPU_KIND" != "none" ]; then
    echo "  GPU VRAM:        ${CYAN}${GPU_VRAM_GB} GB${NC}"
fi
echo "  Disk free:       ${CYAN}${DISK_FREE_GB} GB${NC}"
echo "  Docker:          ${CYAN}${DOCKER_VER}${NC}"
if [ "$IS_WSL" = 1 ] || [ "$OS_NAME" = "macOS" ]; then
    echo "  Memory tax:      ${YELLOW}~${OVERHEAD}GB reserved for OS + Docker Desktop / WSL${NC}"
fi
echo ""

echo "${BOLD}AUTO PROFILE${NC}"
echo "------------------------------------------------------------------------------"
if [ "$SUPPORTED" = 0 ]; then
    echo "  Selected:        ${RED}UNSUPPORTED (<8GB RAM)${NC}"
    echo "  Local chat will be extremely limited. Consider more RAM or a remote session."
else
    echo "  Selected:        ${GREEN}${BOLD}${PROFILE}${NC}  (${PROFILE_FILE})"
    echo "  Rule:            <=10GB → 8gb,  <=24GB → 16gb,  else 32gb"
    if [ "$GPU_KIND" = "nvidia" ] && [ "$GPU_VRAM_INT" -ge 24 ]; then
        echo "  GPU note:        ${GREEN}4090-class VRAM — 24B can run in GPU memory${NC}"
    elif [ "$GPU_VRAM_INT" -lt 8 ] && [ "$IS_UNIFIED" = 0 ]; then
        echo "  GPU note:        ${YELLOW}VRAM < 8GB (or none) — do not treat 24B as a daily driver${NC}"
    fi
fi
echo ""

color_verdict() {
    case "$1" in
        RUN) printf "${GREEN}%-7s${NC}" "$1" ;;
        SLOW) printf "${YELLOW}%-7s${NC}" "$1" ;;
        CRASH) printf "${RED}%-7s${NC}" "$1" ;;
        *) printf "%-7s" "$1" ;;
    esac
}

echo "${BOLD}MODEL FIT FOR THIS MACHINE${NC}"
echo "------------------------------------------------------------------------------"
printf "  %-22s %-8s %-8s %s\n" "MODEL" "SIZE" "VERDICT" "NOTE"
printf "  %-22s %-8s %-8s %s\n" "----------------------" "--------" "-------" "----"
printf "  %-22s %-8s " "nomic-embed-text" "0.3GB"; color_verdict "$V_EMBED"; echo " $(note_for embed "$V_EMBED")"
printf "  %-22s %-8s " "qwen2.5-coder:7b" "4.7GB"; color_verdict "$V_7B"; echo " $(note_for coder7 "$V_7B")"
printf "  %-22s %-8s " "deepseek-r1:8b" "5.2GB"; color_verdict "$V_R18"; echo " $(note_for r1_8 "$V_R18")"
printf "  %-22s %-8s " "deepseek-r1:14b" "9.0GB"; color_verdict "$V_R114"; echo " $(note_for r1_14 "$V_R114")"
printf "  %-22s %-8s " "devstral:24b" "~14GB"; color_verdict "$V_24B"; echo " $(note_for devstral "$V_24B")"
printf "  %-22s %-8s " "qwen3-coder:30b" "19GB"; color_verdict "$V_30B"; echo " $(note_for coder30 "$V_30B")"
printf "  %-22s %-8s " "deepseek-r1:32b" "20GB"; color_verdict "$V_R132"; echo " $(note_for r1_32 "$V_R132")"
echo ""
echo "  ${BOLD}RUN${NC} = fits.  ${BOLD}SLOW${NC} = CPU swap / offload (usable but painful).  ${BOLD}CRASH${NC} = will not fit."
echo ""

echo "${BOLD}RECOMMENDED FOR THIS MACHINE${NC}"
echo "------------------------------------------------------------------------------"
echo "  PRIMARY  (coding):    ${GREEN}${PRIMARY}${NC}"
echo "  RESEARCH (reasoning): ${GREEN}${RESEARCH}${NC}"
echo "  FALLBACK (fast):      ${GREEN}${FALLBACK}${NC}"
echo "  EMBEDDING (RAG):      ${GREEN}${EMBEDDING}${NC}"
echo ""

if [ "$DISK_INT" -lt 30 ]; then
    echo "${RED}  WARNING: only ${DISK_FREE_GB}GB free. You want ~30GB (8GB profile) to ~50GB (32GB profile).${NC}"
    echo ""
fi

if command -v docker >/dev/null 2>&1; then
    :
else
    echo "${YELLOW}  Docker is not installed yet. That is OK — this check does not need it.${NC}"
    echo "  The installer will set up Docker next."
    echo ""
fi

# ---------------------------------------------------------------------------
# Persist — never clobber a custom .env
# ---------------------------------------------------------------------------
{
    echo "# Generated by scripts/check-hardware.sh — $(date -Iseconds 2>/dev/null || date)"
    echo "# Do not commit. install.sh / install.ps1 read this if .env is missing."
    echo "PROFILE=${PROFILE}"
    echo "PROFILE_FILE=${PROFILE_FILE}"
    echo "SUPPORTED=${SUPPORTED}"
    echo "OS_NAME=${OS_NAME}"
    echo "OS_DETAIL=${OS_DETAIL}"
    echo "CPU_MODEL=${CPU_MODEL}"
    echo "CPU_CORES=${CPU_CORES}"
    echo "CPU_THREADS=${CPU_THREADS}"
    echo "RAM_GB=${RAM_GB}"
    echo "RAM_GB_INT=${RAM_INT}"
    echo "GPU_NAME=${GPU_NAME}"
    echo "GPU_VRAM_GB=${GPU_VRAM_GB}"
    echo "GPU_VRAM_INT=${GPU_VRAM_INT}"
    echo "GPU_KIND=${GPU_KIND}"
    echo "PRIMARY_MODEL=${PRIMARY}"
    echo "RESEARCH_MODEL=${RESEARCH}"
    echo "FALLBACK_MODEL=${FALLBACK}"
    echo "EMBEDDING_MODEL=${EMBEDDING}"
    echo "V_DEVSTRAL=${V_24B}"
    echo "V_R1_14=${V_R114}"
    echo "V_CODER7=${V_7B}"
} > "$ROOT/.hardware-profile"

echo "${BOLD}SAVED${NC}"
echo "------------------------------------------------------------------------------"
echo "  Wrote ${CYAN}.hardware-profile${NC} (profile ${GREEN}${PROFILE}${NC}, models above)."
if [ -f "$ROOT/.env" ]; then
    echo "  Existing ${CYAN}.env${NC} left untouched (custom / previous install)."
else
    echo "  No .env yet — ${CYAN}install.sh${NC} will create one from this profile."
fi
echo ""
echo "${BOLD}NEXT${NC}"
echo "------------------------------------------------------------------------------"
echo "  Step 3 — install:"
echo "    ${CYAN}bash install.sh${NC}"
echo ""
echo "  Optional paid help (the stack stays free):  barrelaxman@gmail.com"
echo "  Remote setup: \$200 individual / \$500 business"
echo ""
echo "=============================================================================="
echo "  Diagnostic complete."
echo "=============================================================================="
echo ""

if [ "$SUPPORTED" = 0 ]; then
    exit 1
fi
exit 0
