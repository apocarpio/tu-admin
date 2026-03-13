#!/bin/bash
# Module Logs - Gestion et analyse des logs système

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

        read -p "$(echo -e "${CYAN}Sélectionnez une option [0-7]: ${NC}")" choice

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
                    trap '' INT
                    tail -f /var/log/syslog
                    trap - INT
                    echo ""
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
                    trap '' INT
                    tail -f /var/log/auth.log
                    trap - INT
                    echo ""
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

# Export
export -f menu_logs
