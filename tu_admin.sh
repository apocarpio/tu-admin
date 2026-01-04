#!/bin/bash

# TU Admin - Script d'administration système modulaire
# Version: 3.0 Modulaire
# Description: Interface d'administration avec architecture modulaire

# Détermination du répertoire du script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Chargement des bibliothèques communes
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/ui.sh"
source "$SCRIPT_DIR/lib/database.sh"

# Définition des modules disponibles
declare -A MODULES=(
    ["tu-tools"]="$SCRIPT_DIR/modules/tu-tools.sh"
    ["system"]="$SCRIPT_DIR/modules/system.sh"
    ["network"]="$SCRIPT_DIR/modules/network.sh"
    ["logs"]="$SCRIPT_DIR/modules/logs.sh"
)

# Fonction pour charger un module dynamiquement
load_module() {
    local module_name="$1"
    local module_path="${MODULES[$module_name]}"
    
    if [[ -f "$module_path" ]]; then
        source "$module_path"
        log_message "INFO" "Module chargé: $module_name"
        return 0
    else
        print_message "error" "Module non trouvé: $module_name"
        log_message "ERROR" "Module manquant: $module_path"
        return 1
    fi
}

# Fonction pour vérifier les permissions
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        print_message "warning" "Certaines fonctionnalités nécessitent sudo"
        echo ""
    fi
}

# Fonction principale
main() {
    check_permissions

    # Vérifier que le fichier de log est accessible
    touch "$LOG_FILE" 2>/dev/null || {
        print_message "error" "Impossible de créer le fichier log"
        exit 1
    }

    # Vérifier que base64 est disponible
    if ! command -v base64 &> /dev/null; then
        print_message "error" "base64 requis!"
        print_message "warning" "Installez: sudo apt install coreutils"
        exit 1
    fi

    log_action "Démarrage TU Admin" "INFO" "Utilisateur: $(whoami)"

    # Boucle principale du menu
    while true; do
        show_main_menu
        
        read -p "$(echo -e ${COLOR_CYAN}Sélectionnez une option [0-4]: ${COLOR_RESET})" choice

        case "$choice" in
            1)
                # Module TU TOOLS
                if load_module "tu-tools"; then
                    menu_tu_tools
                fi
                ;;
            2)
                # Module Système
                if load_module "system"; then
                    menu_system
                fi
                ;;
            3)
                # Module Réseau
                if load_module "network"; then
                    menu_network
                fi
                ;;
            4)
                # Module Logs
                if load_module "logs"; then
                    menu_logs
                fi
                ;;
            0)
                print_message "success" "Au revoir !"
                log_action "Arrêt TU Admin" "INFO" "Utilisateur: $(whoami)"
                exit 0
                ;;
            *)
                print_message "error" "Choix non valide"
                sleep 1
                ;;
        esac
    done
}

# Point d'entrée du script
main "$@"
