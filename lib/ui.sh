#!/bin/bash
# Bibliothèque UI - Interface utilisateur

# Chargement couleurs
source "$(dirname "${BASH_SOURCE[0]}")/../config/colors.conf"

# Fonction pour afficher le logo
show_logo() {
    echo ""
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${BLUE}88888888888 888     888            ${WHITE}d8888      888               d8b         ${CYAN}│${NC}"
    echo -e "${CYAN}│${BLUE}    888     888     888           ${WHITE}d88888      888               Y8P         ${CYAN}│${NC}"
    echo -e "${CYAN}│${BLUE}    888     888     888          ${WHITE}d88P888      888                           ${CYAN}│${NC}"
    echo -e "${CYAN}│${BLUE}    888     888     888         ${WHITE}d88P 888  .d88888 88888b.d88b.  888 88888b. ${CYAN}│${NC}"
    echo -e "${CYAN}│${BLUE}    888     888     888        ${WHITE}d88P  888 d88\" 888 888 \"888 \"88b 888 888 \"88b${CYAN}│${NC}"
    echo -e "${CYAN}│${BLUE}    888     888     888       ${WHITE}d88P   888 888  888 888  888  888 888 888  888${CYAN}│${NC}"
    echo -e "${CYAN}│${BLUE}    888     Y88b. .d88P      ${WHITE}d8888888888 Y88b 888 888  888  888 888 888  888${CYAN}│${NC}"
    echo -e "${CYAN}│${BLUE}    888      \"Y88888P\"      ${WHITE}d88P     888  \"Y88888 888  888  888 888 888  888${CYAN}│${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# Fonction pour afficher l'en-tête
show_header() {
    clear
    show_logo
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${WHITE}                    ADMINISTRATION SYSTÈME                     ${NC}"
    echo -e "${CYAN}================================================================${NC}"

    echo -e "${YELLOW}Utilisateur: $(whoami)${NC}"
    
    # Distribution avec la nouvelle fonction
    if command -v get_distribution_info >/dev/null 2>&1; then
        local distribution_info=$(get_distribution_info)
        echo -e "${YELLOW}Distribution: ${YELLOW} $(echo "$distribution_info" | sed 's/Distribution: //g')${NC}"
    else
        # Fallback
        if [[ -f /etc/os-release ]]; then
            local debian_version=$(grep "^VERSION=" /etc/os-release | cut -d'"' -f2 | cut -d' ' -f1)
            local version_codename=$(grep "^VERSION_CODENAME=" /etc/os-release | cut -d'=' -f2)
            if [[ -z "$debian_version" ]]; then
                debian_version=$(grep "^VERSION_ID=" /etc/os-release | cut -d'"' -f2)
            fi
            local kernel_version=$(uname -r)
            if [[ -n "$debian_version" && -n "$version_codename" ]]; then
                echo -e "${YELLOW}Distribution:  Debian GNU/Linux ${debian_version} (${version_codename}) - Kernel: ${kernel_version}${NC}"
            else
                echo -e "${YELLOW}Distribution:  $(lsb_release -d 2>/dev/null | cut -f2 || echo "Linux") - Kernel: ${kernel_version}${NC}"
            fi
        else
            echo -e "${WHITE}Système: Linux $(uname -r)${NC}"
        fi
    fi
    
    echo -e "${YELLOW}Système: $(uname -sr)${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo ""
}

# Fonction clear_screen alias
clear_screen() {
    clear
}

# Fonction print_message
print_message() {
    local type="$1"
    local message="$2"
    
    case "$type" in
        "success"|"ok")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "error"|"err")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "warning"|"warn")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "info")
            echo -e "${CYAN}ℹ️  $message${NC}"
            ;;
        *)
            echo -e "${WHITE}$message${NC}"
            ;;
    esac
}

# Fonction print_section_title
print_section_title() {
    local title="$1"
    echo -e "${WHITE}$title${NC}"
}

# Fonction ask_confirmation
ask_confirmation() {
    local question="$1"
    read -p "$(echo -e "${YELLOW}$question [o/N]: ${NC}")" response
    [[ "$response" =~ ^[Oo]$ ]]
}

# Fonction pause_with_message (alias)
pause_with_message() {
    pause_any_key
}

# Export fonctions
export -f show_logo
export -f show_header
export -f clear_screen
export -f print_message
export -f print_section_title
export -f ask_confirmation
export -f pause_with_message
