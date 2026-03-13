#!/bin/bash
# Module Réseau - Diagnostics et monitoring réseau

# Fonction pour tester la vitesse Internet
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

        read -p "$(echo -e "${CYAN}Sélectionnez [1-4]: ${NC}")" speedtest_choice

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
                    read -p "$(echo -e "${CYAN}ID du serveur (ou ENTER pour automatique): ${NC}")" server_id

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
        echo -e "${WHITE}   • Installation: ${YELLOW}apt install speedtest-cli${NC}"
        echo -e "${WHITE}   • Test manuel: ${YELLOW}speedtest-cli${NC}"
        echo -e "${WHITE}   • Test graphique: ${YELLOW}https://www.speedtest.net${NC}"
    fi

    pause_any_key
}

# Fonction show_network_connections
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

# Fonction network_diagnostics
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
    ip link show 2>/dev/null | grep -E "^[0-9]+:" | while read line; do
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

# Fonction monitor_network_traffic
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
    trap 'echo ""; echo -e "${YELLOW}Surveillance réseau arrêtée.${NC}"; trap - INT; return 0' INT
    while true; do
        clear
        show_network_stats
        sleep 3
    done
    trap - INT
}

# Fonction test_connectivity
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

# Fonction show_network_config
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
    ip addr show 2>/dev/null | grep -E "^[0-9]+:|inet " | while read line; do
        if [[ "$line" =~ ^[0-9]+: ]]; then
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

        read -p "$(echo -e "${CYAN}Sélectionnez une option [0-6]: ${NC}")" choice

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

# Export
export -f test_internet_speed
export -f show_network_connections
export -f network_diagnostics
export -f monitor_network_traffic
export -f test_connectivity
export -f show_network_config
export -f menu_network
