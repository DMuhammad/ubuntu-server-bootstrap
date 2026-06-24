#!/bin/bash
# ============================================================================
# Git & SSH Key Setup Module
# Installs Git, configures user identity, generates SSH keys, and manages
# known_hosts for popular Git hosting providers.
# ============================================================================

set_steps 4

# ── Step 1: Install Git ─────────────────────────────────────────────────────
step "Installing Git"

if is_installed "git"; then
    success "Git is already installed ($(git --version))"
else
    show_spinner "Installing Git" apt-get install -y git
    success "Git installed successfully"
fi

# ── Step 2: Configure Git Identity ──────────────────────────────────────────
step "Configuring Git identity"

# Prompt for user name
input_text "Enter your Git name (user.name)" "$(git config --global user.name 2>/dev/null || echo '')"
GIT_NAME="$INPUT_VALUE"

# Prompt for user email
input_text "Enter your Git email (user.email)" "$(git config --global user.email 2>/dev/null || echo '')"
GIT_EMAIL="$INPUT_VALUE"

# Apply global git configuration
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

success "Git configured: $GIT_NAME <$GIT_EMAIL>"

# ── Step 3: Generate SSH Key ───────────────────────────────────────────────
step "Generating SSH key"

select_one "Select SSH key type" "ed25519 (Recommended)" "rsa"
case $SELECTED in
    0)
        KEY_TYPE="ed25519"
        KEY_FILE="$HOME/.ssh/id_ed25519"
        ;;
    1)
        KEY_TYPE="rsa"
        KEY_FILE="$HOME/.ssh/id_rsa"
        ;;
esac

# Create .ssh directory if it doesn't exist
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Generate the key (non-interactive, no passphrase for automation)
if [[ -f "$KEY_FILE" ]]; then
    warning "SSH key already exists at $KEY_FILE"
    if confirm "Overwrite existing key?" "n"; then
        ssh-keygen -t "$KEY_TYPE" -C "$GIT_EMAIL" -f "$KEY_FILE" -N "" -q
        success "SSH key regenerated ($KEY_TYPE)"
    else
        info "Keeping existing SSH key"
    fi
else
    ssh-keygen -t "$KEY_TYPE" -C "$GIT_EMAIL" -f "$KEY_FILE" -N "" -q
    success "SSH key generated ($KEY_TYPE)"
fi

# Start ssh-agent and add the key
eval "$(ssh-agent -s)" > /dev/null 2>&1
ssh-add "$KEY_FILE" 2>/dev/null
success "SSH key added to ssh-agent"

# ── Step 4: Display Public Key & Configure Known Hosts ─────────────────────
step "Public key & known hosts setup"

divider
info "Your public SSH key (copy this to your Git provider):"
echo ""
cat "${KEY_FILE}.pub"
echo ""
divider

# Select which hosts to add to known_hosts
PRESELECTED=(0 1)
select_multi "Add hosts to known_hosts" "github.com" "gitlab.com" "bitbucket.org"

if [[ ${#SELECTED_ITEMS[@]} -gt 0 ]]; then
    for host in "${SELECTED_ITEMS[@]}"; do
        show_spinner "Adding $host to known_hosts" ssh-keyscan -t "$KEY_TYPE" "$host" >> "$HOME/.ssh/known_hosts" 2>/dev/null
        success "Added $host to known_hosts"
    done
else
    info "No hosts added to known_hosts"
fi

# ── Summary ─────────────────────────────────────────────────────────────────
show_summary "Git & SSH Setup" \
    "Git User=$GIT_NAME" \
    "Git Email=$GIT_EMAIL" \
    "SSH Key Type=$KEY_TYPE" \
    "SSH Key Path=$KEY_FILE" \
    "Known Hosts=${SELECTED_ITEMS[*]:-None}"