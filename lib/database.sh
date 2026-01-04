#!/bin/bash
# Bibliothèque Database pour TU Admin
# Fonctions communes de gestion base de données

# Chargement des dépendances
SCRIPT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_LIB_DIR/common.sh"

# Variables globales DB (chargées depuis config)
DB_HOST=""
DB_DATABASE=""
DB_USER=""
DB_PASSWORD=""

# Fonction de cryptage simple (Base64)
encrypt_string() {
    local input="$1"
    echo -n "$input" | base64 -w 0
}

# Fonction de décryptage simple
decrypt_string() {
    local input="$1"
    echo -n "$input" | base64 -d 2>/dev/null || echo ""
}

# Fonction pour sauvegarder les credentials
save_db_credentials() {
    local host="$1"
    local database="$2"
    local user="$3"
    local password="$4"
    
    local cred_file="${DATA_DIR}/.db_credentials"

    {
        echo "HOST=$(encrypt_string "$host")"
        echo "DATABASE=$(encrypt_string "$database")"
        echo "USER=$(encrypt_string "$user")"
        echo "PASSWORD=$(encrypt_string "$password")"
        echo "CONFIGURED=true"
    } > "$cred_file"

    chmod 600 "$cred_file"
    print_message "success" "Credentials sauvegardées avec succès!"
}

# Fonction pour charger les credentials
load_db_credentials() {
    local cred_file="${DATA_DIR}/.db_credentials"
    
    if [[ -f "$cred_file" ]]; then
        source "$cred_file"
        if [[ "$CONFIGURED" == "true" ]]; then
            DB_HOST=$(decrypt_string "$HOST")
            DB_DATABASE=$(decrypt_string "$DATABASE")
            DB_USER=$(decrypt_string "$USER")
            DB_PASSWORD=$(decrypt_string "$PASSWORD")
            return 0
        fi
    fi
    return 1
}

# Fonction pour tester la connexion DB silencieusement
test_db_connection_silent() {
    # Vérifier que les paramètres de connexion sont définis
    if [[ -z "$DB_HOST" || -z "$DB_USER" || -z "$DB_PASSWORD" || -z "$DB_DATABASE" ]]; then
        return 1
    fi

    # Vérifier que mysql est disponible
    if ! command -v mysql &> /dev/null; then
        return 1
    fi

    # Test de connexion silencieux
    if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1;" "$DB_DATABASE" &>/dev/null; then
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

    # Query pour obtenir taille et nombre de lignes
    local query="SELECT
        ROUND(((data_length + index_length) / 1024 / 1024), 2),
        table_rows
    FROM information_schema.tables
    WHERE table_schema = '$DB_DATABASE' AND table_name = '$table_name';"

    local result=$(mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -sN -e "$query" 2>/dev/null)

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

    local total_size=$(mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -sN -e "
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

# Export des fonctions
export -f encrypt_string
export -f decrypt_string
export -f save_db_credentials
export -f load_db_credentials
export -f test_db_connection_silent
export -f calculate_table_size
export -f get_database_total_size
export -f get_disk_usage
