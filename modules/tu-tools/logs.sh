#!/bin/bash
# TU Tools - Gestion logs application

# Fonction pour consulter les logs de l'application TU
show_tu_logs() {
    show_header
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                    CONSULTATION LOGS TU                     │${NC}"
    echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
    
    if [[ -n "$DB_DATABASE" && -n "$DB_HOST" ]]; then
        echo -e "${WHITE}│  ${GREEN}Base: ${WHITE}${DB_DATABASE}@${DB_HOST}${NC}"
        
        local db_total_size=$(get_database_total_size)
        echo -e "${WHITE}│  ${BLUE}Taille de la base: ${CYAN}${db_total_size}${NC}"
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
        echo -e "${CYAN}Essayez: chmod 644 $log_file${NC}"
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

        read -p "$(echo -e "${CYAN}Sélectionnez une option [0-7]: ${NC}")" log_choice

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
                read -p "$(echo -e "${CYAN}Confirmer l affichage complet? [o/N]: ${NC}")" confirm
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
                read -p "$(echo -e "${CYAN}Terme à rechercher: ${NC}")" search_term
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
                trap '' INT
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
                trap - INT
                echo ""
                ;;
            7)
                echo -e "${RED}⚠️  ATTENTION: Cette opération va vider complètement le fichier de log!${NC}"
                read -p "$(echo -e "${YELLOW}Confirmer la suppression? [o/N]: ${NC}")" confirm_clear
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

# Export
export -f show_tu_logs
