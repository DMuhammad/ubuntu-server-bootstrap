#!/bin/bash
# ============================================================================
# Scheduler / Cron Module
# Configures cron jobs for Laravel's task scheduler or custom cron entries.
# ============================================================================

set_steps 2

CRON_ENTRY=""
SCHEDULER_TYPE=""
CRON_USER=""

# ── Step 1: Select Scheduler Type ──────────────────────────────────────────
step "Selecting scheduler type"

select_one "Select scheduler type" "Laravel Scheduler" "Custom Cron Entry"
SCHEDULER_TYPE="$SELECTED_TEXT"

# ── Step 2: Configure Cron Entry ───────────────────────────────────────────
step "Configuring cron entry"

case $SELECTED in
    # ── Laravel Scheduler ───────────────────────────────────────────────
    0)
        input_text "Enter Laravel project path" "/var/www/myapp"
        PROJECT_PATH="$INPUT_VALUE"

        # Detect PHP binary path
        PHP_PATH=$(which php 2>/dev/null || echo "/usr/bin/php")
        if [[ ! -x "$PHP_PATH" ]]; then
            warning "PHP not found at $PHP_PATH — verify after setup"
        else
            info "Detected PHP at: $PHP_PATH"
        fi

        CRON_ENTRY="* * * * * cd ${PROJECT_PATH} && ${PHP_PATH} artisan schedule:run >> /dev/null 2>&1"
        CRON_USER="www-data"

        info "Cron entry to add (as www-data):"
        echo "  $CRON_ENTRY"
        echo ""

        # Add to www-data's crontab (preserving existing entries)
        (crontab -u www-data -l 2>/dev/null | grep -v "artisan schedule:run"; echo "$CRON_ENTRY") \
            | crontab -u www-data -

        success "Laravel scheduler added to www-data crontab"
        ;;

    # ── Custom Cron Entry ───────────────────────────────────────────────
    1)
        input_text "Enter cron expression" "*/5 * * * *"
        CRON_EXPRESSION="$INPUT_VALUE"

        input_text "Enter command to run" ""
        CRON_COMMAND="$INPUT_VALUE"

        CRON_ENTRY="${CRON_EXPRESSION} ${CRON_COMMAND}"
        CRON_USER="$(whoami)"

        info "Cron entry to add (as $CRON_USER):"
        echo "  $CRON_ENTRY"
        echo ""

        # Add to current user's crontab (preserving existing entries)
        (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -

        success "Custom cron entry added to $CRON_USER crontab"
        ;;
esac

# ── Summary ─────────────────────────────────────────────────────────────────
show_summary "Scheduler / Cron" \
    "Type=$SCHEDULER_TYPE" \
    "User=$CRON_USER" \
    "Cron Entry=$CRON_ENTRY"
