#!/bin/bash
# =============================================================================
# PHP Installation Module
# Installs PHP with selected version and extensions via ondrej/php PPA.
# Optionally installs Composer globally.
# =============================================================================

set_steps 4

# ── Step 1: Select PHP version ──────────────────────────────────────────────
step "Select PHP version"

select_one "Choose PHP version to install" "8.1" "8.2" "8.3" "8.4"
PHP_VERSION="$SELECTED_TEXT"

info "Selected PHP $PHP_VERSION"
divider

# ── Step 2: Select PHP extensions ────────────────────────────────────────────
step "Select PHP extensions"

# Pre-select the first 10 common extensions
PRESELECTED=(0 1 2 3 4 5 6 7 8 9)

select_multi "Choose PHP extensions to install" \
    "fpm" "cli" "common" "mysql" "xml" \
    "curl" "mbstring" "zip" "gd" "bcmath" \
    "redis" "pgsql" "imagick" "intl" "soap"

# Build the package list from selected extensions
PHP_PACKAGES="php${PHP_VERSION}"
EXTENSIONS_LIST=""
for ext in "${SELECTED_ITEMS[@]}"; do
    PHP_PACKAGES="$PHP_PACKAGES php${PHP_VERSION}-${ext}"
    EXTENSIONS_LIST="${EXTENSIONS_LIST}${ext} "
done

EXTENSIONS_COUNT="${#SELECTED_ITEMS[@]}"
info "Selected $EXTENSIONS_COUNT extension(s): ${EXTENSIONS_LIST}"
divider

# ── Step 3: Add PPA and install PHP ──────────────────────────────────────────
step "Install PHP $PHP_VERSION with extensions"

# Add the ondrej/php PPA for latest PHP packages
show_spinner "Adding ondrej/php PPA" \
    bash -c "add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1"

show_spinner "Updating package lists" \
    bash -c "apt-get update -y > /dev/null 2>&1"

# Install PHP and all selected extensions in one go
show_spinner "Installing PHP $PHP_VERSION and $EXTENSIONS_COUNT extension(s)" \
    bash -c "apt-get install -y $PHP_PACKAGES > /dev/null 2>&1"

success "PHP $PHP_VERSION installed with $EXTENSIONS_COUNT extension(s)"
divider

# ── Step 4: Optional Composer installation ───────────────────────────────────
step "Composer installation"

COMPOSER_STATUS="Not installed"

if confirm "Install Composer (PHP dependency manager)?"; then
    show_spinner "Downloading and installing Composer" \
        bash -c "
            curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php && \
            php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer > /dev/null 2>&1 && \
            rm -f /tmp/composer-setup.php
        "

    COMPOSER_STATUS="Installed ($(composer --version 2>/dev/null | awk '{print $3}'))"
    success "Composer installed globally"
else
    info "Skipping Composer installation"
fi

divider

# ── Summary ──────────────────────────────────────────────────────────────────
show_summary "PHP" \
    "PHP Version=PHP $PHP_VERSION" \
    "Extensions ($EXTENSIONS_COUNT)=${EXTENSIONS_LIST}" \
    "Composer=$COMPOSER_STATUS"