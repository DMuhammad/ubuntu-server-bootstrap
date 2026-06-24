#!/bin/bash
# =============================================================================
# Module: Nginx Installation & Configuration
# Description: Installs Nginx, optionally configures a virtual host from a
#              stub template, and validates the configuration.
# =============================================================================

show_section "Nginx Installation"

set_steps 3

# ─────────────────────────────────────────────────────────────────────────────
# Step 1: Install Nginx
# ─────────────────────────────────────────────────────────────────────────────
step "Installing Nginx"

install_package "nginx" "Nginx"

show_spinner "Allowing Nginx Full through UFW" ufw allow "Nginx Full"

# Ensure Nginx is enabled and started
show_spinner "Enabling Nginx service" systemctl enable nginx
show_spinner "Starting Nginx service" systemctl start nginx

success "Nginx installed and running"

# ─────────────────────────────────────────────────────────────────────────────
# Step 2: Configure a Site (Optional)
# ─────────────────────────────────────────────────────────────────────────────
step "Configure Nginx site"

DOMAIN_NAME=""
PROJECT_NAME=""
PHP_VERSION=""
SITE_CONFIGURED="No"

if confirm "Would you like to configure a new Nginx site?"; then
    # Gather domain and project name
    input_text "Enter the domain name" "example.com"
    DOMAIN_NAME="$INPUT_VALUE"

    input_text "Enter the project name" "myproject"
    PROJECT_NAME="$INPUT_VALUE"

    # ── Detect installed PHP versions ──
    # Look for installed PHP-FPM sockets to determine available versions
    INSTALLED_PHP_VERSIONS=()

    for sock in /run/php/php*-fpm.sock; do
        if [[ -e "$sock" ]]; then
            # Extract version number from socket path (e.g., "8.3" from php8.3-fpm.sock)
            ver=$(echo "$sock" | grep -oP 'php\K[0-9]+\.[0-9]+')
            if [[ -n "$ver" ]]; then
                INSTALLED_PHP_VERSIONS+=("$ver")
            fi
        fi
    done

    if [[ ${#INSTALLED_PHP_VERSIONS[@]} -eq 0 ]]; then
        # No PHP detected — ask user to input manually
        warning "No PHP-FPM installation detected"
        input_text "Enter PHP version for FastCGI (e.g., 8.3)" "8.3"
        PHP_VERSION="$INPUT_VALUE"
    elif [[ ${#INSTALLED_PHP_VERSIONS[@]} -eq 1 ]]; then
        # Single version found — use it directly
        PHP_VERSION="${INSTALLED_PHP_VERSIONS[0]}"
        info "Detected PHP version: $PHP_VERSION"
    else
        # Multiple versions found — let user pick
        select_one "Multiple PHP versions detected — select one" "${INSTALLED_PHP_VERSIONS[@]}"
        PHP_VERSION="$SELECTED_TEXT"
    fi

    # ── Deploy Nginx config from stub template ──
    TEMPLATE_FILE="$BASE_DIR/templates/nginx.conf.stub"
    SITE_CONFIG="/etc/nginx/sites-available/$PROJECT_NAME"
    SITE_LINK="/etc/nginx/sites-enabled/$PROJECT_NAME"

    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        error "Template not found: $TEMPLATE_FILE"
        error "Please ensure the nginx.conf.stub template exists in templates/"
    else
        # Copy template and replace placeholders
        cp "$TEMPLATE_FILE" "$SITE_CONFIG"

        sed -i "s/__DOMAIN__/${DOMAIN_NAME}/g" "$SITE_CONFIG"
        sed -i "s/__PROJECT__/${PROJECT_NAME}/g" "$SITE_CONFIG"
        sed -i "s/__PHP_VERSION__/${PHP_VERSION}/g" "$SITE_CONFIG"

        info "Site config written to $SITE_CONFIG"

        # Create symlink in sites-enabled
        if [[ -L "$SITE_LINK" ]]; then
            warning "Symlink already exists — recreating"
            rm -f "$SITE_LINK"
        fi
        ln -s "$SITE_CONFIG" "$SITE_LINK"

        # Remove default site if it exists
        if [[ -L /etc/nginx/sites-enabled/default ]]; then
            unlink /etc/nginx/sites-enabled/default
            info "Default site unlinked"
        fi

        SITE_CONFIGURED="Yes"
        success "Nginx site '$PROJECT_NAME' configured for $DOMAIN_NAME"
    fi
else
    info "Skipping site configuration"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 3: Test & Reload Nginx
# ─────────────────────────────────────────────────────────────────────────────
step "Testing and reloading Nginx"

info "Running Nginx configuration test..."

if nginx -t 2>&1; then
    success "Nginx configuration test passed"
    show_spinner "Reloading Nginx" systemctl reload nginx
    success "Nginx reloaded successfully"
else
    error "Nginx configuration test failed — please check your config files"
    warning "Nginx was NOT reloaded due to configuration errors"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
SUMMARY_ARGS=("Nginx")
SUMMARY_ARGS+=("Nginx=Installed")
SUMMARY_ARGS+=("UFW Rule=Nginx Full")
SUMMARY_ARGS+=("Site Configured=${SITE_CONFIGURED}")

if [[ -n "$DOMAIN_NAME" ]]; then
    SUMMARY_ARGS+=("Domain=${DOMAIN_NAME}")
    SUMMARY_ARGS+=("Project=${PROJECT_NAME}")
    SUMMARY_ARGS+=("PHP Version=${PHP_VERSION}")
    SUMMARY_ARGS+=("Config Path=/etc/nginx/sites-available/${PROJECT_NAME}")
fi

show_summary "${SUMMARY_ARGS[@]}"
