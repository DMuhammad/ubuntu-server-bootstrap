#!/bin/bash
# =============================================================================
# Node.js Installation Module
# Installs Node.js via NVM with version selection.
# Optionally installs additional package managers (yarn, pnpm).
# =============================================================================

set_steps 3

# ── Step 1: Install NVM ─────────────────────────────────────────────────────
step "Install NVM (Node Version Manager)"

# Set NVM directory for root or current user
export NVM_DIR="${HOME}/.nvm"

show_spinner "Installing NVM" \
    bash -c "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash > /dev/null 2>&1"

# Source NVM into the current shell so we can use it immediately
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"

success "NVM installed successfully"
divider

# ── Step 2: Select and install Node.js version ──────────────────────────────
step "Select Node.js version"

select_one "Choose Node.js version to install" \
    "Latest LTS" "18" "20" "22"

case "$SELECTED" in
    0)
        NODE_LABEL="Latest LTS"
        show_spinner "Installing Node.js (Latest LTS)" \
            bash -c "source $NVM_DIR/nvm.sh && nvm install --lts > /dev/null 2>&1"
        ;;
    *)
        NODE_LABEL="$SELECTED_TEXT"
        show_spinner "Installing Node.js $SELECTED_TEXT" \
            bash -c "source $NVM_DIR/nvm.sh && nvm install $SELECTED_TEXT > /dev/null 2>&1"
        ;;
esac

# Re-source NVM to ensure the newly installed node is on PATH
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"

# Capture installed versions for summary
NODE_VERSION="$(node --version 2>/dev/null || echo 'unknown')"
NPM_VERSION="$(npm --version 2>/dev/null || echo 'unknown')"

success "Node.js $NODE_VERSION installed (npm $NPM_VERSION)"
divider

# ── Step 3: Additional package managers ──────────────────────────────────────
step "Additional package managers"

select_multi "Install additional package managers?" \
    "yarn" "pnpm"

EXTRA_PM_LIST=""
if [ "${#SELECTED_ITEMS[@]}" -gt 0 ]; then
    for pm in "${SELECTED_ITEMS[@]}"; do
        show_spinner "Installing $pm via npm" \
            bash -c "source $NVM_DIR/nvm.sh && npm install -g $pm > /dev/null 2>&1"
        EXTRA_PM_LIST="${EXTRA_PM_LIST}${pm} "
    done
    success "Additional package manager(s) installed: ${EXTRA_PM_LIST}"
else
    EXTRA_PM_LIST="None"
    info "No additional package managers selected"
fi

divider

# ── Summary ──────────────────────────────────────────────────────────────────
show_summary "Node.js" \
    "Node.js Version=$NODE_VERSION ($NODE_LABEL)" \
    "npm Version=$NPM_VERSION" \
    "Package Managers=$EXTRA_PM_LIST"