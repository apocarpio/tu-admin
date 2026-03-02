#!/bin/bash
# TU Tools - Menu principal

# Fonction pour le menu TU TOOLS
menu_tu_tools() {
    while true; do
        show_header
        echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${WHITE}│                         TU TOOLS                            │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        
        # App TU
        if [[ -n "$TU_APP_PATH" ]]; then
            echo -e "${WHITE}│  ${PURPLE}App TU: ${WHITE}${TU_APP_PATH}${NC}"
            echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        fi
        
        # Database info
        if [[ -n "$DB_DATABASE" && -n "$DB_HOST" ]]; then
            echo -e "${WHITE}│  ${GREEN}Base: ${WHITE}${DB_DATABASE}@${DB_HOST}${NC}"
            
            local db_total_size=$(get_database_total_size)
            echo -e "${WHITE}│  ${BLUE}Taille de la base: ${CYAN}${db_total_size}${NC}"
            echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        fi
        
        # Espace occupé
        if [[ -n "$TU_APP_PATH" ]]; then
            local disk_usage=$(get_disk_usage "$TU_APP_PATH")
            echo -e "${WHITE}│  ${CYAN}Espace occupé: ${YELLOW}${disk_usage}${NC}"
            echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        fi
        
        # Menu options
        echo -e "${WHITE}│                        DATABASE                             │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  ${WHITE}1. ${GREEN}Test connexion         ${WHITE}Vérifier la connexion${NC}"
        echo -e "${WHITE}│  ${WHITE}2. ${GREEN}État de la base        ${WHITE}Informations et stats${NC}"
        echo -e "${WHITE}│  ${WHITE}3. ${GREEN}MySQLTuner             ${WHITE}Analyse MySQL${NC}"
        echo -e "${WHITE}│  ${WHITE}4. ${RED}Opérations sensibles   ${WHITE}Actions critiques${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│                         LOGS                                │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  ${WHITE}5. ${CYAN}Consultation logs      ${WHITE}Logs de l'application${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│                     ESPACE DISQUE                           │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  ${WHITE}8. ${CYAN}Problèmes espace       ${WHITE}Analyse fichiers/tables${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│                       SERVICES                              │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  ${WHITE}9. ${PURPLE}Services HL7/FTP       ${WHITE}Gestion HL7 et ProFTPD${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│                     CONFIGURATION                           │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  ${WHITE}6. ${YELLOW}Reconfigurer DB        ${WHITE}Modifier paramètres DB${NC}"
        echo -e "${WHITE}│  ${WHITE}7. ${YELLOW}Reconfigurer App TU    ${WHITE}Modifier chemin App TU${NC}"
        echo -e "${WHITE}│  ${WHITE}0. ${YELLOW}Retour                 ${WHITE}Menu principal${NC}"
        echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
        echo ""

        read -p "$(echo -e ${CYAN}Sélectionnez une option [0-9]: ${NC})" choice

        case "$choice" in
            1) test_db_connection ;;
            2) show_db_status ;;
            3) run_mysqltuner ;;
            4) menu_operations_sensibles ;;
            5) show_tu_logs ;;
            6)
                echo -e "${YELLOW}Suppression de l'ancienne configuration DB...${NC}"
                rm -f "$DB_CREDENTIALS_FILE"
                configure_database
                # Recharger toutes les variables DB (inclus PORT)
                load_db_credentials
                ;;
            7)
                echo -e "${YELLOW}Reconfiguration du chemin de l'application TU...${NC}"
                rm -f "$TU_APP_PATH_FILE"
                if configure_tu_app_path; then
                    echo -e "${GREEN}✅ Chemin mis à jour avec succès!${NC}"
                    sleep 2
                fi
                ;;
            8) menu_disk_problems ;;
            9) menu_services ;;
            0) break ;;
            *)
                echo -e "${RED}Choix non valide${NC}"
                sleep 1
                ;;
        esac
    done
}

# Export
export -f menu_tu_tools
