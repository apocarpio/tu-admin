#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# TU ADMIN - Script d'administration système avec TU TOOLS
# ═══════════════════════════════════════════════════════════════════════════
# Auteur: Simone MUREDDU pour iesS
# Version: 3.0 - Architecture modulaire
# Description: Interface complète d'administration système pour environnements
#              healthcare avec gestion base de données et maintenance TU
# ═══════════════════════════════════════════════════════════════════════════

# Déterminer le répertoire du script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Chargement de la configuration
source "$SCRIPT_DIR/config/settings.conf"
source "$SCRIPT_DIR/config/colors.conf"

# Chargement des bibliothèques
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/ui.sh"
source "$SCRIPT_DIR/lib/database.sh"

# Chargement des modules TU Tools
source "$SCRIPT_DIR/modules/tu-tools/config.sh"
source "$SCRIPT_DIR/modules/tu-tools/database.sh"
source "$SCRIPT_DIR/modules/tu-tools/maintenance.sh"
source "$SCRIPT_DIR/modules/tu-tools/logs.sh"
source "$SCRIPT_DIR/modules/tu-tools/disk.sh"
source "$SCRIPT_DIR/modules/tu-tools/services.sh"
source "$SCRIPT_DIR/modules/tu-tools/menu.sh"

# Chargement des modules principaux
source "$SCRIPT_DIR/modules/depannage.sh"
source "$SCRIPT_DIR/modules/system.sh"
source "$SCRIPT_DIR/modules/network.sh"
source "$SCRIPT_DIR/modules/logs.sh"

# Fonction pour afficher le menu principal
show_main_menu() {
   clear
   show_header
   echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
   echo -e "${WHITE}│                      MENU PRINCIPAL                         │${NC}"
   echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
   echo -e "${WHITE}│  ${PURPLE}1. TU TOOLS     ${WHITE}│ Gestion base de données et maintenance   │${NC}"
   echo -e "${WHITE}│  ${YELLOW}2. Dépannage    ${WHITE}│ Diagnostic et résolution rapide           │${NC}"
   echo -e "${WHITE}│  ${CYAN}3. Système      ${WHITE}│ Informations système et performance      │${NC}"
   echo -e "${WHITE}│  ${CYAN}4. Réseau       ${WHITE}│ Configuration et outils réseau           │${NC}"
   echo -e "${WHITE}│  ${CYAN}5. Logs         ${WHITE}│ Consultation des logs système            │${NC}"
   echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
   echo -e "${WHITE}│  ${RED}0. Quitter      ${WHITE}│ Sortir de l'application                  │${NC}"
   echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
   echo ""
}

# Fonction principale
main() {
    check_permissions

    touch "$LOG_FILE" 2>/dev/null || {
        echo -e "${RED}Erreur: Impossible de créer le log${NC}"
        exit 1
    }

    # Verifica que base64 sia disponibile
    if ! command -v base64 &> /dev/null; then
        echo -e "${RED}❌ base64 requis!${NC}"
        echo -e "${YELLOW}Installez: apt install coreutils${NC}"
        exit 1
    fi

    log_action "Démarrage TU Admin" "INFO" "Utilisateur: $(whoami)"

    while true; do
        show_header
        show_main_menu
        echo ""

        read -p "$(echo -e ${CYAN}Sélectionnez une option [0-5]: ${NC})" choice

        case "$choice" in
            1)
                # Charger/configurer l'app TU
                if ! load_tu_app_path; then
                    echo -e "${YELLOW}⚠️  Configuration du chemin de l'application TU requise${NC}"
                    echo -e "${CYAN}Cette configuration est nécessaire pour utiliser TU TOOLS${NC}"
                    echo ""
                    if ! configure_tu_app_path; then
                        echo -e "${RED}❌ Configuration annulée${NC}"
                        pause_any_key
                        continue
                    fi
                else
                    # Vérifier que le répertoire existe encore
                    if [[ ! -d "$TU_APP_PATH" ]]; then
                        echo -e "${RED}❌ L'application TU n'est plus accessible: $TU_APP_PATH${NC}"
                        echo -e "${YELLOW}Reconfiguration nécessaire...${NC}"
                        rm -f "$TU_APP_PATH_FILE"
                        if ! configure_tu_app_path; then
                            echo -e "${RED}❌ Configuration annulée${NC}"
                            pause_any_key
                            continue
                        fi
                    fi
                fi

                # Vérifier/configurer le database
                if check_database_configuration; then
                    menu_tu_tools
                fi
                ;;
            2)
                menu_depannage
                ;;
            3)
                menu_system
                ;;
            4)
                menu_network
                ;;
            5)
                menu_logs
                ;;
            0)
                echo -e "${GREEN}Au revoir !${NC}"
                log_action "Arrêt TU Admin" "INFO" "Utilisateur: $(whoami)"
                exit 0
                ;;
            *)
                echo -e "${RED}Choix non valide${NC}"
                sleep 1
                ;;
        esac
    done
}

# Point d'entrée
main "$@"
