#!/bin/bash

# ============================================================
#  Helper utilities for Ubuntu Server Bootstrap
# ============================================================

LOG_FILE="$HOME/.server-setup.log"
STEP_CURRENT=0
STEP_TOTAL=0

# ── Color output ──

success() {
    echo -e "\e[32m  ✔ $1\e[0m"
    log "SUCCESS" "$1"
}

warning() {
    echo -e "\e[33m  ⚠ $1\e[0m"
    log "WARNING" "$1"
}

error() {
    echo -e "\e[31m  ✘ $1\e[0m"
    log "ERROR" "$1"
}

info() {
    echo -e "\e[36m  ℹ $1\e[0m"
    log "INFO" "$1"
}

# ── Step counter ──

set_steps() {
    STEP_TOTAL=$1
    STEP_CURRENT=0
}

step() {
    ((STEP_CURRENT++))
    echo ""
    echo -e "\e[1m\e[97m  [$STEP_CURRENT/$STEP_TOTAL] $1\e[0m"
    log "STEP" "[$STEP_CURRENT/$STEP_TOTAL] $1"
}

# ── Visual helpers ──

divider() {
    echo -e "\e[2m  ────────────────────────────────────────\e[0m"
}

# ── Logging ──

log() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

# ── System checks ──

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root or with sudo"
        echo ""
        echo -e "  \e[2mUsage: sudo bash install.sh\e[0m"
        echo ""
        exit 1
    fi
}

check_ubuntu() {
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot detect OS. This script requires Ubuntu."
        exit 1
    fi

    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        error "This script requires Ubuntu. Detected: $ID"
        exit 1
    fi

    info "Detected: $PRETTY_NAME"
}

# ── Package helpers ──

install_package() {
    local package="$1"
    local label="${2:-$1}"
    show_spinner "Installing $label..." sudo apt install -y "$package"
}

is_installed() {
    dpkg -l "$1" &>/dev/null
}