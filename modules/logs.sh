#!/bin/bash
# Module Logs - Consultation logs système

# Chargement des dépendances
SCRIPT_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_MODULE_DIR/../lib/common.sh"
source "$SCRIPT_MODULE_DIR/../lib/ui.sh"

# Fonction menu logs
menu_logs() {
    while true; do
        show_header
        echo -e "${COLOR_WHITE}┌─────────────────────────────────────────────────────────────┐${COLOR_RESET}"
        echo -e "${COLOR_WHITE}│                      MENU LOGS                              │${COLOR_RESET}"
        echo -e "${COLOR_WHITE}├─────────────────────────────────────────────────────────────┤${COLOR_RESET}"
        echo -e "${COLOR_WHITE}│  1.${COLOR_GREEN} Logs système (syslog) ${COLOR_WHITE}│ Dernières entrées                │${COLOR_RESET}"
        echo -e "${COLOR_WHITE}│  2.${COLOR_GREEN} Logs authentification ${COLOR_WHITE}│ Connexions SSH                   │${COLOR_RESET}"
        echo -e "${COLOR_WHITE}├─────────────────────────────────────────────────────────────┤${COLOR_RESET}"
        echo -e "${COLOR_WHITE}│  0.${COLOR_YELLOW} Retour                ${COLOR_WHITE}│ Menu principal                   │${COLOR_RESET}"
        echo -e "${COLOR_WHITE}└─────────────────────────────────────────────────────────────┘${COLOR_RESET}"
        echo ""
        
        read -p "$(echo -e ${COLOR_CYAN}Sélectionnez une option [0-2]: ${COLOR_RESET})" choice
        
        case "$choice" in
            1)
                show_header
                print_message "info" "Logs système"
                echo ""
                tail -20 /var/log/syslog 2>/dev/null || journalctl -n 20
                echo ""
                pause_with_message
                ;;
            2)
                show_header
                print_message "info" "Logs authentification"
                echo ""
                tail -20 /var/log/auth.log 2>/dev/null || journalctl -u ssh -n 20
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
export -f menu_logs
