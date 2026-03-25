#!/bin/bash
set -euo pipefail
INSTALL_DIR="/root/tu_admin"
REPO_URL="https://github.com/apocarpio/tu-admin.git"
BRANCH="main"
VERSION="3.0"
LOG_FILE="/var/log/tu_admin_install.log"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'

log() { local l="$1"; shift; echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$l] $*" >> "$LOG_FILE"
  case "$l" in INFO) echo -e "${GREEN}✅ $*${NC}";; WARN) echo -e "${YELLOW}⚠️  $*${NC}";; ERROR) echo -e "${RED}❌ $*${NC}";; STEP) echo -e "${CYAN}▶  $*${NC}";; esac; }

check_root() { [[ $EUID -ne 0 ]] && echo -e "${RED}❌ Ce script doit être exécuté en tant que root${NC}" && exit 1; return 0; }

show_banner() {
  echo -e "\n${CYAN}════════════════════════════════════════════════════════════════${NC}"
  echo -e "${WHITE}  TU ADMIN — Installation automatique v${VERSION}${NC}"
  echo -e "${WHITE}  ieSS — Terminal des Urgences${NC}"
  echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}\n"
}

show_help() {
  echo "Usage: bash install.sh [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --offline    Installation depuis l'archive locale (sans internet)"
  echo "  --update     Mettre à jour une installation existante"
  echo "  --help       Afficher cette aide"
  echo ""
  echo "Exemples:"
  echo "  # Online (serveur avec internet)"
  echo "  curl -sSL https://raw.githubusercontent.com/apocarpio/tu-admin/main/install.sh | bash"
  echo ""
  echo "  # Offline (archive dans /tmp)"
  echo "  bash install.sh --offline"
  echo ""
  echo "  # Mise à jour"
  echo "  bash install.sh --update"
}

check_prerequisites() {
  log STEP "Vérification des prérequis..."
  local missing=()
  for cmd in bash mysql mysqldump; do command -v "$cmd" &>/dev/null || missing+=("$cmd"); done
  command -v perl &>/dev/null || log WARN "Perl non installé — MySQLTuner non disponible"
  [[ ${#missing[@]} -gt 0 ]] && log WARN "Outils manquants: ${missing[*]}" || log INFO "Prérequis OK"
}

_backup_data() {
  local bdir="/tmp/tu_admin_backup_$(date +%Y%m%d_%H%M%S)"; mkdir -p "$bdir"
  [[ -f "$INSTALL_DIR/data/.db_credentials" ]] && cp "$INSTALL_DIR/data/.db_credentials" "$bdir/"
  [[ -f "$INSTALL_DIR/data/.tu_app_path" ]] && cp "$INSTALL_DIR/data/.tu_app_path" "$bdir/"
  [[ -d "$INSTALL_DIR/backups" ]] && cp -r "$INSTALL_DIR/backups" "$bdir/"
  echo "$bdir"
}

_restore_data() {
  local bdir="$1"
  [[ -f "$bdir/.db_credentials" ]] && cp "$bdir/.db_credentials" "$INSTALL_DIR/data/"
  [[ -f "$bdir/.tu_app_path" ]] && cp "$bdir/.tu_app_path" "$INSTALL_DIR/data/"
  [[ -d "$bdir/backups" ]] && cp -r "$bdir/backups"/* "$INSTALL_DIR/backups/" 2>/dev/null || true
}

install_online() {
  log STEP "Installation en ligne depuis GitHub..."
  command -v git &>/dev/null || { log STEP "Installation de git..."; apt-get update -qq && apt-get install -y -qq git; }
  if [[ -d "$INSTALL_DIR" ]]; then
    log WARN "Répertoire existant — sauvegarde données..."
    local bdir; bdir=$(_backup_data)
    rm -rf "$INSTALL_DIR"
    git clone -b "$BRANCH" "$REPO_URL" "$INSTALL_DIR"
    _restore_data "$bdir"
    log INFO "Installation mise à jour (données préservées)"
  else
    git clone -b "$BRANCH" "$REPO_URL" "$INSTALL_DIR"
    log INFO "Repository cloné"
  fi
}

install_offline() {
  log STEP "Installation hors-ligne..."
  local archive=""
  for dir in "." "/tmp" "$(dirname "${BASH_SOURCE[0]}")"; do
    for f in "$dir"/tu_admin*.tar.gz "$dir"/tu-admin*.tar.gz; do [[ -f "$f" ]] && archive="$f" && break 2; done
  done
  [[ -z "$archive" ]] && log ERROR "Archive .tar.gz non trouvée dans . ou /tmp" && exit 1
  log INFO "Archive: $archive"
  if [[ -d "$INSTALL_DIR" ]]; then
    local bdir; bdir=$(_backup_data)
    rm -rf "$INSTALL_DIR"
  fi
  mkdir -p "$INSTALL_DIR"
  tar xzf "$archive" -C "$INSTALL_DIR" --strip-components=1
  [[ -n "${bdir:-}" ]] && _restore_data "$bdir"
  log INFO "Archive extraite"
}

install_update() {
  log STEP "Mise à jour..."
  [[ ! -d "$INSTALL_DIR/.git" ]] && log ERROR "Pas un repo git — utilisez install.sh sans --update" && exit 1
  cd "$INSTALL_DIR"
  git diff --quiet 2>/dev/null || { log WARN "Modifications locales — stash..."; git stash; }
  git pull origin "$BRANCH"
  log INFO "Mise à jour terminée"
}

post_install() {
  log STEP "Post-installation..."
  chmod +x "$INSTALL_DIR/tu_admin.sh" 2>/dev/null || true
  chmod 700 "$INSTALL_DIR/data" 2>/dev/null || true
  mkdir -p "$INSTALL_DIR/backups" "$INSTALL_DIR/logs" "$INSTALL_DIR/data"
  if [[ ! -f "$INSTALL_DIR/MySQLTuner/mysqltuner.pl" ]] && command -v git &>/dev/null; then
    log STEP "Installation MySQLTuner..."
    git clone https://github.com/major/MySQLTuner-perl.git "$INSTALL_DIR/MySQLTuner" 2>/dev/null || true
    [[ -f "$INSTALL_DIR/MySQLTuner/mysqltuner.pl" ]] && chmod +x "$INSTALL_DIR/MySQLTuner/mysqltuner.pl"
  fi
  local bashrc="/root/.bashrc"
  if [[ -f "$bashrc" ]] && ! grep -q "alias tu-admin=" "$bashrc" 2>/dev/null; then
    printf '\n# TU Admin — Terminal des Urgences\nalias tu-admin='\''bash %s/tu_admin.sh'\''\n' "$INSTALL_DIR" >> "$bashrc"
    log INFO "Alias 'tu-admin' ajouté"
  fi
  ln -sf "$INSTALL_DIR/tu_admin.sh" /usr/local/bin/tu-admin 2>/dev/null || true
  log INFO "Commande 'tu-admin' disponible globalement"
}

show_summary() {
  echo -e "\n${GREEN}════════════════════════════════════════════════════════════════${NC}"
  echo -e "${WHITE}  INSTALLATION TERMINÉE AVEC SUCCÈS${NC}"
  echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
  echo -e "${WHITE}  Répertoire: ${CYAN}$INSTALL_DIR${NC}"
  echo -e "${WHITE}  Version:    ${CYAN}$VERSION${NC}"
  echo -e "${WHITE}  Lancer:     ${CYAN}tu-admin${NC}  ou  ${CYAN}bash $INSTALL_DIR/tu_admin.sh${NC}"
  echo -e "${YELLOW}  Au 1er lancement: configurer chemin App TU + base de données${NC}"
  echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}\n"
}

main() {
  # Gérer --help AVANT tout (pas besoin de root pour --help)
  for arg in "$@"; do
    case "$arg" in --help|-h) show_banner; show_help; exit 0;; esac
  done

  mkdir -p "$(dirname "$LOG_FILE")"; touch "$LOG_FILE"
  show_banner; check_root

  local mode="online"
  for arg in "$@"; do
    case "$arg" in --offline) mode="offline";; --update) mode="update";; esac
  done

  log INFO "Mode: $mode"
  case "$mode" in
    online) check_prerequisites; install_online;; offline) check_prerequisites; install_offline;; update) install_update;; esac
  post_install; show_summary
}
main "$@"
