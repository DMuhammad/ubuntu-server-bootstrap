#!/bin/bash
# ============================================================================
# Supervisor Module
# Installs Supervisor process manager and optionally configures a Laravel
# queue worker using a stub template.
# ============================================================================

set_steps 2

# ── Step 1: Install Supervisor ──────────────────────────────────────────────
step "Installing Supervisor"

if is_installed "supervisor"; then
    success "Supervisor is already installed"
else
    show_spinner "Installing Supervisor" apt-get install -y supervisor
    success "Supervisor installed successfully"
fi

# Enable and start the supervisor service
show_spinner "Enabling Supervisor service" systemctl enable supervisor
systemctl start supervisor 2>/dev/null
success "Supervisor service enabled and running"

# ── Step 2: Optional Laravel Queue Worker ───────────────────────────────────
step "Laravel queue worker setup"

WORKER_CONFIGURED="No"
PROJECT_NAME=""
PROJECT_PATH=""
NUM_PROCS=""

if confirm "Set up a Laravel queue worker?" "y"; then

    # Prompt for project details
    input_text "Enter project name" "myapp"
    PROJECT_NAME="$INPUT_VALUE"

    input_text "Enter project path" "/var/www/$PROJECT_NAME"
    PROJECT_PATH="$INPUT_VALUE"

    # Select number of worker processes
    select_one "Number of worker processes" "1" "2" "3" "5" "8"
    NUM_PROCS="$SELECTED_TEXT"

    # Detect PHP binary path
    PHP_PATH=$(which php 2>/dev/null || echo "/usr/bin/php")
    if [[ ! -x "$PHP_PATH" ]]; then
        warning "PHP not found at $PHP_PATH — you may need to adjust the config"
    else
        info "Detected PHP at: $PHP_PATH"
    fi

    # Validate stub template exists
    STUB_FILE="$BASE_DIR/templates/laravel-worker.conf.stub"
    CONF_FILE="/etc/supervisor/conf.d/${PROJECT_NAME}-worker.conf"

    if [[ ! -f "$STUB_FILE" ]]; then
        error "Stub template not found: $STUB_FILE"
        warning "Skipping worker configuration"
    else
        # Copy stub and replace placeholders
        cp "$STUB_FILE" "$CONF_FILE"
        sed -i "s|__PROJECT__|${PROJECT_NAME}|g" "$CONF_FILE"
        sed -i "s|__PROJECT_PATH__|${PROJECT_PATH}|g" "$CONF_FILE"
        sed -i "s|__NUM_PROCS__|${NUM_PROCS}|g" "$CONF_FILE"
        sed -i "s|__PHP_PATH__|${PHP_PATH}|g" "$CONF_FILE"

        success "Worker config written to $CONF_FILE"

        # Reload supervisor with new config
        show_spinner "Reloading Supervisor" bash -c "supervisorctl reread && supervisorctl update"
        success "Supervisor reloaded — worker registered"

        WORKER_CONFIGURED="Yes"
    fi
else
    info "Skipping Laravel queue worker setup"
fi

# ── Summary ─────────────────────────────────────────────────────────────────
if [[ "$WORKER_CONFIGURED" == "Yes" ]]; then
    show_summary "Supervisor" \
        "Supervisor=Installed & enabled" \
        "Laravel Worker=$WORKER_CONFIGURED" \
        "Project=$PROJECT_NAME" \
        "Project Path=$PROJECT_PATH" \
        "Processes=$NUM_PROCS" \
        "PHP Path=$PHP_PATH" \
        "Config File=/etc/supervisor/conf.d/${PROJECT_NAME}-worker.conf"
else
    show_summary "Supervisor" \
        "Supervisor=Installed & enabled" \
        "Laravel Worker=Not configured"
fi