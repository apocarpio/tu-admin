#!/bin/bash
# Bibliothèque de fonctions communes TU Admin
# Chargé par tous les modules

# Determina il percorso base del progetto
SCRIPT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_LIB_DIR/.." && pwd)"

# Chargement des configurations
source "$PROJECT_ROOT/config/colors.conf"
source "$PROJECT_ROOT/config/settings.conf"

# Paths globali del progetto
export APP_DIR="$PROJECT_ROOT"
export BACKUP_DIR="$PROJECT_ROOT/backups"
export MYSQLTUNER_DIR="$PROJECT_ROOT/MySQLTuner"
export DB_CREDENTIALS_FILE="$DATA_DIR/.db_credentials"
export TU_APP_PATH_FILE="$DATA_DIR/.tu_app_path"

# Variable globale pour le chemin de l'application TU
TU_APP_PATH=""

# Fonction: Affichage d'un message avec couleur
# Usage: print_message "type" "message"
# Types: success, error, warning, info, header
print_message() {
    local type="$1"
    local message="$2"
    
    case "$type" in
        success)
            echo -e "${COLOR_SUCCESS}✓ ${message}${COLOR_RESET}"
            ;;
        error)
            echo -e "${COLOR_ERROR}✗ ${message}${COLOR_RESET}"
            ;;
        warning)
            echo -e "${COLOR_WARNING}⚠ ${message}${COLOR_RESET}"
            ;;
        info)
            echo -e "${COLOR_INFO}ℹ ${message}${COLOR_RESET}"
            ;;
        header)
            echo -e "${COLOR_HEADER}${message}${COLOR_RESET}"
            ;;
        *)
            echo -e "${message}"
            ;;
    esac
}

# Fonction: Logging dans fichier
# Usage: log_message "level" "message"
log_message() {
    local level="$1"
    local message="$2"
    
    if [[ "$LOG_ENABLED" == "true" ]]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
    fi
}

# Fonction: Demander confirmation
# Usage: ask_confirmation "message"
# Retourne: 0 si oui, 1 si non
ask_confirmation() {
    local message="$1"
    
    if [[ "$REQUIRE_CONFIRMATION" != "true" ]]; then
        return 0
    fi
    
    echo -e "${COLOR_WARNING}${message}${COLOR_RESET}"
    read -p "Continuer? (o/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[OoYy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Fonction: Vérifier si une commande existe
# Usage: command_exists "commande"
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Fonction: Afficher un titre de section
# Usage: print_section_title "titre"
print_section_title() {
    local title="$1"
    local width=60
    
    echo ""
    echo -e "${COLOR_HEADER}$(printf '═%.0s' $(seq 1 $width))${COLOR_RESET}"
    echo -e "${COLOR_HEADER}  ${title}${COLOR_RESET}"
    echo -e "${COLOR_HEADER}$(printf '═%.0s' $(seq 1 $width))${COLOR_RESET}"
    echo ""
}

# Fonction: Pause avec message
# Usage: pause_with_message "message"
pause_with_message() {
    local message="${1:-Appuyez sur une touche pour continuer...}"
    echo ""
    read -n 1 -s -r -p "$message"
    echo ""
}

# Fonction: Nettoyer l'écran
clear_screen() {
    clear
}

# Export des fonctions pour les sous-modules
export -f print_message
export -f log_message
export -f ask_confirmation
export -f command_exists
export -f print_section_title
export -f pause_with_message
export -f clear_screen
