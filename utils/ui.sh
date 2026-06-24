#!/bin/bash

# ============================================================
#  Interactive UI Engine for Ubuntu Server Bootstrap
#  Pure bash — no external dependencies
#  Supports: arrow-key navigation, space toggle, styled output
# ============================================================

# Colors
readonly UI_RESET="\e[0m"
readonly UI_BOLD="\e[1m"
readonly UI_DIM="\e[2m"
readonly UI_CYAN="\e[36m"
readonly UI_GREEN="\e[32m"
readonly UI_YELLOW="\e[33m"
readonly UI_RED="\e[31m"
readonly UI_MAGENTA="\e[35m"
readonly UI_WHITE="\e[97m"
readonly UI_BG_CYAN="\e[46m"
readonly UI_BG_GREEN="\e[42m"

# Symbols
readonly UI_ARROW="❯"
readonly UI_CHECK="✔"
readonly UI_DOT="●"
readonly UI_CIRCLE="○"
readonly UI_BLOCK_FULL="█"
readonly UI_BLOCK_EMPTY="░"

# ──────────────────────────────────────────────
#  show_header — Branded header with box drawing
#  Usage: show_header "Title" "Subtitle"
# ──────────────────────────────────────────────
show_header() {
    local title="$1"
    local subtitle="${2:-}"
    local width=44

    echo ""
    echo -e "${UI_CYAN}${UI_BOLD}"
    echo "  ╔══════════════════════════════════════════╗"
    printf "  ║  🚀 %-37s║\n" "$title"
    if [[ -n "$subtitle" ]]; then
        printf "  ║  %-40s║\n" "$subtitle"
    fi
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${UI_RESET}"
}

# ──────────────────────────────────────────────
#  show_section — Section header
#  Usage: show_section "Section Title"
# ──────────────────────────────────────────────
show_section() {
    echo ""
    echo -e "  ${UI_CYAN}${UI_BOLD}── $1 ──${UI_RESET}"
    echo ""
}

# ──────────────────────────────────────────────
#  select_one — Single selection with arrow keys
#  Usage: select_one "Title" "opt1" "opt2" "opt3"
#  Result: $SELECTED (0-indexed), $SELECTED_TEXT
# ──────────────────────────────────────────────
select_one() {
    local title="$1"
    shift
    local options=("$@")
    local count=${#options[@]}
    local selected=0

    # Hide cursor
    tput civis 2>/dev/null

    echo -e "  ${UI_BOLD}${UI_WHITE}$title${UI_RESET}"

    # Print initial options
    for i in "${!options[@]}"; do
        if [[ $i -eq $selected ]]; then
            echo -e "  ${UI_CYAN}${UI_ARROW} ${options[$i]}${UI_RESET}"
        else
            echo -e "  ${UI_DIM}  ${options[$i]}${UI_RESET}"
        fi
    done

    echo -e "\n  ${UI_DIM}[↑↓] navigate  [Enter] confirm${UI_RESET}"

    # Move cursor up to options start (count + 2 for hint + empty line)
    local total_lines=$((count + 2))

    while true; do
        # Read a single character
        local key
        IFS= read -rsn1 key

        # Handle escape sequences (arrow keys)
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn1 key
            read -rsn1 key
            case "$key" in
                A) # Up
                    if [[ $selected -gt 0 ]]; then
                        ((selected--))
                    fi
                    ;;
                B) # Down
                    if [[ $selected -lt $((count - 1)) ]]; then
                        ((selected++))
                    fi
                    ;;
            esac
        elif [[ "$key" == "" ]]; then
            # Enter pressed
            break
        fi

        # Move cursor up to redraw
        printf "\e[${total_lines}A"

        # Redraw options
        for i in "${!options[@]}"; do
            printf "\e[2K"  # Clear line
            if [[ $i -eq $selected ]]; then
                echo -e "  ${UI_CYAN}${UI_ARROW} ${options[$i]}${UI_RESET}"
            else
                echo -e "  ${UI_DIM}  ${options[$i]}${UI_RESET}"
            fi
        done
        # Re-print hint lines
        printf "\e[2K"
        echo ""
        printf "\e[2K"
        echo -e "  ${UI_DIM}[↑↓] navigate  [Enter] confirm${UI_RESET}"
    done

    # Show cursor
    tput cnorm 2>/dev/null

    # Clear the menu display — move up and clear
    printf "\e[$((total_lines + 1))A"
    for ((i = 0; i <= total_lines; i++)); do
        printf "\e[2K\n"
    done
    printf "\e[$((total_lines + 1))A"

    # Show final selection
    echo -e "  ${UI_BOLD}${UI_WHITE}$title${UI_RESET} ${UI_GREEN}${UI_CHECK} ${options[$selected]}${UI_RESET}"

    SELECTED=$selected
    SELECTED_TEXT="${options[$selected]}"
}

# ──────────────────────────────────────────────
#  select_multi — Multi-select with space toggle
#  Usage: select_multi "Title" "opt1" "opt2" "opt3"
#  Pre-select: PRESELECTED=(0 1 3)  before calling
#  Result: $SELECTED_ITEMS (array of selected texts)
#          $SELECTED_INDICES (array of selected indices)
# ──────────────────────────────────────────────
select_multi() {
    local title="$1"
    shift
    local options=("$@")
    local count=${#options[@]}
    local cursor=0
    local -a checked=()

    # Initialize checked array
    for ((i = 0; i < count; i++)); do
        checked[$i]=0
    done

    # Apply preselection if PRESELECTED is set
    if [[ -n "${PRESELECTED+x}" ]]; then
        for idx in "${PRESELECTED[@]}"; do
            if [[ $idx -ge 0 && $idx -lt $count ]]; then
                checked[$idx]=1
            fi
        done
        unset PRESELECTED
    fi

    # Hide cursor
    tput civis 2>/dev/null

    echo -e "  ${UI_BOLD}${UI_WHITE}$title${UI_RESET}"

    # Print initial options
    for i in "${!options[@]}"; do
        local marker="${UI_CIRCLE}"
        local color="${UI_DIM}"
        if [[ ${checked[$i]} -eq 1 ]]; then
            marker="${UI_GREEN}${UI_DOT}${UI_RESET}"
            color="${UI_WHITE}"
        fi
        if [[ $i -eq $cursor ]]; then
            echo -e "  ${UI_CYAN}${UI_ARROW}${UI_RESET} $marker ${color}${options[$i]}${UI_RESET}"
        else
            echo -e "    $marker ${color}${options[$i]}${UI_RESET}"
        fi
    done

    echo -e "\n  ${UI_DIM}[↑↓] navigate  [Space] toggle  [a] all  [n] none  [Enter] confirm${UI_RESET}"

    local total_lines=$((count + 2))

    while true; do
        local key
        IFS= read -rsn1 key

        if [[ "$key" == $'\x1b' ]]; then
            read -rsn1 key
            read -rsn1 key
            case "$key" in
                A) # Up
                    if [[ $cursor -gt 0 ]]; then
                        ((cursor--))
                    fi
                    ;;
                B) # Down
                    if [[ $cursor -lt $((count - 1)) ]]; then
                        ((cursor++))
                    fi
                    ;;
            esac
        elif [[ "$key" == " " ]]; then
            # Space — toggle
            if [[ ${checked[$cursor]} -eq 0 ]]; then
                checked[$cursor]=1
            else
                checked[$cursor]=0
            fi
        elif [[ "$key" == "a" || "$key" == "A" ]]; then
            # Select all
            for ((i = 0; i < count; i++)); do
                checked[$i]=1
            done
        elif [[ "$key" == "n" || "$key" == "N" ]]; then
            # Select none
            for ((i = 0; i < count; i++)); do
                checked[$i]=0
            done
        elif [[ "$key" == "" ]]; then
            # Enter
            break
        fi

        # Move cursor up to redraw
        printf "\e[${total_lines}A"

        for i in "${!options[@]}"; do
            printf "\e[2K"
            local marker="${UI_CIRCLE}"
            local color="${UI_DIM}"
            if [[ ${checked[$i]} -eq 1 ]]; then
                marker="${UI_GREEN}${UI_DOT}${UI_RESET}"
                color="${UI_WHITE}"
            fi
            if [[ $i -eq $cursor ]]; then
                echo -e "  ${UI_CYAN}${UI_ARROW}${UI_RESET} $marker ${color}${options[$i]}${UI_RESET}"
            else
                echo -e "    $marker ${color}${options[$i]}${UI_RESET}"
            fi
        done
        printf "\e[2K"
        echo ""
        printf "\e[2K"
        echo -e "  ${UI_DIM}[↑↓] navigate  [Space] toggle  [a] all  [n] none  [Enter] confirm${UI_RESET}"
    done

    # Show cursor
    tput cnorm 2>/dev/null

    # Clear the menu
    printf "\e[$((total_lines + 1))A"
    for ((i = 0; i <= total_lines; i++)); do
        printf "\e[2K\n"
    done
    printf "\e[$((total_lines + 1))A"

    # Collect selected items
    SELECTED_ITEMS=()
    SELECTED_INDICES=()
    local selected_display=""
    for i in "${!options[@]}"; do
        if [[ ${checked[$i]} -eq 1 ]]; then
            SELECTED_ITEMS+=("${options[$i]}")
            SELECTED_INDICES+=("$i")
            if [[ -n "$selected_display" ]]; then
                selected_display+=", "
            fi
            selected_display+="${options[$i]}"
        fi
    done

    # Show summary
    if [[ ${#SELECTED_ITEMS[@]} -eq 0 ]]; then
        echo -e "  ${UI_BOLD}${UI_WHITE}$title${UI_RESET} ${UI_YELLOW}(none selected)${UI_RESET}"
    else
        echo -e "  ${UI_BOLD}${UI_WHITE}$title${UI_RESET} ${UI_GREEN}${UI_CHECK} ${selected_display}${UI_RESET}"
    fi
}

# ──────────────────────────────────────────────
#  confirm — Yes/No prompt
#  Usage: confirm "Install Composer?"
#  Returns: 0 = yes, 1 = no
# ──────────────────────────────────────────────
confirm() {
    local prompt="$1"
    local default="${2:-y}"  # Default: yes

    local hint
    if [[ "$default" == "y" ]]; then
        hint="[Y/n]"
    else
        hint="[y/N]"
    fi

    echo -ne "  ${UI_BOLD}${UI_WHITE}$prompt${UI_RESET} ${UI_DIM}$hint${UI_RESET} "
    local answer
    read -r answer

    # Move up and rewrite with result
    printf "\e[1A\e[2K"

    if [[ -z "$answer" ]]; then
        answer="$default"
    fi

    case "$answer" in
        [yY]|[yY][eE][sS])
            echo -e "  ${UI_BOLD}${UI_WHITE}$prompt${UI_RESET} ${UI_GREEN}${UI_CHECK} Yes${UI_RESET}"
            return 0
            ;;
        *)
            echo -e "  ${UI_BOLD}${UI_WHITE}$prompt${UI_RESET} ${UI_RED}✘ No${UI_RESET}"
            return 1
            ;;
    esac
}

# ──────────────────────────────────────────────
#  input_text — Text input with optional default
#  Usage: input_text "Domain name" "example.com"
#  Result: $INPUT_VALUE
# ──────────────────────────────────────────────
input_text() {
    local prompt="$1"
    local default="${2:-}"

    local hint=""
    if [[ -n "$default" ]]; then
        hint=" ${UI_DIM}($default)${UI_RESET}"
    fi

    echo -ne "  ${UI_BOLD}${UI_WHITE}$prompt${UI_RESET}$hint: "
    local value
    read -r value

    if [[ -z "$value" && -n "$default" ]]; then
        value="$default"
    fi

    # Move up and rewrite with result
    printf "\e[1A\e[2K"
    echo -e "  ${UI_BOLD}${UI_WHITE}$prompt${UI_RESET} ${UI_GREEN}${UI_CHECK} ${value}${UI_RESET}"

    INPUT_VALUE="$value"
}

# ──────────────────────────────────────────────
#  input_secret — Password/secret input (hidden)
#  Usage: input_secret "MySQL root password"
#  Result: $INPUT_VALUE
# ──────────────────────────────────────────────
input_secret() {
    local prompt="$1"

    echo -ne "  ${UI_BOLD}${UI_WHITE}$prompt${UI_RESET}: "
    local value
    read -rs value
    echo ""

    # Move up and rewrite
    printf "\e[1A\e[2K"
    echo -e "  ${UI_BOLD}${UI_WHITE}$prompt${UI_RESET} ${UI_GREEN}${UI_CHECK} ********${UI_RESET}"

    INPUT_VALUE="$value"
}

# ──────────────────────────────────────────────
#  show_spinner — Spinner animation while command runs
#  Usage: show_spinner "Installing nginx..." apt install nginx -y
# ──────────────────────────────────────────────
show_spinner() {
    local msg="$1"
    shift
    local -a cmd=("$@")
    local spin_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local pid

    # Run the command in background
    "${cmd[@]}" &>/dev/null &
    pid=$!

    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        local char="${spin_chars:i%${#spin_chars}:1}"
        printf "\r  ${UI_CYAN}${char}${UI_RESET} ${msg}"
        ((i++))
        sleep 0.1
    done

    # Check exit status
    wait "$pid"
    local exit_code=$?

    printf "\r\e[2K"
    if [[ $exit_code -eq 0 ]]; then
        echo -e "  ${UI_GREEN}${UI_CHECK}${UI_RESET} ${msg} ${UI_GREEN}done${UI_RESET}"
    else
        echo -e "  ${UI_RED}✘${UI_RESET} ${msg} ${UI_RED}failed${UI_RESET}"
    fi

    return $exit_code
}

# ──────────────────────────────────────────────
#  show_progress — Progress bar
#  Usage: show_progress 3 8 "Installing PHP..."
# ──────────────────────────────────────────────
show_progress() {
    local current=$1
    local total=$2
    local msg="$3"
    local width=20
    local pct=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    local bar=""
    for ((i = 0; i < filled; i++)); do
        bar+="${UI_BLOCK_FULL}"
    done
    for ((i = 0; i < empty; i++)); do
        bar+="${UI_BLOCK_EMPTY}"
    done

    printf "\r\e[2K"
    echo -ne "  ${UI_CYAN}[${bar}]${UI_RESET} ${current}/${total} ${msg}"

    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# ──────────────────────────────────────────────
#  show_summary — Summary box after installation
#  Usage: show_summary "Module" "key1=val1" "key2=val2"
# ──────────────────────────────────────────────
show_summary() {
    local module="$1"
    shift
    local details=("$@")

    echo ""
    echo -e "  ${UI_GREEN}${UI_BOLD}┌──────────────────────────────────────────┐${UI_RESET}"
    printf "  ${UI_GREEN}${UI_BOLD}│${UI_RESET}  ${UI_CHECK} %-39s${UI_GREEN}${UI_BOLD}│${UI_RESET}\n" "$module installed successfully!"
    echo -e "  ${UI_GREEN}${UI_BOLD}├──────────────────────────────────────────┤${UI_RESET}"
    for detail in "${details[@]}"; do
        local key="${detail%%=*}"
        local val="${detail#*=}"
        printf "  ${UI_GREEN}${UI_BOLD}│${UI_RESET}  ${UI_DIM}%-15s${UI_RESET} %-24s${UI_GREEN}${UI_BOLD}│${UI_RESET}\n" "$key:" "$val"
    done
    echo -e "  ${UI_GREEN}${UI_BOLD}└──────────────────────────────────────────┘${UI_RESET}"
    echo ""
}
