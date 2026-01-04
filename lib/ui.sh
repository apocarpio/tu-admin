#!/bin/bash
# Bibliothèque UI pour TU Admin
# Fonctions d'affichage: logo, header, menus

# Chargement des dépendances
SCRIPT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_LIB_DIR/common.sh"

# Fonction pour afficher le logo TU Admin
show_logo() {
    echo ""
    echo -e "${COLOR_CYAN}┌────────────────────────────────────────────────────────────────────────────┐${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│${COLOR_BLUE}88888888888 888     888            ${COLOR_WHITE}d8888      888               d8b         ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│${COLOR_BLUE}    888     888     888           ${COLOR_WHITE}d88888      888               Y8P         ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│${COLOR_BLUE}    888     888     888          ${COLOR_WHITE}d88P888      888                           ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│${COLOR_BLUE}    888     888     888         ${COLOR_WHITE}d88P 888  .d88888 88888b.d88b.  888 88888b. ${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│${COLOR_BLUE}    888     888     888        ${COLOR_WHITE}d88P  888 d88\" 888 888 \"888 \"88b 888 888 \"88b${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│${COLOR_BLUE}    888     888     888       ${COLOR_WHITE}d88P   888 888  888 888  888  888 888 888  888${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│${COLOR_BLUE}    888     Y88b. .d88P      ${COLOR_WHITE}d8888888888 Y88b 888 888  888  888 888 888  888${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│${COLOR_BLUE}    888      \"Y88888P\"      ${COLOR_WHITE}d88P     888  \"Y88888 888  888  888 888 888  888${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}└────────────────────────────────────────────────────────────────────────────┘${COLOR_RESET}"
    echo ""
}

# Fonction pour obtenir la version Debian détaillée
get_debian_version() {
    local version_info=""

    if [[ -f /etc/debian_version ]]; then
        local debian_version=$(cat /etc/debian_version)

        if [[ -f /etc/os-release ]]; then
            local pretty_name=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d'"' -f2)
            local version_id=$(grep '^VERSION_ID=' /etc/os-release | cut -d'"' -f2)
            local version_codename=$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d'"' -f2)

            if [[ -n "$version_id" && -n "$version_codename" ]]; then
                version_info="${pretty_name} ${version_id} (${version_codename}) - Debian ${debian_version}"
            elif [[ -n "$version_codename" ]]; then
                version_info="${pretty_name} (${version_codename}) - Debian ${debian_version}"
            elif [[ -n "$version_id" ]]; then
                version_info="${pretty_name} ${version_id} - Debian ${debian_version}"
            else
                version_info="${pretty_name} - Debian ${debian_version}"
            fi
        else
            version_info="Debian ${debian_version}"
        fi

        if [[ -f /proc/version ]]; then
            local kernel_build=$(grep -o 'Debian [0-9]*\.[0-9]*\.[0-9]*-[0-9]*' /proc/version 2>/dev/null)
            if [[ -n "$kernel_build" ]]; then
                version_info="${version_info} (Kernel: ${kernel_build})"
            fi
        fi

    elif [[ -f /etc/os-release ]]; then
        local pretty_name=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d'"' -f2)
        local version_id=$(grep '^VERSION_ID=' /etc/os-release | cut -d'"' -f2)

        if [[ -n "$version_id" ]]; then
            version_info="${pretty_name} ${version_id}"
        else
            version_info="${pretty_name}"
        fi
    else
        version_info="Distribution inconnue"
    fi

    echo "$version_info"
}

# Fonction pour générer les informations distribution
get_distribution_info() {
    local distrib_info=""

    if [[ -f /etc/os-release ]]; then
        local debian_version=$(grep "^VERSION=" /etc/os-release | cut -d'"' -f2 | cut -d' ' -f1)
        local version_codename=$(grep "^VERSION_CODENAME=" /etc/os-release | cut -d'=' -f2)

        if [[ -z "$debian_version" ]]; then
            debian_version=$(grep "^VERSION_ID=" /etc/os-release | cut -d'"' -f2)
        fi

        local kernel_version=$(uname -r)

        if [[ -n "$debian_version" && -n "$version_codename" ]]; then
            distrib_info="Debian GNU/Linux ${debian_version} (${version_codename}) - Kernel: ${kernel_version}"
        else
            distrib_info="$(lsb_release -d 2>/dev/null | cut -f2 || echo "Linux") - Kernel: ${kernel_version}"
        fi
    else
        local kernel_version=$(uname -r)
        distrib_info="$(lsb_release -d 2>/dev/null | cut -f2 || echo "Linux") - Kernel: ${kernel_version}"
    fi

    echo "$distrib_info"
}

# Fonction pour afficher l'en-tête
show_header() {
    clear_screen
    show_logo
    echo -e "${COLOR_CYAN}================================================================${COLOR_RESET}"
    echo -e "${COLOR_WHITE}                    ADMINISTRATION SYSTÈME                     ${COLOR_RESET}"
    echo -e "${COLOR_CYAN}================================================================${COLOR_RESET}"

    echo -e "${COLOR_YELLOW}Utilisateur: $(whoami)${COLOR_RESET}"
    
    if command -v get_distribution_info >/dev/null 2>&1; then
        local distribution_info=$(get_distribution_info)
        echo -e "${COLOR_YELLOW}Distribution: ${distribution_info}${COLOR_RESET}"
    else
        echo -e "${COLOR_WHITE}Système: Linux $(uname -r)${COLOR_RESET}"
    fi
    
    echo -e "${COLOR_YELLOW}Système: $(uname -sr)${COLOR_RESET}"
    echo -e "${COLOR_CYAN}================================================================${COLOR_RESET}"
    echo ""
}

# Fonction pour afficher le menu principal
show_main_menu() {
   clear_screen
   show_header
   echo -e "${COLOR_WHITE}┌─────────────────────────────────────────────────────────────┐${COLOR_RESET}"
   echo -e "${COLOR_WHITE}│                      MENU PRINCIPAL                         │${COLOR_RESET}"
   echo -e "${COLOR_WHITE}├─────────────────────────────────────────────────────────────┤${COLOR_RESET}"
   echo -e "${COLOR_WHITE}│  ${COLOR_PURPLE}1. TU TOOLS     ${COLOR_WHITE}│ Gestion base de données et maintenance   │${COLOR_RESET}"
   echo -e "${COLOR_WHITE}│  ${COLOR_CYAN}2. Système      ${COLOR_WHITE}│ Informations système et performance      │${COLOR_RESET}"
   echo -e "${COLOR_WHITE}│  ${COLOR_CYAN}3. Réseau       ${COLOR_WHITE}│ Configuration et outils réseau           │${COLOR_RESET}"
   echo -e "${COLOR_WHITE}│  ${COLOR_CYAN}4. Logs         ${COLOR_WHITE}│ Consultation des logs système            │${COLOR_RESET}"
   echo -e "${COLOR_WHITE}├─────────────────────────────────────────────────────────────┤${COLOR_RESET}"
   echo -e "${COLOR_WHITE}│  ${COLOR_RED}0. Quitter      ${COLOR_WHITE}│ Sortir de l'application                  │${COLOR_RESET}"
   echo -e "${COLOR_WHITE}└─────────────────────────────────────────────────────────────┘${COLOR_RESET}"
   echo ""
}

# Export des fonctions
export -f show_logo
export -f get_debian_version
export -f get_distribution_info
export -f show_header
export -f show_main_menu
