#!/bin/bash
# TU Tools - Opérations database

# Fonction pour tester la connexion à la base de données
test_db_connection() {
    show_header
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                    TEST CONNEXION BASE                      │${NC}"
    echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
    if [[ -n "$DB_DATABASE" && -n "$DB_HOST" ]]; then
        local port_display="${DB_PORT:-3306}"
        echo -e "${WHITE}│  ${GREEN}Base: ${DB_DATABASE}@${DB_HOST}:${port_display}${WHITE}                              │${NC}"
        local db_total_size=$(get_database_total_size)
        echo -e "${WHITE}│  ${BLUE}Taille de la base: ${db_total_size}${WHITE}                               │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
    fi
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    if [[ -z "$DB_HOST" || -z "$DB_USER" || -z "$DB_PASSWORD" || -z "$DB_DATABASE" ]]; then
        echo -e "${RED}❌ Paramètres de connexion non configurés${NC}"
        echo -e "${YELLOW}Utilisez l'option 6 pour configurer la base de données${NC}"
        pause_any_key
        return 1
    fi

    local port_opt=$(_mysql_port_opt)
    local port_display="${DB_PORT:-3306}"

    echo -e "${CYAN}Test de connexion vers:${NC}"
    echo -e "${WHITE}  Host:     ${YELLOW}$DB_HOST${NC}"
    echo -e "${WHITE}  Port:     ${YELLOW}$port_display${NC}"
    echo -e "${WHITE}  Database: ${YELLOW}$DB_DATABASE${NC}"
    echo -e "${WHITE}  User:     ${YELLOW}$DB_USER${NC}"
    echo ""

    if ! command -v mysql &> /dev/null; then
        echo -e "${RED}❌ Client MySQL non installé${NC}"
        pause_any_key
        return 1
    fi

    echo -e "${CYAN}Connexion en cours...${NC}"

    if mysql -h "$DB_HOST" $port_opt -u "$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1;" "$DB_DATABASE" 2>/dev/null; then
        echo -e "${GREEN}✅ Connexion réussie!${NC}"

        echo ""
        echo -e "${CYAN}Informations sur la base:${NC}"
        local version=$(mysql -h "$DB_HOST" $port_opt -u "$DB_USER" -p"$DB_PASSWORD" -sN -e "SELECT VERSION();" 2>/dev/null)
        if [[ -n "$version" ]]; then
            echo -e "${WHITE}  Version MySQL/MariaDB: ${GREEN}$version${NC}"
        fi

        local tables_count=$(mysql -h "$DB_HOST" $port_opt -u "$DB_USER" -p"$DB_PASSWORD" -sN \
            -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$DB_DATABASE';" 2>/dev/null)
        if [[ -n "$tables_count" ]]; then
            echo -e "${WHITE}  Nombre de tables: ${GREEN}$tables_count${NC}"
        fi

        pause_any_key
        return 0
    else
        echo -e "${RED}❌ Échec de connexion${NC}"
        echo -e "${YELLOW}Vérifiez les paramètres de connexion${NC}"
        pause_any_key
        return 1
    fi
}

# Fonction show_db_status
show_db_status() {
    show_header
    echo -e "${WHITE}ÉTAT BASE DE DONNÉES${NC}"
    echo ""

    local port_opt=$(_mysql_port_opt)

    if command -v mysql &> /dev/null; then
        mysql -h "$DB_HOST" $port_opt -u "$DB_USER" -p"$DB_PASSWORD" -e "
            SELECT '$DB_DATABASE' as 'Base', VERSION() as 'Version';
            SELECT COUNT(*) as 'Tables' FROM information_schema.tables WHERE table_schema = '$DB_DATABASE';
        " 2>/dev/null || echo -e "${RED}❌ Erreur de connexion${NC}"
    else
        echo -e "${RED}❌ MySQL client non installé${NC}"
    fi

    pause_any_key
}

# Fonction execute_sql_query
execute_sql_query() {
    show_header
    echo -e "${WHITE}EXÉCUTER REQUÊTE SQL${NC}"
    echo ""

    local port_opt=$(_mysql_port_opt)

    read -p "$(echo -e ${CYAN}Requête SQL: ${NC})" sql_query

    if [[ -n "$sql_query" ]]; then
        mysql -h "$DB_HOST" $port_opt -u "$DB_USER" -p"$DB_PASSWORD" -e "$sql_query" "$DB_DATABASE" 2>/dev/null || {
            echo -e "${RED}❌ Erreur dans la requête${NC}"
        }
    fi

    pause_any_key
}

# Fonction backup_database
backup_database() {
    show_header
    echo -e "${WHITE}SAUVEGARDE BASE DE DONNÉES${NC}"
    echo ""

    local port_opt=$(_mysql_port_opt)
    local backup_file="$BACKUP_DIR/backup_${DB_DATABASE}_$(date +%Y%m%d_%H%M%S).sql"

    if command -v mysqldump &> /dev/null; then
        if mysqldump -h "$DB_HOST" $port_opt -u "$DB_USER" -p"$DB_PASSWORD" "$DB_DATABASE" > "$backup_file" 2>/dev/null; then
            echo -e "${GREEN}✅ Sauvegarde créée: $backup_file${NC}"
        else
            echo -e "${RED}❌ Erreur lors de la sauvegarde${NC}"
        fi
    else
        echo -e "${RED}❌ mysqldump non installé${NC}"
    fi

    pause_any_key
}

# Fonction restore_database
restore_database() {
    show_header
    echo -e "${WHITE}RESTAURATION BASE DE DONNÉES${NC}"
    echo ""

    local port_opt=$(_mysql_port_opt)

    echo -e "${YELLOW}Fichiers disponibles:${NC}"
    ls -lh "$BACKUP_DIR"/*.sql 2>/dev/null || echo "Aucun backup trouvé"
    echo ""

    read -p "$(echo -e ${CYAN}Fichier à restaurer: ${NC})" backup_file

    if [[ -f "$backup_file" ]]; then
        echo -e "${RED}⚠️  Cette opération va écraser la base!${NC}"
        read -p "$(echo -e ${YELLOW}Continuer? [o/N]: ${NC})" confirm

        if [[ "$confirm" =~ ^[Oo]$ ]]; then
            mysql -h "$DB_HOST" $port_opt -u "$DB_USER" -p"$DB_PASSWORD" "$DB_DATABASE" < "$backup_file" 2>/dev/null && {
                echo -e "${GREEN}✅ Restauration réussie${NC}"
            } || {
                echo -e "${RED}❌ Erreur lors de la restauration${NC}"
            }
        fi
    else
        echo -e "${RED}❌ Fichier non trouvé${NC}"
    fi

    pause_any_key
}

# Fonction optimize_tables
optimize_tables() {
    show_header
    echo -e "${WHITE}OPTIMISATION DES TABLES${NC}"
    echo ""

    local port_opt=$(_mysql_port_opt)

    if command -v mysql &> /dev/null; then
        mysql -h "$DB_HOST" $port_opt -u "$DB_USER" -p"$DB_PASSWORD" -e "
            SELECT CONCAT('OPTIMIZE TABLE ', table_name, ';') as cmd
            FROM information_schema.tables
            WHERE table_schema = '$DB_DATABASE';
        " -N 2>/dev/null | while read cmd; do
            mysql -h "$DB_HOST" $port_opt -u "$DB_USER" -p"$DB_PASSWORD" -e "$cmd" "$DB_DATABASE" 2>/dev/null
        done
        echo -e "${GREEN}✅ Optimisation terminée${NC}"
    else
        echo -e "${RED}❌ MySQL client non installé${NC}"
    fi

    pause_any_key
}

# Fonction pour exécuter MySQLTuner
run_mysqltuner() {
    show_header
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                    MYSQLTUNER                               │${NC}"
    echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
    if [[ -n "$DB_DATABASE" && -n "$DB_HOST" ]]; then
        local port_display="${DB_PORT:-3306}"
        echo -e "${WHITE}│  ${GREEN}Base: ${DB_DATABASE}@${DB_HOST}:${port_display}${WHITE}                              │${NC}"
        local db_total_size=$(get_database_total_size)
        echo -e "${WHITE}│  ${BLUE}Taille de la base: ${db_total_size}${WHITE}                               │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
    fi
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    local mysqltuner_dir="$MYSQLTUNER_DIR"
    local mysqltuner_script="$mysqltuner_dir/mysqltuner.pl"

    if [[ ! -d "$mysqltuner_dir" ]]; then
        echo -e "${RED}❌ Répertoire MySQLTuner non trouvé!${NC}"
        echo -e "${YELLOW}Répertoire attendu: $mysqltuner_dir${NC}"
        echo ""
        echo -e "${CYAN}Pour installer MySQLTuner:${NC}"
        echo -e "${WHITE}1.${NC} cd $SCRIPT_DIR"
        echo -e "${WHITE}2.${NC} git clone https://github.com/major/MySQLTuner-perl.git MySQLTuner"
        echo -e "${WHITE}3.${NC} chmod +x MySQLTuner/mysqltuner.pl"
        pause_any_key
        return
    fi

    if [[ ! -f "$mysqltuner_script" ]]; then
        echo -e "${RED}❌ Script mysqltuner.pl non trouvé!${NC}"
        echo -e "${YELLOW}Fichier attendu: $mysqltuner_script${NC}"
        pause_any_key
        return
    fi

    if ! command -v perl &> /dev/null; then
        echo -e "${RED}❌ Perl non installé!${NC}"
        echo -e "${YELLOW}Installez Perl: sudo apt install perl${NC}"
        pause_any_key
        return
    fi

    if [[ ! -x "$mysqltuner_script" ]]; then
        echo -e "${YELLOW}⚠️  Script non exécutable, application des permissions...${NC}"
        chmod +x "$mysqltuner_script"
    fi

    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}              ANALYSE MYSQL AVEC MYSQLTUNER                ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Serveur: ${DB_HOST}:${DB_PORT:-3306}${NC}"
    echo -e "${YELLOW}Base de données: ${DB_DATABASE}${NC}"
    echo -e "${YELLOW}Utilisateur: ${DB_USER}${NC}"
    echo ""
    echo -e "${GREEN}Lancement de MySQLTuner...${NC}"
    echo ""

    cd "$mysqltuner_dir"

    local mysqltuner_options=""
    if [[ "$DB_HOST" != "localhost" && "$DB_HOST" != "127.0.0.1" ]]; then
        mysqltuner_options="--host $DB_HOST"
    fi
    # Aggiungere porta se non standard
    if [[ -n "$DB_PORT" && "$DB_PORT" != "3306" ]]; then
        mysqltuner_options="$mysqltuner_options --port $DB_PORT"
    fi

    echo -e "${CYAN}Commande: perl mysqltuner.pl $mysqltuner_options --user $DB_USER --pass [hidden]${NC}"
    echo ""

    perl mysqltuner.pl $mysqltuner_options --user "$DB_USER" --pass "$DB_PASSWORD" 2>/dev/null || {
        echo ""
        echo -e "${RED}❌ Erreur lors de l'exécution de MySQLTuner${NC}"
        echo -e "${YELLOW}Vérifiez:${NC}"
        echo -e "${YELLOW}  - La connexion à MySQL${NC}"
        echo -e "${YELLOW}  - Les permissions de l'utilisateur${NC}"
        echo -e "${YELLOW}  - La version de Perl${NC}"
    }

    cd "$SCRIPT_DIR"

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}              ANALYSE MYSQLTUNER TERMINÉE                   ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    log_action "Exécution MySQLTuner" "INFO" "Host: $DB_HOST:${DB_PORT:-3306}, User: $DB_USER"

    pause_any_key
}

# Export
export -f test_db_connection
export -f show_db_status
export -f execute_sql_query
export -f backup_database
export -f restore_database
export -f optimize_tables
export -f run_mysqltuner
