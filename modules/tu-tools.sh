#!/bin/bash
# Module TU Tools - Loader principal

# Chargement des dépendances
SCRIPT_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_MODULE_DIR/../lib/common.sh"
source "$SCRIPT_MODULE_DIR/../lib/ui.sh"
source "$SCRIPT_MODULE_DIR/../lib/database.sh"

# Chargement des sous-modules TU Tools
TU_TOOLS_DIR="$SCRIPT_MODULE_DIR/tu-tools"

# Charger tous les sous-modules
for module in "$TU_TOOLS_DIR"/*.sh; do
    if [[ -f "$module" ]]; then
        source "$module"
        log_message "DEBUG" "Sous-module TU Tools chargé: $(basename $module)"
    fi
done

# Export de la fonction principale
export -f menu_tu_tools
