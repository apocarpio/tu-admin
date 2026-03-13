#!/bin/bash
# Module Dépannage - Diagnostic et résolution rapide
# Regroupe les outils de résolution des problèmes courants serveur TU

# ═══════════════════════════════════════════════════════════════
# GESTION MÉMOIRE & SWAP
# ═══════════════════════════════════════════════════════════════

# Vue détaillée mémoire et swap
show_memory_detail() {
    show_header
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                   DÉTAIL MÉMOIRE & SWAP                     │${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # === RAM ===
    echo -e "${CYAN}═══ MÉMOIRE RAM ═══${NC}"
    free -h | head -2 | tail -1 | while read type total used free shared buff_cache available; do
        echo -e "  ${WHITE}Total       :${NC} ${GREEN}${total}${NC}"
        echo -e "  ${WHITE}Utilisée    :${NC} ${YELLOW}${used}${NC}"
        echo -e "  ${WHITE}Libre       :${NC} ${GREEN}${free}${NC}"
        echo -e "  ${WHITE}Buff/Cache  :${NC} ${BLUE}${buff_cache}${NC}"
        echo -e "  ${WHITE}Disponible  :${NC} ${GREEN}${available}${NC}"
    done
    echo ""

    # === SWAP ===
    echo -e "${CYAN}═══ SWAP ═══${NC}"
    local swap_total=$(grep "SwapTotal" /proc/meminfo | awk '{print $2}')
    local swap_free=$(grep "SwapFree" /proc/meminfo | awk '{print $2}')
    local swap_used=$((swap_total - swap_free))

    if [[ $swap_total -eq 0 ]]; then
        echo -e "  ${RED}Swap non configuré${NC}"
    else
        local swap_total_mb=$((swap_total / 1024))
        local swap_used_mb=$((swap_used / 1024))
        local swap_free_mb=$((swap_free / 1024))
        local swap_percent=$((swap_used * 100 / swap_total))

        local color="${GREEN}"
        [[ $swap_percent -gt 50 ]] && color="${YELLOW}"
        [[ $swap_percent -gt 80 ]] && color="${RED}"

        echo -e "  ${WHITE}Total       :${NC} ${GREEN}${swap_total_mb} MB${NC}"
        echo -e "  ${WHITE}Utilisé     :${NC} ${color}${swap_used_mb} MB (${swap_percent}%)${NC}"
        echo -e "  ${WHITE}Libre       :${NC} ${GREEN}${swap_free_mb} MB${NC}"

        # Swap devices
        echo ""
        echo -e "  ${WHITE}Périphériques swap:${NC}"
        swapon --show 2>/dev/null | while IFS= read -r line; do
            echo -e "  ${CYAN}  $line${NC}"
        done
    fi

    echo ""

    # === SWAPPINESS ===
    local swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null)
    echo -e "${CYAN}═══ PARAMÈTRES ═══${NC}"
    echo -e "  ${WHITE}Swappiness  :${NC} ${GREEN}${swappiness}${NC} (0=évite swap, 100=swap agressif)"
    local vfs_cache=$(cat /proc/sys/vm/vfs_cache_pressure 2>/dev/null)
    echo -e "  ${WHITE}Cache press.:${NC} ${GREEN}${vfs_cache}${NC} (100=défaut)"

    # === OOM Score ===
    echo ""
    echo -e "${CYAN}═══ PRESSION MÉMOIRE ═══${NC}"
    if [[ -f /proc/pressure/memory ]]; then
        echo -e "  ${WHITE}PSI Memory:${NC}"
        cat /proc/pressure/memory | while IFS= read -r line; do
            echo -e "  ${YELLOW}  $line${NC}"
        done
    fi

    # Derniers OOM kills
    local oom_count=$(dmesg 2>/dev/null | grep -ci "out of memory\|oom-killer" || echo "0")
    if [[ $oom_count -gt 0 ]]; then
        echo -e "  ${RED}OOM Killer activé: ${oom_count} fois depuis le boot${NC}"
        echo -e "  ${YELLOW}Derniers événements:${NC}"
        dmesg 2>/dev/null | grep -i "out of memory\|killed process" | tail -3 | while IFS= read -r line; do
            echo -e "  ${RED}  $line${NC}"
        done
    else
        echo -e "  ${GREEN}Aucun OOM Kill détecté depuis le boot${NC}"
    fi

    echo ""
    pause_any_key
}

# Processus qui consomment le plus de swap
show_swap_by_process() {
    show_header
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│              UTILISATION SWAP PAR PROCESSUS                 │${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    local swap_total=$(grep "SwapTotal" /proc/meminfo | awk '{print $2}')
    if [[ $swap_total -eq 0 ]]; then
        echo -e "  ${YELLOW}Swap non configuré sur ce système${NC}"
        pause_any_key
        return
    fi

    local swap_used=$((swap_total - $(grep "SwapFree" /proc/meminfo | awk '{print $2}')))
    if [[ $swap_used -lt 100 ]]; then
        echo -e "  ${GREEN}Swap quasi vide — rien à signaler${NC}"
        pause_any_key
        return
    fi

    echo -e "${YELLOW}Analyse des processus utilisant la swap...${NC}"
    echo ""
    printf "  ${WHITE}%-8s %-6s %-12s %s${NC}\n" "PID" "SWAP" "USER" "COMMANDE"
    echo -e "  ${CYAN}──────────────────────────────────────────────────────${NC}"

    local found=0
    for pid_dir in /proc/[0-9]*; do
        local pid=$(basename "$pid_dir")
        local swap_kb=0

        if [[ -f "$pid_dir/smaps_rollup" ]]; then
            swap_kb=$(grep "^Swap:" "$pid_dir/smaps_rollup" 2>/dev/null | awk '{sum+=$2} END{print sum+0}')
        elif [[ -f "$pid_dir/smaps" ]]; then
            swap_kb=$(grep "^Swap:" "$pid_dir/smaps" 2>/dev/null | awk '{sum+=$2} END{print sum+0}')
        fi

        if [[ $swap_kb -gt 0 ]]; then
            local cmd=$(cat "$pid_dir/comm" 2>/dev/null || echo "?")
            local user=$(stat -c '%U' "$pid_dir" 2>/dev/null || echo "?")
            echo "${swap_kb} ${pid} ${user} ${cmd}"
            found=1
        fi
    done | sort -rn | head -20 | while read swap_kb pid user cmd; do
        local swap_mb=$((swap_kb / 1024))
        local color="${GREEN}"
        [[ $swap_mb -gt 100 ]] && color="${YELLOW}"
        [[ $swap_mb -gt 500 ]] && color="${RED}"

        printf "  ${WHITE}%-8s${NC} ${color}%-6s${NC} ${CYAN}%-12s${NC} %s\n" \
               "$pid" "${swap_mb}M" "$user" "$cmd"
    done

    if [[ $found -eq 0 ]]; then
        echo -e "  ${GREEN}Aucun processus n'utilise la swap${NC}"
    fi

    echo ""
    pause_any_key
}

# Purge sécurisée de la swap
flush_swap() {
    show_header
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                   PURGE DE LA SWAP                          │${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # Vérifier si swap est active
    local swap_total=$(grep "SwapTotal" /proc/meminfo | awk '{print $2}')
    if [[ $swap_total -eq 0 ]]; then
        echo -e "  ${YELLOW}Swap non configuré — rien à purger${NC}"
        pause_any_key
        return
    fi

    local swap_free=$(grep "SwapFree" /proc/meminfo | awk '{print $2}')
    local swap_used=$((swap_total - swap_free))
    local swap_used_mb=$((swap_used / 1024))

    if [[ $swap_used_mb -lt 1 ]]; then
        echo -e "  ${GREEN}Swap déjà vide — rien à purger${NC}"
        pause_any_key
        return
    fi

    # Vérifier RAM disponible AVANT de purger
    local mem_available=$(grep "MemAvailable" /proc/meminfo | awk '{print $2}')
    local mem_available_mb=$((mem_available / 1024))

    echo -e "${CYAN}═══ ÉTAT ACTUEL ═══${NC}"
    echo -e "  ${WHITE}Swap utilisé    :${NC} ${YELLOW}${swap_used_mb} MB${NC}"
    echo -e "  ${WHITE}RAM disponible  :${NC} ${GREEN}${mem_available_mb} MB${NC}"
    echo ""

    # Vérification de sécurité: assez de RAM libre?
    if [[ $mem_available -lt $swap_used ]]; then
        local deficit_mb=$(( (swap_used - mem_available) / 1024 ))
        echo -e "  ${RED}ATTENTION: RAM insuffisante pour absorber la swap!${NC}"
        echo -e "  ${RED}Il manque environ ${deficit_mb} MB de RAM libre.${NC}"
        echo -e "  ${YELLOW}La purge pourrait provoquer l'OOM Killer.${NC}"
        echo ""
        echo -e "  ${WHITE}Options:${NC}"
        echo -e "  ${CYAN}1.${NC} Forcer quand même (risqué)"
        echo -e "  ${CYAN}2.${NC} Purger partiellement (drop caches d'abord)"
        echo -e "  ${CYAN}0.${NC} Annuler"
        echo ""
        read -p "$(echo -e "${CYAN}Choix [0-2]: ${NC}")" force_choice

        case "$force_choice" in
            1)
                echo ""
                echo -e "${RED}Purge forcée en cours...${NC}"
                ;;
            2)
                echo ""
                echo -e "${YELLOW}Libération des caches système d'abord...${NC}"
                sync
                echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
                sleep 1
                mem_available=$(grep "MemAvailable" /proc/meminfo | awk '{print $2}')
                mem_available_mb=$((mem_available / 1024))
                echo -e "  ${GREEN}RAM disponible après drop caches: ${mem_available_mb} MB${NC}"
                echo ""
                if [[ $mem_available -lt $swap_used ]]; then
                    echo -e "  ${RED}Toujours insuffisant. Abandon.${NC}"
                    pause_any_key
                    return
                fi
                echo -e "  ${GREEN}OK, assez de RAM maintenant.${NC}"
                ;;
            *)
                echo -e "  ${WHITE}Annulé.${NC}"
                pause_any_key
                return
                ;;
        esac
    else
        local margin_mb=$(( (mem_available - swap_used) / 1024 ))
        echo -e "  ${GREEN}RAM suffisante (marge: ${margin_mb} MB)${NC}"
        echo ""
        if ! ask_confirmation "Purger la swap (${swap_used_mb} MB) ?"; then
            pause_any_key
            return
        fi
    fi

    # Exécution de la purge
    echo ""
    echo -e "${YELLOW}Désactivation de la swap...${NC}"
    local start_time=$(date +%s)
    swapoff -a 2>&1
    local swapoff_rc=$?

    if [[ $swapoff_rc -eq 0 ]]; then
        echo -e "${GREEN}Swap désactivée.${NC}"
        echo -e "${YELLOW}Réactivation de la swap...${NC}"
        swapon -a 2>&1
        local swapon_rc=$?
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))

        if [[ $swapon_rc -eq 0 ]]; then
            echo -e "${GREEN}Swap réactivée avec succès.${NC}"
            echo ""
            echo -e "${CYAN}═══ RÉSULTAT ═══${NC}"
            echo -e "  ${WHITE}Swap libérée    :${NC} ${GREEN}${swap_used_mb} MB${NC}"
            echo -e "  ${WHITE}Durée           :${NC} ${GREEN}${duration} secondes${NC}"

            local new_swap_used=$(( $(grep "SwapTotal" /proc/meminfo | awk '{print $2}') - $(grep "SwapFree" /proc/meminfo | awk '{print $2}') ))
            local new_swap_used_mb=$((new_swap_used / 1024))
            echo -e "  ${WHITE}Swap actuel     :${NC} ${GREEN}${new_swap_used_mb} MB${NC}"

            log_action "SWAP Flush" "INFO" "Libéré: ${swap_used_mb}MB en ${duration}s"
        else
            echo -e "${RED}Erreur à la réactivation de la swap!${NC}"
            echo -e "${YELLOW}Tentative manuelle: swapon -a${NC}"
            log_action "SWAP Flush" "ERROR" "Erreur swapon"
        fi
    else
        echo -e "${RED}Erreur à la désactivation de la swap!${NC}"
        echo -e "${YELLOW}Processus utilisant la swap peuvent bloquer l'opération.${NC}"
        echo -e "${YELLOW}Vérifiez avec l'option 'Swap par processus'.${NC}"
        log_action "SWAP Flush" "ERROR" "Erreur swapoff"
    fi

    echo ""
    pause_any_key
}

# Modifier le swappiness
configure_swappiness() {
    show_header
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                 CONFIGURATION SWAPPINESS                    │${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    local current=$(cat /proc/sys/vm/swappiness 2>/dev/null)
    echo -e "${CYAN}═══ VALEUR ACTUELLE ═══${NC}"
    echo -e "  ${WHITE}Swappiness :${NC} ${GREEN}${current}${NC}"
    echo ""

    echo -e "${CYAN}═══ GUIDE ═══${NC}"
    echo -e "  ${WHITE} 0${NC}  = N'utilise la swap qu'en dernier recours"
    echo -e "  ${WHITE}10${NC}  = ${GREEN}Recommandé serveur (TU)${NC} — swap minimale"
    echo -e "  ${WHITE}30${NC}  = Bon compromis usage mixte"
    echo -e "  ${WHITE}60${NC}  = Défaut Debian — swap modérée"
    echo -e "  ${WHITE}100${NC} = Swap agressive"
    echo ""

    echo -e "${CYAN}═══ VALEURS PRÉDÉFINIES ═══${NC}"
    echo -e "  ${CYAN}1.${NC} Serveur TU (swappiness=10) ${GREEN}— Recommandé${NC}"
    echo -e "  ${CYAN}2.${NC} Compromis (swappiness=30)"
    echo -e "  ${CYAN}3.${NC} Défaut Debian (swappiness=60)"
    echo -e "  ${CYAN}4.${NC} Valeur personnalisée"
    echo -e "  ${CYAN}0.${NC} Annuler"
    echo ""

    read -p "$(echo -e "${CYAN}Choix [0-4]: ${NC}")" choice

    local new_value=""
    case "$choice" in
        1) new_value=10 ;;
        2) new_value=30 ;;
        3) new_value=60 ;;
        4)
            read -p "$(echo -e "${CYAN}Valeur [0-100]: ${NC}")" new_value
            if ! [[ "$new_value" =~ ^[0-9]+$ ]] || [[ $new_value -gt 100 ]]; then
                echo -e "${RED}Valeur invalide${NC}"
                pause_any_key
                return
            fi
            ;;
        0) return ;;
        *) echo -e "${RED}Choix non valide${NC}"; pause_any_key; return ;;
    esac

    if [[ -n "$new_value" ]]; then
        sysctl vm.swappiness=$new_value > /dev/null 2>&1
        echo ""
        echo -e "${GREEN}Swappiness modifié: ${current} → ${new_value}${NC}"

        echo ""
        if ask_confirmation "Rendre permanent (survit au reboot) ?"; then
            if grep -q "^vm.swappiness" /etc/sysctl.conf 2>/dev/null; then
                sed -i "s/^vm.swappiness.*/vm.swappiness=${new_value}/" /etc/sysctl.conf
            else
                echo "vm.swappiness=${new_value}" >> /etc/sysctl.conf
            fi
            echo -e "${GREEN}Ajouté à /etc/sysctl.conf${NC}"
        else
            echo -e "${YELLOW}Changement temporaire (perdu au reboot)${NC}"
        fi

        log_action "Swappiness" "INFO" "Modifié: ${current} → ${new_value}"
    fi

    pause_any_key
}

# Drop caches système
drop_system_caches() {
    show_header
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                 LIBÉRATION CACHES SYSTÈME                   │${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    local mem_before=$(grep "MemAvailable" /proc/meminfo | awk '{print $2}')
    local cached_before=$(grep "^Cached:" /proc/meminfo | awk '{print $2}')
    local buffers_before=$(grep "^Buffers:" /proc/meminfo | awk '{print $2}')

    echo -e "${CYAN}═══ AVANT PURGE ═══${NC}"
    echo -e "  ${WHITE}RAM disponible :${NC} ${GREEN}$((mem_before / 1024)) MB${NC}"
    echo -e "  ${WHITE}Cache          :${NC} ${YELLOW}$((cached_before / 1024)) MB${NC}"
    echo -e "  ${WHITE}Buffers        :${NC} ${YELLOW}$((buffers_before / 1024)) MB${NC}"
    echo ""

    echo -e "${CYAN}═══ OPTIONS ═══${NC}"
    echo -e "  ${CYAN}1.${NC} Page cache uniquement (safe)"
    echo -e "  ${CYAN}2.${NC} Dentries et inodes (safe)"
    echo -e "  ${CYAN}3.${NC} Tout (page cache + dentries + inodes) ${GREEN}— Recommandé${NC}"
    echo -e "  ${CYAN}0.${NC} Annuler"
    echo ""

    read -p "$(echo -e "${CYAN}Choix [0-3]: ${NC}")" choice

    case "$choice" in
        1|2|3)
            echo ""
            echo -e "${YELLOW}Synchronisation des données sur disque...${NC}"
            sync
            echo -e "${YELLOW}Libération des caches (niveau ${choice})...${NC}"
            echo "$choice" > /proc/sys/vm/drop_caches 2>/dev/null

            sleep 1

            local mem_after=$(grep "MemAvailable" /proc/meminfo | awk '{print $2}')
            local cached_after=$(grep "^Cached:" /proc/meminfo | awk '{print $2}')
            local freed=$((mem_after - mem_before))
            local freed_mb=$((freed / 1024))

            echo ""
            echo -e "${CYAN}═══ APRÈS PURGE ═══${NC}"
            echo -e "  ${WHITE}RAM disponible :${NC} ${GREEN}$((mem_after / 1024)) MB${NC}"
            echo -e "  ${WHITE}Cache          :${NC} ${GREEN}$((cached_after / 1024)) MB${NC}"
            echo -e "  ${WHITE}RAM libérée    :${NC} ${GREEN}${freed_mb} MB${NC}"

            log_action "Drop Caches" "INFO" "Niveau: ${choice}, Libéré: ${freed_mb}MB"
            ;;
        0) return ;;
        *) echo -e "${RED}Choix non valide${NC}" ;;
    esac

    echo ""
    pause_any_key
}

# Sous-menu mémoire & swap
menu_memory_swap() {
    while true; do
        local mem_total=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
        local mem_available=$(grep "MemAvailable" /proc/meminfo | awk '{print $2}')
        local mem_percent=$(( (mem_total - mem_available) * 100 / mem_total ))

        local swap_total=$(grep "SwapTotal" /proc/meminfo | awk '{print $2}')
        local swap_info=""
        if [[ $swap_total -gt 0 ]]; then
            local swap_free=$(grep "SwapFree" /proc/meminfo | awk '{print $2}')
            local swap_used_mb=$(( (swap_total - swap_free) / 1024 ))
            local swap_percent=$(( (swap_total - swap_free) * 100 / swap_total ))
            local swap_color="${GREEN}"
            [[ $swap_percent -gt 50 ]] && swap_color="${YELLOW}"
            [[ $swap_percent -gt 80 ]] && swap_color="${RED}"
            swap_info="${swap_color}${swap_used_mb} MB (${swap_percent}%)${NC}"
        else
            swap_info="${YELLOW}Non configuré${NC}"
        fi

        local mem_color="${GREEN}"
        [[ $mem_percent -gt 70 ]] && mem_color="${YELLOW}"
        [[ $mem_percent -gt 90 ]] && mem_color="${RED}"

        local swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null)

        show_header
        echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${WHITE}│                    MÉMOIRE & SWAP                           │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        format_menu_row "RAM:  ${mem_color}${mem_percent}% utilisée${NC}" ""
        format_menu_row "SWAP: ${swap_info}" ""
        format_menu_row "Swappiness: ${GREEN}${swappiness}${NC}" ""
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  ${GREEN}1. Détail mémoire    ${WHITE}│ RAM, swap, caches, pression      │${NC}"
        echo -e "${WHITE}│  ${YELLOW}2. Swap par process  ${WHITE}│ Qui consomme la swap             │${NC}"
        echo -e "${WHITE}│  ${RED}3. Purger la swap    ${WHITE}│ swapoff/swapon sécurisé          │${NC}"
        echo -e "${WHITE}│  ${CYAN}4. Drop caches       ${WHITE}│ Libérer caches page/dentries     │${NC}"
        echo -e "${WHITE}│  ${BLUE}5. Swappiness        ${WHITE}│ Configurer vm.swappiness         │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  ${WHITE}0. Retour            ${WHITE}│ Menu dépannage                   │${NC}"
        echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
        echo ""

        read -p "$(echo -e "${CYAN}Sélectionnez une option [0-5]: ${NC}")" choice

        case "$choice" in
            1) show_memory_detail ;;
            2) show_swap_by_process ;;
            3) flush_swap ;;
            4) drop_system_caches ;;
            5) configure_swappiness ;;
            0) break ;;
            *)
                echo -e "${RED}Choix non valide${NC}"
                sleep 1
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════
# DIAGNOSTIC & NETTOYAGE ESPACE DISQUE
# ═══════════════════════════════════════════════════════════════

# Nombre de catégories de nettoyage
DISK_CLEAN_CATEGORIES=7

# Convertir KB en format lisible
_format_size_kb() {
    local kb=$1
    if [[ $kb -ge 1048576 ]]; then
        echo "$((kb / 1048576)) GB"
    elif [[ $kb -ge 1024 ]]; then
        echo "$((kb / 1024)) MB"
    else
        echo "${kb} KB"
    fi
}

# Scanner la taille des logs système nettoyables
_scan_logs_system() {
    # Logs compressés et rotated (sans journald, compté séparément cat.7)
    find /var/log -type f \( -name "*.gz" -o -name "*.old" -o -name "*.[0-9]" \) \
        -not -path "*/journal/*" -not -path "*/apache2/*" -not -path "*/nginx/*" \
        2>/dev/null | xargs --no-run-if-empty du -sk 2>/dev/null | awk '{sum+=$1} END{print sum+0}'
}

# Scanner cache APT
_scan_cache_apt() {
    du -sk /var/cache/apt/archives/ 2>/dev/null | awk '{print $1}'
}

# Scanner fichiers temporaires > 7 jours
_scan_tmp_files() {
    local total=0
    local tmp_size=$(find /tmp -type f -atime +7 2>/dev/null | xargs --no-run-if-empty du -sk 2>/dev/null | awk '{sum+=$1} END{print sum+0}')
    total=$((total + tmp_size))
    local vartmp_size=$(find /var/tmp -type f -atime +7 2>/dev/null | xargs --no-run-if-empty du -sk 2>/dev/null | awk '{sum+=$1} END{print sum+0}')
    total=$((total + vartmp_size))
    echo "$total"
}

# Scanner anciens kernels
_scan_old_kernels() {
    local current_kernel=$(uname -r)
    # Utiliser dpkg-query Installed-Size (en KB) pour éviter le double comptage
    dpkg-query -W -f='${Package} ${Installed-Size}\n' 'linux-image-*' 2>/dev/null | \
        grep -v "$current_kernel" | grep -v "meta" | \
        awk '{sum+=$2} END{print sum+0}'
}

# Scanner logs Apache/Nginx
_scan_logs_web() {
    local total=0
    if [[ -d /var/log/apache2 ]]; then
        local apache_gz=$(find /var/log/apache2 -name "*.gz" -o -name "*.old" -o -name "*.[0-9]" 2>/dev/null | xargs --no-run-if-empty du -sk 2>/dev/null | awk '{sum+=$1} END{print sum+0}')
        total=$((total + apache_gz))
    fi
    if [[ -d /var/log/nginx ]]; then
        local nginx_gz=$(find /var/log/nginx -name "*.gz" -o -name "*.old" -o -name "*.[0-9]" 2>/dev/null | xargs --no-run-if-empty du -sk 2>/dev/null | awk '{sum+=$1} END{print sum+0}')
        total=$((total + nginx_gz))
    fi
    echo "$total"
}

# Scanner les gros fichiers inutiles (core dumps, crash reports)
_scan_crash_files() {
    local total=0
    # Core dumps (seulement fichiers > 1MB pour éviter faux positifs)
    local cores=$(find /tmp /var/tmp /home /root -maxdepth 2 -type f \( -name "core" -o -name "core.[0-9]*" \) -size +1M 2>/dev/null | xargs --no-run-if-empty du -sk 2>/dev/null | awk '{sum+=$1} END{print sum+0}')
    total=$((total + cores))
    # Crash reports
    if [[ -d /var/crash ]]; then
        local crash=$(du -sk /var/crash 2>/dev/null | awk '{print $1}')
        total=$((total + crash))
    fi
    echo "$total"
}

# Scanner problèmes inodes
_scan_inodes() {
    # Retourne le nombre de fichiers dans les répertoires les plus peuplés
    local inode_usage=$(df -i /var 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//')
    echo "${inode_usage:-0}"
}

# Diagnostic complet espace disque avec checklist interactive
menu_disk_cleanup() {
    show_header
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│              DIAGNOSTIC ESPACE DISQUE                       │${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # État actuel des disques
    echo -e "${CYAN}═══ ÉTAT DES DISQUES ═══${NC}"
    df -h / /var /tmp /home 2>/dev/null | sort -u | while IFS= read -r line; do
        if echo "$line" | grep -q "^Filesystem\|^Sys"; then
            echo -e "  ${WHITE}$line${NC}"
        else
            local pct=$(echo "$line" | awk '{print $5}' | sed 's/%//')
            local color="${GREEN}"
            [[ -n "$pct" && "$pct" =~ ^[0-9]+$ ]] && {
                [[ $pct -gt 80 ]] && color="${YELLOW}"
                [[ $pct -gt 90 ]] && color="${RED}"
            }
            echo -e "  ${color}$line${NC}"
        fi
    done

    # Inodes
    echo ""
    echo -e "${CYAN}═══ INODES ═══${NC}"
    df -ih / /var 2>/dev/null | sort -u | while IFS= read -r line; do
        if echo "$line" | grep -q "^Filesystem\|^Sys"; then
            echo -e "  ${WHITE}$line${NC}"
        else
            local pct=$(echo "$line" | awk '{print $5}' | sed 's/%//')
            local color="${GREEN}"
            [[ -n "$pct" && "$pct" =~ ^[0-9]+$ ]] && {
                [[ $pct -gt 70 ]] && color="${YELLOW}"
                [[ $pct -gt 90 ]] && color="${RED}"
            }
            echo -e "  ${color}$line${NC}"
        fi
    done

    echo ""
    echo -e "${YELLOW}Analyse en cours (peut prendre quelques secondes)...${NC}"
    echo ""

    # === Scanner toutes les catégories ===
    local -a cat_names
    local -a cat_sizes
    local -a cat_selected
    local -a cat_descriptions

    cat_names[1]="Logs système compressés"
    cat_descriptions[1]="/var/log/*.gz, *.old, rotated"
    cat_sizes[1]=$(_scan_logs_system)
    cat_selected[1]=1

    cat_names[2]="Cache APT"
    cat_descriptions[2]="/var/cache/apt/archives/"
    cat_sizes[2]=$(_scan_cache_apt)
    cat_selected[2]=1

    cat_names[3]="Fichiers temporaires"
    cat_descriptions[3]="/tmp et /var/tmp > 7 jours"
    cat_sizes[3]=$(_scan_tmp_files)
    cat_selected[3]=1

    cat_names[4]="Logs web (Apache/Nginx)"
    cat_descriptions[4]="Logs compressés et rotated"
    cat_sizes[4]=$(_scan_logs_web)
    cat_selected[4]=1

    cat_names[5]="Anciens kernels"
    cat_descriptions[5]="Images kernel inutilisées"
    cat_sizes[5]=$(_scan_old_kernels)
    cat_selected[5]=0

    cat_names[6]="Core dumps & crash"
    cat_descriptions[6]="Fichiers core, /var/crash"
    cat_sizes[6]=$(_scan_crash_files)
    cat_selected[6]=1

    cat_names[7]="Journald (>3 jours)"
    cat_descriptions[7]="Logs systemd-journal anciens"
    cat_sizes[7]=0
    cat_selected[7]=1
    # Calcul spécifique journald
    local journal_bytes=$(journalctl --disk-usage 2>/dev/null | grep -oP '[0-9.]+' | head -1)
    local journal_unit=$(journalctl --disk-usage 2>/dev/null | grep -oP '[MG]' | head -1)
    if [[ "$journal_unit" == "G" ]]; then
        cat_sizes[7]=$(echo "${journal_bytes:-0}" | awk '{printf "%d", $1 * 1048576}')
    elif [[ "$journal_unit" == "M" ]]; then
        cat_sizes[7]=$(echo "${journal_bytes:-0}" | awk '{printf "%d", $1 * 1024}')
    fi

    # === Boucle interactive ===
    while true; do
        clear
        show_header
        echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${WHITE}│            NETTOYAGE ESPACE DISQUE                          │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"

        local total_selected=0

        for i in $(seq 1 $DISK_CLEAN_CATEGORIES); do
            local check=" "
            local color="${WHITE}"
            if [[ ${cat_selected[$i]} -eq 1 ]]; then
                check="x"
                color="${GREEN}"
                total_selected=$((total_selected + ${cat_sizes[$i]:-0}))
            fi

            local size_str=$(_format_size_kb ${cat_sizes[$i]:-0})

            # Griser si rien à nettoyer
            if [[ ${cat_sizes[$i]:-0} -eq 0 ]]; then
                color="${WHITE}"
                check="-"
                echo -e "${WHITE}│  ${WHITE}${i}. [${check}] ${cat_names[$i]}"
                printf "%-61s│\n" "       ${cat_descriptions[$i]} (vide)"
            else
                echo -e "${WHITE}│  ${color}${i}. [${check}] ${cat_names[$i]}${NC}"
                local size_color="${GREEN}"
                [[ ${cat_sizes[$i]:-0} -gt 1048576 ]] && size_color="${RED}"
                [[ ${cat_sizes[$i]:-0} -gt 102400 ]] && size_color="${YELLOW}"
                echo -e "${WHITE}│       ${CYAN}${cat_descriptions[$i]}  ${size_color}libérable: ${size_str}${NC}"
            fi
        done

        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        local total_str=$(_format_size_kb $total_selected)
        echo -e "${WHITE}│  ${YELLOW}TOTAL SÉLECTIONNÉ: ${GREEN}${total_str}${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  ${WHITE}[1-7] Cocher/décocher  ${GREEN}[P] Purger  ${CYAN}[A] Tout  ${RED}[0] Retour${NC}"
        echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
        echo ""

        read -p "$(echo -e "${CYAN}Choix: ${NC}")" choice

        case "$choice" in
            [1-7])
                # Toggle sélection (seulement si taille > 0)
                if [[ ${cat_sizes[$choice]:-0} -gt 0 ]]; then
                    if [[ ${cat_selected[$choice]} -eq 1 ]]; then
                        cat_selected[$choice]=0
                    else
                        cat_selected[$choice]=1
                    fi
                fi
                ;;
            a|A)
                # Tout sélectionner
                for i in $(seq 1 $DISK_CLEAN_CATEGORIES); do
                    [[ ${cat_sizes[$i]:-0} -gt 0 ]] && cat_selected[$i]=1
                done
                ;;
            p|P)
                if [[ $total_selected -eq 0 ]]; then
                    echo -e "${YELLOW}Rien à purger (total: 0)${NC}"
                    sleep 1
                    continue
                fi

                echo ""
                echo -e "${YELLOW}Éléments sélectionnés pour suppression:${NC}"
                for i in $(seq 1 $DISK_CLEAN_CATEGORIES); do
                    if [[ ${cat_selected[$i]} -eq 1 && ${cat_sizes[$i]:-0} -gt 0 ]]; then
                        echo -e "  ${CYAN}- ${cat_names[$i]} ($(_format_size_kb ${cat_sizes[$i]}))${NC}"
                    fi
                done
                echo ""
                echo -e "${WHITE}Total à libérer: ${GREEN}${total_str}${NC}"
                echo ""

                if ! ask_confirmation "Confirmer la purge ?"; then
                    continue
                fi

                echo ""
                local freed_total=0

                # 1. Logs système compressés
                if [[ ${cat_selected[1]} -eq 1 && ${cat_sizes[1]:-0} -gt 0 ]]; then
                    echo -e "${YELLOW}Nettoyage logs système compressés...${NC}"
                    find /var/log -name "*.gz" -delete 2>/dev/null
                    find /var/log -name "*.old" -delete 2>/dev/null
                    find /var/log -name "*.[0-9]" -not -name "*.log" -delete 2>/dev/null
                    freed_total=$((freed_total + ${cat_sizes[1]}))
                    echo -e "  ${GREEN}OK${NC}"
                fi

                # 2. Cache APT
                if [[ ${cat_selected[2]} -eq 1 && ${cat_sizes[2]:-0} -gt 0 ]]; then
                    echo -e "${YELLOW}Nettoyage cache APT...${NC}"
                    apt-get clean -y 2>/dev/null
                    freed_total=$((freed_total + ${cat_sizes[2]}))
                    echo -e "  ${GREEN}OK${NC}"
                fi

                # 3. Fichiers temporaires
                if [[ ${cat_selected[3]} -eq 1 && ${cat_sizes[3]:-0} -gt 0 ]]; then
                    echo -e "${YELLOW}Nettoyage fichiers temporaires > 7 jours...${NC}"
                    find /tmp -type f -atime +7 -delete 2>/dev/null
                    find /var/tmp -type f -atime +7 -delete 2>/dev/null
                    freed_total=$((freed_total + ${cat_sizes[3]}))
                    echo -e "  ${GREEN}OK${NC}"
                fi

                # 4. Logs web
                if [[ ${cat_selected[4]} -eq 1 && ${cat_sizes[4]:-0} -gt 0 ]]; then
                    echo -e "${YELLOW}Nettoyage logs web compressés...${NC}"
                    find /var/log/apache2 -name "*.gz" -delete 2>/dev/null
                    find /var/log/apache2 -name "*.old" -delete 2>/dev/null
                    find /var/log/nginx -name "*.gz" -delete 2>/dev/null
                    find /var/log/nginx -name "*.old" -delete 2>/dev/null
                    freed_total=$((freed_total + ${cat_sizes[4]}))
                    echo -e "  ${GREEN}OK${NC}"
                fi

                # 5. Anciens kernels
                if [[ ${cat_selected[5]} -eq 1 && ${cat_sizes[5]:-0} -gt 0 ]]; then
                    echo -e "${YELLOW}Suppression anciens kernels...${NC}"
                    apt-get autoremove --purge -y 2>/dev/null
                    freed_total=$((freed_total + ${cat_sizes[5]}))
                    echo -e "  ${GREEN}OK${NC}"
                fi

                # 6. Core dumps
                if [[ ${cat_selected[6]} -eq 1 && ${cat_sizes[6]:-0} -gt 0 ]]; then
                    echo -e "${YELLOW}Suppression core dumps et crash...${NC}"
                    find / -maxdepth 3 \( -name "core" -o -name "core.*" -o -name "*.core" \) -delete 2>/dev/null
                    rm -rf /var/crash/* 2>/dev/null
                    freed_total=$((freed_total + ${cat_sizes[6]}))
                    echo -e "  ${GREEN}OK${NC}"
                fi

                # 7. Journald
                if [[ ${cat_selected[7]} -eq 1 && ${cat_sizes[7]:-0} -gt 0 ]]; then
                    echo -e "${YELLOW}Nettoyage journald (conservation 3 jours)...${NC}"
                    journalctl --vacuum-time=3d 2>/dev/null
                    freed_total=$((freed_total + ${cat_sizes[7]}))
                    echo -e "  ${GREEN}OK${NC}"
                fi

                echo ""
                echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
                echo -e "${WHITE}│  ${GREEN}PURGE TERMINÉE${NC}"
                echo -e "${WHITE}│  ${WHITE}Espace libéré estimé: ${GREEN}$(_format_size_kb $freed_total)${NC}"
                echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"

                log_action "Disk Cleanup" "INFO" "Libéré estimé: $(_format_size_kb $freed_total)"

                echo ""
                echo -e "${CYAN}═══ ÉTAT DISQUES APRÈS NETTOYAGE ═══${NC}"
                df -h / /var /tmp 2>/dev/null | sort -u | while IFS= read -r line; do
                    echo -e "  ${GREEN}$line${NC}"
                done

                echo ""
                pause_any_key
                return
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}Choix non valide${NC}"
                sleep 1
                ;;
        esac
    done
}

# Analyse des gros fichiers
show_large_files() {
    show_header
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                    GROS FICHIERS                            │${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    echo -e "${CYAN}Où chercher ?${NC}"
    echo -e "  ${CYAN}1.${NC} /var (logs, cache, bases) ${GREEN}— Recommandé${NC}"
    echo -e "  ${CYAN}2.${NC} /home"
    echo -e "  ${CYAN}3.${NC} /tmp"
    echo -e "  ${CYAN}4.${NC} / (tout le système)"
    echo -e "  ${CYAN}5.${NC} Chemin personnalisé"
    echo -e "  ${CYAN}0.${NC} Retour"
    echo ""

    read -p "$(echo -e "${CYAN}Choix [0-5]: ${NC}")" choice

    local search_path=""
    case "$choice" in
        1) search_path="/var" ;;
        2) search_path="/home" ;;
        3) search_path="/tmp" ;;
        4) search_path="/" ;;
        5)
            read -p "$(echo -e "${CYAN}Chemin: ${NC}")" search_path
            if [[ ! -d "$search_path" ]]; then
                echo -e "${RED}Répertoire introuvable${NC}"
                pause_any_key
                return
            fi
            ;;
        0) return ;;
        *) echo -e "${RED}Choix non valide${NC}"; pause_any_key; return ;;
    esac

    echo ""
    echo -e "${YELLOW}Recherche des fichiers > 100 MB dans ${search_path}...${NC}"
    echo ""
    printf "  ${WHITE}%-10s %-50s${NC}\n" "TAILLE" "FICHIER"
    echo -e "  ${CYAN}──────────────────────────────────────────────────────${NC}"

    local count=0
    find "$search_path" -xdev -type f -size +100M 2>/dev/null | \
        xargs --no-run-if-empty du -sh 2>/dev/null | sort -rh | head -20 | while read size filepath; do
        local color="${YELLOW}"
        # Colorer en rouge si > 1G
        if echo "$size" | grep -q "G"; then
            color="${RED}"
        fi
        printf "  ${color}%-10s${NC} ${WHITE}%s${NC}\n" "$size" "$filepath"
        count=$((count + 1))
    done

    if [[ $count -eq 0 ]]; then
        echo -e "  ${GREEN}Aucun fichier > 100 MB trouvé${NC}"
    fi

    echo ""
    pause_any_key
}

# Diagnostic inodes
show_inode_diagnostic() {
    show_header
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│                  DIAGNOSTIC INODES                          │${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    echo -e "${CYAN}═══ UTILISATION INODES PAR PARTITION ═══${NC}"
    df -ih 2>/dev/null | while IFS= read -r line; do
        if echo "$line" | grep -q "^Filesystem\|^Sys"; then
            echo -e "  ${WHITE}$line${NC}"
        else
            local pct=$(echo "$line" | awk '{print $5}' | sed 's/%//')
            local color="${GREEN}"
            [[ -n "$pct" && "$pct" =~ ^[0-9]+$ ]] && {
                [[ $pct -gt 70 ]] && color="${YELLOW}"
                [[ $pct -gt 90 ]] && color="${RED}"
            }
            echo -e "  ${color}$line${NC}"
        fi
    done

    echo ""
    echo -e "${CYAN}═══ TOP 15 RÉPERTOIRES PAR NOMBRE DE FICHIERS ═══${NC}"
    echo -e "${YELLOW}Analyse en cours (scan /var, /tmp, /home)...${NC}"
    echo ""

    printf "  ${WHITE}%-10s %s${NC}\n" "FICHIERS" "RÉPERTOIRE"
    echo -e "  ${CYAN}──────────────────────────────────────────────────────${NC}"

    for dir in /var /tmp /home; do
        [[ -d "$dir" ]] || continue
        find "$dir" -maxdepth 3 -type d 2>/dev/null | while read d; do
            local fcount=$(find "$d" -maxdepth 1 -type f 2>/dev/null | wc -l)
            if [[ $fcount -gt 100 ]]; then
                echo "$fcount $d"
            fi
        done
    done | sort -rn | head -15 | while read count dir; do
        local color="${GREEN}"
        [[ $count -gt 10000 ]] && color="${RED}"
        [[ $count -gt 1000 ]] && color="${YELLOW}"
        printf "  ${color}%-10s${NC} ${WHITE}%s${NC}\n" "$count" "$dir"
    done

    echo ""
    echo -e "${CYAN}═══ CONSEILS ═══${NC}"
    local var_inode_pct=$(df -i /var 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ -n "$var_inode_pct" && "$var_inode_pct" =~ ^[0-9]+$ && $var_inode_pct -gt 70 ]]; then
        echo -e "  ${RED}/var est à ${var_inode_pct}% d'inodes !${NC}"
        echo -e "  ${YELLOW}Sources fréquentes de fichiers excessifs:${NC}"
        echo -e "  ${WHITE}  - Sessions PHP:     /var/lib/php/sessions/${NC}"
        echo -e "  ${WHITE}  - Cache applicatif: /var/cache/${NC}"
        echo -e "  ${WHITE}  - Logs applicatifs: /var/log/${NC}"
        echo -e "  ${WHITE}  - Mail queue:       /var/spool/mail/${NC}"
    else
        echo -e "  ${GREEN}Utilisation inodes normale${NC}"
    fi

    echo ""
    pause_any_key
}

# Sous-menu espace disque
menu_disk_space() {
    while true; do
        # Snapshot rapido disque
        local root_pct=$(df / 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//')
        local var_pct=$(df /var 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//')
        local inode_pct=$(df -i /var 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//')

        local root_color="${GREEN}"
        [[ -n "$root_pct" && "$root_pct" =~ ^[0-9]+$ ]] && {
            [[ $root_pct -gt 80 ]] && root_color="${YELLOW}"
            [[ $root_pct -gt 90 ]] && root_color="${RED}"
        }
        local var_color="${GREEN}"
        [[ -n "$var_pct" && "$var_pct" =~ ^[0-9]+$ ]] && {
            [[ $var_pct -gt 80 ]] && var_color="${YELLOW}"
            [[ $var_pct -gt 90 ]] && var_color="${RED}"
        }
        local inode_color="${GREEN}"
        [[ -n "$inode_pct" && "$inode_pct" =~ ^[0-9]+$ ]] && {
            [[ $inode_pct -gt 70 ]] && inode_color="${YELLOW}"
            [[ $inode_pct -gt 90 ]] && inode_color="${RED}"
        }

        show_header
        echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${WHITE}│                    ESPACE DISQUE                            │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        format_menu_row "/       ${root_color}${root_pct:-?}%${NC} utilisé" ""
        format_menu_row "/var    ${var_color}${var_pct:-?}%${NC} utilisé" ""
        format_menu_row "Inodes  ${inode_color}${inode_pct:-?}%${NC} /var" ""
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  ${GREEN}1. Nettoyage guidé   ${WHITE}│ Scan + checklist interactive      │${NC}"
        echo -e "${WHITE}│  ${YELLOW}2. Gros fichiers     ${WHITE}│ Trouver fichiers > 100 MB         │${NC}"
        echo -e "${WHITE}│  ${CYAN}3. Diagnostic inodes ${WHITE}│ Répertoires avec trop de fichiers  │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  ${WHITE}0. Retour            ${WHITE}│ Menu dépannage                    │${NC}"
        echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
        echo ""

        read -p "$(echo -e "${CYAN}Sélectionnez une option [0-3]: ${NC}")" choice

        case "$choice" in
            1) menu_disk_cleanup ;;
            2) show_large_files ;;
            3) show_inode_diagnostic ;;
            0) break ;;
            *)
                echo -e "${RED}Choix non valide${NC}"
                sleep 1
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════
# MENU PRINCIPAL DÉPANNAGE
# ═══════════════════════════════════════════════════════════════

menu_depannage() {
    while true; do
        show_header
        echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${WHITE}│                      DÉPANNAGE                              │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  ${GREEN}1. Mémoire & Swap    ${WHITE}│ RAM, swap, caches, swappiness     │${NC}"
        echo -e "${WHITE}│  ${YELLOW}2. Espace disque     ${WHITE}│ Nettoyage guidé, inodes, fichiers │${NC}"
        echo -e "${WHITE}├─────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${WHITE}│  ${WHITE}0. Retour            ${WHITE}│ Menu principal                    │${NC}"
        echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
        echo ""

        read -p "$(echo -e "${CYAN}Sélectionnez une option [0-2]: ${NC}")" choice

        case "$choice" in
            1) menu_memory_swap ;;
            2) menu_disk_space ;;
            0) break ;;
            *)
                echo -e "${RED}Choix non valide${NC}"
                sleep 1
                ;;
        esac
    done
}

# Export
export -f show_memory_detail
export -f show_swap_by_process
export -f flush_swap
export -f configure_swappiness
export -f drop_system_caches
export -f menu_memory_swap
export -f menu_disk_cleanup
export -f show_large_files
export -f show_inode_diagnostic
export -f menu_disk_space
export -f menu_depannage
