#!/bin/bash

# TU Admin - Script d'administration système avec TU TOOLS
# Version: 2.1
# Description: Interface d'administration système avec gestion base de données

# Configuration des couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration des fichiers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/tu_admin.log"
CONFIG_FILE="$SCRIPT_DIR/tu_admin.conf"
LOGO_FILE="$SCRIPT_DIR/logo.txt"
DB_CREDENTIALS_FILE="$SCRIPT_DIR/.db_credentials"
TU_APP_PATH_FILE="$SCRIPT_DIR/.tu_app_path"

# Variables globales pour DB

# Definire le directory mancanti
APP_DIR="$SCRIPT_DIR"
BACKUP_DIR="$SCRIPT_DIR/backups"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
TOOLS_DIR="$SCRIPT_DIR/tools"
MYSQLTUNER_DIR="$SCRIPT_DIR/MySQLTuner"
DB_HOST=""
DB_DATABASE=""
DB_USER=""
DB_PASSWORD=""

# Variable globale pour le chemin de l'application TU
TU_APP_PATH=""

# Fonction per crittografia semplificata (Base64 + XOR)
encrypt_string() {
    local input="$1"
    local key="TUADMIN2024"
    echo -n "$input" | base64 -w 0
}

# Fonction per decrittografia semplificata
decrypt_string() {
    local input="$1"
    echo -n "$input" | base64 -d 2>/dev/null || echo ""
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

pause_any_key() {
    local message="${1:-Appuyez sur Entrée pour continuer...}"
    read -p "$(echo -e ${GREEN}$message${NC})" dummy
}

# Fonction pour afficher le nouveau logo avec TU en blu et Admin en bianco
show_logo() {
    echo ""
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${BLUE}88888888888 888     888            ${WHITE}d8888      888               d8b         ${CYAN}│${NC}"
    echo -e "${CYAN}│${BLUE}    888     888     888           ${WHITE}d88888      888               Y8P         ${CYAN}│${NC}"
    echo -e "${CYAN}│${BLUE}    888     888     888          ${WHITE}d88P888      888                           ${CYAN}│${NC}"
    echo -e "${CYAN}│${BLUE}    888     888     888         ${WHITE}d88P 888  .d88888 88888b.d88b.  888 88888b. ${CYAN}│${NC}"
    echo -e "${CYAN}│${BLUE}    888     888     888        ${WHITE}d88P  888 d88\" 888 888 \"888 \"88b 888 888 \"88b${CYAN}│${NC}"
    echo -e "${CYAN}│${BLUE}    888     888     888       ${WHITE}d88P   888 888  888 888  888  888 888 888  888${CYAN}│${NC}"
    echo -e "${CYAN}│${BLUE}    888     Y88b. .d88P      ${WHITE}d8888888888 Y88b 888 888  888  888 888 888  888${CYAN}│${NC}"
    echo -e "${CYAN}│${BLUE}    888      \"Y88888P\"      ${WHITE}d88P     888  \"Y88888 888  888  888 888 888  888${CYAN}│${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────────────────────┘${NC}"
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
            local kernel_build=$(grep -o 'Debian [0-4][0-4]*\.[0-4][0-4]*\.[0-4][0-4]*-[0-4][0-4]*' /proc/version 2>/dev/null)
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
        version_info="${YELLOW}Distribution${NC} inconnue"
    fi

    echo "$version_info"
}

# Fonction pour afficher l'en-tête semplificato

# Fonction pour générer les informations ${YELLOW}Distribution${NC}
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
show_header() {
    clear
    show_logo
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${WHITE}                    ADMINISTRATION SYSTÈME                     ${NC}"
    echo -e "${CYAN}================================================================${NC}"

    local debian_version=$(get_debian_version)

    echo -e "${YELLOW}Utilisateur: $(whoami)${NC}"
    # ${YELLOW}Distribution${NC} avec la nouvelle fonction corrigée
    if command -v get_distribution_info >/dev/null 2>&1; then
        local distribution_info=$(get_distribution_info)
        echo -e "${YELLOW}${YELLOW}Distribution${NC}: ${YELLOW} ${YELLOW}$(echo "$distribution_info" | sed 's/${YELLOW}Distribution${NC}: //g')${NC}"
    else
        # Fallback avec génération directe
        if [[ -f /etc/os-release ]]; then
            local debian_version=$(grep "^VERSION=" /etc/os-release | cut -d'"' -f2 | cut -d' ' -f1)
            local version_codename=$(grep "^VERSION_CODENAME=" /etc/os-release | cut -d'=' -f2)
            if [[ -z "$debian_version" ]]; then
                debian_version=$(grep "^VERSION_ID=" /etc/os-release | cut -d'"' -f2)
            fi
            local kernel_version=$(uname -r)
            if [[ -n "$debian_version" && -n "$version_codename" ]]; then
                echo -e "${YELLOW}${YELLOW}Distribution${NC}: ${YELLOW} ${YELLOW} Debian GNU/Linux ${debian_version} (${version_codename}) - Kernel: ${kernel_version}${NC}"
            else
                echo -e "${YELLOW}${YELLOW}Distribution${NC}: ${YELLOW} ${YELLOW} $(lsb_release -d 2>/dev/null | cut -f2 || echo "Linux") - Kernel: ${kernel_version}${NC}"
            fi
        else
            echo -e "${WHITE}Système: Linux $(uname -r)${NC}"
        fi
    fi
    echo -e "${YELLOW}Système: $(uname -sr)${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo ""
}

# Fonction de logging
log_action() {
    local action="$1"
    local status="$2"
    local details="$3"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$status] $action - $details" >> "$LOG_FILE"
}

# Fonction pour sauvegarder les credentials
save_db_credentials() {
    local host="$1"
    local database="$2"
    local user="$3"
    local password="$4"

    {
        echo "HOST=$(encrypt_string "$host")"
        echo "DATABASE=$(encrypt_string "$database")"
        echo "USER=$(encrypt_string "$user")"
        echo "PASSWORD=$(encrypt_string "$password")"
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
            return 0
        fi
    fi
    return 1
}

# Fonction pour sauvegarder le percorso dell'applicazione TU
save_tu_app_path() {
    local app_path="$1"
    echo "TU_APP_PATH=$(encrypt_string "$app_path")" > "$TU_APP_PATH_FILE"
    chmod 600 "$TU_APP_PATH_FILE"
    echo -e "${GREEN}✅ Percorso applicazione TU salvato con successo!${NC}"
}

# Fonction pour charger le percorso dell'applicazione TU
load_tu_app_path() {
    if [[ -f "$TU_APP_PATH_FILE" ]]; then
        source "$TU_APP_PATH_FILE"
        if [[ -n "$TU_APP_PATH" ]]; then
            TU_APP_PATH=$(decrypt_string "$TU_APP_PATH")
            return 0
        fi
    fi
    return 1
}

# Fonction pour configurer le percorso dell'applicazione TU
# Fonction pour configurer le percorso dell'applicazione TU
configure_tu_app_path() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}        CONFIGURATION CHEMIN APPLICATION TU               ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Indiquez le chemin vers votre application TU${NC}"
    echo -e "${CYAN}Exemple: /var/www/html/tu-app${NC}"
    echo -e "${CYAN}Exemple: /home/user/projects/tu-application${NC}"
    echo ""

    # Proposer quelques chemins courants
    echo -e "${BLUE}Chemins suggérés:${NC}"
    echo -e "${WHITE}1.${NC} /var/www/html/"
    echo -e "${WHITE}2.${NC} /home/www/"
    echo -e "${WHITE}3.${NC} Chemin personnalisé"
    echo ""

    read -p "$(echo -e ${CYAN}Sélectionnez une option [1-3] ou tapez le chemin directement: ${NC})" path_choice

    case "$path_choice" in
        1)
            app_path="/var/www/html/"
            ;;
        2)
            app_path="/home/www/"
            ;;
        3)
            read -p "$(echo -e ${CYAN}Chemin personnalisé: ${NC})" app_path
            ;;
        *)
            # Si l'utilisateur tape directement un chemin
            app_path="$path_choice"
            ;;
    esac

    # Vérifier que le chemin n'est pas vide
    if [[ -z "$app_path" ]]; then
        echo -e "${RED}❌ Le chemin ne peut pas être vide!${NC}"
        sleep 2
        return 1
    fi

    # Nettoyer le chemin (supprimer les / en fin)
    app_path="${app_path%/}"

    echo ""
    echo -e "${YELLOW}Chemin sélectionné: ${app_path}${NC}"
    echo ""

    # Vérifier si le répertoire existe
    if [[ -d "$app_path" ]]; then
        echo -e "${GREEN}✅ Répertoire trouvé${NC}"

        # Vérifier s'il y a des fichiers PHP ou des indices d'une application web
        local php_files=$(find "$app_path" -name "*.php" -type f 2>/dev/null | wc -l)
        local js_files=$(find "$app_path" -name "*.js" -type f 2>/dev/null | wc -l)
        local html_files=$(find "$app_path" -name "*.html" -type f 2>/dev/null | wc -l)

        if [[ $php_files -gt 0 || $js_files -gt 0 || $html_files -gt 0 ]]; then
            echo -e "${GREEN}✅ Application détectée (PHP: $php_files, JS: $js_files, HTML: $html_files)${NC}"
        else
            echo -e "${YELLOW}⚠️  Aucun fichier d'application détecté${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Répertoire non existant${NC}"
        read -p "$(echo -e ${CYAN}Créer le répertoire? [O/n]: ${NC})" create_dir

        if [[ ! "$create_dir" =~ ^[Nn]$ ]]; then
            if mkdir -p "$app_path" 2>/dev/null; then
                echo -e "${GREEN}✅ Répertoire créé${NC}"
            else
                echo -e "${RED}❌ Impossible de créer le répertoire${NC}"
                echo -e "${YELLOW}Vérifiez les permissions${NC}"
                sleep 3
                return 1
            fi
        else
            echo -e "${YELLOW}⚠️  Configuration sans création du répertoire${NC}"
        fi
    fi

    echo ""
    read -p "$(echo -e ${CYAN}Confirmer ce chemin? [O/n]: ${NC})" confirm

    if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
        save_tu_app_path "$app_path"
        TU_APP_PATH="$app_path"
        log_action "Configuration chemin TU App" "INFO" "Chemin: $app_path"
        sleep 2
        return 0
    else
        echo -e "${RED}❌ Configuration annulée${NC}"
        sleep 2
        return 1
    fi
}

# Fonction pour lire les paramètres DB depuis define.xml.php
read_db_from_define_xml() {
    local define_file="$TU_APP_PATH/src/terminal/var/define.xml.php"

    if [[ ! -f "$define_file" ]]; then
        echo -e "${RED}❌ Fichier define.xml.php non trouvé!${NC}"
        echo -e "${YELLOW}Chemin attendu: $define_file${NC}"
        return 1
    fi

    echo -e "${CYAN}Lecture du fichier define.xml.php...${NC}"

    # Extraire les valeurs des tags XML
    local mysqlhost=$(grep -oP '<mysqlhost>\K[^<]*' "$define_file" 2>/dev/null)
    local mysqluser=$(grep -oP '<mysqluser>\K[^<]*' "$define_file" 2>/dev/null)
    local mysqlpass=$(grep -oP '<mysqlpass>\K[^<]*' "$define_file" 2>/dev/null)
    local basegts=$(grep -oP '<basegts>\K[^<]*' "$define_file" 2>/dev/null)

    # Vérifier que tous les paramètres ont été trouvés
    if [[ -z "$mysqlhost" || -z "$mysqluser" || -z "$mysqlpass" || -z "$basegts" ]]; then
        echo -e "${RED}❌ Impossible de lire tous les paramètres du fichier!${NC}"
        echo -e "${YELLOW}Paramètres trouvés:${NC}"
        echo -e "${YELLOW}  Host: ${mysqlhost:-'NON TROUVÉ'}${NC}"
        echo -e "${YELLOW}  User: ${mysqluser:-'NON TROUVÉ'}${NC}"
        echo -e "${YELLOW}  Pass: ${mysqlpass:+'***'}${mysqlpass:-'NON TROUVÉ'}${NC}"
        echo -e "${YELLOW}  Base: ${basegts:-'NON TROUVÉ'}${NC}"
        return 1
    fi

    echo -e "${GREEN}✅ Paramètres extraits avec succès:${NC}"
    echo -e "${YELLOW}  Host: ${mysqlhost}${NC}"
    echo -e "${YELLOW}  User: ${mysqluser}${NC}"
    echo -e "${YELLOW}  Pass: ***${NC}"
    echo -e "${YELLOW}  Base: ${basegts}${NC}"
    echo ""

    # Test de connexion
    echo -e "${YELLOW}Test de connexion...${NC}"
    if command -v mysql &> /dev/null; then
        if mysql -h "$mysqlhost" -u "$mysqluser" -p"$mysqlpass" -e "USE $basegts;" 2>/dev/null; then
            echo -e "${GREEN}✅ Connexion réussie!${NC}"
        else
            echo -e "${RED}❌ Erreur de connexion avec les paramètres du fichier!${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  MySQL client non trouvé, impossible de tester${NC}"
    fi

    # Sauvegarder les credentials
    save_db_credentials "$mysqlhost" "$basegts" "$mysqluser" "$mysqlpass"
    return 0
}

# Fonction pour configurer la base de données
configure_database() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}           CONFIGURATION BASE DE DONNÉES                   ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Configuration de la connexion à la base de données MySQL/MariaDB${NC}"
    echo ""

    # Proposer de lire depuis define.xml.php si l'app TU est configurée
    if [[ -n "$TU_APP_PATH" && -f "$TU_APP_PATH/src/terminal/var/define.xml.php" ]]; then
        echo -e "${BLUE}Options de configuration:${NC}"
        echo -e "${WHITE}1.${NC} Lire depuis define.xml.php (recommandé)"
        echo -e "${WHITE}2.${NC} Configuration manuelle"
        echo ""

        read -p "$(echo -e ${CYAN}Sélectionnez une option [1-2]: ${NC})" config_choice

        case "$config_choice" in
            1)
                if read_db_from_define_xml; then
                    sleep 2
                    return 0
                else
                    echo -e "${YELLOW}Échec de la lecture automatique, passage en mode manuel...${NC}"
                    sleep 2
                fi
                ;;
            2)
                echo -e "${YELLOW}Mode manuel sélectionné${NC}"
                ;;
            *)
                echo -e "${YELLOW}Option invalide, passage en mode manuel...${NC}"
                ;;
        esac
        echo ""
    fi

    # Configuration manuelle
    echo -e "${CYAN}═══ CONFIGURATION MANUELLE ═══${NC}"
    read -p "$(echo -e ${CYAN}Hôte: ${NC})" db_host
    read -p "$(echo -e ${CYAN}Nom de la base de données: ${NC})" db_name
    read -p "$(echo -e ${CYAN}Utilisateur: ${NC})" db_user
    read -s -p "$(echo -e ${CYAN}Mot de passe: ${NC})" db_password
    echo ""
    echo ""

    if [[ -z "$db_host" || -z "$db_name" || -z "$db_user" || -z "$db_password" ]]; then
        echo -e "${RED}❌ Tous les champs sont obligatoires!${NC}"
        sleep 3
        return 1
    fi

    echo -e "${YELLOW}Test de connexion...${NC}"
    if command -v mysql &> /dev/null; then
        if mysql -h "$db_host" -u "$db_user" -p"$db_password" -e "USE $db_name;" 2>/dev/null; then
            echo -e "${GREEN}✅ Connexion réussie!${NC}"
        else
            echo -e "${YELLOW}⚠️  Impossible de tester la connexion${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  MySQL client non trouvé${NC}"
    fi

    save_db_credentials "$db_host" "$db_name" "$db_user" "$db_password"
    sleep 2
    return 0
}

# Fonction pour vérifier la configuration DB
check_database_configuration() {
    # Se i credentials sono già caricati, va bene
    if load_db_credentials; then
        return 0
    fi

    # Se non ci sono credentials, proviamo a leggere da define.xml.php se l'app TU è configurata
    if [[ -n "$TU_APP_PATH" && -f "$TU_APP_PATH/src/terminal/var/define.xml.php" ]]; then
        echo -e "${CYAN}Tentativo di lettura automatica dei paramètres DB depuis define.xml.php...${NC}"
        if read_db_from_define_xml; then
            # Ricaricare i credentials appena salvati
            load_db_credentials
            return 0
        fi
    fi

    # Se tutto fallisce, chiediamo la configurazione manuale
    echo -e "${YELLOW}⚠️  Configuration base de données requise!${NC}"
    read -p "$(echo -e ${CYAN}Configurer maintenant? [O/n]: ${NC})" configure_now

    if [[ ! "$configure_now" =~ ^[Nn]$ ]]; then
        configure_database
        return $?
    else
        echo -e "${RED}❌ Configuration annulée${NC}"
        sleep 2
        return 1
    fi
}

# Fonction pour afficher le menu principal
show_main_menu() {
   clear
   show_header
   echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
   echo -e "${WHITE}│                      MENU PRINCIPAL                         │${NC}"
   echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
   echo -e "${WHITE}│  ${PURPLE}1. TU TOOLS     ${WHITE}│ Gestion base de données et maintenance   │${NC}"
   echo -e "${WHITE}│  ${CYAN}2. Système      ${WHITE}│ Informations système et performance      │${NC}"
   echo -e "${WHITE}│  ${CYAN}3. Réseau       ${WHITE}│ Configuration et outils réseau           │${NC}"
   echo -e "${WHITE}│  ${CYAN}4. Logs         ${WHITE}│ Consultation des logs système            │${NC}"
   echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
   echo -e "${WHITE}│  ${RED}0. Quitter      ${WHITE}│ Sortir de l'application                  │${NC}"
   echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
   echo ""
}

# Fonctions pour TU TOOLS


# Fonction pour tester la connexion à la base de données
test_db_connection() {
    show_header
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                    TEST CONNEXION BASE                      │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        if [[ -n "$DB_DATABASE" && -n "$DB_HOST" ]]; then
            echo -e "${WHITE}│  ${GREEN}Base: ${DB_DATABASE}@${DB_HOST}${WHITE}                                   │${NC}"
            local db_total_size=$(get_database_total_size)
            echo -e "${WHITE}│  ${BLUE}Taille de la base: ${db_total_size}${WHITE}                               │${NC}"
            echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        fi
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    
    if [[ -z "$DB_HOST" || -z "$DB_USER" || -z "$DB_PASSWORD" || -z "$DB_DATABASE" ]]; then
        echo -e "${RED}❌ Paramètres de connexion non configurés${NC}"
        echo -e "${YELLOW}Utilisez l'option 7 pour configurer la base de données${NC}"
        pause_any_key
        return 1
    fi
    
    echo -e "${CYAN}Test de connexion vers:${NC}"
    echo -e "${WHITE}  Host: ${YELLOW}$DB_HOST${NC}"
    echo -e "${WHITE}  Database: ${YELLOW}$DB_DATABASE${NC}"
    echo -e "${WHITE}  User: ${YELLOW}$DB_USER${NC}"
    echo ""
    
    if ! command -v mysql &> /dev/null; then
        echo -e "${RED}❌ Client MySQL non installé${NC}"
        pause_any_key
        return 1
    fi
    
    echo -e "${CYAN}Connexion en cours...${NC}"
    
    if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1;" "$DB_DATABASE" 2>/dev/null; then
        echo -e "${GREEN}✅ Connexion réussie!${NC}"
        
        # Informations supplémentaires
        echo ""
        echo -e "${CYAN}Informations sur la base:${NC}"
        local version=$(mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -sN -e "SELECT VERSION();" 2>/dev/null)
        if [[ -n "$version" ]]; then
            echo -e "${WHITE}  Version MySQL: ${GREEN}$version${NC}"
        fi
        
        local tables_count=$(mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -sN -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$DB_DATABASE';" 2>/dev/null)
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

# Fonction pour tester la connexion DB silencieusement (sans affichage)
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
show_db_status() {
    show_header
    echo -e "${WHITE}ÉTAT BASE DE DONNÉES${NC}"
    echo ""

    if command -v mysql &> /dev/null; then
        mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "
            SELECT '$DB_DATABASE' as 'Base', VERSION() as 'Version';
            SELECT COUNT(*) as 'Tables' FROM information_schema.tables WHERE table_schema = '$DB_DATABASE';
        " 2>/dev/null || echo -e "${RED}❌ Erreur de connexion${NC}"
    else
        echo -e "${RED}❌ MySQL client non installé${NC}"
    fi

    pause_any_key
}

execute_sql_query() {
    show_header
    echo -e "${WHITE}EXÉCUTER REQUÊTE SQL${NC}"
    echo ""

    read -p "$(echo -e ${CYAN}Requête SQL: ${NC})" sql_query

    if [[ -n "$sql_query" ]]; then
        mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "$sql_query" "$DB_DATABASE" 2>/dev/null || {
            echo -e "${RED}❌ Erreur dans la requête${NC}"
        }
    fi

    pause_any_key
}

backup_database() {
    show_header
    echo -e "${WHITE}SAUVEGARDE BASE DE DONNÉES${NC}"
    echo ""

    local backup_file="backup_${DB_DATABASE}_$(date +%Y%m%d_%H%M%S).sql"

    if command -v mysqldump &> /dev/null; then
        if mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_DATABASE" > "$backup_file" 2>/dev/null; then
            echo -e "${GREEN}✅ Sauvegarde créée: $backup_file${NC}"
        else
            echo -e "${RED}❌ Erreur lors de la sauvegarde${NC}"
        fi
    else
        echo -e "${RED}❌ mysqldump non installé${NC}"
    fi

    pause_any_key
}

restore_database() {
    show_header
    echo -e "${WHITE}RESTAURATION BASE DE DONNÉES${NC}"
    echo ""

    echo -e "${YELLOW}Fichiers disponibles:${NC}"
    ls -lh backup_*.sql 2>/dev/null || echo "Aucun backup trouvé"
    echo ""

    read -p "$(echo -e ${CYAN}Fichier à restaurer: ${NC})" backup_file

    if [[ -f "$backup_file" ]]; then
        echo -e "${RED}⚠️  Cette opération va écraser la base!${NC}"
        read -p "$(echo -e ${YELLOW}Continuer? [o/N]: ${NC})" confirm

        if [[ "$confirm" =~ ^[Oo]$ ]]; then
            mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_DATABASE" < "$backup_file" 2>/dev/null && {
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

optimize_tables() {
    show_header
    echo -e "${WHITE}OPTIMISATION DES TABLES${NC}"
    echo ""

    if command -v mysql &> /dev/null; then
        mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "
            SELECT CONCAT('OPTIMIZE TABLE ', table_name, ';') as cmd
            FROM information_schema.tables
            WHERE table_schema = '$DB_DATABASE';
        " -N 2>/dev/null | while read cmd; do
            mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "$cmd" "$DB_DATABASE" 2>/dev/null
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
            echo -e "${WHITE}│  ${GREEN}Base: ${DB_DATABASE}@${DB_HOST}${WHITE}                                   │${NC}"
            local db_total_size=$(get_database_total_size)
            echo -e "${WHITE}│  ${BLUE}Taille de la base: ${db_total_size}${WHITE}                               │${NC}"
            echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        fi
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    local mysqltuner_dir="$SCRIPT_DIR/MySQLTuner"
    local mysqltuner_script="$mysqltuner_dir/mysqltuner.pl"

    # Vérifier si le répertoire MySQLTuner existe
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

    # Vérifier si le script mysqltuner.pl existe
    if [[ ! -f "$mysqltuner_script" ]]; then
        echo -e "${RED}❌ Script mysqltuner.pl non trouvé!${NC}"
        echo -e "${YELLOW}Fichier attendu: $mysqltuner_script${NC}"
        pause_any_key
        return
    fi

    # Vérifier si perl est installé
    if ! command -v perl &> /dev/null; then
        echo -e "${RED}❌ Perl non installé!${NC}"
        echo -e "${YELLOW}Installez Perl: sudo apt install perl${NC}"
        pause_any_key
        return
    fi

    # Vérifier les permissions d'exécution
    if [[ ! -x "$mysqltuner_script" ]]; then
        echo -e "${YELLOW}⚠️  Script non exécutable, application des permissions...${NC}"
        chmod +x "$mysqltuner_script"
    fi

    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}              ANALYSE MYSQL AVEC MYSQLTUNER                ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Serveur: ${DB_HOST}${NC}"
    echo -e "${YELLOW}Base de données: ${DB_DATABASE}${NC}"
    echo -e "${YELLOW}Utilisateur: ${DB_USER}${NC}"
    echo ""
    echo -e "${GREEN}Lancement de MySQLTuner...${NC}"
    echo ""

    # Exécuter MySQLTuner avec les credentials
    cd "$mysqltuner_dir"

    # Préparer les options pour MySQLTuner
    local mysqltuner_options=""
    if [[ "$DB_HOST" != "localhost" && "$DB_HOST" != "127.0.0.1" ]]; then
        mysqltuner_options="--host $DB_HOST"
    fi

    # Exécuter MySQLTuner
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

    # Retourner au répertoire d'origine
    cd "$SCRIPT_DIR"

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}              ANALYSE MYSQLTUNER TERMINÉE                   ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    log_action "Exécution MySQLTuner" "INFO" "Host: $DB_HOST, User: $DB_USER"

    pause_any_key
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

# Fonction pour consulter les logs de l'application TU
show_tu_logs() {
    show_header
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                    CONSULTATION LOGS TU                     │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        if [[ -n "$DB_DATABASE" && -n "$DB_HOST" ]]; then
            echo -e "${WHITE}│  ${GREEN}Base: ${DB_DATABASE}@${DB_HOST}${WHITE}                                   │${NC}"
            local db_total_size=$(get_database_total_size)
            echo -e "${WHITE}│  ${BLUE}Taille de la base: ${db_total_size}${WHITE}                               │${NC}"
            echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        fi
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    local log_file="$TU_APP_PATH/src/terminal/var/log/php.log"

    if [[ ! -f "$log_file" ]]; then
        echo -e "${RED}❌ Fichier de log non trouvé!${NC}"
        echo -e "${YELLOW}Chemin attendu: $log_file${NC}"
        echo ""
        echo -e "${CYAN}Vérifiez que:${NC}"
        echo -e "${WHITE}  • L'application TU est correctement installée${NC}"
        echo -e "${WHITE}  • Le répertoire des logs existe${NC}"
        echo -e "${WHITE}  • Les logs sont activés dans l'application${NC}"
        pause_any_key
        return
    fi

    if [[ ! -r "$log_file" ]]; then
        echo -e "${RED}❌ Impossible de lire le fichier de log!${NC}"
        echo -e "${YELLOW}Permissions insuffisantes pour: $log_file${NC}"
        echo -e "${CYAN}Essayez: sudo chmod 644 $log_file${NC}"
        pause_any_key
        return
    fi

    local file_size=$(du -h "$log_file" | cut -f1)
    local line_count=$(wc -l < "$log_file" 2>/dev/null || echo "0")
    local last_modified=$(stat -c %y "$log_file" 2>/dev/null | cut -d'.' -f1 || echo "Inconnu")

    echo -e "${CYAN}═══ INFORMATIONS FICHIER ═══${NC}"
    echo -e "${YELLOW}Fichier: ${log_file}${NC}"
    echo -e "${YELLOW}Taille: ${file_size}${NC}"
    echo -e "${YELLOW}Lignes: ${line_count}${NC}"
    echo -e "${YELLOW}Dernière modification: ${last_modified}${NC}"
    echo ""

    while true; do
        echo -e "${BLUE}Options d'affichage:${NC}"
        echo -e "${WHITE}1.${NC} Afficher les 20 dernières lignes"
        echo -e "${WHITE}2.${NC} Afficher les 50 dernières lignes"
        echo -e "${WHITE}3.${NC} Afficher les 100 dernières lignes"
        echo -e "${WHITE}4.${NC} Afficher tout le fichier"
        echo -e "${WHITE}5.${NC} Rechercher dans les logs"
        echo -e "${WHITE}6.${NC} Surveiller en temps réel"
        echo -e "${WHITE}7.${NC} Vider le fichier de log"
        echo -e "${WHITE}0.${NC} Retour"
        echo ""

        read -p "$(echo -e ${CYAN}Sélectionnez une option [0-7]: ${NC})" log_choice

        case "$log_choice" in
            1)
                echo -e "${GREEN}═══ 20 DERNIÈRES LIGNES ═══${NC}"
                tail -n 20 "$log_file" | while IFS= read -r line; do
                    if [[ "$line" =~ \[ERROR\] ]] || [[ "$line" =~ \[FATAL\] ]]; then
                        echo -e "${RED}$line${NC}"
                    elif [[ "$line" =~ \[WARNING\] ]] || [[ "$line" =~ \[WARN\] ]]; then
                        echo -e "${YELLOW}$line${NC}"
                    elif [[ "$line" =~ \[INFO\] ]]; then
                        echo -e "${GREEN}$line${NC}"
                    elif [[ "$line" =~ \[DEBUG\] ]]; then
                        echo -e "${CYAN}$line${NC}"
                    else
                        echo "$line"
                    fi
                done
                echo ""
                pause_any_key
                ;;
            2)
                echo -e "${GREEN}═══ 50 DERNIÈRES LIGNES ═══${NC}"
                tail -n 50 "$log_file" | while IFS= read -r line; do
                    if [[ "$line" =~ \[ERROR\] ]] || [[ "$line" =~ \[FATAL\] ]]; then
                        echo -e "${RED}$line${NC}"
                    elif [[ "$line" =~ \[WARNING\] ]] || [[ "$line" =~ \[WARN\] ]]; then
                        echo -e "${YELLOW}$line${NC}"
                    elif [[ "$line" =~ \[INFO\] ]]; then
                        echo -e "${GREEN}$line${NC}"
                    elif [[ "$line" =~ \[DEBUG\] ]]; then
                        echo -e "${CYAN}$line${NC}"
                    else
                        echo "$line"
                    fi
                done
                echo ""
                pause_any_key
                ;;
            3)
                echo -e "${GREEN}═══ 100 DERNIÈRES LIGNES ═══${NC}"
                tail -n 100 "$log_file" | while IFS= read -r line; do
                    if [[ "$line" =~ \[ERROR\] ]] || [[ "$line" =~ \[FATAL\] ]]; then
                        echo -e "${RED}$line${NC}"
                    elif [[ "$line" =~ \[WARNING\] ]] || [[ "$line" =~ \[WARN\] ]]; then
                        echo -e "${YELLOW}$line${NC}"
                    elif [[ "$line" =~ \[INFO\] ]]; then
                        echo -e "${GREEN}$line${NC}"
                    elif [[ "$line" =~ \[DEBUG\] ]]; then
                        echo -e "${CYAN}$line${NC}"
                    else
                        echo "$line"
                    fi
                done
                echo ""
                pause_any_key
                ;;
            4)
                echo -e "${GREEN}═══ FICHIER COMPLET ═══${NC}"
                echo -e "${YELLOW}⚠️  Fichier de ${line_count} lignes${NC}"
                echo -e "${CYAN}Confirmer l'affichage complet? [o/N]: ${NC}"
                read confirm
                if [[ "$confirm" =~ ^[Oo]$ ]]; then
                    cat "$log_file" | while IFS= read -r line; do
                        if [[ "$line" =~ \[ERROR\] ]] || [[ "$line" =~ \[FATAL\] ]]; then
                            echo -e "${RED}$line${NC}"
                        elif [[ "$line" =~ \[WARNING\] ]] || [[ "$line" =~ \[WARN\] ]]; then
                            echo -e "${YELLOW}$line${NC}"
                        elif [[ "$line" =~ \[INFO\] ]]; then
                            echo -e "${GREEN}$line${NC}"
                        elif [[ "$line" =~ \[DEBUG\] ]]; then
                            echo -e "${CYAN}$line${NC}"
                        else
                            echo "$line"
                        fi
                    done | less -R
                fi
                ;;
            5)
                echo -e "${CYAN}Terme à rechercher: ${NC}"
                read search_term
                if [[ -n "$search_term" ]]; then
                    echo -e "${GREEN}═══ RÉSULTATS RECHERCHE: '$search_term' ═══${NC}"
                    grep -i --color=always "$search_term" "$log_file" || echo -e "${YELLOW}Aucun résultat trouvé${NC}"
                    echo ""
                    pause_any_key
                fi
                ;;
            6)
                echo -e "${GREEN}═══ SURVEILLANCE TEMPS RÉEL ═══${NC}"
                echo -e "${YELLOW}Appuyez sur Ctrl+C pour arrêter${NC}"
                echo ""
                tail -f "$log_file" | while IFS= read -r line; do
                    if [[ "$line" =~ \[ERROR\] ]] || [[ "$line" =~ \[FATAL\] ]]; then
                        echo -e "${RED}$line${NC}"
                    elif [[ "$line" =~ \[WARNING\] ]] || [[ "$line" =~ \[WARN\] ]]; then
                        echo -e "${YELLOW}$line${NC}"
                    elif [[ "$line" =~ \[INFO\] ]]; then
                        echo -e "${GREEN}$line${NC}"
                    elif [[ "$line" =~ \[DEBUG\] ]]; then
                        echo -e "${CYAN}$line${NC}"
                    else
                        echo "$line"
                    fi
                done
                ;;
            7)
                echo -e "${RED}⚠️  ATTENTION: Cette opération va vider complètement le fichier de log!${NC}"
                echo -e "${YELLOW}Confirmer la suppression? [o/N]: ${NC}"
                read confirm_clear
                if [[ "$confirm_clear" =~ ^[Oo]$ ]]; then
                    if > "$log_file" 2>/dev/null; then
                        echo -e "${GREEN}✅ Fichier de log vidé avec succès${NC}"
                        log_action "Vidage log TU" "INFO" "Fichier: $log_file"
                    else
                        echo -e "${RED}❌ Erreur lors du vidage du fichier${NC}"
                        echo -e "${YELLOW}Permissions insuffisantes ou fichier protégé${NC}"
                    fi
                    sleep 2
                fi
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
            mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "OPTIMIZE TABLE patients_editions;" "$DB_DATABASE" 2>/dev/null && {
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

# Fonction pour le menu Opérations Sensibles

# Fonction pour calculer l'espace de la table

# Fonction pour purger les logs

# Fonction pour calculer l'espace de la table

# Fonction de debug pour tester les tables

# Fonction de debug pour tester les tables

# Fonction pour calculer l'espace de la table
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
    
    # Query identique à list_large_tables
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
    if [[ "$table_info" != "N/A" ]]; then
        local size_mb=$(echo "$table_info" | awk '{print $1" "$2}')
        echo -e "${GREEN}   Espace qui sera libéré: $size_mb MB${NC}"
    fi
    echo -e "${YELLOW}   Tous les logs seront définitivement supprimés${NC}"
    echo -e "${GREEN}   Espace qui sera libéré: $size_mb MB${NC}"
    echo ""
    
    read -p "$(echo -e ${RED}Êtes-vous sûr de vouloir vider la table logs? [oui/NON]: ${NC})" confirm
    
    if [[ "$confirm" == "oui" ]]; then
        echo ""
        echo -e "${CYAN}Purge de la table 'logs' en cours...${NC}"
        
        if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "TRUNCATE TABLE logs;" "$DB_DATABASE" 2>/dev/null; then
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

# Fonction pour purger les messages patients
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
        
        if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "TRUNCATE TABLE patients_messages;" "$DB_DATABASE" 2>/dev/null; then
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
            9) 
                echo -e "${CYAN}Sélectionnez la table à analyser:${NC}"
                echo -e "${WHITE}1.${NC} logs"
                echo -e "${WHITE}2.${NC} patients_messages"
                echo -e "${WHITE}3.${NC} Autre (saisir nom)"
                read -p "$(echo -e ${CYAN}Choix [1-3]: ${NC})" debug_choice
                case "$debug_choice" in
                    1) debug_table_info "logs" ;;
                    2) debug_table_info "patients_messages" ;;
                    3) 
                        read -p "$(echo -e ${CYAN}Nom de la table: ${NC})" custom_table
                        debug_table_info "$custom_table"
                        ;;
                    *) echo -e "${RED}Choix invalide${NC}"; sleep 1 ;;
                esac
                ;;
            9) 
                echo -e "${CYAN}Sélectionnez la table à analyser:${NC}"
                echo -e "${WHITE}1.${NC} logs"
                echo -e "${WHITE}2.${NC} patients_messages"
                echo -e "${WHITE}3.${NC} Autre (saisir nom)"
                read -p "$(echo -e ${CYAN}Choix [1-3]: ${NC})" debug_choice
                case "$debug_choice" in
                    1) debug_table_info "logs" ;;
                    2) debug_table_info "patients_messages" ;;
                    3) 
                        read -p "$(echo -e ${CYAN}Nom de la table: ${NC})" custom_table
                        debug_table_info "$custom_table"
                        ;;
                    *) echo -e "${RED}Choix invalide${NC}"; sleep 1 ;;
                esac
                ;;
            9) menu_disk_problems ;;
            0) break ;;
            *)
                echo -e "${RED}Choix non valide${NC}"
                sleep 1
                ;;
        esac
    done
}

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
    
    read -p "$(echo -e ${CYAN}Choix [1-7]: ${NC})" dir_choice
    
    local search_path=""
    case "$dir_choice" in
        1) search_path="/var" ;;
        2) search_path="/home" ;;
        3) search_path="/tmp" ;;
        4) search_path="/usr" ;;
        5) search_path="/" ;;
        6)
            read -p "$(echo -e ${CYAN}Chemin personnalisé: ${NC})" search_path
            ;;
        7)
            if [[ -n "$TU_APP_PATH" ]]; then
                search_path="$TU_APP_PATH"
            else
                echo -e "${RED}❌ Chemin TU App non configuré${NC}"
                sleep 2
                return
            fi
            ;;
        *)
            echo -e "${RED}❌ Choix invalide${NC}"
            sleep 2
            return
            ;;
    esac
    
    if [[ ! -d "$search_path" ]]; then
        echo -e "${RED}❌ Répertoire non trouvé: $search_path${NC}"
        sleep 2
        return
    fi
    
    echo ""
    echo -e "${YELLOW}Analyse en cours de: $search_path${NC}"
    echo -e "${CYAN}(Cela peut prendre quelques minutes...)${NC}"
    echo ""
    
    # Chercher les 20 plus gros fichiers
    echo -e "${GREEN}═══ TOP 20 FICHIERS LES PLUS VOLUMINEUX ═══${NC}"
    echo -e "${CYAN}Taille    Fichier${NC}"
    echo -e "${CYAN}────────  ──────────────────────────────────────────${NC}"
    
    find "$search_path" -type f -exec du -h {} + 2>/dev/null | \
        sort -rh | head -20 | \
        while read size file; do
            if [[ "${size: -1}" == "G" ]]; then
                echo -e "${RED}$size	$file${NC}"
            elif [[ "${size: -1}" == "M" ]]; then
                local num=${size%M}
                if (( $(echo "$num > 100" | bc -l 2>/dev/null || echo 0) )); then
                    echo -e "${YELLOW}$size	$file${NC}"
                else
                    echo -e "${WHITE}$size	$file${NC}"
                fi
            else
                echo -e "${WHITE}$size	$file${NC}"
            fi
        done
    
    echo ""
    echo -e "${CYAN}Légende: ${RED}Rouge=GB${NC} ${YELLOW}Jaune=+100MB${NC} ${WHITE}Blanc=Autres${NC}"
    
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
    
    echo -e "${YELLOW}Analyse de la base: $DB_DATABASE@$DB_HOST${NC}"
    echo -e "${CYAN}Recherche des tables > 100MB...${NC}"
    echo ""
    
    # Requête pour obtenir la taille des tables
    local query="SELECT 
        table_name as `Table`,
        ROUND(((data_length + index_length) / 1024 / 1024), 2) as `Taille_MB`,
        ROUND((data_length / 1024 / 1024), 2) as `Données_MB`,
        ROUND((index_length / 1024 / 1024), 2) as `Index_MB`,
        table_rows as `Lignes`
    FROM information_schema.tables 
    WHERE table_schema = '$DB_DATABASE' 
        AND ((data_length + index_length) / 1024 / 1024) > 100 
    ORDER BY (data_length + index_length) DESC;"
    
    if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "$query" 2>/dev/null; then
        echo ""
        echo -e "${GREEN}═══ STATISTIQUES GLOBALES ═══${NC}"
        
        local total_query="SELECT 
            COUNT(*) as `Total_Tables`,
            ROUND(SUM((data_length + index_length) / 1024 / 1024), 2) as `Taille_Totale_MB`
        FROM information_schema.tables 
        WHERE table_schema = '$DB_DATABASE';"
        
        mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "$total_query" 2>/dev/null
        
        echo ""
        echo -e "${CYAN}Note: Seules les tables > 100MB sont affichées${NC}"
    else
        echo -e "${RED}❌ Erreur lors de la connexion à la base${NC}"
    fi
    
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
            echo -e "${WHITE}│  ${GREEN}Base: ${DB_DATABASE}@${DB_HOST}${WHITE}                                   │${NC}"
            local db_total_size=$(get_database_total_size)
            echo -e "${WHITE}│  ${BLUE}Taille de la base: ${db_total_size}${WHITE}                               │${NC}"
            echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        fi
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        if [[ -n "$TU_APP_PATH" ]]; then
            local disk_usage=$(get_disk_usage "$TU_APP_PATH")
            echo -e "${WHITE}│  ${CYAN}App TU: ${disk_usage}${WHITE}                                             │${NC}"
            echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        fi
        echo -e "${WHITE}│                      ANALYSE FICHIERS                      │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  1.${YELLOW} Fichiers volumineux    ${WHITE}│ Analyse des gros fichiers          │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│                    ANALYSE BASE DONNÉES                    │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  2.${YELLOW} Tables volumineuses    ${WHITE}│ Tables > 100MB dans la base        │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  0.${GREEN} Retour                ${WHITE}│ Menu TU TOOLS                       │${NC}"
        echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        echo ""
        
        read -p "$(echo -e ${CYAN}Sélectionnez une option [0-2]: ${NC})" choice
        
        case "$choice" in
            1) list_large_files ;;
            2) list_large_tables ;;
            9) menu_disk_problems ;;
            0) break ;;
            *)
                echo -e "${RED}Choix non valide${NC}"
                sleep 1
                ;;
        esac
    done
}


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
    
    read -p "$(echo -e ${CYAN}Choix [1-7]: ${NC})" dir_choice
    
    local search_path=""
    case "$dir_choice" in
        1) search_path="/var" ;;
        2) search_path="/home" ;;
        3) search_path="/tmp" ;;
        4) search_path="/usr" ;;
        5) search_path="/" ;;
        6)
            read -p "$(echo -e ${CYAN}Chemin personnalisé: ${NC})" search_path
            ;;
        7)
            if [[ -n "$TU_APP_PATH" ]]; then
                search_path="$TU_APP_PATH"
            else
                echo -e "${RED}❌ Chemin TU App non configuré${NC}"
                sleep 2
                return
            fi
            ;;
        *)
            echo -e "${RED}❌ Choix invalide${NC}"
            sleep 2
            return
            ;;
    esac
    
    if [[ ! -d "$search_path" ]]; then
        echo -e "${RED}❌ Répertoire non trouvé: $search_path${NC}"
        sleep 2
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
            echo -e "${WHITE}│  ${GREEN}Base: ${DB_DATABASE}@${DB_HOST}${WHITE}                                   │${NC}"
            local db_total_size=$(get_database_total_size)
            echo -e "${WHITE}│  ${BLUE}Taille de la base: ${db_total_size}${WHITE}                               │${NC}"
            echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        fi
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        if [[ -n "$TU_APP_PATH" ]]; then
            local disk_usage=$(get_disk_usage "$TU_APP_PATH")
            echo -e "${WHITE}│  ${CYAN}App TU: ${disk_usage}${WHITE}                                     │${NC}"
            echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        fi
        echo -e "${WHITE}│                      ANALYSE FICHIERS                       │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  1.${YELLOW} Fichiers volumineux    ${WHITE}│ Analyse des gros fichiers      │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│                    ANALYSE BASE DONNÉES                     │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  2.${YELLOW} Tables volumineuses    ${WHITE}│ Tables > 100MB dans la base    │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  0.${GREEN} Retour                 ${WHITE}│ Menu TU TOOLS                  │${NC}"
        echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        echo ""
        
        read -p "$(echo -e ${CYAN}Sélectionnez une option [0-2]: ${NC})" choice
        
        case "$choice" in
            1) list_large_files ;;
            2) list_large_tables ;;
            9) menu_disk_problems ;;
            0) break ;;
            *)
                echo -e "${RED}Choix non valide${NC}"
                sleep 1
                ;;
        esac
    done
}

# Fonction pour le menu TU TOOLS

# Fonctions sistema semplificato
show_system_info() {
    clear
    show_header
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                    INFORMATIONS SYSTÈME                       ${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${YELLOW}🔍 Collecte des informations système en cours...${NC}"
    echo ""
    
    # ════════════════════════════════════════════════════════════════
    # SYSTÈME D'EXPLOITATION ET DISTRIBUTION
    # ════════════════════════════════════════════════════════════════
    echo -e "${WHITE}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                  SYSTÈME D'EXPLOITATION                    │${NC}"
    echo -e "${WHITE}└────────────────────────────────────────────────────────────┘${NC}"
    
    # Distribution
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo -e "${CYAN}🐧 ${YELLOW}Distribution${NC}        : ${GREEN}$NAME $VERSION${NC}"
        echo -e "${CYAN}📋 ID Distribution      : ${WHITE}$ID${NC}"
        if [[ -n "$VERSION_CODENAME" ]]; then
            echo -e "${CYAN}🏷️  Nom de code         : ${PURPLE}$VERSION_CODENAME${NC}"
        fi
        if [[ -n "$PRETTY_NAME" ]]; then
            echo -e "${CYAN}✨ Nom complet          : ${BLUE}$PRETTY_NAME${NC}"
        fi
    else
        echo -e "${CYAN}🐧 ${YELLOW}Distribution${NC}        : ${RED}Non identifiée${NC}"
    fi
    
    # Kernel
    echo -e "${CYAN}🔧 Noyau               : ${GREEN}$(uname -r)${NC}"
    echo -e "${CYAN}⚙️  Architecture        : ${GREEN}$(uname -m)${NC}"
    
    # Uptime
    local uptime_info=$(uptime -p 2>/dev/null || uptime | awk '{print $3 " " $4}')
    echo -e "${CYAN}⏰ Temps de fonct.      : ${GREEN}$uptime_info${NC}"
    
    # Date et heure
    echo -e "${CYAN}📅 Date/Heure          : ${GREEN}$(date '+%d/%m/%Y %H:%M:%S %Z')${NC}"
    
    # Hostname
    echo -e "${CYAN}🌐 Nom d'hôte          : ${GREEN}$(hostname)${NC}"
    
    echo ""
    
    # ════════════════════════════════════════════════════════════════
    # PROCESSEUR
    # ════════════════════════════════════════════════════════════════
    echo -e "${WHITE}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                       PROCESSEUR                           │${NC}"
    echo -e "${WHITE}└────────────────────────────────────────────────────────────┘${NC}"
    
    if [[ -f /proc/cpuinfo ]]; then
        local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ *//')
        local cpu_cores=$(grep "^processor" /proc/cpuinfo | wc -l)
        local cpu_threads=$(grep "^processor" /proc/cpuinfo | wc -l)
        local cpu_physical=$(grep "physical id" /proc/cpuinfo | sort -u | wc -l)
        
        if [[ $cpu_physical -eq 0 ]]; then cpu_physical=1; fi
        
        echo -e "${CYAN}💻 Modèle               : ${GREEN}$cpu_model${NC}"
        echo -e "${CYAN}🔢 Cœurs physiques      : ${GREEN}$cpu_physical${NC}"
        echo -e "${CYAN}⚡ Threads totaux       : ${GREEN}$cpu_threads${NC}"
        
        # Fréquence CPU
        if [[ -f /proc/cpuinfo ]]; then
            local cpu_freq=$(grep "cpu MHz" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ *//' | cut -d. -f1)
            if [[ -n "$cpu_freq" ]]; then
                echo -e "${CYAN}🚀 Fréquence            : ${GREEN}${cpu_freq} MHz${NC}"
            fi
        fi
        
        # Cache CPU
        local cpu_cache=$(grep "cache size" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ *//')
        if [[ -n "$cpu_cache" ]]; then
            echo -e "${CYAN}💾 Cache L3             : ${GREEN}$cpu_cache${NC}"
        fi
    fi
    
    # Charge CPU actuelle
    if command -v top &> /dev/null; then
        local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        if [[ -n "$cpu_usage" ]]; then
            if (( $(echo "$cpu_usage > 80" | bc -l 2>/dev/null || echo 0) )); then
                echo -e "${CYAN}📊 Utilisation actuelle : ${RED}${cpu_usage}%${NC}"
            elif (( $(echo "$cpu_usage > 50" | bc -l 2>/dev/null || echo 0) )); then
                echo -e "${CYAN}📊 Utilisation actuelle : ${YELLOW}${cpu_usage}%${NC}"
            else
                echo -e "${CYAN}📊 Utilisation actuelle : ${GREEN}${cpu_usage}%${NC}"
            fi
        fi
    fi
    
    echo ""
    
    # ════════════════════════════════════════════════════════════════
    # MÉMOIRE
    # ════════════════════════════════════════════════════════════════
    echo -e "${WHITE}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                        MÉMOIRE                             │${NC}"
    echo -e "${WHITE}└────────────────────────────────────────────────────────────┘${NC}"
    
    if [[ -f /proc/meminfo ]]; then
        local mem_total=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
        local mem_available=$(grep "MemAvailable" /proc/meminfo | awk '{print $2}')
        local mem_free=$(grep "MemFree" /proc/meminfo | awk '{print $2}')
        local mem_used=$((mem_total - mem_available))
        local swap_total=$(grep "SwapTotal" /proc/meminfo | awk '{print $2}')
        local swap_free=$(grep "SwapFree" /proc/meminfo | awk '{print $2}')
        local swap_used=$((swap_total - swap_free))
        
        # Conversion en GB et MB
        local mem_total_gb=$((mem_total / 1024 / 1024))
        local mem_available_gb=$((mem_available / 1024 / 1024))
        local mem_used_gb=$((mem_used / 1024 / 1024))
        local swap_total_gb=$((swap_total / 1024 / 1024))
        local swap_used_gb=$((swap_used / 1024 / 1024))
        
        # Pourcentages
        local mem_usage_percent=$((mem_used * 100 / mem_total))
        local swap_usage_percent=0
        if [[ $swap_total -gt 0 ]]; then
            swap_usage_percent=$((swap_used * 100 / swap_total))
        fi
        
        echo -e "${CYAN}💾 RAM Totale           : ${GREEN}${mem_total_gb} GB${NC}"
        echo -e "${CYAN}✅ RAM Disponible       : ${GREEN}${mem_available_gb} GB${NC}"
        
        # Couleur selon l'utilisation
        if [[ $mem_usage_percent -gt 90 ]]; then
            echo -e "${CYAN}🔥 RAM Utilisée         : ${RED}${mem_used_gb} GB (${mem_usage_percent}%)${NC}"
        elif [[ $mem_usage_percent -gt 70 ]]; then
            echo -e "${CYAN}⚠️  RAM Utilisée         : ${YELLOW}${mem_used_gb} GB (${mem_usage_percent}%)${NC}"
        else
            echo -e "${CYAN}✅ RAM Utilisée         : ${GREEN}${mem_used_gb} GB (${mem_usage_percent}%)${NC}"
        fi
        
        # SWAP
        if [[ $swap_total -gt 0 ]]; then
            echo -e "${CYAN}💿 SWAP Total           : ${GREEN}${swap_total_gb} GB${NC}"
            if [[ $swap_usage_percent -gt 50 ]]; then
                echo -e "${CYAN}⚠️  SWAP Utilisé         : ${YELLOW}${swap_used_gb} GB (${swap_usage_percent}%)${NC}"
            else
                echo -e "${CYAN}✅ SWAP Utilisé         : ${GREEN}${swap_used_gb} GB (${swap_usage_percent}%)${NC}"
            fi
        else
            echo -e "${CYAN}💿 SWAP                 : ${YELLOW}Non configuré${NC}"
        fi
        
        # Buffer/Cache
        local buffers=$(grep "Buffers" /proc/meminfo | awk '{print $2}')
        local cached=$(grep "^Cached" /proc/meminfo | awk '{print $2}')
        local buffers_gb=$((buffers / 1024 / 1024))
        local cached_gb=$((cached / 1024 / 1024))
        echo -e "${CYAN}📦 Buffers/Cache        : ${BLUE}${buffers_gb} GB / ${cached_gb} GB${NC}"
    fi
    
    echo ""
    
    # ════════════════════════════════════════════════════════════════
    # STOCKAGE
    # ════════════════════════════════════════════════════════════════
    echo -e "${WHITE}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                        STOCKAGE                            │${NC}"
    echo -e "${WHITE}└────────────────────────────────────────────────────────────┘${NC}"
    
    # Partitions principales
    echo -e "${YELLOW}📁 Partitions principales:${NC}"
    df -h | grep -E "^/dev" | while read filesystem size used avail percent mount; do
        # Couleur selon l'utilisation
        usage_num=$(echo $percent | sed 's/%//')
        if [[ $usage_num -gt 90 ]]; then
            color="${RED}"
        elif [[ $usage_num -gt 80 ]]; then
            color="${YELLOW}"
        else
            color="${GREEN}"
        fi
        
        printf "${CYAN}   %-15s${NC} : ${color}%-8s${NC} (${WHITE}%-8s${NC} utilisé, ${GREEN}%-8s${NC} libre) ${color}%s${NC}\n" \
               "$mount" "$size" "$used" "$avail" "$percent"
    done
    
    # Disques physiques
    echo ""
    echo -e "${YELLOW}💿 Disques physiques:${NC}"
    if command -v lsblk &> /dev/null; then
        lsblk -d -o NAME,SIZE,MODEL | grep -v "loop\|sr" | tail -n +2 | while read name size model; do
            echo -e "${CYAN}   /dev/${name}${NC} : ${GREEN}${size}${NC} ${WHITE}${model}${NC}"
        done
    fi
    
    echo ""
    
    # ════════════════════════════════════════════════════════════════
    # RÉSEAU
    # ════════════════════════════════════════════════════════════════
    echo -e "${WHITE}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                        RÉSEAU                              │${NC}"
    echo -e "${WHITE}└────────────────────────────────────────────────────────────┘${NC}"
    
    # Interfaces réseau
    echo -e "${YELLOW}🌐 Interfaces réseau:${NC}"
    ip -4 addr show 2>/dev/null | grep -E "^[0-4]+:" | while read line; do
        interface=$(echo "$line" | cut -d: -f2 | sed 's/^ *//')
        state=$(echo "$line" | grep -o "state [A-Z]*" | cut -d' ' -f2)
        
        # IP de l'interface
        ip_addr=$(ip -4 addr show "$interface" 2>/dev/null | grep "inet " | awk '{print $2}' | head -1)
        
        if [[ "$state" == "UP" ]]; then
            state_color="${GREEN}"
        else
            state_color="${RED}"
        fi
        
        if [[ -n "$ip_addr" ]]; then
            echo -e "${CYAN}   ${interface}${NC} : ${state_color}${state}${NC} - ${GREEN}${ip_addr}${NC}"
        else
            echo -e "${CYAN}   ${interface}${NC} : ${state_color}${state}${NC}"
        fi
    done
    
    # IP publique
    echo ""
    echo -e "${YELLOW}🌍 IP publique:${NC}"
    public_ip=$(curl -s --connect-timeout 3 https://ipinfo.io/ip 2>/dev/null)
    if [[ -n "$public_ip" ]]; then
        echo -e "${CYAN}   IP externe${NC} : ${GREEN}${public_ip}${NC}"
    else
        echo -e "${CYAN}   IP externe${NC} : ${YELLOW}Non accessible${NC}"
    fi
    
    # DNS
    if [[ -f /etc/resolv.conf ]]; then
        echo ""
        echo -e "${YELLOW}🔍 Serveurs DNS:${NC}"
        grep "nameserver" /etc/resolv.conf | while read ns ip; do
            echo -e "${CYAN}   DNS${NC} : ${GREEN}${ip}${NC}"
        done
    fi
    
    echo ""
    
    # ════════════════════════════════════════════════════════════════
    # SERVICES SYSTÈME
    # ════════════════════════════════════════════════════════════════
    echo -e "${WHITE}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                    SERVICES SYSTÈME                       │${NC}"
    echo -e "${WHITE}└────────────────────────────────────────────────────────────┘${NC}"
    
    # Services critiques
    echo -e "${YELLOW}⚙️  Services critiques:${NC}"
    critical_services=("ssh" "sshd" "systemd-networkd" "networkd" "networking" "cron" "rsyslog" "systemd-logind")
    
    for service in "${critical_services[@]}"; do
        if systemctl list-units --all | grep -q "$service.service"; then
            status=$(systemctl is-active "$service" 2>/dev/null)
            if [[ "$status" == "active" ]]; then
                echo -e "${CYAN}   ${service}${NC} : ${GREEN}✅ Actif${NC}"
            elif [[ "$status" == "inactive" ]]; then
                echo -e "${CYAN}   ${service}${NC} : ${YELLOW}⏸️  Inactif${NC}"
            else
                echo -e "${CYAN}   ${service}${NC} : ${RED}❌ Erreur${NC}"
            fi
        fi
    done
    
    # Services web/base de données
    echo ""
    echo -e "${YELLOW}🌐 Services web/BDD:${NC}"
    web_services=("apache2" "nginx" "mysql" "mariadb" "postgresql" "php-fpm" "php7.4-fpm" "php8.0-fpm" "php8.1-fpm")
    
    found_web_services=false
    for service in "${web_services[@]}"; do
        if systemctl list-units --all | grep -q "$service.service"; then
            found_web_services=true
            status=$(systemctl is-active "$service" 2>/dev/null)
            if [[ "$status" == "active" ]]; then
                echo -e "${CYAN}   ${service}${NC} : ${GREEN}✅ Actif${NC}"
            elif [[ "$status" == "inactive" ]]; then
                echo -e "${CYAN}   ${service}${NC} : ${YELLOW}⏸️  Inactif${NC}"
            else
                echo -e "${CYAN}   ${service}${NC} : ${RED}❌ Erreur${NC}"
            fi
        fi
    done
    
    if [[ "$found_web_services" == false ]]; then
        echo -e "${CYAN}   ${YELLOW}Aucun service web/BDD détecté${NC}"
    fi
    
    echo ""
    
    # ════════════════════════════════════════════════════════════════
    # SÉCURITÉ ET LOGS
    # ════════════════════════════════════════════════════════════════
    echo -e "${WHITE}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                   SÉCURITÉ ET LOGS                         │${NC}"
    echo -e "${WHITE}└────────────────────────────────────────────────────────────┘${NC}"
    
    # Firewall
    if command -v ufw &> /dev/null; then
        ufw_status=$(ufw status | head -1 | awk '{print $2}')
        if [[ "$ufw_status" == "active" ]]; then
            echo -e "${CYAN}🔥 Firewall (UFW)       : ${GREEN}✅ Actif${NC}"
        else
            echo -e "${CYAN}🔥 Firewall (UFW)       : ${RED}❌ Inactif${NC}"
        fi
    elif command -v iptables &> /dev/null; then
        iptables_rules=$(iptables -L 2>/dev/null | wc -l)
        if [[ $iptables_rules -gt 8 ]]; then
            echo -e "${CYAN}🔥 Firewall (iptables)  : ${GREEN}✅ Configuré${NC}"
        else
            echo -e "${CYAN}🔥 Firewall (iptables)  : ${YELLOW}⚠️  Basique${NC}"
        fi
    fi
    
    # Dernières connexions SSH
    if [[ -f /var/log/auth.log ]]; then
        last_ssh=$(grep "Accepted" /var/log/auth.log 2>/dev/null | tail -1 | awk '{print $1, $2, $3, $9, $11}')
        if [[ -n "$last_ssh" ]]; then
            echo -e "${CYAN}🔐 Dernière connexion   : ${GREEN}${last_ssh}${NC}"
        fi
    fi
    
    # Utilisateurs connectés
    echo -e "${CYAN}👥 Utilisateurs actifs  : ${GREEN}$(who | wc -l)${NC}"
    if [[ $(who | wc -l) -gt 0 ]]; then
        who | while read user term date time other; do
            echo -e "${CYAN}   • ${user}${NC} depuis ${GREEN}${date} ${time}${NC}"
        done
    fi
    
    echo ""
    
    # ════════════════════════════════════════════════════════════════
    # PERFORMANCE ET CHARGE
    # ════════════════════════════════════════════════════════════════
    echo -e "${WHITE}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                 PERFORMANCE ET CHARGE                      │${NC}"
    echo -e "${WHITE}└────────────────────────────────────────────────────────────┘${NC}"
    
    # Load average
    if [[ -f /proc/loadavg ]]; then
        read load1 load5 load15 processes last_pid < /proc/loadavg
        echo -e "${CYAN}📊 Charge système       : ${GREEN}${load1}${NC} (1min) ${GREEN}${load5}${NC} (5min) ${GREEN}${load15}${NC} (15min)"
        echo -e "${CYAN}🔢 Processus actifs     : ${GREEN}${processes}${NC}"
    fi
    
    # Processus les plus gourmands
    echo ""
    echo -e "${YELLOW}🔝 Top 5 processus CPU:${NC}"
    ps aux --sort=-%cpu | head -6 | tail -5 | while read user pid cpu mem vsz rss tty stat start time command; do
        if (( $(echo "$cpu > 10" | bc -l 2>/dev/null || echo 0) )); then
            color="${RED}"
        elif (( $(echo "$cpu > 5" | bc -l 2>/dev/null || echo 0) )); then
            color="${YELLOW}"
        else
            color="${GREEN}"
        fi
        printf "${CYAN}   %-12s${NC} : ${color}%5s%%${NC} CPU ${WHITE}%5s%%${NC} MEM ${BLUE}%s${NC}\n" \
               "${command:0:12}" "$cpu" "$mem" "${command:0:30}"
    done
    
    echo ""
    echo -e "${YELLOW}🧠 Top 5 processus MEM:${NC}"
    ps aux --sort=-%mem | head -6 | tail -5 | while read user pid cpu mem vsz rss tty stat start time command; do
        if (( $(echo "$mem > 20" | bc -l 2>/dev/null || echo 0) )); then
            color="${RED}"
        elif (( $(echo "$mem > 10" | bc -l 2>/dev/null || echo 0) )); then
            color="${YELLOW}"
        else
            color="${GREEN}"
        fi
        printf "${CYAN}   %-12s${NC} : ${WHITE}%5s%%${NC} CPU ${color}%5s%%${NC} MEM ${BLUE}%s${NC}\n" \
               "${command:0:12}" "$cpu" "$mem" "${command:0:30}"
    done
    
    echo ""
    echo -e "${WHITE}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│            Appuyez sur une touche pour continuer           │${NC}"
    echo -e "${WHITE}└────────────────────────────────────────────────────────────┘${NC}"
    
    pause_any_key
}

show_processes() {
    show_header
    echo -e "${WHITE}PROCESSUS${NC}"
    echo ""
    ps aux --sort=-%cpu | head -20
    pause_any_key
}

show_performance() {
    show_header
    echo -e "${WHITE}PERFORMANCE${NC}"
    echo ""
    echo -e "${CYAN}═══ CPU ═══${NC}"
    top -bn1 | grep "Cpu(s)"
    echo ""
    echo -e "${CYAN}═══ MÉMOIRE ═══${NC}"
    free -h
    echo ""
    echo -e "${CYAN}═══ CHARGE ═══${NC}"
    uptime
    pause_any_key
}

show_disk_usage() {
    show_header
    echo -e "${WHITE}ESPACE DISQUE${NC}"
    echo ""
    df -h
    pause_any_key
}

show_mounts() {
    show_header
    echo -e "${WHITE}POINTS DE MONTAGE${NC}"
    echo ""
    mount | column -t
    pause_any_key
}

# Fonction pour le menu Système
menu_system() {
    while true; do
        show_header
        echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${WHITE}│                      MENU SYSTÈME                           │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  1.${GREEN} Informations système ${WHITE}│ CPU, RAM, disque, uptime         │${NC}"
        echo -e "${WHITE}│  2.${GREEN} Processus            ${WHITE}│ Liste et gestion des processus   │${NC}"
        echo -e "${WHITE}│  3.${GREEN} Performance          ${WHITE}│ Monitoring temps réel            │${NC}"
        echo -e "${WHITE}│  4.${GREEN} Espace disque        ${WHITE}│ Utilisation des disques          │${NC}"
        echo -e "${WHITE}│  5.${GREEN} Montages             ${WHITE}│ Points de montage                │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  0.${YELLOW} Retour               ${WHITE}│ Menu principal                   │${NC}"
        echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        echo ""

        read -p "$(echo -e ${CYAN}Sélectionnez une option [0-5]: ${NC})" choice

        case "$choice" in
            1) show_system_info ;;
            2) show_processes ;;
            3) show_performance ;;
            4) show_disk_usage ;;
            5) show_mounts ;;
            9) menu_disk_problems ;;
            0) break ;;
            *)
                echo -e "${RED}Choix non valide${NC}"
                sleep 1
                ;;
        esac
    done
}

# Fonction pour vérifier les permissions
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}⚠️  Certaines fonctionnalités nécessitent sudo${NC}"
        echo ""
    fi
}

# Fonction pour le menu TU TOOLS
menu_tu_tools() {
    # L'app TU è già configurata quando arriviamo qui, non serve ricontrollare

    while true; do
        show_header
        echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${WHITE}│                         TU TOOLS                            │${NC}"
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
        if [[ -n "$TU_APP_PATH" ]]; then
            local disk_usage=$(get_disk_usage "$TU_APP_PATH")
            echo -e "${WHITE}│  ${CYAN}Espace occupé: ${disk_usage}${WHITE}                              │${NC}"
            echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        fi
        echo -e "${WHITE}│                        DATABASE                             │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  1.${GREEN} Test connexion      ${WHITE}│ Vérifier la connexion à la base   │${NC}"
        echo -e "${WHITE}│  2.${GREEN} État de la base     ${WHITE}│ Informations et statistiques      │${NC}"
        echo -e "${WHITE}│  3.${GREEN} MySQLTuner          ${WHITE}│ Analyse et optimisation MySQL     │${NC}"
        echo -e "${WHITE}│  4.${RED} Opérations sensibles${WHITE}│ Actions critiques pour la base    │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│                         LOGS                                │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  5.${CYAN} Consultation logs   ${WHITE}│ Logs de l'application             │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│                     ESPACE DISQUE                           │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  8.${CYAN} Problèmes espace     ${WHITE}│ Analyse fichiers et tables       │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│                     CONFIGURATION                           │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  6.${YELLOW} Reconfigurer DB     ${WHITE}│ Modifier les paramètres DB        │${NC}"
        echo -e "${WHITE}│  7.${YELLOW} Reconfigurer App TU ${WHITE}│ Modifier le chemin App TU         │${NC}"
        echo -e "${WHITE}│  0.${YELLOW} Retour              ${WHITE}│ Menu principal                    │${NC}"
        echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        echo ""

        read -p "$(echo -e ${CYAN}Sélectionnez une option [0-8]: ${NC})" choice

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
                if [[ -f "$DB_CREDENTIALS_FILE" ]]; then
                    source "$DB_CREDENTIALS_FILE"
                    if [[ "$CONFIGURED" == "true" ]]; then
                        DB_HOST=$(decrypt_string "$HOST")
                        DB_DATABASE=$(decrypt_string "$DATABASE")
                        DB_USER=$(decrypt_string "$USER")
                        DB_PASSWORD=$(decrypt_string "$PASSWORD")
                    fi
                fi
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

# Fonction principale

# Menu logs simple
# Fonction complète de gestion des logs
menu_logs() {
    while true; do
        clear
        show_header
        
        echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}                       GESTION DES LOGS                        ${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        echo -e "${WHITE}┌────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${WHITE}│                    ANALYSE DES LOGS                        │${NC}"
        echo -e "${WHITE}├────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  1.${GREEN} Logs système (syslog)  ${WHITE}│ Messages système généraux     │${NC}"
        echo -e "${WHITE}│  2.${YELLOW} Authentification       ${WHITE}│ Connexions SSH/login          │${NC}"
        echo -e "${WHITE}│  3.${RED} Erreurs récentes       ${WHITE}│ Détection erreurs 24h         │${NC}"
        echo -e "${WHITE}│  4.${CYAN} Serveur web            ${WHITE}│ Apache/Nginx logs             │${NC}"
        echo -e "${WHITE}│  5.${PURPLE} Espace disque logs     ${WHITE}│ Analyse utilisation /var/log  │${NC}"
        echo -e "${WHITE}├────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│                  SURVEILLANCE TEMPS RÉEL                   │${NC}"
        echo -e "${WHITE}├────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  6.${BLUE} Syslog temps réel      ${WHITE}│ tail -f /var/log/syslog       │${NC}"
        echo -e "${WHITE}│  7.${BLUE} Auth.log temps réel    ${WHITE}│ tail -f /var/log/auth.log     │${NC}"
        echo -e "${WHITE}├────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  0.${WHITE} Retour                 ${WHITE}│ Menu principal                │${NC}"
        echo -e "${WHITE}└────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        
        read -p "$(echo -e ${CYAN}Sélectionnez une option [0-7]: ${NC})" choice
        
        case "$choice" in
            1)
                clear
                echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
                echo -e "${GREEN}                        LOGS SYSTÈME                            ${NC}"
                echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
                echo ""
                
                if [[ -f "/var/log/syslog" ]]; then
                    echo -e "${YELLOW}📊 Statistiques syslog:${NC}"
                    local total_lines=$(wc -l < /var/log/syslog 2>/dev/null)
                    echo -e "   Total lignes: ${CYAN}$total_lines${NC}"
                    
                    local errors=$(grep -ci "error" /var/log/syslog 2>/dev/null)
                    local warnings=$(grep -ci "warn" /var/log/syslog 2>/dev/null)
                    echo -e "   Erreurs: ${RED}$errors${NC}"
                    echo -e "   Warnings: ${YELLOW}$warnings${NC}"
                    echo ""
                    
                    echo -e "${YELLOW}📋 50 dernières lignes (colorées):${NC}"
                    echo ""
                    tail -50 /var/log/syslog | while read line; do
                        if echo "$line" | grep -qi "error\|critical\|alert"; then
                            echo -e "${RED}$line${NC}"
                        elif echo "$line" | grep -qi "warn"; then
                            echo -e "${YELLOW}$line${NC}"
                        elif echo "$line" | grep -qi "info"; then
                            echo -e "${GREEN}$line${NC}"
                        else
                            echo "$line"
                        fi
                    done
                else
                    echo -e "${RED}❌ /var/log/syslog non accessible${NC}"
                fi
                echo ""
                pause_any_key
                ;;
                
            2)
                clear
                echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
                echo -e "${GREEN}                    LOGS AUTHENTIFICATION                       ${NC}"
                echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
                echo ""
                
                if [[ -f "/var/log/auth.log" ]]; then
                    echo -e "${YELLOW}📊 Statistiques authentification:${NC}"
                    local successful=$(grep -c "Accepted" /var/log/auth.log 2>/dev/null)
                    local failed=$(grep -c "Failed password" /var/log/auth.log 2>/dev/null)
                    echo -e "   Connexions réussies: ${GREEN}$successful${NC}"
                    echo -e "   Tentatives échouées: ${RED}$failed${NC}"
                    echo ""
                    
                    echo -e "${GREEN}✅ 10 dernières connexions réussies:${NC}"
                    grep "Accepted" /var/log/auth.log 2>/dev/null | tail -10 | while read line; do
                        echo -e "   ${GREEN}$line${NC}"
                    done
                    echo ""
                    
                    echo -e "${RED}❌ 10 dernières tentatives échouées:${NC}"
                    grep "Failed password" /var/log/auth.log 2>/dev/null | tail -10 | while read line; do
                        echo -e "   ${RED}$line${NC}"
                    done
                    echo ""
                    
                    echo -e "${YELLOW}🔝 Top 5 IPs tentatives échouées:${NC}"
                    grep "Failed password" /var/log/auth.log 2>/dev/null | awk '{print $(NF-3)}' | sort | uniq -c | sort -nr | head -5 | while read count ip; do
                        echo -e "   ${RED}$ip${NC}: ${YELLOW}$count tentatives${NC}"
                    done
                else
                    echo -e "${RED}❌ /var/log/auth.log non accessible${NC}"
                fi
                echo ""
                pause_any_key
                ;;
                
            3)
                clear
                echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
                echo -e "${GREEN}                      ERREURS RÉCENTES                          ${NC}"
                echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
                echo ""
                
                echo -e "${YELLOW}🔍 Recherche d'erreurs dans les dernières 24h...${NC}"
                echo ""
                
                # Syslog errors
                if [[ -f "/var/log/syslog" ]]; then
                    echo -e "${CYAN}📋 Erreurs système (syslog):${NC}"
                    grep -i "error\|critical\|alert\|emergency" /var/log/syslog 2>/dev/null | tail -10 | while read line; do
                        echo -e "   ${RED}$line${NC}"
                    done
                    echo ""
                fi
                
                # Apache errors
                if [[ -f "/var/log/apache2/error.log" ]]; then
                    echo -e "${CYAN}🌐 Erreurs Apache:${NC}"
                    tail -5 /var/log/apache2/error.log 2>/dev/null | while read line; do
                        echo -e "   ${RED}$line${NC}"
                    done
                    echo ""
                fi
                
                # MySQL errors
                local mysql_error_log=$(find /var/log -name "*mysql*error*" -o -name "*mysqld*" 2>/dev/null | head -1)
                if [[ -n "$mysql_error_log" && -f "$mysql_error_log" ]]; then
                    echo -e "${CYAN}🗄️  Erreurs MySQL:${NC}"
                    tail -5 "$mysql_error_log" 2>/dev/null | while read line; do
                        echo -e "   ${RED}$line${NC}"
                    done
                    echo ""
                fi
                
                pause_any_key
                ;;
                
            4)
                clear
                echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
                echo -e "${GREEN}                      LOGS SERVEUR WEB                          ${NC}"
                echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
                echo ""
                
                # Apache
                if [[ -d "/var/log/apache2" ]]; then
                    echo -e "${YELLOW}🌐 Apache détecté${NC}"
                    
                    if [[ -f "/var/log/apache2/access.log" ]]; then
                        echo ""
                        echo -e "${CYAN}📊 Statistiques accès:${NC}"
                        local total_requests=$(wc -l < /var/log/apache2/access.log 2>/dev/null)
                        echo -e "   Total requêtes: ${YELLOW}$total_requests${NC}"
                        
                        echo ""
                        echo -e "${CYAN}📈 Top 5 codes de réponse:${NC}"
                        awk '{print $9}' /var/log/apache2/access.log 2>/dev/null | sort | uniq -c | sort -nr | head -5 | while read count code; do
                            if [[ "$code" =~ ^[45] ]]; then
                                echo -e "   Code ${RED}$code${NC}: ${YELLOW}$count${NC}"
                            else
                                echo -e "   Code ${GREEN}$code${NC}: ${YELLOW}$count${NC}"
                            fi
                        done
                        
                        echo ""
                        echo -e "${CYAN}🔝 Top 5 IPs visiteurs:${NC}"
                        awk '{print $1}' /var/log/apache2/access.log 2>/dev/null | sort | uniq -c | sort -nr | head -5 | while read count ip; do
                            echo -e "   ${CYAN}$ip${NC}: ${YELLOW}$count requêtes${NC}"
                        done
                    fi
                    
                    if [[ -f "/var/log/apache2/error.log" ]]; then
                        echo ""
                        echo -e "${CYAN}❌ Dernières erreurs Apache:${NC}"
                        tail -5 /var/log/apache2/error.log 2>/dev/null | while read line; do
                            echo -e "   ${RED}$line${NC}"
                        done
                    fi
                fi
                
                # Nginx
                if [[ -d "/var/log/nginx" ]]; then
                    echo -e "${YELLOW}🌐 Nginx détecté${NC}"
                    
                    if [[ -f "/var/log/nginx/access.log" ]]; then
                        echo ""
                        echo -e "${CYAN}📊 Statistiques accès Nginx:${NC}"
                        local total_requests=$(wc -l < /var/log/nginx/access.log 2>/dev/null)
                        echo -e "   Total requêtes: ${YELLOW}$total_requests${NC}"
                    fi
                    
                    if [[ -f "/var/log/nginx/error.log" ]]; then
                        echo ""
                        echo -e "${CYAN}❌ Dernières erreurs Nginx:${NC}"
                        tail -5 /var/log/nginx/error.log 2>/dev/null | while read line; do
                            echo -e "   ${RED}$line${NC}"
                        done
                    fi
                fi
                
                if [[ ! -d "/var/log/apache2" && ! -d "/var/log/nginx" ]]; then
                    echo -e "${RED}❌ Aucun serveur web détecté (Apache/Nginx)${NC}"
                fi
                
                echo ""
                pause_any_key
                ;;
                
            5)
                clear
                echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
                echo -e "${GREEN}                    ANALYSE ESPACE LOGS                         ${NC}"
                echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
                echo ""
                
                echo -e "${YELLOW}💾 Utilisation espace /var/log:${NC}"
                local log_size=$(du -sh /var/log 2>/dev/null | cut -f1)
                echo -e "   Taille totale: ${CYAN}$log_size${NC}"
                echo ""
                
                echo -e "${YELLOW}📈 Top 10 plus gros fichiers logs:${NC}"
                find /var/log -type f -name "*.log*" 2>/dev/null | xargs ls -lah 2>/dev/null | sort -k5 -hr | head -10 | while read line; do
                    local size=$(echo "$line" | awk '{print $5}')
                    local file=$(echo "$line" | awk '{print $9}')
                    if [[ "${size: -1}" == "G" ]] || [[ "${size%.*}" -gt 100 && "${size: -1}" == "M" ]]; then
                        echo -e "   ${RED}$size${NC} - ${YELLOW}$file${NC}"
                    else
                        echo -e "   ${GREEN}$size${NC} - $file"
                    fi
                done
                
                echo ""
                echo -e "${RED}⚠️  Logs de plus de 100MB:${NC}"
                find /var/log -type f -size +100M 2>/dev/null | while read file; do
                    local size=$(ls -lh "$file" 2>/dev/null | awk '{print $5}')
                    echo -e "   ${RED}$file${NC} (${YELLOW}$size${NC})"
                done
                
                echo ""
                pause_any_key
                ;;
                
            6)
                echo -e "${YELLOW}📖 Surveillance syslog en temps réel...${NC}"
                echo -e "${CYAN}Appuyez sur Ctrl+C pour quitter${NC}"
                sleep 2
                if [[ -f "/var/log/syslog" ]]; then
                    tail -f /var/log/syslog
                else
                    echo -e "${RED}❌ /var/log/syslog non accessible${NC}"
                    pause_any_key
                fi
                ;;
                
            7)
                echo -e "${YELLOW}🔐 Surveillance auth.log en temps réel...${NC}"
                echo -e "${CYAN}Appuyez sur Ctrl+C pour quitter${NC}"
                sleep 2
                if [[ -f "/var/log/auth.log" ]]; then
                    tail -f /var/log/auth.log
                else
                    echo -e "${RED}❌ /var/log/auth.log non accessible${NC}"
                    pause_any_key
                fi
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
    if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1;" "$DB_DATABASE" 2>/dev/null; then
        echo -e "${GREEN}✅ Connexion réussie${NC}"
    else
        echo -e "${RED}❌ Impossible de se connecter à la base de données${NC}"
        echo -e "${YELLOW}💡 Vérifiez les paramètres de connexion MySQL${NC}"
        pause_any_key
        return
    fi
    
    echo ""
    echo -e "${CYAN}🗃️  Liste des bases de données:${NC}"
    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "SHOW DATABASES;" 2>/dev/null | grep -v "Database\|information_schema\|performance_schema\|mysql\|sys" | while read db; do
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
    if ! mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "USE $target_db;" 2>/dev/null; then
        echo -e "${RED}❌ Base de données '$target_db' non trouvée${NC}"
        pause_any_key
        return
    fi
    
    tables=$(mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "USE $target_db; SHOW TABLES;" 2>/dev/null | grep -v "Tables_in")
    
    if [[ -n "$tables" ]]; then
        echo -e "${YELLOW}📋 Vérification des tables:${NC}"
        echo ""
        
        table_count=0
        ok_count=0
        error_count=0
        
        echo "$tables" | while read table; do
            if [[ -n "$table" ]]; then
                echo -e "${CYAN}🔍 Vérification: $table${NC}"
                result=$(mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "USE $target_db; CHECK TABLE $table;" 2>/dev/null)
                
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
                for service in mysql mariadb mysqld; do
                    if systemctl is-active --quiet "$service" 2>/dev/null; then
                        echo -e "${GREEN}Surveillance du service: $service${NC}"
                        journalctl -u "$service" -f
                        break
                    fi
                done
                
                echo -e "${YELLOW}Aucun service MySQL/MariaDB actif trouvé${NC}"
                pause_any_key
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

# ═══════════════════════════════════════════════════════════════════════════════
# FONZIONI RÉSEAU POUR TU ADMIN
# ═══════════════════════════════════════════════════════════════════════════════

# Funzione per testare la velocità di connessione Internet
# Funzione migliorata per testare la velocità Internet con fallback
# Funzione migliorata per test velocità con server multipli
# Funzione completa per test velocità con speedtest-cli integrato
test_internet_speed() {
    show_header
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                    TEST VITESSE INTERNET                    │${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    echo -e "${CYAN}🌐 Test complet de la vitesse de connexion Internet...${NC}"
    echo ""

    # Determina quale metodo usare
    local use_speedtest=false
    local use_basic=false
    
    if command -v speedtest-cli &> /dev/null; then
        use_speedtest=true
        echo -e "${GREEN}✅ speedtest-cli détecté - Tests avancés disponibles${NC}"
    else
        use_basic=true
        echo -e "${YELLOW}⚠️  speedtest-cli non disponible - Tests de base${NC}"
    fi

    echo ""

    # Test di ping base
    echo -e "${CYAN}🔍 Test de latence rapide:${NC}"
    local ping_tests=(
        "Google DNS|8.8.8.8"
        "Cloudflare|1.1.1.1"
    )
    
    local total_latency=0
    local successful_tests=0
    
    for test_info in "${ping_tests[@]}"; do
        local name=$(echo "$test_info" | cut -d'|' -f1)
        local ip=$(echo "$test_info" | cut -d'|' -f2)
        
        ping_result=$(ping -c 2 -W 1 "$ip" 2>/dev/null)
        if [[ $? -eq 0 ]]; then
            avg_ping=$(echo "$ping_result" | tail -1 | awk -F '/' '{print $5}')
            echo -e "   ${GREEN}✅ $name: ${avg_ping}ms${NC}"
            total_latency=$(echo "$total_latency + $avg_ping" | bc -l 2>/dev/null || echo "$total_latency")
            ((successful_tests++))
        else
            echo -e "   ${RED}❌ $name: Timeout${NC}"
        fi
    done

    if [[ $use_speedtest == true ]]; then
        echo ""
        echo -e "${CYAN}🚀 Test avancé avec speedtest-cli:${NC}"
        echo -e "${YELLOW}   (Cela peut prendre 30-60 secondes...)${NC}"
        echo ""
        
        # Menu pour speedtest
        echo -e "${BLUE}Options de test:${NC}"
        echo -e "${WHITE}1.${NC} Test complet (download + upload + ping)"
        echo -e "${WHITE}2.${NC} Test rapide (download seulement)"
        echo -e "${WHITE}3.${NC} Choisir serveur spécifique"
        echo -e "${WHITE}4.${NC} Tests de base seulement"
        echo ""
        
        read -p "$(echo -e ${CYAN}Sélectionnez [1-4]: ${NC})" speedtest_choice
        
        case "$speedtest_choice" in
            1)
                echo -e "${YELLOW}📊 Test complet en cours...${NC}"
                if timeout 120 speedtest-cli --simple 2>/dev/null; then
                    echo -e "${GREEN}✅ Test complet terminé${NC}"
                else
                    echo -e "${RED}❌ Test complet échoué, passage aux tests de base${NC}"
                    use_basic=true
                fi
                ;;
            2)
                echo -e "${YELLOW}📥 Test de téléchargement rapide...${NC}"
                local download_result=$(timeout 60 speedtest-cli --no-upload --simple 2>/dev/null)
                if [[ $? -eq 0 && -n "$download_result" ]]; then
                    echo "$download_result"
                    echo -e "${GREEN}✅ Test de téléchargement terminé${NC}"
                else
                    echo -e "${RED}❌ Test rapide échoué${NC}"
                    use_basic=true
                fi
                ;;
            3)
                echo -e "${YELLOW}🌍 Recherche des serveurs disponibles...${NC}"
                local servers=$(timeout 30 speedtest-cli --list 2>/dev/null | head -10)
                if [[ -n "$servers" ]]; then
                    echo "$servers"
                    echo ""
                    read -p "$(echo -e ${CYAN}ID du serveur (ou ENTER pour automatique): ${NC})" server_id
                    
                    if [[ -n "$server_id" ]]; then
                        echo -e "${YELLOW}📊 Test avec serveur $server_id...${NC}"
                        timeout 120 speedtest-cli --server "$server_id" --simple 2>/dev/null
                    else
                        echo -e "${YELLOW}📊 Test avec serveur automatique...${NC}"
                        timeout 120 speedtest-cli --simple 2>/dev/null
                    fi
                else
                    echo -e "${RED}❌ Impossible de récupérer la liste des serveurs${NC}"
                    use_basic=true
                fi
                ;;
            4|*)
                echo -e "${YELLOW}Passage aux tests de base${NC}"
                use_basic=true
                ;;
        esac
        
        # Test addizionale DNS se speedtest ha funzionato
        if [[ $use_basic == false ]]; then
            echo ""
            echo -e "${CYAN}🔍 Test DNS détaillé:${NC}"
            local dns_start=$(date +%s.%N)
            if nslookup google.com >/dev/null 2>&1; then
                local dns_end=$(date +%s.%N)
                local dns_time=$(echo "scale=3; $dns_end - $dns_start" | bc -l 2>/dev/null || echo "N/A")
                echo -e "   ${GREEN}✅ Résolution DNS: ${dns_time}s${NC}"
            fi
        fi
    fi

    # Se speedtest non è disponibile o è fallito, usa test base
    if [[ $use_basic == true ]]; then
        echo ""
        echo -e "${CYAN}📥 Tests de base de téléchargement:${NC}"
        
        local test_servers=(
            "Test 1MB|http://ipv4.download.thinkbroadband.com/1MB.zip|1"
            "Test 5MB|http://ipv4.download.thinkbroadband.com/5MB.zip|5"
        )
        
        local download_success=0
        
        for server_info in "${test_servers[@]}"; do
            local name=$(echo "$server_info" | cut -d'|' -f1)
            local url=$(echo "$server_info" | cut -d'|' -f2)
            local size=$(echo "$server_info" | cut -d'|' -f3)
            
            echo -e "${YELLOW}   $name (${size}MB)...${NC}"
            
            if command -v curl &> /dev/null; then
                local start_time=$(date +%s.%N)
                
                if timeout 20 curl -L -o /dev/null -s "$url" 2>/dev/null; then
                    local end_time=$(date +%s.%N)
                    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")
                    
                    if [[ $(echo "$duration > 0.1" | bc -l 2>/dev/null || echo 0) == 1 ]]; then
                        local speed=$(echo "scale=2; $size / $duration" | bc -l 2>/dev/null || echo "N/A")
                        echo -e "     ${GREEN}✅ Vitesse: ${speed} MB/s${NC}"
                        download_success=1
                        break
                    fi
                else
                    echo -e "     ${RED}❌ Échec${NC}"
                fi
            fi
            sleep 1
        done
        
        if [[ $download_success -eq 0 ]]; then
            echo -e "   ${YELLOW}⚠️  Tests de téléchargement limités${NC}"
        fi
    fi

    echo ""
    echo -e "${CYAN}📊 Résumé de la connexion:${NC}"
    
    if [[ $successful_tests -gt 0 ]]; then
        local avg_latency=$(echo "scale=1; $total_latency / $successful_tests" | bc -l 2>/dev/null || echo "999")
        echo -e "   ${YELLOW}📡 Latence moyenne: ${avg_latency}ms${NC}"
        
        if (( $(echo "$avg_latency < 20" | bc -l 2>/dev/null || echo 0) )); then
            echo -e "   ${GREEN}🚀 Qualité: Excellente${NC}"
        elif (( $(echo "$avg_latency < 50" | bc -l 2>/dev/null || echo 0) )); then
            echo -e "   ${GREEN}⚡ Qualité: Très bonne${NC}"
        elif (( $(echo "$avg_latency < 100" | bc -l 2>/dev/null || echo 0) )); then
            echo -e "   ${YELLOW}📡 Qualité: Bonne${NC}"
        else
            echo -e "   ${RED}🐌 Qualité: À améliorer${NC}"
        fi
    fi

    if [[ $use_speedtest == false ]]; then
        echo ""
        echo -e "${CYAN}💡 Pour des tests plus précis:${NC}"
        echo -e "${WHITE}   • Installation: ${YELLOW}sudo apt install speedtest-cli${NC}"
        echo -e "${WHITE}   • Test manuel: ${YELLOW}speedtest-cli${NC}"
        echo -e "${WHITE}   • Test graphique: ${YELLOW}https://www.speedtest.net${NC}"
    fi

    pause_any_key
}
show_network_connections() {
    show_header
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                 CONNEXIONS RÉSEAU ACTIVES                   │${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    echo -e "${CYAN}🔍 Analyse des connexions réseau...${NC}"
    echo ""

    # Connessioni TCP stabilite
    echo -e "${YELLOW}📡 Connexions TCP établies:${NC}"
    netstat -tn 2>/dev/null | grep ESTABLISHED | head -10 | while read line; do
        local_addr=$(echo "$line" | awk '{print $4}')
        foreign_addr=$(echo "$line" | awk '{print $5}')
        echo -e "   ${CYAN}Local:${NC} $local_addr ${CYAN}↔${NC} ${YELLOW}Distant:${NC} $foreign_addr"
    done
    
    echo ""
    
    # Porte in ascolto
    echo -e "${YELLOW}👂 Ports en écoute:${NC}"
    echo -e "${CYAN}   Port     Type    Service${NC}"
    echo -e "${CYAN}   ────     ────    ───────${NC}"
    
    netstat -tln 2>/dev/null | grep LISTEN | awk '{print $4}' | cut -d: -f2 | sort -n | head -15 | while read port; do
        if [[ -n "$port" ]]; then
            service_name=$(getent services "$port" 2>/dev/null | awk '{print $1}' || echo "inconnu")
            if [[ "$port" -eq 22 ]]; then
                echo -e "   ${GREEN}$port${NC}      TCP     ${GREEN}SSH${NC}"
            elif [[ "$port" -eq 80 ]]; then
                echo -e "   ${BLUE}$port${NC}       TCP     ${BLUE}HTTP${NC}"
            elif [[ "$port" -eq 443 ]]; then
                echo -e "   ${BLUE}$port${NC}      TCP     ${BLUE}HTTPS${NC}"
            elif [[ "$port" -eq 3306 ]]; then
                echo -e "   ${PURPLE}$port${NC}     TCP     ${PURPLE}MySQL${NC}"
            else
                echo -e "   ${WHITE}$port${NC}      TCP     $service_name"
            fi
        fi
    done

    echo ""
    
    # Statistiche generali
    echo -e "${YELLOW}📊 Statistiques:${NC}"
    local tcp_count=$(netstat -tn 2>/dev/null | grep -c ESTABLISHED)
    local listen_count=$(netstat -tln 2>/dev/null | grep -c LISTEN)
    echo -e "   ${CYAN}Connexions établies:${NC} $tcp_count"
    echo -e "   ${CYAN}Ports en écoute:${NC} $listen_count"

    pause_any_key
}

# Funzione per diagnosticare i problemi di rete
network_diagnostics() {
    show_header
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                 DIAGNOSTIC RÉSEAU COMPLET                   │${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    echo -e "${CYAN}🔧 Diagnostic réseau en cours...${NC}"
    echo ""

    # Test di connettività Internet
    echo -e "${YELLOW}🌐 Test de connectivité Internet:${NC}"
    if ping -c 2 8.8.8.8 >/dev/null 2>&1; then
        echo -e "   ${GREEN}✅ Connectivité Internet OK${NC}"
    else
        echo -e "   ${RED}❌ Pas de connectivité Internet${NC}"
    fi

    # Test DNS
    echo -e "${YELLOW}🔍 Test de résolution DNS:${NC}"
    if nslookup google.com >/dev/null 2>&1; then
        echo -e "   ${GREEN}✅ Résolution DNS OK${NC}"
    else
        echo -e "   ${RED}❌ Problème de résolution DNS${NC}"
    fi

    # Verifica delle interfacce di rete
    echo ""
    echo -e "${YELLOW}🔌 État des interfaces réseau:${NC}"
    ip link show 2>/dev/null | grep -E "^[0-4]+:" | while read line; do
        interface=$(echo "$line" | cut -d: -f2 | sed 's/^ *//')
        state=$(echo "$line" | grep -o "state [A-Z]*" | cut -d' ' -f2)
        
        if [[ "$state" == "UP" ]]; then
            echo -e "   ${GREEN}✅ $interface: $state${NC}"
        else
            echo -e "   ${RED}❌ $interface: $state${NC}"
        fi
    done

    # Verifica del gateway di default
    echo ""
    echo -e "${YELLOW}🚪 Passerelle par défaut:${NC}"
    gateway=$(ip route | grep default | awk '{print $3}' | head -1)
    if [[ -n "$gateway" ]]; then
        echo -e "   ${CYAN}Passerelle:${NC} $gateway"
        if ping -c 2 "$gateway" >/dev/null 2>&1; then
            echo -e "   ${GREEN}✅ Passerelle accessible${NC}"
        else
            echo -e "   ${RED}❌ Passerelle inaccessible${NC}"
        fi
    else
        echo -e "   ${RED}❌ Aucune passerelle configurée${NC}"
    fi

    # Server DNS configurati
    echo ""
    echo -e "${YELLOW}🔍 Serveurs DNS configurés:${NC}"
    if [[ -f /etc/resolv.conf ]]; then
        grep nameserver /etc/resolv.conf | while read ns ip; do
            echo -e "   ${CYAN}DNS:${NC} $ip"
            if ping -c 1 -W 2 "$ip" >/dev/null 2>&1; then
                echo -e "   ${GREEN}✅ $ip accessible${NC}"
            else
                echo -e "   ${YELLOW}⚠️  $ip inaccessible${NC}"
            fi
        done
    fi

    # Test di performance di rete locale
    echo ""
    echo -e "${YELLOW}📊 Test de performance réseau local:${NC}"
    local interface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [[ -n "$interface" ]]; then
        local speed=$(ethtool "$interface" 2>/dev/null | grep Speed | awk '{print $2}')
        if [[ -n "$speed" ]]; then
            echo -e "   ${CYAN}Vitesse interface $interface:${NC} $speed"
        fi
    fi

    pause_any_key
}

# Funzione per monitorare il traffico di rete in tempo reale
monitor_network_traffic() {
    show_header
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│               MONITORING TRAFIC RÉSEAU                      │${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    echo -e "${CYAN}📊 Surveillance du trafic réseau...${NC}"
    echo -e "${YELLOW}Appuyez sur Ctrl+C pour arrêter${NC}"
    echo ""

    # Funzione per visualizzare le statistiche di rete
    show_network_stats() {
        echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}📈 Statistiques réseau - $(date '+%H:%M:%S')${NC}"
        echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"

        # Statistiche per interfaccia
        echo -e "${WHITE}Interface   RX Bytes    TX Bytes    RX Packets  TX Packets${NC}"
        echo -e "${CYAN}─────────   ────────    ────────    ──────────  ──────────${NC}"
        
        for interface in $(ls /sys/class/net/ | grep -v lo); do
            if [[ -f "/sys/class/net/$interface/statistics/rx_bytes" ]]; then
                rx_bytes=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null || echo 0)
                tx_bytes=$(cat /sys/class/net/$interface/statistics/tx_bytes 2>/dev/null || echo 0)
                rx_packets=$(cat /sys/class/net/$interface/statistics/rx_packets 2>/dev/null || echo 0)
                tx_packets=$(cat /sys/class/net/$interface/statistics/tx_packets 2>/dev/null || echo 0)
                
                # Convertire in unità leggibili
                rx_mb=$(echo "scale=1; $rx_bytes / 1024 / 1024" | bc -l 2>/dev/null || echo "0")
                tx_mb=$(echo "scale=1; $tx_bytes / 1024 / 1024" | bc -l 2>/dev/null || echo "0")
                
                printf "${GREEN}%-11s${NC} %8s MB %8s MB %10s %10s\n" \
                       "$interface" "$rx_mb" "$tx_mb" "$rx_packets" "$tx_packets"
            fi
        done
        
        echo ""
        
        # Top connessioni attive
        echo -e "${YELLOW}🔝 Top 5 connexions actives:${NC}"
        netstat -tn 2>/dev/null | grep ESTABLISHED | head -5 | while read line; do
            foreign_addr=$(echo "$line" | awk '{print $5}' | cut -d: -f1)
            port=$(echo "$line" | awk '{print $5}' | cut -d: -f2)
            echo -e "   ${CYAN}→${NC} $foreign_addr:$port"
        done
        
        echo ""
    }

    # Loop di monitoraggio
    while true; do
        clear
        show_network_stats
        sleep 3
    done
}

# Funzione per testare la connettività verso host specifici
test_connectivity() {
    show_header
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                  TEST DE CONNECTIVITÉ                       │${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    echo -e "${CYAN}🎯 Test de connectivité vers différents hôtes...${NC}"
    echo ""

    # Lista di host da testare
    declare -A hosts=(
        ["Google DNS"]="8.8.8.8"
        ["Cloudflare DNS"]="1.1.1.1"
        ["Google"]="google.com"
        ["GitHub"]="github.com"
        ["OVH"]="ovh.com"
    )

    echo -e "${YELLOW}📡 Tests de ping:${NC}"
    echo -e "${CYAN}Hôte               Statut    Latence${NC}"
    echo -e "${CYAN}────               ──────    ───────${NC}"

    for host_name in "${!hosts[@]}"; do
        host_addr="${hosts[$host_name]}"
        ping_result=$(ping -c 3 -W 2 "$host_addr" 2>/dev/null)
        
        if [[ $? -eq 0 ]]; then
            avg_time=$(echo "$ping_result" | tail -1 | awk -F '/' '{print $5}' 2>/dev/null || echo "N/A")
            printf "${GREEN}%-18s ✅ OK      %s ms${NC}\n" "$host_name" "$avg_time"
        else
            printf "${RED}%-18s ❌ ÉCHEC   N/A${NC}\n" "$host_name"
        fi
    done

    echo ""
    echo -e "${YELLOW}🌐 Tests de ports spécifiques:${NC}"
    echo -e "${CYAN}Service            Port    Statut${NC}"
    echo -e "${CYAN}───────            ────    ──────${NC}"

    # Test di porte comuni
    declare -A services=(
        ["HTTP"]="80"
        ["HTTPS"]="443"
        ["SSH"]="22"
        ["DNS"]="53"
        ["SMTP"]="25"
    )

    for service in "${!services[@]}"; do
        port="${services[$service]}"
        if timeout 3 bash -c "</dev/tcp/google.com/$port" 2>/dev/null; then
            printf "${GREEN}%-18s %-7s ✅ OK${NC}\n" "$service" "$port"
        else
            printf "${RED}%-18s %-7s ❌ ÉCHEC${NC}\n" "$service" "$port"
        fi
    done

    pause_any_key
}

# Funzione per analizzare la configurazione di rete
show_network_config() {
    show_header
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│               CONFIGURATION RÉSEAU                          │${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    echo -e "${CYAN}⚙️ Configuration réseau du système...${NC}"
    echo ""

    # Interfacce e indirizzi IP
    echo -e "${YELLOW}🔌 Interfaces réseau:${NC}"
    ip addr show 2>/dev/null | grep -E "^[0-4]+:|inet " | while read line; do
        if [[ "$line" =~ ^[0-4]+: ]]; then
            interface=$(echo "$line" | cut -d: -f2 | sed 's/^ *//')
            state=$(echo "$line" | grep -o "state [A-Z]*" | cut -d' ' -f2 || echo "UNKNOWN")
            echo -e "   ${CYAN}Interface: $interface ($state)${NC}"
        elif [[ "$line" =~ inet ]]; then
            ip_addr=$(echo "$line" | awk '{print $2}')
            echo -e "     ${GREEN}IP: $ip_addr${NC}"
        fi
    done

    echo ""

    # Routing
    echo -e "${YELLOW}🚪 Table de routage:${NC}"
    ip route show 2>/dev/null | head -10 | while read line; do
        if echo "$line" | grep -q "default"; then
            echo -e "   ${GREEN}$line${NC}"
        else
            echo -e "   ${WHITE}$line${NC}"
        fi
    done

    echo ""

    # Configurazione DNS
    echo -e "${YELLOW}🔍 Configuration DNS:${NC}"
    if [[ -f /etc/resolv.conf ]]; then
        while read line; do
            if [[ "$line" =~ ^nameserver ]]; then
                dns_server=$(echo "$line" | awk '{print $2}')
                echo -e "   ${CYAN}Serveur DNS: $dns_server${NC}"
            elif [[ "$line" =~ ^search ]]; then
                search_domain=$(echo "$line" | cut -d' ' -f2-)
                echo -e "   ${YELLOW}Domaines de recherche: $search_domain${NC}"
            fi
        done < /etc/resolv.conf
    fi

    echo ""

    # Hostname e dominio
    echo -e "${YELLOW}🏷️ Identification:${NC}"
    echo -e "   ${CYAN}Hostname: $(hostname)${NC}"
    echo -e "   ${CYAN}FQDN: $(hostname -f 2>/dev/null || echo "N/A")${NC}"
    echo -e "   ${CYAN}Domaine: $(hostname -d 2>/dev/null || echo "N/A")${NC}"

    pause_any_key
}

# Menu principale delle funzioni di rete
menu_network() {
    while true; do
        show_header
        echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${WHITE}│                      MENU RÉSEAU                            │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│                     TESTS DE PERFORMANCE                    │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  1.${GREEN} Test vitesse Internet  ${WHITE}│ Mesure débit et latence        │${NC}"
        echo -e "${WHITE}│  2.${GREEN} Test connectivité      ${WHITE}│ Ping vers hôtes importants     │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│                        DIAGNOSTIC                           │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  3.${CYAN} Diagnostic complet     ${WHITE}│ Analyse problèmes réseau       │${NC}"
        echo -e "${WHITE}│  4.${CYAN} Connexions actives     ${WHITE}│ Ports et connexions en cours   │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│                      SURVEILLANCE                           │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  5.${BLUE} Monitoring trafic      ${WHITE}│ Surveillance temps réel        │${NC}"
        echo -e "${WHITE}│  6.${BLUE} Configuration réseau   ${WHITE}│ Affichage config système       │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  0.${YELLOW} Retour                 ${WHITE}│ Menu principal                 │${NC}"
        echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
        echo ""

        read -p "$(echo -e ${CYAN}Sélectionnez une option [0-6]: ${NC})" choice

        case "$choice" in
            1) test_internet_speed ;;
            2) test_connectivity ;;
            3) network_diagnostics ;;
            4) show_network_connections ;;
            5) monitor_network_traffic ;;
            6) show_network_config ;;
            0) break ;;
            *)
                echo -e "${RED}Choix non valide${NC}"
                sleep 1
                ;;
        esac
    done
}

main() {
    check_permissions

    touch "$LOG_FILE" 2>/dev/null || {
        echo -e "${RED}Erreur: Impossible de créer le log${NC}"
        exit 1
    }

    # Verifica que base64 sia disponibile (standard su tutti i sistemi Unix)
    if ! command -v base64 &> /dev/null; then
        echo -e "${RED}❌ base64 requis!${NC}"
        echo -e "${YELLOW}Installez: sudo apt install coreutils${NC}"
        exit 1
    fi

    log_action "Démarrage TU Admin" "INFO" "Utilisateur: $(whoami)"

    while true; do
        show_header
        show_main_menu
        echo ""

        read -p "$(echo -e ${CYAN}Sélectionnez une option [0-4]: ${NC})" choice

        case "$choice" in
            1)
                # Prima caricare/configurare l'app TU, poi verificare il DB
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

                # Ora verificare/configurare il database
                if check_database_configuration; then
                    menu_tu_tools
                fi
                ;;
            2)
                menu_system
                ;;
            3)
                menu_network
                
                ;;
            4)
                menu_logs
                ;;
            5)
                echo -e "${YELLOW}Menu Utilisateurs - En développement${NC}"
                sleep 2
                ;;
            6)
                echo -e "${YELLOW}Menu Fichiers - En développement${NC}"
                sleep 2
                ;;
            7)
                echo -e "${YELLOW}Menu Sécurité - En développement${NC}"
                sleep 2
                ;;
            8)
        menu_logs
                sleep 2
                ;;
            8)
                echo -e "${YELLOW}Menu Configuration - En développement${NC}"
                sleep 2
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
