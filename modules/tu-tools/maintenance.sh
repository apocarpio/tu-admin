#!/bin/bash
# TU Tools - Maintenance et opérations sensibles

# Fonction pour ottimizzare la tabella patients_editions
optimize_patients_editions() {
    show_header
    echo -e "${WHITE}OPTIMISATION TABLE PATIENTS_EDITIONS${NC}"
    echo ""
    echo -e "${RED}⚠️  Cette opération peut prendre du temps et bloquer la table!${NC}"
    read -p "$(echo -e ${YELLOW}Continuer? [o/N]: ${NC})" confirm

    if [[ "$confirm" =~ ^[Oo]$ ]]; then
        echo -e "${YELLOW}Optimisation en cours...${NC}"
        if command -v mysql &> /dev/null; then
            mysql -h "$DB_HOST" $(_mysql_port_opt) -u "$DB_USER" -p"$DB_PASSWORD" -e "OPTIMIZE TABLE patients_editions;" "$DB_DATABASE" 2>/dev/null && {
                echo -e "${GREEN}✅ Optimisation réussie${NC}"
            } || {
                echo -e "${RED}❌ Erreur lors de l optimisation${NC}"
            }
        else
            echo -e "${RED}❌ MySQL client non installé${NC}"
        fi
    else
        echo -e "${YELLOW}Opération annulée${NC}"
    fi

    pause_any_key
}

# Fonction pour purger la table patients_messages
purge_patients_messages() {
    show_header
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                   PURGE PATIENTS MESSAGES                  │${NC}"
    echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${WHITE}│           Vider la table patients_messages                │${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # Vérifier la connexion à la base
    if ! test_db_connection_silent; then
        echo -e "${RED}❌ Impossible de se connecter à la base de données${NC}"
        pause_any_key
        return
    fi

    echo -e "${CYAN}Analyse de la table 'patients_messages'...${NC}"
    echo ""

    # Obtenir les informations sur la table patients_messages
    local table_info=$(calculate_table_size "patients_messages")
    if [[ "$table_info" == "N/A|0" ]]; then
        echo -e "${RED}❌ Impossible d'analyser la table patients_messages${NC}"
        pause_any_key
        return
    fi

    local size_mb=$(echo "$table_info" | cut -d"|" -f1)
    local rows_count=$(echo "$table_info" | cut -d"|" -f2)

    echo -e "${YELLOW}📊 Informations sur la table 'patients_messages':${NC}"
    echo -e "${WHITE}   • Taille actuelle: ${CYAN}$size_mb MB${NC}"
    echo -e "${WHITE}   • Nombre d'entrées: ${CYAN}$rows_count${NC}"
    echo ""

    if [[ "$rows_count" == "0" ]]; then
        echo -e "${GREEN}✅ La table 'patients_messages' est déjà vide${NC}"
        pause_any_key
        return
    fi

    echo -e "${RED}⚠️  ATTENTION: Cette opération est IRRÉVERSIBLE!${NC}"
    echo -e "${YELLOW}   Tous les messages patients seront définitivement supprimés${NC}"
    echo -e "${GREEN}   Espace qui sera libéré: $size_mb MB${NC}"
    echo ""

    read -p "$(echo -e ${RED}Êtes-vous sûr de vouloir vider la table patients_messages? [oui/NON]: ${NC})" confirm

    if [[ "$confirm" == "oui" ]]; then
        echo ""
        echo -e "${CYAN}Purge de la table 'patients_messages' en cours...${NC}"

        if mysql -h "$DB_HOST" $(_mysql_port_opt) -u "$DB_USER" -p"$DB_PASSWORD" -e "TRUNCATE TABLE patients_messages;" "$DB_DATABASE" 2>/dev/null; then
            echo -e "${GREEN}✅ Table 'patients_messages' vidée avec succès!${NC}"
            echo -e "${GREEN}   Espace libéré: $size_mb MB${NC}"
        else
            echo -e "${RED}❌ Erreur lors de la purge de la table 'patients_messages'${NC}"
        fi
    else
        echo -e "${YELLOW}Opération annulée${NC}"
    fi

    pause_any_key
}

# Fonction pour purger les logs
purge_logs() {
    show_header
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                        PURGE LOGS                           │${NC}"
    echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${WHITE}│              Vider la table logs                           │${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # Vérifier la connexion à la base
    if ! test_db_connection_silent; then
        echo -e "${RED}❌ Impossible de se connecter à la base de données${NC}"
        pause_any_key
        return
    fi

    echo -e "${CYAN}Analyse de la table 'logs'...${NC}"
    echo ""

    # Obtenir les informations sur la table logs
    local table_info=$(calculate_table_size "logs")
    if [[ "$table_info" == "N/A" ]]; then
        echo -e "${RED}❌ Impossible d'analyser la table logs${NC}"
        pause_any_key
        return
    fi

    local size_mb=$(echo "$table_info" | cut -d"|" -f1)
    local rows_count=$(echo "$table_info" | cut -d"|" -f2)

    echo -e "${YELLOW}📊 Informations sur la table 'logs':${NC}"
    echo -e "${WHITE}   • Taille actuelle: ${CYAN}$size_mb MB${NC}"
    echo -e "${WHITE}   • Nombre d'entrées: ${CYAN}$rows_count${NC}"
    echo ""

    if [[ "$rows_count" == "0" ]]; then
        echo -e "${GREEN}✅ La table 'logs' est déjà vide${NC}"
        pause_any_key
        return
    fi

    echo -e "${RED}⚠️  ATTENTION: Cette opération est IRRÉVERSIBLE!${NC}"
    echo -e "${YELLOW}   Tous les logs seront définitivement supprimés${NC}"
    echo -e "${GREEN}   Espace qui sera libéré: $size_mb MB${NC}"
    echo ""

    read -p "$(echo -e ${RED}Êtes-vous sûr de vouloir vider la table logs? [oui/NON]: ${NC})" confirm

    if [[ "$confirm" == "oui" ]]; then
        echo ""
        echo -e "${CYAN}Purge de la table 'logs' en cours...${NC}"

        if mysql -h "$DB_HOST" $(_mysql_port_opt) -u "$DB_USER" -p"$DB_PASSWORD" -e "TRUNCATE TABLE logs;" "$DB_DATABASE" 2>/dev/null; then
            echo -e "${GREEN}✅ Table 'logs' vidée avec succès!${NC}"
            echo -e "${GREEN}   Espace libéré: $size_mb MB${NC}"
        else
            echo -e "${RED}❌ Erreur lors de la purge de la table 'logs'${NC}"
        fi
    else
        echo -e "${YELLOW}Opération annulée${NC}"
    fi

    pause_any_key
}

# Fonction de vérification des tables database
check_database() {
    clear
    show_header
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                    VÉRIFICATION DATABASE                      ${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""

    echo -e "${YELLOW}🔍 Vérification des tables MariaDB/MySQL...${NC}"
    echo ""

    # Vérifier si MariaDB/MySQL est installé
    if ! command -v mysql &> /dev/null && ! command -v mariadb &> /dev/null; then
        echo -e "${RED}❌ MariaDB/MySQL non installé ou non accessible${NC}"
        pause_any_key
        return
    fi

    echo -e "${CYAN}📊 Test de connexion à la base de données...${NC}"

    # Tester la connexion
    if mysql -h "$DB_HOST" $(_mysql_port_opt) -u "$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1;" "$DB_DATABASE" 2>/dev/null; then
        echo -e "${GREEN}✅ Connexion réussie${NC}"
    else
        echo -e "${RED}❌ Impossible de se connecter à la base de données${NC}"
        echo -e "${YELLOW}💡 Vérifiez les paramètres de connexion MySQL${NC}"
        pause_any_key
        return
    fi

    echo ""
    echo -e "${CYAN}🗃️  Liste des bases de données:${NC}"
    mysql -h "$DB_HOST" $(_mysql_port_opt) -u "$DB_USER" -p"$DB_PASSWORD" -e "SHOW DATABASES;" 2>/dev/null | grep -v "Database\|information_schema\|performance_schema\|mysql\|sys" | while read db; do
        if [[ -n "$db" ]]; then
            echo -e "   ${GREEN}📄 $db${NC}"
        fi
    done

    echo ""
    read -p "$(echo -e ${YELLOW}Entrez le nom de la base à vérifier [ou ENTER pour la base configurée]: ${NC})" target_db

    if [[ -z "$target_db" ]]; then
        target_db="$DB_DATABASE"
    fi

    echo ""
    echo -e "${CYAN}🔧 Démarrage de la vérification de la base: $target_db${NC}"
    echo ""

    # Vérifier si la base existe
    if ! mysql -h "$DB_HOST" $(_mysql_port_opt) -u "$DB_USER" -p"$DB_PASSWORD" -e "USE $target_db;" 2>/dev/null; then
        echo -e "${RED}❌ Base de données '$target_db' non trouvée${NC}"
        pause_any_key
        return
    fi

    tables=$(mysql -h "$DB_HOST" $(_mysql_port_opt) -u "$DB_USER" -p"$DB_PASSWORD" -e "USE $target_db; SHOW TABLES;" 2>/dev/null | grep -v "Tables_in")

    if [[ -n "$tables" ]]; then
        echo -e "${YELLOW}📋 Vérification des tables:${NC}"
        echo ""

        table_count=0
        ok_count=0
        error_count=0

        echo "$tables" | while read table; do
            if [[ -n "$table" ]]; then
                echo -e "${CYAN}🔍 Vérification: $table${NC}"
                result=$(mysql -h "$DB_HOST" $(_mysql_port_opt) -u "$DB_USER" -p"$DB_PASSWORD" -e "USE $target_db; CHECK TABLE $table;" 2>/dev/null)

                if echo "$result" | grep -q "OK$"; then
                    echo -e "   ${GREEN}✅ OK${NC}"
                    ((ok_count++))
                else
                    echo -e "   ${RED}❌ ERREUR${NC}"
                    echo -e "   ${YELLOW}💡 Détails: $(echo "$result" | tail -1)${NC}"
                    ((error_count++))
                fi
                ((table_count++))
            fi
        done

        echo ""
        echo -e "${GREEN}═══ RÉSUMÉ ═══${NC}"
        echo -e "Tables vérifiées: ${CYAN}$table_count${NC}"
        echo -e "Tables OK: ${GREEN}$ok_count${NC}"
        echo -e "Tables avec erreurs: ${RED}$error_count${NC}"

        if [[ $error_count -gt 0 ]]; then
            echo ""
            echo -e "${YELLOW}💡 Pour réparer une table: REPAIR TABLE nom_table;${NC}"
        fi

    else
        echo -e "${YELLOW}⚠️  Aucune table trouvée dans la base $target_db${NC}"
    fi

    echo ""
    pause_any_key
}

# Fonction de consultation des logs MariaDB
view_mariadb_logs() {
    clear
    show_header
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                     LOGS MARIADB/MYSQL                        ${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""

    echo -e "${YELLOW}🔍 Recherche avancée des fichiers de logs...${NC}"
    echo ""

    found_logs=()

    # 1. Vérifier les chemins standards
    echo -e "${CYAN}📂 Vérification chemins standards...${NC}"
    standard_paths=(
        "/var/log/mysql/error.log"
        "/var/log/mysqld.log"
        "/var/log/mariadb/mariadb.log"
        "/var/log/mysql.log"
        "/var/log/mysql.err"
        "/var/log/mysql/mysql.err"
        "/var/log/mariadb.err"
    )

    for log_file in "${standard_paths[@]}"; do
        if [[ -f "$log_file" && -r "$log_file" ]]; then
            found_logs+=("$log_file")
            echo -e "   ${GREEN}✅ $log_file${NC}"
        fi
    done

    # 2. Recherche dans /var/lib/mysql
    echo -e "${CYAN}📂 Recherche dans /var/lib/mysql...${NC}"
    if [[ -d "/var/lib/mysql" ]]; then
        while IFS= read -r -d '' file; do
            found_logs+=("$file")
            echo -e "   ${GREEN}✅ $file${NC}"
        done < <(find /var/lib/mysql -name "*.err" -readable -print0 2>/dev/null)

        # Chercher aussi les fichiers .log
        while IFS= read -r -d '' file; do
            found_logs+=("$file")
            echo -e "   ${GREEN}✅ $file${NC}"
        done < <(find /var/lib/mysql -name "*.log" -readable -print0 2>/dev/null)
    fi

    # 3. Recherche dans /var/log avec find
    echo -e "${CYAN}📂 Recherche étendue dans /var/log...${NC}"
    while IFS= read -r -d '' file; do
        # Éviter les doublons
        if [[ ! " ${found_logs[@]} " =~ " ${file} " ]]; then
            found_logs+=("$file")
            echo -e "   ${GREEN}✅ $file${NC}"
        fi
    done < <(find /var/log -name "*mysql*" -o -name "*mariadb*" 2>/dev/null | grep -E "\.(log|err)$" | head -10 | tr '\n' '\0')

    # 4. Tenter de lire la configuration MySQL pour trouver le log
    echo -e "${CYAN}📂 Vérification configuration MySQL...${NC}"
    config_files=("/etc/mysql/my.cnf" "/etc/my.cnf" "/usr/etc/my.cnf")
    for config in "${config_files[@]}"; do
        if [[ -f "$config" ]]; then
            log_error=$(grep -i "^log.error\|^log-error" "$config" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
            if [[ -n "$log_error" && -f "$log_error" && -r "$log_error" ]]; then
                if [[ ! " ${found_logs[@]} " =~ " ${log_error} " ]]; then
                    found_logs+=("$log_error")
                    echo -e "   ${GREEN}✅ $log_error (depuis $config)${NC}"
                fi
            fi
        fi
    done

    # 5. Utiliser les journaux systemd si disponibles
    echo -e "${CYAN}📂 Vérification journaux systemd...${NC}"
    if command -v journalctl &> /dev/null; then
        # Vérifier si les services MySQL/MariaDB ont des logs
        for service in mysql mariadb mysqld; do
            if systemctl is-active --quiet "$service" 2>/dev/null || systemctl list-units --all | grep -q "$service"; then
                echo -e "   ${BLUE}📋 Service $service détecté (logs via journalctl)${NC}"
                found_logs+=("systemd:$service")
            fi
        done
    fi

    echo ""

    if [[ ${#found_logs[@]} -eq 0 ]]; then
        echo -e "${RED}❌ Aucun fichier de log MariaDB/MySQL trouvé${NC}"
        echo ""
        echo -e "${YELLOW}💡 Solutions possibles:${NC}"
        echo -e "   ${WHITE}1.${NC} Vérifier que MySQL/MariaDB est installé"
        echo -e "   ${WHITE}2.${NC} Vérifier les permissions sur /var/log/"
        echo -e "   ${WHITE}3.${NC} Activer les logs dans la configuration MySQL"
        echo -e "   ${WHITE}4.${NC} Utiliser les journaux systemd: ${CYAN}journalctl -u mysql -f${NC}"
        echo ""
        pause_any_key
        return
    fi

    echo -e "${GREEN}✅ ${#found_logs[@]} source(s) de logs trouvée(s)${NC}"
    echo ""

    # Menu d'options
    while true; do
        echo -e "${WHITE}┌────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${WHITE}│                      OPTIONS D'ANALYSE                     │${NC}"
        echo -e "${WHITE}├────────────────────────────────────────────────────────────┤${NC}"

        # Afficher les fichiers trouvés
        for i in "${!found_logs[@]}"; do
            local log_file="${found_logs[i]}"
            if [[ "$log_file" == systemd:* ]]; then
                local service_name="${log_file#systemd:}"
                echo -e "${WHITE}│  $((i+1)).${GREEN} Logs $service_name           ${WHITE}│ Logs systemd du service          │${NC}"
            else
                local basename_log=$(basename "$log_file")
                printf -v padded_name "%-20s" "$basename_log"
                local file_size=$(ls -lh "$log_file" 2>/dev/null | awk '{print $5}' || echo "N/A")
                echo -e "${WHITE}│  $((i+1)).${GREEN} ${padded_name:0:20}${WHITE}│ ${file_size} - $(echo "$log_file" | cut -c1-20)...${NC}"
            fi
        done

        echo -e "${WHITE}├────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  a.${YELLOW} Toutes les erreurs     ${WHITE}│ Compilation erreurs tous logs  │${NC}"
        echo -e "${WHITE}│  w.${CYAN} Warnings              ${WHITE}│ Avertissements récents         │${NC}"
        echo -e "${WHITE}│  s.${PURPLE} Statistiques          ${WHITE}│ Analyse détaillée des logs     │${NC}"
        echo -e "${WHITE}│  j.${BLUE} Journalctl MySQL      ${WHITE}│ Logs systemd temps réel         │${NC}"
        echo -e "${WHITE}├────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  0.${WHITE} Retour                ${WHITE}│ Menu précédent                 │${NC}"
        echo -e "${WHITE}└────────────────────────────────────────────────────────────┘${NC}"
        echo ""

        read -p "$(echo -e ${CYAN}Votre choix: ${NC})" choice

        case "$choice" in
            [1-9])
                local index=$((choice - 1))
                if [[ $index -lt ${#found_logs[@]} ]]; then
                    local selected_log="${found_logs[$index]}"

                    if [[ "$selected_log" == systemd:* ]]; then
                        # Log systemd
                        local service_name="${selected_log#systemd:}"
                        echo ""
                        echo -e "${GREEN}📄 Logs systemd pour le service: $service_name${NC}"
                        echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
                        echo -e "${YELLOW}📋 50 dernières lignes:${NC}"
                        echo ""
                        journalctl -u "$service_name" -n 50 --no-pager | while read line; do
                            if echo "$line" | grep -qi "error\|fatal\|critical"; then
                                echo -e "${RED}$line${NC}"
                            elif echo "$line" | grep -qi "warn"; then
                                echo -e "${YELLOW}$line${NC}"
                            else
                                echo "$line"
                            fi
                        done
                    else
                        # File di log normale
                        echo ""
                        echo -e "${GREEN}📄 Consultation: $selected_log${NC}"
                        echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"

                        if [[ -f "$selected_log" ]]; then
                            echo -e "${YELLOW}📊 Informations fichier:${NC}"
                            ls -lh "$selected_log"
                            echo ""

                            echo -e "${YELLOW}📋 50 dernières lignes:${NC}"
                            echo ""
                            tail -50 "$selected_log" | while read line; do
                                if echo "$line" | grep -qi "error\|fatal\|critical"; then
                                    echo -e "${RED}$line${NC}"
                                elif echo "$line" | grep -qi "warn"; then
                                    echo -e "${YELLOW}$line${NC}"
                                else
                                    echo "$line"
                                fi
                            done
                        else
                            echo -e "${RED}❌ Fichier non accessible${NC}"
                        fi
                    fi
                else
                    echo -e "${RED}Choix invalide${NC}"
                fi
                echo ""
                pause_any_key
                ;;

            "a"|"A")
                echo ""
                echo -e "${GREEN}🔍 COMPILATION DE TOUTES LES ERREURS${NC}"
                echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
                echo ""

                local total_errors=0
                local total_sources=0

                for log_file in "${found_logs[@]}"; do
                    ((total_sources++))
                    if [[ "$log_file" == systemd:* ]]; then
                        local service_name="${log_file#systemd:}"
                        echo -e "${YELLOW}📄 Erreurs systemd ($service_name):${NC}"
                        local errors=$(journalctl -u "$service_name" -n 100 --no-pager | grep -i "error\|fatal\|critical" | tail -5)
                        if [[ -n "$errors" ]]; then
                            echo "$errors" | while read line; do
                                echo -e "   ${RED}$line${NC}"
                                ((total_errors++))
                            done
                        else
                            echo -e "   ${GREEN}✅ Aucune erreur récente${NC}"
                        fi
                    elif [[ -f "$log_file" ]]; then
                        echo -e "${YELLOW}📄 Erreurs dans: $log_file${NC}"
                        local errors=$(grep -i "error\|fatal\|critical" "$log_file" 2>/dev/null | tail -5)
                        if [[ -n "$errors" ]]; then
                            echo "$errors" | while read line; do
                                echo -e "   ${RED}$line${NC}"
                                ((total_errors++))
                            done
                        else
                            echo -e "   ${GREEN}✅ Aucune erreur dans ce fichier${NC}"
                        fi
                    fi
                    echo ""
                done

                echo -e "${CYAN}═══ RÉSUMÉ ═══${NC}"
                echo -e "${YELLOW}Sources analysées: ${total_sources}${NC}"
                if [[ $total_errors -eq 0 ]]; then
                    echo -e "${GREEN}✅ Aucune erreur trouvée - MySQL/MariaDB fonctionne correctement!${NC}"
                else
                    echo -e "${RED}❌ $total_errors erreur(s) trouvée(s)${NC}"
                fi
                echo ""
                pause_any_key
                ;;

            "w"|"W")
                echo ""
                echo -e "${GREEN}⚠️  WARNINGS ET AVERTISSEMENTS${NC}"
                echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
                echo ""

                local total_warnings=0

                for log_file in "${found_logs[@]}"; do
                    if [[ "$log_file" == systemd:* ]]; then
                        local service_name="${log_file#systemd:}"
                        echo -e "${YELLOW}📄 Warnings systemd ($service_name):${NC}"
                        local warnings=$(journalctl -u "$service_name" -n 100 --no-pager | grep -i "warn\|warning" | tail -3)
                        if [[ -n "$warnings" ]]; then
                            echo "$warnings" | while read line; do
                                echo -e "   ${YELLOW}$line${NC}"
                                ((total_warnings++))
                            done
                        else
                            echo -e "   ${GREEN}✅ Aucun warning récent${NC}"
                        fi
                    elif [[ -f "$log_file" ]]; then
                        echo -e "${YELLOW}📄 Warnings dans: $log_file${NC}"
                        local warnings=$(grep -i "warn\|warning" "$log_file" 2>/dev/null | tail -3)
                        if [[ -n "$warnings" ]]; then
                            echo "$warnings" | while read line; do
                                echo -e "   ${YELLOW}$line${NC}"
                                ((total_warnings++))
                            done
                        else
                            echo -e "   ${GREEN}✅ Aucun warning dans ce fichier${NC}"
                        fi
                    fi
                    echo ""
                done

                echo -e "${CYAN}═══ RÉSUMÉ ═══${NC}"
                if [[ $total_warnings -eq 0 ]]; then
                    echo -e "${GREEN}✅ Aucun warning trouvé${NC}"
                else
                    echo -e "${YELLOW}⚠️  $total_warnings warning(s) trouvé(s)${NC}"
                fi
                echo ""
                pause_any_key
                ;;

            "s"|"S")
                echo ""
                echo -e "${GREEN}📊 STATISTIQUES DES LOGS${NC}"
                echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
                echo ""

                for log_file in "${found_logs[@]}"; do
                    if [[ "$log_file" == systemd:* ]]; then
                        local service_name="${log_file#systemd:}"
                        echo -e "${YELLOW}📄 Statistiques systemd: $service_name${NC}"
                        local total_entries=$(journalctl -u "$service_name" --no-pager | wc -l)
                        local errors=$(journalctl -u "$service_name" --no-pager | grep -ci "error\|fatal\|critical")
                        local warnings=$(journalctl -u "$service_name" --no-pager | grep -ci "warn")
                        echo -e "   Entrées totales: ${CYAN}$total_entries${NC}"
                        echo -e "   Erreurs: ${RED}$errors${NC}"
                        echo -e "   Warnings: ${YELLOW}$warnings${NC}"

                        # Status du service
                        local status=$(systemctl is-active "$service_name" 2>/dev/null)
                        if [[ "$status" == "active" ]]; then
                            echo -e "   Status: ${GREEN}$status${NC}"
                        else
                            echo -e "   Status: ${RED}$status${NC}"
                        fi
                    elif [[ -f "$log_file" ]]; then
                        echo -e "${YELLOW}📄 Analyse: $log_file${NC}"
                        echo -e "   Taille: ${CYAN}$(ls -lh "$log_file" | awk '{print $5}')${NC}"
                        echo -e "   Lignes totales: ${CYAN}$(wc -l < "$log_file" 2>/dev/null)${NC}"
                        echo -e "   Erreurs: ${RED}$(grep -ci "error\|fatal\|critical" "$log_file" 2>/dev/null)${NC}"
                        echo -e "   Warnings: ${YELLOW}$(grep -ci "warn" "$log_file" 2>/dev/null)${NC}"
                        echo -e "   Dernière modification: ${CYAN}$(stat -c %y "$log_file" 2>/dev/null | cut -d. -f1)${NC}"
                    fi
                    echo ""
                done
                pause_any_key
                ;;

            "j"|"J")
                echo ""
                echo -e "${GREEN}📖 Surveillance MySQL/MariaDB temps réel via journalctl${NC}"
                echo -e "${CYAN}Appuyez sur Ctrl+C pour quitter${NC}"
                echo ""
                sleep 2

                # Essayer les services dans l'ordre
                local found_service=false
                for service in mysql mariadb mysqld; do
                    if systemctl is-active --quiet "$service" 2>/dev/null; then
                        echo -e "${GREEN}Surveillance du service: $service${NC}"
                        trap '' INT
                        journalctl -u "$service" -f
                        trap - INT
                        echo ""
                        found_service=true
                        break
                    fi
                done

                if [[ "$found_service" == false ]]; then
                    echo -e "${YELLOW}Aucun service MySQL/MariaDB actif trouvé${NC}"
                    pause_any_key
                fi
                ;;

            "0")
                return
                ;;

            *)
                echo -e "${RED}Choix non valide${NC}"
                sleep 1
                ;;
        esac
    done
}

# Fonction pour le menu Opérations Sensibles
menu_operations_sensibles() {
    while true; do
        show_header
        echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${WHITE}│                   OPÉRATIONS SENSIBLES                      │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        if [[ -n "$TU_APP_PATH" ]]; then
            echo -e "${WHITE}│  ${PURPLE}App TU: ${TU_APP_PATH}${WHITE}                                      │${NC}"
            echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        fi
        if [[ -n "$DB_DATABASE" && -n "$DB_HOST" ]]; then
            echo -e "${WHITE}│  ${GREEN}Base: ${DB_DATABASE}@${DB_HOST}${WHITE}                                   │${NC}"
            local db_total_size=$(get_database_total_size)
            echo -e "${WHITE}│  ${BLUE}Taille de la base: ${db_total_size}${WHITE}                               │${NC}"
            echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        fi
        echo -e "${RED}│  ⚠️  ATTENTION: Ces opérations peuvent causer des           │${NC}"
        echo -e "${RED}│      ralentissements ou indisponibilité de l'application    │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  1.${RED} Sauvegarde          ${WHITE}│ Créer un backup de la base        │${NC}"
        echo -e "${WHITE}│  2.${RED} Restauration        ${WHITE}│ Restaurer depuis un fichier       │${NC}"
        echo -e "${WHITE}│  3.${RED} Check database      ${WHITE}│ Vérification tables MariaDB       │${NC}"
        echo -e "${WHITE}│  4.${RED} Logs MariaDB        ${WHITE}│ Consultation erreurs DB           │${NC}"
        echo -e "${WHITE}│  5.${RED} Optimiser tables    ${WHITE}│ Optimisation des tables           │${NC}"
        echo -e "${WHITE}│  6.${RED} Optimiser patients  ${WHITE}│ Optimiser table patients_editions │${NC}"
        echo -e "${WHITE}│  7.${RED} Purge patients msgs ${WHITE}│ Vider table patients_messages     │${NC}"
        echo -e "${WHITE}│  8.${RED} Purge logs          ${WHITE}│ Vider la table logs               │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  0.${YELLOW} Retour              ${WHITE}│ Menu TU TOOLS                     │${NC}"
        echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        echo ""

        read -p "$(echo -e ${CYAN}Sélectionnez une option [0-8]: ${NC})" choice

        case "$choice" in
            1) backup_database ;;
            2) restore_database ;;
            3) check_database ;;
            4) view_mariadb_logs ;;
            5) optimize_tables ;;
            6) optimize_patients_editions ;;
            7) purge_patients_messages ;;
            8) purge_logs ;;
            0) break ;;
            *)
                echo -e "${RED}Choix non valide${NC}"
                sleep 1
                ;;
        esac
    done
}

# Export
export -f optimize_patients_editions
export -f purge_patients_messages
export -f purge_logs
export -f check_database
export -f view_mariadb_logs
export -f menu_operations_sensibles
