#!/bin/bash
# TU Tools - Configuration

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

    read -p "$(echo -e "${CYAN}Sélectionnez une option [1-3] ou tapez le chemin directement: ${NC}")" path_choice

    case "$path_choice" in
        1)
            app_path="/var/www/html/"
            ;;
        2)
            app_path="/home/www/"
            ;;
        3)
            read -p "$(echo -e "${CYAN}Chemin personnalisé: ${NC}")" app_path
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
        read -p "$(echo -e "${CYAN}Créer le répertoire? [O/n]: ${NC}")" create_dir

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
    read -p "$(echo -e "${CYAN}Confirmer ce chemin? [O/n]: ${NC}")" confirm

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

# Fonction core: lire les paramètres DB depuis un chemin define.xml.php quelconque
read_db_from_define_xml_path() {
    local define_file="$1"

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
    # Port optionnel (tag <mysqlport> - défaut 3306 si absent)
    local mysqlport=$(grep -oP '<mysqlport>\K[^<]*' "$define_file" 2>/dev/null)
    mysqlport="${mysqlport:-3306}"

    # Vérifier que tous les paramètres obligatoires ont été trouvés
    if [[ -z "$mysqlhost" || -z "$mysqluser" || -z "$mysqlpass" || -z "$basegts" ]]; then
        echo -e "${RED}❌ Impossible de lire tous les paramètres du fichier!${NC}"
        echo -e "${YELLOW}Paramètres trouvés:${NC}"
        echo -e "${YELLOW}  Host: ${mysqlhost:-NON TROUVE}${NC}"
        echo -e "${YELLOW}  User: ${mysqluser:-NON TROUVE}${NC}"
        [[ -n "$mysqlpass" ]] && echo -e "${YELLOW}  Pass: ***${NC}" || echo -e "${YELLOW}  Pass: NON TROUVE${NC}"
        echo -e "${YELLOW}  Base: ${basegts:-NON TROUVE}${NC}"
        return 1
    fi

    echo -e "${GREEN}✅ Paramètres extraits avec succès:${NC}"
    echo -e "${YELLOW}  Host: ${mysqlhost}${NC}"
    echo -e "${YELLOW}  Port: ${mysqlport}${NC}"
    echo -e "${YELLOW}  User: ${mysqluser}${NC}"
    echo -e "${YELLOW}  Pass: ***${NC}"
    echo -e "${YELLOW}  Base: ${basegts}${NC}"
    echo ""

    # Test de connexion
    echo -e "${YELLOW}Test de connexion...${NC}"
    local port_arg=""
    [[ "$mysqlport" != "3306" ]] && port_arg="-P $mysqlport"

    if command -v mysql &> /dev/null; then
        if mysql -h "$mysqlhost" $port_arg -u "$mysqluser" -p"$mysqlpass" -e "USE $basegts;" 2>/dev/null; then
            echo -e "${GREEN}✅ Connexion réussie!${NC}"
        else
            echo -e "${RED}❌ Erreur de connexion avec les paramètres du fichier!${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  MySQL client non trouvé, impossible de tester${NC}"
    fi

    # Sauvegarder les credentials (avec port)
    save_db_credentials "$mysqlhost" "$basegts" "$mysqluser" "$mysqlpass" "$mysqlport"
    return 0
}

# Fonction pour lire les paramètres DB depuis define.xml.php (chemin TU_APP_PATH)
read_db_from_define_xml() {
    local define_file="$TU_APP_PATH/src/terminal/var/define.xml.php"
    read_db_from_define_xml_path "$define_file"
}

# Fonction pour configurer la base de données
configure_database() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}           CONFIGURATION BASE DE DONNÉES                   ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Configuration de la connexion à la base de données MySQL/MariaDB${NC}"
    echo ""

    # Construire la liste des options disponibili
    echo -e "${BLUE}Options de configuration:${NC}"

    if [[ -n "$TU_APP_PATH" && -f "$TU_APP_PATH/src/terminal/var/define.xml.php" ]]; then
        echo -e "${WHITE}1.${NC} Lire depuis define.xml.php ${GREEN}(chemin App TU - recommandé)${NC}"
        echo -e "${WHITE}2.${NC} Lire depuis define.xml.php ${CYAN}(chemin personnalisé)${NC}"
        echo -e "${WHITE}3.${NC} Configuration manuelle ${YELLOW}(serveur externe / cluster)${NC}"
        echo ""
        read -p "$(echo -e "${CYAN}Sélectionnez une option [1-3]: ${NC}")" config_choice
    else
        echo -e "${WHITE}1.${NC} Lire depuis define.xml.php ${CYAN}(chemin personnalisé)${NC}"
        echo -e "${WHITE}2.${NC} Configuration manuelle ${YELLOW}(serveur externe / cluster)${NC}"
        echo ""
        read -p "$(echo -e "${CYAN}Sélectionnez une option [1-2]: ${NC}")" config_choice
        # Décaler les choix si TU_APP_PATH non défini
        [[ "$config_choice" == "1" ]] && config_choice="2"
        [[ "$config_choice" == "2" ]] && config_choice="3"
    fi

    case "$config_choice" in
        1)
            # define.xml.php depuis TU_APP_PATH
            if read_db_from_define_xml; then
                load_db_credentials
                sleep 2
                return 0
            else
                echo -e "${YELLOW}Échec lecture automatique, passage en mode manuel...${NC}"
                sleep 2
            fi
            ;;
        2)
            # define.xml.php depuis chemin personnalisé
            echo ""
            echo -e "${CYAN}Indiquez le chemin complet vers le fichier define.xml.php${NC}"
            echo -e "${YELLOW}Exemple: /var/www/html/tu-app/src/terminal/var/define.xml.php${NC}"
            echo ""
            read -p "$(echo -e "${CYAN}Chemin define.xml.php: ${NC}")" custom_define_path

            if [[ -z "$custom_define_path" ]]; then
                echo -e "${RED}❌ Chemin vide${NC}"
                sleep 2
                return 1
            fi

            if read_db_from_define_xml_path "$custom_define_path"; then
                load_db_credentials
                sleep 2
                return 0
            else
                echo -e "${YELLOW}Échec lecture, passage en mode manuel...${NC}"
                sleep 2
            fi
            ;;
        3|*)
            echo -e "${YELLOW}Configuration manuelle sélectionnée${NC}"
            ;;
    esac

    echo ""

    # ═══ CONFIGURATION MANUELLE (supporte serveur externe / cluster) ═══
    echo -e "${CYAN}═══ CONFIGURATION MANUELLE / SERVEUR EXTERNE ═══${NC}"
    echo -e "${YELLOW}Exemples d'hôte: localhost, 192.168.1.100, db.monserveur.fr${NC}"
    echo ""

    read -p "$(echo -e "${CYAN}Hôte: ${NC}")" db_host
    read -p "$(echo -e "${CYAN}Port MySQL [3306]: ${NC}")" db_port
    db_port="${db_port:-3306}"
    read -p "$(echo -e "${CYAN}Nom de la base de données: ${NC}")" db_name
    read -p "$(echo -e "${CYAN}Utilisateur: ${NC}")" db_user
    read -s -p "$(echo -e "${CYAN}Mot de passe: ${NC}")" db_password
    echo ""
    echo ""

    if [[ -z "$db_host" || -z "$db_name" || -z "$db_user" || -z "$db_password" ]]; then
        echo -e "${RED}❌ Tous les champs sont obligatoires!${NC}"
        sleep 3
        return 1
    fi

    local port_arg=""
    [[ "$db_port" != "3306" ]] && port_arg="-P $db_port"

    echo -e "${YELLOW}Test de connexion vers ${db_host}:${db_port}...${NC}"
    if command -v mysql &> /dev/null; then
        if mysql -h "$db_host" $port_arg -u "$db_user" -p"$db_password" -e "USE $db_name;" 2>/dev/null; then
            echo -e "${GREEN}✅ Connexion réussie!${NC}"
        else
            echo -e "${YELLOW}⚠️  Impossible de tester la connexion (vérifiez les paramètres)${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  MySQL client non trouvé${NC}"
    fi

    save_db_credentials "$db_host" "$db_name" "$db_user" "$db_password" "$db_port"
    load_db_credentials
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
        echo -e "${CYAN}Tentativo di lettura automatica des paramètres DB depuis define.xml.php...${NC}"
        if read_db_from_define_xml; then
            # Ricaricare i credentials appena salvati
            load_db_credentials
            return 0
        fi
    fi

    # Se tutto fallisce, chiediamo la configurazione manuale
    echo -e "${YELLOW}⚠️  Configuration base de données requise!${NC}"
    read -p "$(echo -e "${CYAN}Configurer maintenant? [O/n]: ${NC}")" configure_now

    if [[ ! "$configure_now" =~ ^[Nn]$ ]]; then
        configure_database
        return $?
    else
        echo -e "${RED}❌ Configuration annulée${NC}"
        sleep 2
        return 1
    fi
}

# Export
export -f save_tu_app_path
export -f load_tu_app_path
export -f configure_tu_app_path
export -f read_db_from_define_xml_path
export -f read_db_from_define_xml
export -f configure_database
export -f check_database_configuration
