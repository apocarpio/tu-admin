#!/bin/bash
# Module Système - Informations et monitoring système

# Fonction show_system_info - COPIATA ESATTAMENTE DALL'ORIGINALE
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
        echo -e "${CYAN}🐧 Distribution        : ${GREEN}$NAME $VERSION${NC}"
        echo -e "${CYAN}📋 ID Distribution      : ${WHITE}$ID${NC}"
        if [[ -n "$VERSION_CODENAME" ]]; then
            echo -e "${CYAN}🏷️  Nom de code         : ${PURPLE}$VERSION_CODENAME${NC}"
        fi
        if [[ -n "$PRETTY_NAME" ]]; then
            echo -e "${CYAN}✨ Nom complet          : ${BLUE}$PRETTY_NAME${NC}"
        fi
    else
        echo -e "${CYAN}🐧 Distribution        : ${RED}Non identifiée${NC}"
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
    ip -4 addr show 2>/dev/null | grep -E "^[0-9]+:" | while read line; do
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

# Fonction show_processes
show_processes() {
    show_header
    echo -e "${WHITE}PROCESSUS${NC}"
    echo ""
    ps aux --sort=-%cpu | head -20
    pause_any_key
}

# Fonction show_performance
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

# Fonction show_disk_usage
show_disk_usage() {
    show_header
    echo -e "${WHITE}ESPACE DISQUE${NC}"
    echo ""
    df -h
    pause_any_key
}

# Fonction show_mounts
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

        read -p "$(echo -e "${CYAN}Sélectionnez une option [0-5]: ${NC}")" choice

        case "$choice" in
            1) show_system_info ;;
            2) show_processes ;;
            3) show_performance ;;
            4) show_disk_usage ;;
            5) show_mounts ;;
            0) break ;;
            *)
                echo -e "${RED}Choix non valide${NC}"
                sleep 1
                ;;
        esac
    done
}

# Export
export -f show_system_info
export -f show_processes
export -f show_performance
export -f show_disk_usage
export -f show_mounts
export -f menu_system
