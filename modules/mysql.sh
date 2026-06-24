#!/bin/bash
# =============================================================================
# MySQL Installation Module
# Installs MySQL Server, performs automated secure installation,
# and optionally creates a new database and user.
# =============================================================================

set_steps 3

# ── Step 1: Install MySQL Server ─────────────────────────────────────────────
step "Install MySQL Server"

# Pre-configure mysql-server to install non-interactively
show_spinner "Installing MySQL Server" \
    bash -c "
        export DEBIAN_FRONTEND=noninteractive && \
        apt-get install -y mysql-server > /dev/null 2>&1
    "

# Ensure MySQL service is running
show_spinner "Starting MySQL service" \
    bash -c "systemctl start mysql && systemctl enable mysql > /dev/null 2>&1"

success "MySQL Server installed and running"
divider

# ── Step 2: Secure MySQL installation ────────────────────────────────────────
step "Secure MySQL installation"

input_secret "Enter a root password for MySQL"
MYSQL_ROOT_PASS="$INPUT_VALUE"

# Automated equivalent of mysql_secure_installation:
# 1. Set root password with auth_socket fallback to native password
# 2. Remove anonymous users
# 3. Disallow remote root login
# 4. Remove test database
# 5. Reload privilege tables
show_spinner "Securing MySQL installation" \
    bash -c "
        mysql -u root <<EOSQL
-- Set root password and switch to native password authentication
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASS}';

-- Remove anonymous users
DELETE FROM mysql.user WHERE User='';

-- Disallow remote root login
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

-- Remove test database
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

-- Reload privilege tables
FLUSH PRIVILEGES;
EOSQL
    "

success "MySQL secured (root password set, anonymous users removed)"
divider

# ── Step 3: Optional database and user creation ─────────────────────────────
step "Create database and user"

DB_NAME=""
DB_USER=""
DB_STATUS="Skipped"

if confirm "Create a new database and user?"; then
    # Gather database details
    input_text "Enter database name" "myapp"
    DB_NAME="$INPUT_VALUE"

    input_text "Enter username for the database" "myapp_user"
    DB_USER="$INPUT_VALUE"

    input_secret "Enter password for $DB_USER"
    DB_PASS="$INPUT_VALUE"

    # Create the database, user, and grant all privileges
    show_spinner "Creating database '$DB_NAME' and user '$DB_USER'" \
        bash -c "
            mysql -u root -p'${MYSQL_ROOT_PASS}' <<EOSQL
-- Create the database
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create the user with the specified password
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';

-- Grant all privileges on the new database to the user
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';

-- Apply changes
FLUSH PRIVILEGES;
EOSQL
        "

    DB_STATUS="Created"
    success "Database '$DB_NAME' and user '$DB_USER' created"
else
    info "Skipping database and user creation"
fi

divider

# ── Summary ──────────────────────────────────────────────────────────────────
if [ -n "$DB_NAME" ]; then
    show_summary "MySQL" \
        "MySQL Server=Installed & Secured" \
        "Root Password=Set" \
        "Database=$DB_NAME ($DB_STATUS)" \
        "Database User=$DB_USER"
else
    show_summary "MySQL" \
        "MySQL Server=Installed & Secured" \
        "Root Password=Set" \
        "Database=$DB_STATUS"
fi