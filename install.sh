#!/bin/bash

# ============================================================
#  Ubuntu Server Bootstrap
#  One-command server setup with interactive CLI
#
#  Usage: sudo bash install.sh
# ============================================================

# ── Determine BASE_DIR or Auto-bootstrap ──
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]:-$0}")"

if [[ -f "$SCRIPT_DIR/utils/helper.sh" ]]; then
    BASE_DIR="$(cd "$SCRIPT_DIR" 2>/dev/null && pwd)"
elif [[ -f "./utils/helper.sh" ]]; then
    BASE_DIR="$(pwd)"
else
    echo -e "\e[36m=> Downloading Ubuntu Server Bootstrap...\e[0m"
    
    SUDO=""
    if [[ $EUID -ne 0 ]]; then
        SUDO="sudo"
    fi

    $SUDO rm -rf /tmp/ubuntu-server-bootstrap
    $SUDO mkdir -p /tmp/ubuntu-server-bootstrap
    
    # Download tarball instead of git clone to avoid any authentication prompts
    DOWNLOAD_SUCCESS=false
    if curl -fsSL "https://github.com/DMuhammad/ubuntu-server-bootstrap/archive/main.tar.gz" -o /tmp/ubuntu-server-bootstrap.tar.gz; then
        $SUDO tar -xzf /tmp/ubuntu-server-bootstrap.tar.gz -C /tmp/ubuntu-server-bootstrap --strip-components=1
        $SUDO rm -f /tmp/ubuntu-server-bootstrap.tar.gz
        DOWNLOAD_SUCCESS=true
        break
    fi

    if [[ "$DOWNLOAD_SUCCESS" != "true" ]]; then
        echo -e "\e[31mError: Failed to download repository. Please check if the repository is public and uses main/master branch.\e[0m"
        exit 1
    fi
    
    cd /tmp/ubuntu-server-bootstrap || exit 1
    exec $SUDO bash install.sh "$@"
fi

# Load utilities
source "$BASE_DIR/utils/helper.sh"
source "$BASE_DIR/utils/ui.sh"

# ── Module registry ──
# Each entry: "label|script|description"
MODULES=(
    "Initial Setup|initial.sh|Update packages, configure timezone, setup firewall, create swap & sudo user"
    "Nginx|nginx.sh|Install Nginx web server, configure virtual host with domain"
    "SSL (Let's Encrypt)|ssl.sh|Install Certbot, obtain free SSL certificate, auto-renewal"
    "PHP|php.sh|Install PHP-FPM with selectable version (8.1-8.4) and extensions, optional Composer"
    "Node.js|node.sh|Install NVM + Node.js with selectable version, optional yarn/pnpm"
    "MySQL|mysql.sh|Install MySQL server, secure installation, optional database & user creation"
    "PostgreSQL|postgres.sh|Install PostgreSQL with selectable version (14-17), optional database & user"
    "Redis|redis.sh|Install Redis server, optional password & configurable maxmemory"
    "phpMyAdmin|phpmyadmin.sh|Install phpMyAdmin with Nginx config and custom access path"
    "Git + SSH|github.sh|Install Git, configure user, generate SSH key, add to known_hosts"
    "Supervisor|supervisor.sh|Install Supervisor, optional Laravel queue worker setup"
    "Scheduler (Cron)|scheduler.sh|Setup Laravel scheduler or custom cron entry"
)

# ── Functions ──

get_module_label() {
    echo "${MODULES[$1]}" | cut -d'|' -f1
}

get_module_script() {
    echo "${MODULES[$1]}" | cut -d'|' -f2
}

get_module_desc() {
    echo "${MODULES[$1]}" | cut -d'|' -f3
}

show_help() {
    clear
    show_header "Ubuntu Server Bootstrap" "Help & Module Descriptions"

    echo -e "  ${UI_BOLD}${UI_WHITE}Available Modules:${UI_RESET}"
    echo ""

    for i in "${!MODULES[@]}"; do
        local label=$(get_module_label $i)
        local desc=$(get_module_desc $i)
        local num=$((i + 1))
        printf "  ${UI_CYAN}${UI_BOLD}%2d. %-22s${UI_RESET} %s\n" "$num" "$label" "$desc"
    done

    echo ""
    divider
    echo ""
    echo -e "  ${UI_BOLD}${UI_WHITE}Usage:${UI_RESET}"
    echo -e "  ${UI_DIM}Clone & run:${UI_RESET}"
    echo -e "    git clone https://github.com/<user>/server-setup.git"
    echo -e "    cd server-setup"
    echo -e "    sudo bash install.sh"
    echo ""
    echo -e "  ${UI_DIM}Or one-liner:${UI_RESET}"
    echo -e "    curl -sL https://raw.githubusercontent.com/<user>/server-setup/main/install.sh | sudo bash"
    echo ""
    echo -e "  ${UI_BOLD}${UI_WHITE}Interactive Controls:${UI_RESET}"
    echo -e "  ${UI_DIM}  ↑ ↓       Navigate options${UI_RESET}"
    echo -e "  ${UI_DIM}  Space     Toggle selection (multi-select)${UI_RESET}"
    echo -e "  ${UI_DIM}  a         Select all (multi-select)${UI_RESET}"
    echo -e "  ${UI_DIM}  n         Select none (multi-select)${UI_RESET}"
    echo -e "  ${UI_DIM}  Enter     Confirm selection${UI_RESET}"
    echo ""
    echo -e "  ${UI_BOLD}${UI_WHITE}Log file:${UI_RESET} ${UI_DIM}~/.server-setup.log${UI_RESET}"
    echo ""
    divider
    echo ""

    echo -ne "  ${UI_DIM}Press any key to return to main menu...${UI_RESET}"
    read -rsn1
}

run_selected_modules() {
    local indices=("$@")
    local total=${#indices[@]}
    local current=0

    echo ""
    divider
    info "Starting installation of $total module(s)..."
    divider
    echo ""

    log "START" "Installing $total modules"

    for idx in "${indices[@]}"; do
        ((current++))
        local label=$(get_module_label $idx)
        local script=$(get_module_script $idx)

        show_progress $current $total "$label"
        echo ""

        log "MODULE" "Starting: $label"

        source "$BASE_DIR/modules/$script"

        log "MODULE" "Completed: $label"

        echo ""
    done

    # ── Final summary ──
    echo ""
    echo -e "  ${UI_GREEN}${UI_BOLD}╔══════════════════════════════════════════╗${UI_RESET}"
    echo -e "  ${UI_GREEN}${UI_BOLD}║                                          ║${UI_RESET}"
    echo -e "  ${UI_GREEN}${UI_BOLD}║   🎉  All installations complete!        ║${UI_RESET}"
    echo -e "  ${UI_GREEN}${UI_BOLD}║                                          ║${UI_RESET}"
    echo -e "  ${UI_GREEN}${UI_BOLD}╚══════════════════════════════════════════╝${UI_RESET}"
    echo ""
    echo -e "  ${UI_DIM}Installed modules:${UI_RESET}"
    for idx in "${indices[@]}"; do
        echo -e "    ${UI_GREEN}${UI_CHECK}${UI_RESET} $(get_module_label $idx)"
    done
    echo ""
    echo -e "  ${UI_DIM}Log file: ~/.server-setup.log${UI_RESET}"
    echo ""
}

# ── Main ──

main() {
    # Check prerequisites
    check_root
    check_ubuntu

    while true; do
        clear

        show_header "Ubuntu Server Bootstrap" "v1.0.0"

        # Build labels for menu
        local menu_labels=()
        for i in "${!MODULES[@]}"; do
            menu_labels+=("$(get_module_label $i)")
        done

        # Main menu options
        local main_options=(
            "Select modules to install"
            "Full Installation (all modules)"
            "Help (module descriptions)"
            "Exit"
        )

        select_one "What would you like to do?" "${main_options[@]}"

        case $SELECTED in
            0)
                # ── Multi-select modules ──
                echo ""
                select_multi "Select modules to install:" "${menu_labels[@]}"

                if [[ ${#SELECTED_ITEMS[@]} -eq 0 ]]; then
                    warning "No modules selected."
                    echo ""
                    echo -ne "  ${UI_DIM}Press any key to continue...${UI_RESET}"
                    read -rsn1
                    continue
                fi

                # Confirmation
                echo ""
                echo -e "  ${UI_BOLD}${UI_WHITE}Modules to install (${#SELECTED_ITEMS[@]}):${UI_RESET}"
                for item in "${SELECTED_ITEMS[@]}"; do
                    echo -e "    ${UI_CYAN}${UI_DOT}${UI_RESET} $item"
                done
                echo ""

                if confirm "Proceed with installation?"; then
                    run_selected_modules "${SELECTED_INDICES[@]}"
                    echo -ne "  ${UI_DIM}Press any key to return to menu...${UI_RESET}"
                    read -rsn1
                fi
                ;;
            1)
                # ── Full installation ──
                echo ""
                echo -e "  ${UI_BOLD}${UI_WHITE}Full Installation — all ${#MODULES[@]} modules:${UI_RESET}"
                for i in "${!MODULES[@]}"; do
                    echo -e "    ${UI_CYAN}${UI_DOT}${UI_RESET} $(get_module_label $i)"
                done
                echo ""

                if confirm "Proceed with full installation?"; then
                    local all_indices=()
                    for i in "${!MODULES[@]}"; do
                        all_indices+=("$i")
                    done
                    run_selected_modules "${all_indices[@]}"
                    echo -ne "  ${UI_DIM}Press any key to return to menu...${UI_RESET}"
                    read -rsn1
                fi
                ;;
            2)
                # ── Help ──
                show_help
                ;;
            3)
                # ── Exit ──
                echo ""
                success "Goodbye! 👋"
                echo ""
                exit 0
                ;;
        esac
    done
}

main