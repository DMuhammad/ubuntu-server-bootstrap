#!/bin/bash
# =============================================================================
# PostgreSQL Installation Module
# Installs PostgreSQL from the official PGDG repository with optional
# database and user creation.
# =============================================================================

set_steps 3

# ─── Step 1: Install PostgreSQL ─────────────────────────────────────────────

step "Install PostgreSQL"

select_one "Select PostgreSQL version" "14" "15" "16" "17"
PG_VERSION="$SELECTED_TEXT"
info "Selected PostgreSQL $PG_VERSION"

# Add the official PostgreSQL APT repository (pgdg)
show_spinner "Adding PostgreSQL official APT repository" bash -c "
    apt-get install -y curl ca-certificates gnupg >/dev/null 2>&1 &&
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg 2>/dev/null &&
    echo \"deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] https://apt.postgresql.org/pub/repos/apt \$(lsb_release -cs)-pgdg main\" > /etc/apt/sources.list.d/pgdg.list &&
    apt-get update >/dev/null 2>&1
"

if [ $? -ne 0 ]; then
    error "Failed to add PostgreSQL repository"
    return 1
fi
success "PostgreSQL APT repository added"

# Install the selected PostgreSQL version
show_spinner "Installing PostgreSQL $PG_VERSION" apt-get install -y "postgresql-${PG_VERSION}" >/dev/null 2>&1

if [ $? -ne 0 ]; then
    error "Failed to install PostgreSQL $PG_VERSION"
    return 1
fi
success "PostgreSQL $PG_VERSION installed"

# ─── Step 2: Start and Enable Service ───────────────────────────────────────

step "Start and enable PostgreSQL service"

show_spinner "Enabling PostgreSQL service" systemctl enable postgresql
show_spinner "Starting PostgreSQL service" systemctl start postgresql

if systemctl is-active --quiet postgresql; then
    success "PostgreSQL service is running"
else
    error "PostgreSQL service failed to start"
    return 1
fi

# ─── Step 3: Optional Database & User Creation ─────────────────────────────

step "Configure database and user"

DB_NAME=""
DB_USER=""
DB_CREATED="No"

if confirm "Create a new database and user?"; then

    input_text "Enter database name" "myapp"
    DB_NAME="$INPUT_VALUE"

    input_text "Enter username" "myapp_user"
    DB_USER="$INPUT_VALUE"

    input_secret "Enter password for '$DB_USER'"
    DB_PASS="$INPUT_VALUE"

    # Create the PostgreSQL user and database
    show_spinner "Creating user '$DB_USER'" sudo -u postgres psql -c \
        "CREATE USER \"${DB_USER}\" WITH ENCRYPTED PASSWORD '${DB_PASS}';" 2>/dev/null

    show_spinner "Creating database '$DB_NAME'" sudo -u postgres psql -c \
        "CREATE DATABASE \"${DB_NAME}\" OWNER \"${DB_USER}\";" 2>/dev/null

    show_spinner "Granting privileges" sudo -u postgres psql -c \
        "GRANT ALL PRIVILEGES ON DATABASE \"${DB_NAME}\" TO \"${DB_USER}\";" 2>/dev/null

    if [ $? -eq 0 ]; then
        success "Database '$DB_NAME' and user '$DB_USER' created"
        DB_CREATED="Yes"
    else
        warning "There was an issue creating the database or user — check manually"
        DB_CREATED="Partial"
    fi
else
    info "Skipping database and user creation"
fi

# ─── Summary ────────────────────────────────────────────────────────────────

divider

SUMMARY_ARGS=(
    "PostgreSQL"
    "Version=$PG_VERSION"
    "Service=Running"
    "DB Created=$DB_CREATED"
)

if [ -n "$DB_NAME" ]; then
    SUMMARY_ARGS+=("Database=$DB_NAME")
    SUMMARY_ARGS+=("DB User=$DB_USER")
fi

show_summary "${SUMMARY_ARGS[@]}"

log "INFO" "PostgreSQL $PG_VERSION installed. DB=$DB_NAME, User=$DB_USER"
