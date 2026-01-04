#!/bin/bash
# Module Réseau - Diagnostics et outils réseau

# Chargement des dépendances
SCRIPT_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_MODULE_DIR/../lib/common.sh"
source "$SCRIPT_MODULE_DIR/../lib/ui.sh"

# Fonction menu réseau
menu_network() {
    while true; do
        show_header
        echo -e "${COLOR_WHITE}┌─────────────────────────────────────────────────────────────┐${COLOR_RESET}"
        echo -e "${COLOR_WHITE}│                      MENU RÉSEAU                            │${COLOR_RESET}"
        echo -e "${COLOR_WHITE}├─────────────────────────────────────────────────────────────┤${COLOR_RESET}"
        echo -e "${COLOR_WHITE}│  1.${COLOR_GREEN} Test connectivité     ${COLOR_WHITE}│ Ping serveurs importants         │${COLOR_RESET}"
        echo -e "${COLOR_WHITE}│  2.${COLOR_GREEN} Interfaces réseau     ${COLOR_WHITE}│ Liste des interfaces             │${COLOR_RESET}"
        echo -e "${COLOR_WHITE}├─────────────────────────────────────────────────────────────┤${COLOR_RESET}"
        echo -e "${COLOR_WHITE}│  0.${COLOR_YELLOW} Retour                ${COLOR_WHITE}│ Menu principal                   │${COLOR_RESET}"
        echo -e "${COLOR_WHITE}└─────────────────────────────────────────────────────────────┘${COLOR_RESET}"
        echo ""
        
        read -p "$(echo -e ${COLOR_CYAN}Sélectionnez une option [0-2]: ${COLOR_RESET})" choice
        
        case "$choice" in
            1)
                show_header
                print_message "info" "Test de connectivité"
                echo ""
                ping -c 2 8.8.8.8 && print_message "success" "Connectivité OK" || print_message "error" "Pas de connexion"
                echo ""
                pause_with_message
                ;;
            2)
                show_header
                print_message "info" "Interfaces réseau"
                echo ""
                ip addr show 2>/dev/null || ifconfig
                echo ""
                pause_with_message
                ;;
            0) break ;;
            *) 
                print_message "error" "Choix non valide"
                sleep 1
                ;;
        esac
    done
}

# Export des fonctions
export -f menu_network
