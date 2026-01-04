#!/bin/bash
# Module TU Tools - Gestion Terminal Urgence (À COMPLÉTER)

# Chargement des dépendances
SCRIPT_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_MODULE_DIR/../lib/common.sh"
source "$SCRIPT_MODULE_DIR/../lib/ui.sh"
source "$SCRIPT_MODULE_DIR/../lib/database.sh"

# Fonction menu TU Tools (temporaire)
menu_tu_tools() {
    show_header
    print_message "warning" "Module TU TOOLS en cours de migration..."
    echo ""
    echo -e "${COLOR_YELLOW}Ce module sera complété prochainement.${COLOR_RESET}"
    echo -e "${COLOR_CYAN}Pour l'instant, utilisez le script original.${COLOR_RESET}"
    echo ""
    pause_with_message
}

# Export des fonctions
export -f menu_tu_tools
