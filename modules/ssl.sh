#!/bin/bash
# =============================================================================
# Module: SSL / Let's Encrypt
# Description: Installs Certbot, provisions an SSL certificate via Let's Encrypt
#              with the Nginx plugin, and sets up automatic renewal.
# =============================================================================

show_section "SSL / Let's Encrypt"

set_steps 3

# ─────────────────────────────────────────────────────────────────────────────
# Step 1: Install Certbot
# ─────────────────────────────────────────────────────────────────────────────
step "Installing Certbot and Nginx plugin"

install_package "certbot" "Certbot"
install_package "python3-certbot-nginx" "Certbot Nginx Plugin"

success "Certbot installed successfully"

# ─────────────────────────────────────────────────────────────────────────────
# Step 2: Gather Domain & Email
# ─────────────────────────────────────────────────────────────────────────────
step "Configuring SSL certificate details"

input_text "Enter the domain name for the SSL certificate" "example.com"
SSL_DOMAIN="$INPUT_VALUE"

input_text "Enter your email address (for Let's Encrypt notifications)" "admin@${SSL_DOMAIN}"
SSL_EMAIL="$INPUT_VALUE"

info "Domain: $SSL_DOMAIN"
info "Email:  $SSL_EMAIL"

# ─────────────────────────────────────────────────────────────────────────────
# Step 3: Obtain SSL Certificate
# ─────────────────────────────────────────────────────────────────────────────
step "Obtaining SSL certificate from Let's Encrypt"

info "Requesting certificate for $SSL_DOMAIN and www.$SSL_DOMAIN..."

if show_spinner "Obtaining SSL certificate" \
    certbot --nginx \
        --non-interactive \
        --agree-tos \
        -d "$SSL_DOMAIN" \
        -d "www.$SSL_DOMAIN" \
        -m "$SSL_EMAIL"; then
    success "SSL certificate obtained successfully"
else
    error "Failed to obtain SSL certificate"
    warning "Please verify your domain's DNS records point to this server"
    warning "and that ports 80/443 are accessible from the internet"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Setup Auto-Renewal Cron
# ─────────────────────────────────────────────────────────────────────────────
info "Checking auto-renewal cron job..."

# Certbot typically installs a systemd timer or cron entry automatically.
# We add a cron job only if one doesn't already exist.
CRON_JOB="0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'"

if crontab -l 2>/dev/null | grep -qF "certbot renew"; then
    info "Auto-renewal cron job already exists — skipping"
else
    # Append the renewal cron job to the existing crontab
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    success "Auto-renewal cron job added (daily at 3:00 AM)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Retrieve certificate expiry for summary
# ─────────────────────────────────────────────────────────────────────────────
CERT_EXPIRY=""
CERT_FILE="/etc/letsencrypt/live/${SSL_DOMAIN}/fullchain.pem"

if [[ -f "$CERT_FILE" ]]; then
    CERT_EXPIRY=$(openssl x509 -enddate -noout -in "$CERT_FILE" 2>/dev/null | cut -d= -f2)
fi

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
SUMMARY_ARGS=("SSL / Let's Encrypt")
SUMMARY_ARGS+=("Domain=${SSL_DOMAIN}")
SUMMARY_ARGS+=("WWW=www.${SSL_DOMAIN}")
SUMMARY_ARGS+=("Email=${SSL_EMAIL}")
SUMMARY_ARGS+=("Auto-Renewal=Enabled (daily 3:00 AM)")

if [[ -n "$CERT_EXPIRY" ]]; then
    SUMMARY_ARGS+=("Expires=${CERT_EXPIRY}")
else
    SUMMARY_ARGS+=("Expires=Check with: certbot certificates")
fi

show_summary "${SUMMARY_ARGS[@]}"
