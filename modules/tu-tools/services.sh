#!/bin/bash
# TU Tools - Gestion des services HL7 et ProFTPD

# ═══════════════════════════════════════════════════════════════
# FONCTIONS UTILITAIRES SERVICES
# ═══════════════════════════════════════════════════════════════

# Détecter le mode de contrôle d'un service (systemd ou init.d)
detect_service_mode() {
    local service_name="$1"

    # Priorità: systemd se disponibile
    if systemctl list-units --type=service --all 2>/dev/null | grep -q "${service_name}"; then
        echo "systemd"
    elif systemctl list-unit-files 2>/dev/null | grep -q "${service_name}"; then
        echo "systemd"
    elif [[ -f "/etc/init.d/${service_name}" ]]; then
        echo "initd"
    else
        echo "unknown"
    fi
}

# Ottenere lo stato di un servizio
get_service_status() {
    local service_name="$1"
    local mode=$(detect_service_mode "$service_name")

    case "$mode" in
        systemd)
            local state=$(systemctl is-active "$service_name" 2>/dev/null)
            echo "$state"
            ;;
        initd)
            if /etc/init.d/"$service_name" status 2>/dev/null | grep -qi "is running\|PID:"; then
                echo "active"
            else
                echo "inactive"
            fi
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Eseguire un'azione su un servizio (start/stop/restart)
service_action() {
    local service_name="$1"
    local action="$2"
    local mode=$(detect_service_mode "$service_name")

    case "$mode" in
        systemd)
            systemctl "$action" "$service_name" 2>&1
            return $?
            ;;
        initd)
            /etc/init.d/"$service_name" "$action" 2>&1
            return $?
            ;;
        *)
            echo "Impossible de contrôler le service: $service_name (mode inconnu)"
            return 1
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════
# SCAN ET GESTION HL7
# ═══════════════════════════════════════════════════════════════

# Scanner tous les services HL7 disponibles
scan_hl7_services() {
    local -a found=()

    # 1. Chercher dans /etc/init.d/
    for script in /etc/init.d/hl7*; do
        if [[ -f "$script" && -x "$script" ]]; then
            local name=$(basename "$script")
            found+=("$name")
        fi
    done

    # 2. Chercher dans systemd
    while IFS= read -r line; do
        local name=$(echo "$line" | awk '{print $1}' | sed 's/\.service//')
        # Evitare duplicati con init.d
        if [[ ! " ${found[*]} " =~ " ${name} " ]]; then
            found+=("$name")
        fi
    done < <(systemctl list-unit-files --type=service 2>/dev/null | grep -i "hl7")

    # Restituire l'array
    echo "${found[@]}"
}

# Mostrare lo stato di tutti i servizi HL7
show_hl7_status() {
    local -a services
    read -ra services <<< "$(scan_hl7_services)"

    show_header
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                   SERVICES HL7 DÉTECTÉS                     │${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    if [[ ${#services[@]} -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  Aucun service HL7 détecté${NC}"
        echo ""
        echo -e "${CYAN}Chemins scannés:${NC}"
        echo -e "   ${WHITE}/etc/init.d/hl7*${NC}"
        echo -e "   ${WHITE}systemctl (units hl7*)${NC}"
        echo ""
        echo -e "${CYAN}💡 Pour installer le connecteur HL7:${NC}"
        echo -e "   ${WHITE}https://tgs.iess.fr/supa-sih-connecteur-hl7-socket/${NC}"
        pause_any_key
        return
    fi

    echo -e "${CYAN}${#services[@]} service(s) HL7 trouvé(s):${NC}"
    echo ""
    echo -e "${WHITE}  Service                    Mode      Statut${NC}"
    echo -e "${CYAN}  ───────────────────────────────────────────────${NC}"

    for svc in "${services[@]}"; do
        local mode=$(detect_service_mode "$svc")
        local status=$(get_service_status "$svc")
        local mode_label=""

        case "$mode" in
            systemd) mode_label="${BLUE}systemd${NC}" ;;
            initd)   mode_label="${YELLOW}init.d ${NC}" ;;
            *)       mode_label="${RED}inconnu${NC}" ;;
        esac

        local status_icon=""
        if [[ "$status" == "active" ]]; then
            status_icon="${GREEN}● actif${NC}"
        else
            status_icon="${RED}○ inactif${NC}"
        fi

        printf "  ${CYAN}%-28s${NC} " "$svc"
        echo -e "${mode_label}   ${status_icon}"
    done

    echo ""
    pause_any_key
}

# Menu di gestione HL7
menu_hl7_management() {
    while true; do
        local -a services
        read -ra services <<< "$(scan_hl7_services)"

        show_header
        echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${WHITE}│                   GESTION SERVICES HL7                      │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"

        if [[ ${#services[@]} -eq 0 ]]; then
            echo -e "${WHITE}│  ${YELLOW}⚠️  Aucun service HL7 détecté                             │${NC}"
            echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
            echo -e "${WHITE}│  ${RED}0. Retour                                                │${NC}"
            echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
            echo ""
            read -p "$(echo -e "${CYAN}Sélectionnez une option: ${NC}")" choice
            [[ "$choice" == "0" ]] && break
            continue
        fi

        # Afficher les services avec leur statut
        local i=1
        for svc in "${services[@]}"; do
            local status=$(get_service_status "$svc")
            local status_icon=""
            if [[ "$status" == "active" ]]; then
                status_icon="${GREEN}●${NC}"
            else
                status_icon="${RED}○${NC}"
            fi
            local mode=$(detect_service_mode "$svc")
            local mode_short=""
            [[ "$mode" == "systemd" ]] && mode_short="[systemd]" || mode_short="[init.d]"

            printf "${WHITE}│  ${CYAN}%d.${NC} " "$i"
            echo -e "${status_icon} ${WHITE}${svc}${NC} ${YELLOW}${mode_short}${NC}"
            ((i++))
        done

        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  ${GREEN}a. Démarrer TOUS    ${WHITE}│ Start tous les services HL7         │${NC}"
        echo -e "${WHITE}│  ${YELLOW}r. Redémarrer TOUS  ${WHITE}│ Restart tous les services HL7       │${NC}"
        echo -e "${WHITE}│  ${RED}s. Arrêter TOUS     ${WHITE}│ Stop tous les services HL7          │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  ${WHITE}0. Retour           ${WHITE}│ Menu services                       │${NC}"
        echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${CYAN}  (Entrez le numéro d'un service pour le gérer individuellement)${NC}"
        echo ""

        read -p "$(echo -e "${CYAN}Sélectionnez une option: ${NC}")" choice

        case "$choice" in
            [0-9]*)
                if [[ "$choice" == "0" ]]; then
                    break
                fi
                local idx=$((choice - 1))
                if [[ $idx -ge 0 && $idx -lt ${#services[@]} ]]; then
                    menu_single_hl7_service "${services[$idx]}"
                else
                    echo -e "${RED}Choix non valide${NC}"
                    sleep 1
                fi
                ;;
            a|A)
                echo ""
                echo -e "${CYAN}Démarrage de tous les services HL7...${NC}"
                for svc in "${services[@]}"; do
                    echo -e "${YELLOW}→ Start: $svc${NC}"
                    service_action "$svc" "start"
                done
                log_action "HL7 Start All" "INFO" "Services: ${services[*]}"
                pause_any_key
                ;;
            r|R)
                echo ""
                echo -e "${CYAN}Redémarrage de tous les services HL7...${NC}"
                for svc in "${services[@]}"; do
                    echo -e "${YELLOW}→ Restart: $svc${NC}"
                    service_action "$svc" "restart"
                done
                log_action "HL7 Restart All" "INFO" "Services: ${services[*]}"
                pause_any_key
                ;;
            s|S)
                echo ""
                echo -e "${RED}⚠️  Arrêt de tous les services HL7...${NC}"
                read -p "$(echo -e "${YELLOW}Confirmer l arrêt de tous les services HL7? [o/N]: ${NC}")" confirm
                if [[ "$confirm" =~ ^[Oo]$ ]]; then
                    for svc in "${services[@]}"; do
                        echo -e "${YELLOW}→ Stop: $svc${NC}"
                        service_action "$svc" "stop"
                    done
                    log_action "HL7 Stop All" "INFO" "Services: ${services[*]}"
                fi
                pause_any_key
                ;;
            *)
                echo -e "${RED}Choix non valide${NC}"
                sleep 1
                ;;
        esac
    done
}

# Gestione di un singolo servizio HL7
menu_single_hl7_service() {
    local svc="$1"
    local mode=$(detect_service_mode "$svc")

    while true; do
        local status=$(get_service_status "$svc")
        local status_label=""
        [[ "$status" == "active" ]] && status_label="${GREEN}● ACTIF${NC}" || status_label="${RED}○ INACTIF${NC}"

        show_header
        echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${WHITE}│                     SERVICE HL7                             │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        format_menu_row "Service: ${CYAN}${svc}${NC}" ""
        format_menu_row "Mode:    ${YELLOW}${mode}${NC}" ""
        format_menu_row "Statut:  ${status_label}" ""
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  ${GREEN}1. Démarrer     ${WHITE}│ Start le service                       │${NC}"
        echo -e "${WHITE}│  ${YELLOW}2. Redémarrer   ${WHITE}│ Restart le service                     │${NC}"
        echo -e "${WHITE}│  ${RED}3. Arrêter      ${WHITE}│ Stop le service                        │${NC}"
        echo -e "${WHITE}│  ${CYAN}4. Statut       ${WHITE}│ Statut détaillé                        │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  ${WHITE}0. Retour       ${WHITE}│ Liste des services HL7                 │${NC}"
        echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
        echo ""

        read -p "$(echo -e "${CYAN}Sélectionnez une option [0-4]: ${NC}")" choice

        case "$choice" in
            1)
                echo ""
                echo -e "${CYAN}Démarrage de $svc...${NC}"
                service_action "$svc" "start"
                log_action "HL7 Start" "INFO" "Service: $svc"
                pause_any_key
                ;;
            2)
                echo ""
                echo -e "${YELLOW}Redémarrage de $svc...${NC}"
                service_action "$svc" "restart"
                log_action "HL7 Restart" "INFO" "Service: $svc"
                pause_any_key
                ;;
            3)
                echo ""
                echo -e "${RED}Arrêt de $svc...${NC}"
                service_action "$svc" "stop"
                log_action "HL7 Stop" "INFO" "Service: $svc"
                pause_any_key
                ;;
            4)
                echo ""
                echo -e "${CYAN}Statut détaillé de $svc:${NC}"
                echo -e "${CYAN}════════════════════════════════════════${NC}"
                if [[ "$mode" == "systemd" ]]; then
                    systemctl status "$svc" 2>&1
                else
                    /etc/init.d/"$svc" status 2>&1
                    echo ""
                    # Informations supplémentaires init.d
                    local pidfile="/var/run/${svc}.pid"
                    if [[ -f "$pidfile" ]]; then
                        local pid=$(cat "$pidfile")
                        echo -e "${CYAN}PID File:${NC} $pidfile (PID: $pid)"
                        if kill -0 "$pid" 2>/dev/null; then
                            echo -e "${GREEN}Process actif${NC}"
                            ps -p "$pid" -o pid,ppid,cmd,%cpu,%mem 2>/dev/null
                        fi
                    fi
                    local logfile="/var/log/${svc}.log"
                    if [[ -f "$logfile" ]]; then
                        echo ""
                        echo -e "${CYAN}Dernières lignes log ($logfile):${NC}"
                        tail -5 "$logfile"
                    fi
                fi
                echo ""
                pause_any_key
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

# ═══════════════════════════════════════════════════════════════
# GESTION PROFTPD
# ═══════════════════════════════════════════════════════════════

menu_proftpd() {
    while true; do
        local status=$(get_service_status "proftpd")
        local status_label=""
        [[ "$status" == "active" ]] && status_label="${GREEN}● ACTIF${NC}" || status_label="${RED}○ INACTIF${NC}"
        local mode=$(detect_service_mode "proftpd")

        show_header
        echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${WHITE}│                   GESTION PROFTPD                           │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        format_menu_row "Service: ${CYAN}proftpd${NC}" ""
        format_menu_row "Mode:    ${YELLOW}${mode}${NC}" ""
        format_menu_row "Statut:  ${status_label}" ""
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"

        # Vérifier si proftpd est installé
        if ! command -v proftpd &>/dev/null && [[ ! -f "/etc/init.d/proftpd" ]]; then
            echo -e "${WHITE}│  ${RED}❌ ProFTPD non installé                                    │${NC}"
            echo -e "${WHITE}│  ${YELLOW}   apt install proftpd-basic                              │${NC}"
            echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
            echo -e "${WHITE}│  ${WHITE}0. Retour                                                │${NC}"
            echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
            echo ""
            read -p "$(echo -e "${CYAN}Sélectionnez une option: ${NC}")" choice
            [[ "$choice" == "0" ]] && break
            continue
        fi

        echo -e "${WHITE}│  ${GREEN}1. Démarrer     ${WHITE}│ Start ProFTPD                          │${NC}"
        echo -e "${WHITE}│  ${YELLOW}2. Redémarrer   ${WHITE}│ Restart ProFTPD                        │${NC}"
        echo -e "${WHITE}│  ${RED}3. Arrêter      ${WHITE}│ Stop ProFTPD                           │${NC}"
        echo -e "${WHITE}│  ${CYAN}4. Statut       ${WHITE}│ Statut détaillé                        │${NC}"
        echo -e "${WHITE}│  ${BLUE}5. Connexions   ${WHITE}│ Sessions FTP actives                   │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  ${WHITE}0. Retour       ${WHITE}│ Menu services                          │${NC}"
        echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
        echo ""

        read -p "$(echo -e "${CYAN}Sélectionnez une option [0-5]: ${NC}")" choice

        case "$choice" in
            1)
                echo ""
                echo -e "${CYAN}Démarrage de ProFTPD...${NC}"
                service_action "proftpd" "start"
                log_action "ProFTPD Start" "INFO" "Mode: $mode"
                pause_any_key
                ;;
            2)
                echo ""
                echo -e "${YELLOW}Redémarrage de ProFTPD...${NC}"
                service_action "proftpd" "restart"
                log_action "ProFTPD Restart" "INFO" "Mode: $mode"
                pause_any_key
                ;;
            3)
                echo ""
                echo -e "${RED}⚠️  Arrêt de ProFTPD (connexions FTP interrompues)${NC}"
                read -p "$(echo -e "${YELLOW}Confirmer? [o/N]: ${NC}")" confirm
                if [[ "$confirm" =~ ^[Oo]$ ]]; then
                    service_action "proftpd" "stop"
                    log_action "ProFTPD Stop" "INFO" "Mode: $mode"
                fi
                pause_any_key
                ;;
            4)
                echo ""
                echo -e "${CYAN}Statut détaillé ProFTPD:${NC}"
                echo -e "${CYAN}════════════════════════════════════════${NC}"
                if [[ "$mode" == "systemd" ]]; then
                    systemctl status proftpd 2>&1
                else
                    /etc/init.d/proftpd status 2>&1
                fi

                # Info configurazione
                echo ""
                local config_file=$(proftpd --configtest 2>&1 | grep "Config file" | awk '{print $NF}' || echo "/etc/proftpd/proftpd.conf")
                if [[ -z "$config_file" ]]; then
                    config_file="/etc/proftpd/proftpd.conf"
                fi
                if [[ -f "$config_file" ]]; then
                    echo -e "${CYAN}Configuration ($config_file):${NC}"
                    local ftp_port=$(grep -i "^Port" "$config_file" 2>/dev/null | awk '{print $2}')
                    local ftp_user=$(grep -i "^User " "$config_file" 2>/dev/null | awk '{print $2}')
                    [[ -n "$ftp_port" ]] && echo -e "   ${YELLOW}Port FTP: $ftp_port${NC}"
                    [[ -n "$ftp_user" ]] && echo -e "   ${YELLOW}User: $ftp_user${NC}"
                fi
                echo ""
                pause_any_key
                ;;
            5)
                echo ""
                echo -e "${CYAN}Sessions FTP actives:${NC}"
                echo -e "${CYAN}════════════════════════════════════════${NC}"
                # Verificare sessioni FTP attive
                local ftp_sessions=$(ss -tn sport = :21 2>/dev/null | grep ESTABLISHED | wc -l)
                echo -e "${YELLOW}Connexions établies sur port 21: ${ftp_sessions}${NC}"
                echo ""
                ss -tnp sport = :21 2>/dev/null | grep ESTABLISHED | while read line; do
                    echo -e "   ${CYAN}$line${NC}"
                done
                # Processi proftpd
                echo ""
                echo -e "${YELLOW}Processus ProFTPD:${NC}"
                ps aux | grep "[p]roftpd" | while read line; do
                    echo -e "   ${WHITE}$line${NC}"
                done
                echo ""
                pause_any_key
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

# ═══════════════════════════════════════════════════════════════
# MENU PRINCIPAL SERVICES
# ═══════════════════════════════════════════════════════════════

menu_services() {
    while true; do
        # Snapshot rapido degli stati
        local hl7_services
        read -ra hl7_services <<< "$(scan_hl7_services)"
        local hl7_count=${#hl7_services[@]}
        local hl7_active=0
        for svc in "${hl7_services[@]}"; do
            [[ "$(get_service_status "$svc")" == "active" ]] && ((hl7_active++))
        done

        local proftpd_status=$(get_service_status "proftpd")
        local proftpd_icon=""
        [[ "$proftpd_status" == "active" ]] && proftpd_icon="${GREEN}●${NC}" || proftpd_icon="${RED}○${NC}"

        show_header
        echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${WHITE}│                    GESTION DES SERVICES                     │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"

        # Stato HL7
        if [[ $hl7_count -eq 0 ]]; then
            echo -e "${WHITE}│  ${YELLOW}⚠️  HL7:      Aucun service détecté                        │${NC}"
        else
            local hl7_status_str="${GREEN}${hl7_active}/${hl7_count} actif(s)${NC}"
            if [[ $hl7_active -eq 0 ]]; then
                hl7_status_str="${RED}0/${hl7_count} actif(s)${NC}"
            elif [[ $hl7_active -lt $hl7_count ]]; then
                hl7_status_str="${YELLOW}${hl7_active}/${hl7_count} actif(s)${NC}"
            fi
            format_menu_row "${PURPLE}HL7:     ${NC}${hl7_status_str}" ""
        fi

        # Stato ProFTPD
        format_menu_row "${BLUE}ProFTPD: ${NC}${proftpd_icon} ${proftpd_status}" ""

        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  ${PURPLE}1. Services HL7    ${WHITE}│ Scan et gestion connecteurs HL7     │${NC}"
        echo -e "${WHITE}│  ${BLUE}2. ProFTPD         ${WHITE}│ Gestion serveur FTP                 │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  ${CYAN}3. Statut global   ${WHITE}│ Vue d'ensemble tous les services    │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  ${WHITE}0. Retour          ${WHITE}│ Menu TU TOOLS                       │${NC}"
        echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
        echo ""

        read -p "$(echo -e "${CYAN}Sélectionnez une option [0-3]: ${NC}")" choice

        case "$choice" in
            1) menu_hl7_management ;;
            2) menu_proftpd ;;
            3) show_services_overview ;;
            0) break ;;
            *)
                echo -e "${RED}Choix non valide${NC}"
                sleep 1
                ;;
        esac
    done
}

# Vue d'ensemble de tutti i servizi
show_services_overview() {
    show_header
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                   VUE D'ENSEMBLE SERVICES                   │${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # HL7
    echo -e "${PURPLE}═══ SERVICES HL7 ═══${NC}"
    local -a hl7_services
    read -ra hl7_services <<< "$(scan_hl7_services)"

    if [[ ${#hl7_services[@]} -eq 0 ]]; then
        echo -e "  ${YELLOW}⚠️  Aucun service HL7 détecté${NC}"
    else
        for svc in "${hl7_services[@]}"; do
            local status=$(get_service_status "$svc")
            local mode=$(detect_service_mode "$svc")
            if [[ "$status" == "active" ]]; then
                echo -e "  ${GREEN}● $svc${NC} ${CYAN}[$mode]${NC} - ${GREEN}actif${NC}"
            else
                echo -e "  ${RED}○ $svc${NC} ${CYAN}[$mode]${NC} - ${RED}inactif${NC}"
            fi
        done
    fi

    echo ""

    # ProFTPD
    echo -e "${BLUE}═══ PROFTPD ═══${NC}"
    local proftpd_status=$(get_service_status "proftpd")
    local proftpd_mode=$(detect_service_mode "proftpd")
    if [[ "$proftpd_status" == "active" ]]; then
        echo -e "  ${GREEN}● proftpd${NC} ${CYAN}[$proftpd_mode]${NC} - ${GREEN}actif${NC}"
    elif [[ "$proftpd_mode" == "unknown" ]]; then
        echo -e "  ${RED}○ proftpd${NC} - ${RED}non installé${NC}"
    else
        echo -e "  ${RED}○ proftpd${NC} ${CYAN}[$proftpd_mode]${NC} - ${RED}inactif${NC}"
    fi

    echo ""
    pause_any_key
}

# Export
export -f detect_service_mode
export -f get_service_status
export -f service_action
export -f scan_hl7_services
export -f show_hl7_status
export -f menu_hl7_management
export -f menu_single_hl7_service
export -f menu_proftpd
export -f menu_services
export -f show_services_overview
