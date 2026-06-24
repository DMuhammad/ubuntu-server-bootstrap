#!/bin/bash
# =============================================================================
# Module: Initial Server Setup
# Description: Performs essential first-time server configuration including
#              package updates, firewall, timezone, user creation, and swap.
# =============================================================================

show_section "Initial Server Setup"

set_steps 5

# ─────────────────────────────────────────────────────────────────────────────
# Step 1: Update & Upgrade Packages
# ─────────────────────────────────────────────────────────────────────────────
step "Updating & upgrading system packages"

show_spinner "Updating package lists" apt-get update -y
show_spinner "Upgrading installed packages" apt-get upgrade -y

success "System packages updated and upgraded"

# ─────────────────────────────────────────────────────────────────────────────
# Step 2: Enable Firewall (UFW)
# ─────────────────────────────────────────────────────────────────────────────
step "Configuring firewall (UFW)"

# Define available ports with labels
FIREWALL_OPTIONS=(
    "SSH (22)"
    "HTTP (80)"
    "HTTPS (443)"
    "MySQL (3306)"
    "PostgreSQL (5432)"
    "Redis (6379)"
)

# Map labels to actual port numbers
FIREWALL_PORTS=(22 80 443 3306 5432 6379)

# Pre-select SSH, HTTP, and HTTPS by default
PRESELECTED=(0 1 2)

select_multi "Select ports to allow through the firewall" "${FIREWALL_OPTIONS[@]}"

ALLOWED_PORTS_SUMMARY=""

if [[ ${#SELECTED_INDICES[@]} -gt 0 ]]; then
    for idx in "${SELECTED_INDICES[@]}"; do
        port="${FIREWALL_PORTS[$idx]}"
        show_spinner "Allowing port $port (${SELECTED_ITEMS[$idx]})" ufw allow "$port"
        ALLOWED_PORTS_SUMMARY+="${FIREWALL_PORTS[$idx]} "
    done
else
    warning "No ports selected — only enabling UFW with no extra rules"
fi

# Enable UFW (non-interactive: force yes)
show_spinner "Enabling UFW" ufw --force enable

success "Firewall configured and enabled"

# ─────────────────────────────────────────────────────────────────────────────
# Step 3: Set Timezone
# ─────────────────────────────────────────────────────────────────────────────
step "Setting server timezone"

TIMEZONE_OPTIONS=(
    "Asia/Jakarta"
    "Asia/Singapore"
    "Asia/Kuala_Lumpur"
    "UTC"
    "America/New_York"
)

select_one "Select your timezone" "${TIMEZONE_OPTIONS[@]}"

CHOSEN_TIMEZONE="$SELECTED_TEXT"

show_spinner "Setting timezone to $CHOSEN_TIMEZONE" timedatectl set-timezone "$CHOSEN_TIMEZONE"

success "Timezone set to $CHOSEN_TIMEZONE"

# ─────────────────────────────────────────────────────────────────────────────
# Step 4: Create New Sudo User (Optional)
# ─────────────────────────────────────────────────────────────────────────────
step "Create new sudo user (optional)"

NEW_USER=""

if confirm "Would you like to create a new sudo user?"; then
    input_text "Enter the new username" "deploy"
    NEW_USER="$INPUT_VALUE"

    if id "$NEW_USER" &>/dev/null; then
        warning "User '$NEW_USER' already exists — skipping creation"
    else
        show_spinner "Creating user '$NEW_USER'" adduser --gecos "" --disabled-password "$NEW_USER"
        show_spinner "Adding '$NEW_USER' to sudo group" usermod -aG sudo "$NEW_USER"

        # Prompt for password
        info "Set a password for the new user '$NEW_USER':"
        passwd "$NEW_USER"

        success "User '$NEW_USER' created and added to sudo group"
    fi
else
    info "Skipping sudo user creation"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 5: Setup Swap Space (Optional)
# ─────────────────────────────────────────────────────────────────────────────
step "Setup swap space (optional)"

SWAP_SIZE=""

if confirm "Would you like to configure swap space?"; then
    SWAP_OPTIONS=("1GB" "2GB" "4GB")

    select_one "Select swap size" "${SWAP_OPTIONS[@]}"

    SWAP_SIZE="$SELECTED_TEXT"

    # Convert label to fallocate-compatible value (e.g., "2GB" -> "2G")
    SWAP_VALUE="${SWAP_SIZE%B}"

    if [[ -f /swapfile ]]; then
        warning "Swapfile already exists — removing old swapfile first"
        swapoff /swapfile 2>/dev/null
        rm -f /swapfile
    fi

    show_spinner "Allocating ${SWAP_SIZE} swapfile" fallocate -l "$SWAP_VALUE" /swapfile

    # Secure permissions
    chmod 600 /swapfile

    show_spinner "Formatting swapfile" mkswap /swapfile
    show_spinner "Enabling swap" swapon /swapfile

    # Persist swap across reboots via fstab
    if ! grep -q '/swapfile' /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
        info "Swap entry added to /etc/fstab"
    else
        info "Swap entry already exists in /etc/fstab"
    fi

    success "Swap space configured (${SWAP_SIZE})"
else
    info "Skipping swap setup"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
SUMMARY_ARGS=("Initial Server Setup")
SUMMARY_ARGS+=("Timezone=${CHOSEN_TIMEZONE}")
SUMMARY_ARGS+=("Firewall=Enabled")
SUMMARY_ARGS+=("Allowed Ports=${ALLOWED_PORTS_SUMMARY:-None}")

if [[ -n "$NEW_USER" ]]; then
    SUMMARY_ARGS+=("Sudo User=${NEW_USER}")
else
    SUMMARY_ARGS+=("Sudo User=Skipped")
fi

if [[ -n "$SWAP_SIZE" ]]; then
    SUMMARY_ARGS+=("Swap Size=${SWAP_SIZE}")
else
    SUMMARY_ARGS+=("Swap=Skipped")
fi

show_summary "${SUMMARY_ARGS[@]}"