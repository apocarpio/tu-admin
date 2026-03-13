#!/bin/bash
# TU Tools - Analyse espace disque

# Fonction pour lister les fichiers les plus volumineux
list_large_files() {
    show_header
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│              FICHIERS LES PLUS VOLUMINEUX                  │${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    echo -e "${BLUE}Sélectionnez le répertoire à analyser:${NC}"
    echo -e "${WHITE}1.${NC} /var (logs, cache, bases de données)"
    echo -e "${WHITE}2.${NC} /home (répertoires utilisateurs)"
    echo -e "${WHITE}3.${NC} /tmp (fichiers temporaires)"
    echo -e "${WHITE}4.${NC} /usr (programmes et librairies)"
    echo -e "${WHITE}5.${NC} / (racine complète - peut être long)"
    echo -e "${WHITE}6.${NC} Chemin personnalisé"
    if [[ -n "$TU_APP_PATH" ]]; then
        echo -e "${WHITE}7.${NC} Application TU ($TU_APP_PATH)"
    fi
    echo ""

    read -p "$(echo -e "${CYAN}Choix [1-7]: ${NC}")" dir_choice

    local search_path=""
    case "$dir_choice" in
        1) search_path="/var" ;;
        2) search_path="/home" ;;
        3) search_path="/tmp" ;;
        4) search_path="/usr" ;;
        5) search_path="/" ;;
        6)
            read -p "$(echo -e "${CYAN}Chemin personnalisé: ${NC}")" search_path
            ;;
        7)
            if [[ -n "$TU_APP_PATH" ]]; then
                search_path="$TU_APP_PATH"
            else
                echo -e "${RED}❌ Chemin TU App non configuré${NC}"
                pause_any_key
                return
            fi
            ;;
        *)
            echo -e "${RED}❌ Choix invalide${NC}"
            pause_any_key
            return
            ;;
    esac

    if [[ ! -d "$search_path" ]]; then
        echo -e "${RED}❌ Répertoire non trouvé: $search_path${NC}"
        pause_any_key
        return
    fi

    echo ""
    echo -e "${YELLOW}Analyse en cours de: $search_path${NC}"
    echo -e "${CYAN}(Cela peut prendre quelques minutes...)${NC}"
    echo ""

    echo -e "${GREEN}═══ TOP 20 FICHIERS LES PLUS VOLUMINEUX ═══${NC}"
    echo -e "${CYAN}Taille    Fichier${NC}"
    echo -e "${CYAN}────────  ──────────────────────────────────────────${NC}"

    find "$search_path" -type f -exec du -h {} + 2>/dev/null | \
        sort -rh | head -20 | \
        while read size file; do
            if [[ "${size: -1}" == "G" ]]; then
                echo -e "${RED}$size\t$file${NC}"
            elif [[ "${size: -1}" == "M" ]]; then
                local num=${size%M}
                if (( $(echo "$num > 100" | bc -l 2>/dev/null || echo 0) )); then
                    echo -e "${YELLOW}$size\t$file${NC}"
                else
                    echo -e "${WHITE}$size\t$file${NC}"
                fi
            else
                echo -e "${WHITE}$size\t$file${NC}"
            fi
        done

    echo ""
    echo -e "${CYAN}Légende: ${RED}Rouge=GB${NC} ${YELLOW}Jaune=+100MB${NC} ${WHITE}Blanc=Autres${NC}"
    echo ""
    
    pause_any_key
}

# Fonction pour lister les tables les plus volumineuses
list_large_tables() {
    show_header
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│              TABLES LES PLUS VOLUMINEUSES                  │${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    if ! command -v mysql &> /dev/null; then
        echo -e "${RED}❌ MySQL client non installé${NC}"
        pause_any_key
        return
    fi

    if [[ -z "$DB_HOST" || -z "$DB_USER" || -z "$DB_PASSWORD" || -z "$DB_DATABASE" ]]; then
        echo -e "${RED}❌ Configuration base de données manquante${NC}"
        pause_any_key
        return
    fi

    echo -e "${YELLOW}Analyse de la base: $DB_DATABASE@$DB_HOST${NC}"
    echo -e "${CYAN}Recherche des tables > 100MB...${NC}"
    echo ""

    local query="SELECT
        table_name as \`Table\`,
        ROUND(((data_length + index_length) / 1024 / 1024), 2) as \`Taille_MB\`,
        ROUND((data_length / 1024 / 1024), 2) as \`Données_MB\`,
        ROUND((index_length / 1024 / 1024), 2) as \`Index_MB\`,
        table_rows as \`Lignes\`
    FROM information_schema.tables
    WHERE table_schema = '$DB_DATABASE'
        AND ((data_length + index_length) / 1024 / 1024) > 100
    ORDER BY (data_length + index_length) DESC;"

    if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "$query" 2>/dev/null; then
        echo ""
        echo -e "${GREEN}═══ STATISTIQUES GLOBALES ═══${NC}"

        local total_query="SELECT
            COUNT(*) as \`Total_Tables\`,
            ROUND(SUM((data_length + index_length) / 1024 / 1024), 2) as \`Taille_Totale_MB\`
        FROM information_schema.tables
        WHERE table_schema = '$DB_DATABASE';"

        mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "$total_query" 2>/dev/null

        echo ""
        echo -e "${CYAN}Note: Seules les tables > 100MB sont affichées${NC}"
    else
        echo -e "${RED}❌ Erreur lors de la connexion à la base${NC}"
    fi

    echo ""
    pause_any_key
}

# Fonction pour le menu Problèmes espace disque
menu_disk_problems() {
    while true; do
        show_header
        echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${WHITE}│                PROBLÈMES D'ESPACE DISQUE                    │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        
        if [[ -n "$DB_DATABASE" && -n "$DB_HOST" ]]; then
            echo -e "${WHITE}│  ${GREEN}Base: ${WHITE}${DB_DATABASE}@${DB_HOST}${NC}"
            
            local db_total_size=$(get_database_total_size)
            echo -e "${WHITE}│  ${BLUE}Taille de la base: ${CYAN}${db_total_size}${NC}"
            echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        fi
        
        if [[ -n "$TU_APP_PATH" ]]; then
            local disk_usage=$(get_disk_usage "$TU_APP_PATH")
            echo -e "${WHITE}│  ${CYAN}App TU: ${YELLOW}${disk_usage}${NC}"
            echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        fi
        
        echo -e "${WHITE}│                      ANALYSE FICHIERS                       │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  ${WHITE}1. ${YELLOW}Fichiers volumineux    ${WHITE}Analyse des gros fichiers${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│                    ANALYSE BASE DONNÉES                     │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  ${WHITE}2. ${YELLOW}Tables volumineuses    ${WHITE}Tables > 100MB${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  ${WHITE}0. ${GREEN}Retour                 ${WHITE}Menu TU TOOLS${NC}"
        echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
        echo ""

        read -p "$(echo -e "${CYAN}Sélectionnez une option [0-2]: ${NC}")" choice

        case "$choice" in
            1) 
                list_large_files
                ;;
            2) 
                list_large_tables
                ;;
            0) 
                break
                ;;
            *)
                echo -e "${RED}Choix non valide${NC}"
                sleep 1
                ;;
        esac
    done
}

# Export
export -f list_large_files
export -f list_large_tables
export -f menu_disk_problems
