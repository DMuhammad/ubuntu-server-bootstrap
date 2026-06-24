#!/bin/bash
# =============================================================================
# Redis Installation Module
# Installs Redis server with optional password protection and configurable
# memory limits.
# =============================================================================

set_steps 3

# ─── Step 1: Install Redis ──────────────────────────────────────────────────

step "Install Redis"

show_spinner "Installing Redis server" apt-get install -y redis-server >/dev/null 2>&1

if [ $? -ne 0 ]; then
    error "Failed to install Redis"
    return 1
fi
success "Redis server installed"

# ─── Step 2: Optional Password Protection ───────────────────────────────────

step "Configure authentication"

REDIS_CONF="/etc/redis/redis.conf"
REDIS_PASSWORD_SET="No"

if confirm "Set a Redis password?"; then

    input_secret "Enter Redis password"
    REDIS_PASS="$INPUT_VALUE"

    if [ -n "$REDIS_PASS" ]; then
        # Remove any existing requirepass directive and add the new one
        show_spinner "Configuring Redis password" bash -c "
            sed -i 's/^# *requirepass .*//' '$REDIS_CONF' &&
            sed -i 's/^requirepass .*//' '$REDIS_CONF' &&
            echo 'requirepass ${REDIS_PASS}' >> '$REDIS_CONF'
        "
        success "Redis password configured"
        REDIS_PASSWORD_SET="Yes"
    else
        warning "Empty password provided — skipping"
    fi
else
    info "Skipping Redis password configuration"
fi

# ─── Step 3: Configure Memory Limit ─────────────────────────────────────────

step "Configure memory limit"

select_one "Select maxmemory limit" "256mb" "512mb" "1gb" "2gb"
MAXMEMORY="$SELECTED_TEXT"
info "Selected maxmemory: $MAXMEMORY"

# Apply maxmemory and eviction policy to redis.conf
show_spinner "Applying memory configuration" bash -c "
    # Remove existing maxmemory directives
    sed -i 's/^# *maxmemory .*//' '$REDIS_CONF'
    sed -i 's/^maxmemory .*//' '$REDIS_CONF'
    sed -i 's/^# *maxmemory-policy .*//' '$REDIS_CONF'
    sed -i 's/^maxmemory-policy .*//' '$REDIS_CONF'

    # Append new configuration
    echo '' >> '$REDIS_CONF'
    echo '# Memory configuration (set by server-setup)' >> '$REDIS_CONF'
    echo 'maxmemory ${MAXMEMORY}' >> '$REDIS_CONF'
    echo 'maxmemory-policy allkeys-lru' >> '$REDIS_CONF'
"
success "Memory limit set to $MAXMEMORY with allkeys-lru eviction policy"

# ─── Enable and Restart Redis ───────────────────────────────────────────────

show_spinner "Enabling Redis service" systemctl enable redis-server
show_spinner "Restarting Redis service" systemctl restart redis-server

if systemctl is-active --quiet redis-server; then
    success "Redis service is running"
else
    error "Redis service failed to start"
    return 1
fi

# ─── Summary ────────────────────────────────────────────────────────────────

divider

show_summary "Redis" \
    "Version=$(redis-server --version 2>/dev/null | awk '{print $3}' | cut -d= -f2)" \
    "Password=$REDIS_PASSWORD_SET" \
    "Max Memory=$MAXMEMORY" \
    "Eviction Policy=allkeys-lru" \
    "Service=Running"

log "INFO" "Redis installed. Password=$REDIS_PASSWORD_SET, MaxMemory=$MAXMEMORY"
