#!/bin/bash
# Bibliothèque commune - Fonctions utilitaires

# Chargement couleurs
source "$(dirname "${BASH_SOURCE[0]}")/../config/colors.conf"

# Fonction per crittografia semplificata (Base64)
encrypt_string() {
    local input="$1"
    echo -n "$input" | base64 -w 0
}

# Fonction per decrittografia semplificata
decrypt_string() {
    local input="$1"
    echo -n "$input" | base64 -d 2>/dev/null || echo ""
}

# Fonction pause
pause_any_key() {
    local message="${1:-Appuyez sur Entrée pour continuer...}"
    read -p "$(echo -e ${GREEN}$message${NC})" dummy
}

# Fonction de logging
log_action() {
    local action="$1"
    local status="$2"
    local details="$3"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$status] $action - $details" >> "$LOG_FILE"
}

# Fonction pour créer la structure des répertoires
create_app_structure() {
    echo -e "${CYAN}Vérification de la structure de l'application...${NC}"

    # Créer les répertoires nécessaires s'ils n'existent pas
    local dirs_to_create=(
        "$BACKUP_DIR"
        "$SCRIPTS_DIR"
        "$TOOLS_DIR"
    )

    for dir in "${dirs_to_create[@]}"; do
        if [[ ! -d "$dir" ]]; then
            echo -e "${YELLOW}Création du répertoire: $(basename "$dir")${NC}"
            mkdir -p "$dir" || {
                echo -e "${RED}❌ Impossible de créer $dir${NC}"
                return 1
            }
        fi
    done

    return 0
}

# Fonction pour afficher les informations de l'application
show_app_info() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}              INFORMATIONS APPLICATION TU ADMIN            ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Répertoire application:${NC} $APP_DIR"
    echo -e "${YELLOW}Fichier de log:${NC} $LOG_FILE"
    echo -e "${YELLOW}Fichier de configuration:${NC} $CONFIG_FILE"
    echo -e "${YELLOW}Credentials DB:${NC} $DB_CREDENTIALS_FILE"
    echo ""
    echo -e "${CYAN}═══ RÉPERTOIRES MODULES ═══${NC}"
    echo -e "${YELLOW}MySQLTuner:${NC} $MYSQLTUNER_DIR"
    echo -e "${YELLOW}Backups:${NC} $BACKUP_DIR"
    echo -e "${YELLOW}Scripts:${NC} $SCRIPTS_DIR"
    echo -e "${YELLOW}Outils:${NC} $TOOLS_DIR"
    echo ""
    echo -e "${CYAN}═══ ÉTAT DES MODULES ═══${NC}"

    # Vérifier MySQLTuner
    if [[ -f "$MYSQLTUNER_DIR/mysqltuner.pl" ]]; then
        echo -e "${GREEN}✅ MySQLTuner:${NC} Installé"
    else
        echo -e "${RED}❌ MySQLTuner:${NC} Non installé"
    fi

    # Vérifier les répertoires
    for dir in "$BACKUP_DIR" "$SCRIPTS_DIR" "$TOOLS_DIR"; do
        if [[ -d "$dir" ]]; then
            local count=$(find "$dir" -type f 2>/dev/null | wc -l)
            echo -e "${GREEN}✅ $(basename "$dir"):${NC} $count fichier(s)"
        else
            echo -e "${RED}❌ $(basename "$dir"):${NC} Répertoire manquant"
        fi
    done

    echo ""
}

# Fonction per ottenere la versione Debian dettagliata
get_debian_version() {
    local version_info=""

    if [[ -f /etc/debian_version ]]; then
        local debian_version=$(cat /etc/debian_version)

        if [[ -f /etc/os-release ]]; then
            local pretty_name=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d'"' -f2)
            local version_id=$(grep '^VERSION_ID=' /etc/os-release | cut -d'"' -f2)
            local version_codename=$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d'"' -f2)

            if [[ -n "$version_id" && -n "$version_codename" ]]; then
                version_info="${pretty_name} ${version_id} (${version_codename}) - Debian ${debian_version}"
            elif [[ -n "$version_codename" ]]; then
                version_info="${pretty_name} (${version_codename}) - Debian ${debian_version}"
            elif [[ -n "$version_id" ]]; then
                version_info="${pretty_name} ${version_id} - Debian ${debian_version}"
            else
                version_info="${pretty_name} - Debian ${debian_version}"
            fi
        else
            version_info="Debian ${debian_version}"
        fi

        if [[ -f /proc/version ]]; then
            local kernel_build=$(grep -o 'Debian [0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*-[0-9][0-9]*' /proc/version 2>/dev/null)
            if [[ -n "$kernel_build" ]]; then
                version_info="${version_info} (Kernel: ${kernel_build})"
            fi
        fi

    elif [[ -f /etc/os-release ]]; then
        local pretty_name=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d'"' -f2)
        local version_id=$(grep '^VERSION_ID=' /etc/os-release | cut -d'"' -f2)

        if [[ -n "$version_id" ]]; then
            version_info="${pretty_name} ${version_id}"
        else
            version_info="${pretty_name}"
        fi
    else
        version_info="Distribution inconnue"
    fi

    echo "$version_info"
}

# Fonction pour générer les informations Distribution
get_distribution_info() {
    local distrib_info=""

    if [[ -f /etc/os-release ]]; then
        local debian_version=$(grep "^VERSION=" /etc/os-release | cut -d'"' -f2 | cut -d' ' -f1)
        local version_codename=$(grep "^VERSION_CODENAME=" /etc/os-release | cut -d'=' -f2)

        if [[ -z "$debian_version" ]]; then
            debian_version=$(grep "^VERSION_ID=" /etc/os-release | cut -d'"' -f2)
        fi

        local kernel_version=$(uname -r)

        if [[ -n "$debian_version" && -n "$version_codename" ]]; then
            distrib_info="Debian GNU/Linux ${debian_version} (${version_codename}) - Kernel: ${kernel_version}"
        else
            distrib_info="$(lsb_release -d 2>/dev/null | cut -f2 || echo "Linux") - Kernel: ${kernel_version}"
        fi
    else
        local kernel_version=$(uname -r)
        distrib_info="$(lsb_release -d 2>/dev/null | cut -f2 || echo "Linux") - Kernel: ${kernel_version}"
    fi

    echo "$distrib_info"
}

# Fonction pour vérifier les permissions
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}⚠️  Certaines fonctionnalités nécessitent sudo${NC}"
        echo ""
    fi
}

# Fonction pour calculer la longueur visible (sans codes couleur)
visible_length() {
    local text="$1"
    # Rimuove tutti i codici ANSI
    local clean=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    echo ${#clean}
}

# Fonction pour créer une ligne de menu parfaitement alignée
format_menu_row() {
    local left="$1"   # Testo sinistra (con colori)
    local right="$2"  # Testo destra (con colori)
    local total_width=61
    
    # Lunghezze visibili (senza colori)
    local left_clean=$(echo -e "$left" | sed 's/\x1b\[[0-9;]*m//g')
    local right_clean=$(echo -e "$right" | sed 's/\x1b\[[0-9;]*m//g')
    local left_len=${#left_clean}
    local right_len=${#right_clean}
    
    # Calcola spazi necessari
    # total_width - 2 (bordi) - 2 (spazi interni) - left_len - right_len
    local spaces_needed=$((total_width - 4 - left_len - right_len))
    
    # Crea gli spazi
    local spaces=$(printf '%*s' "$spaces_needed" '')
    
    # Stampa la riga
    echo -e "${WHITE}│  ${left}${spaces}${right} │${NC}"
}

# Export fonctions
export -f encrypt_string
export -f decrypt_string
export -f pause_any_key
export -f log_action
export -f create_app_structure
export -f show_app_info
export -f get_debian_version
export -f get_distribution_info
export -f check_permissions
export -f visible_length
export -f format_menu_row
