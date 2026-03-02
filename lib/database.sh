#!/bin/bash
# Bibliothèque Database - Fonctions de gestion base de données
# Auteur: Simone MUREDDU pour iesS
# Description: Gestion complète des opérations base de données pour TU Admin

# Chargement des dépendances
source "$(dirname "${BASH_SOURCE[0]}")/../config/colors.conf"

# Fonction pour sauvegarder les credentials (port optionnel, défaut 3306)
save_db_credentials() {
    local host="$1"
    local database="$2"
    local user="$3"
    local password="$4"
    local port="${5:-3306}"

    {
        echo "HOST=$(encrypt_string "$host")"
        echo "DATABASE=$(encrypt_string "$database")"
        echo "USER=$(encrypt_string "$user")"
        echo "PASSWORD=$(encrypt_string "$password")"
        echo "PORT=$(encrypt_string "$port")"
        echo "CONFIGURED=true"
    } > "$DB_CREDENTIALS_FILE"

    chmod 600 "$DB_CREDENTIALS_FILE"
    echo -e "${GREEN}✅ Credentials sauvegardées avec succès!${NC}"
}

# Fonction pour charger les credentials
load_db_credentials() {
    if [[ -f "$DB_CREDENTIALS_FILE" ]]; then
        source "$DB_CREDENTIALS_FILE"
        if [[ "$CONFIGURED" == "true" ]]; then
            DB_HOST=$(decrypt_string "$HOST")
            DB_DATABASE=$(decrypt_string "$DATABASE")
            DB_USER=$(decrypt_string "$USER")
            DB_PASSWORD=$(decrypt_string "$PASSWORD")
            # Compatibilità backward: se PORT non presente, default 3306
            DB_PORT=""
            if [[ -n "$PORT" ]]; then
                DB_PORT=$(decrypt_string "$PORT")
            fi
            [[ -z "$DB_PORT" ]] && DB_PORT="3306"
            export DB_PORT
            return 0
        fi
    fi
    return 1
}

# Helper: opzione porta per comandi mysql
_mysql_port_opt() {
    if [[ -n "$DB_PORT" && "$DB_PORT" != "3306" ]]; then
        echo "-P $DB_PORT"
    fi
}

# Fonction test connexion silencieuse
test_db_connection_silent() {
    if [[ -z "$DB_HOST" || -z "$DB_USER" || -z "$DB_PASSWORD" || -z "$DB_DATABASE" ]]; then
        return 1
    fi

    if ! command -v mysql &> /dev/null; then
        return 1
    fi

    local port_opt=$(_mysql_port_opt)
    if mysql -h "$DB_HOST" $port_opt -u "$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1;" "$DB_DATABASE" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Fonction pour calculer la taille d'une table
calculate_table_size() {
    local table_name="$1"

    if ! command -v mysql &> /dev/null; then
        echo "N/A|0"
        return 1
    fi

    if ! test_db_connection_silent; then
        echo "N/A|0"
        return 1
    fi

    local port_opt=$(_mysql_port_opt)
    local query="SELECT
        ROUND(((data_length + index_length) / 1024 / 1024), 2),
        table_rows
    FROM information_schema.tables
    WHERE table_schema = '$DB_DATABASE' AND table_name = '$table_name';"

    local result=$(mysql -h "$DB_HOST" $port_opt -u "$DB_USER" -p"$DB_PASSWORD" -sN -e "$query" 2>/dev/null)

    if [[ -n "$result" && "$result" != "NULL	NULL" ]]; then
        local size_mb=$(echo "$result" | awk '{print $1}')
        local rows=$(echo "$result" | awk '{print $2}')

        if [[ "$size_mb" == "NULL" || -z "$size_mb" ]]; then
            size_mb="0.00"
        fi
        if [[ "$rows" == "NULL" || -z "$rows" ]]; then
            rows="0"
        fi

        echo "${size_mb}|${rows}"
    else
        echo "0.00|0"
    fi
}

# Fonction pour calculer la taille totale de la base de données
get_database_total_size() {
    if ! command -v mysql &> /dev/null; then
        echo "N/A"
        return 1
    fi

    if ! test_db_connection_silent; then
        echo "N/A"
        return 1
    fi

    local port_opt=$(_mysql_port_opt)
    local total_size=$(mysql -h "$DB_HOST" $port_opt -u "$DB_USER" -p"$DB_PASSWORD" -sN -e "
        SELECT ROUND(SUM((data_length + index_length) / 1024 / 1024), 2) as total_mb
        FROM information_schema.tables
        WHERE table_schema = '$DB_DATABASE';" 2>/dev/null)

    if [[ -n "$total_size" && "$total_size" != "NULL" ]]; then
        echo "$total_size MB"
    else
        echo "N/A"
    fi
}

# Fonction pour obtenir les informations d'espace disque
get_disk_usage() {
    local path="$1"
    if [[ -d "$path" ]]; then
        df -h "$path" | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}'
    else
        echo "N/A"
    fi
}

# Export fonctions
export -f save_db_credentials
export -f load_db_credentials
export -f _mysql_port_opt
export -f test_db_connection_silent
export -f calculate_table_size
export -f get_database_total_size
export -f get_disk_usage
