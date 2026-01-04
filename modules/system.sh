#!/bin/bash
# Module Système - Informations et monitoring système

# Chargement des dépendances
SCRIPT_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_MODULE_DIR/../lib/common.sh"
source "$SCRIPT_MODULE_DIR/../lib/ui.sh"

# Fonction menu système
menu_system() {
    while true; do
        show_header
        echo -e "${COLOR_WHITE}┌─────────────────────────────────────────────────────────────┐${COLOR_RESET}"
        echo -e "${COLOR_WHITE}│                      MENU SYSTÈME                           │${COLOR_RESET}"
        echo -e "${COLOR_WHITE}├─────────────────────────────────────────────────────────────┤${COLOR_RESET}"
        echo -e "${COLOR_WHITE}│  1.${COLOR_GREEN} Informations système ${COLOR_WHITE}│ CPU, RAM, disque, uptime         │${COLOR_RESET}"
        echo -e "${COLOR_WHITE}│  2.${COLOR_GREEN} Processus            ${COLOR_WHITE}│ Liste des processus              │${COLOR_RESET}"
        echo -e "${COLOR_WHITE}├─────────────────────────────────────────────────────────────┤${COLOR_RESET}"
        echo -e "${COLOR_WHITE}│  0.${COLOR_YELLOW} Retour               ${COLOR_WHITE}│ Menu principal                   │${COLOR_RESET}"
        echo -e "${COLOR_WHITE}└─────────────────────────────────────────────────────────────┘${COLOR_RESET}"
        echo ""
        
        read -p "$(echo -e ${COLOR_CYAN}Sélectionnez une option [0-2]: ${COLOR_RESET})" choice
        
        case "$choice" in
            1) 
                show_header
                print_message "info" "Module Système - Informations"
                echo ""
                echo -e "${COLOR_YELLOW}📊 Informations système de base:${COLOR_RESET}"
                echo -e "${COLOR_CYAN}Utilisateur:${COLOR_RESET} $(whoami)"
                echo -e "${COLOR_CYAN}Hostname:${COLOR_RESET} $(hostname)"
                echo -e "${COLOR_CYAN}Uptime:${COLOR_RESET} $(uptime -p 2>/dev/null || uptime)"
                echo ""
                pause_with_message
                ;;
            2)
                show_header
                print_message "info" "Module Système - Processus"
                echo ""
                ps aux | head -20
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
export -f menu_system
