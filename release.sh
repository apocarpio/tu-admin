#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="${1:-$(date +%Y%m%d)}"
OUTPUT_NAME="tu_admin-${VERSION}.tar.gz"
OUTPUT_DIR="${SCRIPT_DIR}/releases"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${CYAN}TU ADMIN — Création release v${VERSION}${NC}"
mkdir -p "$OUTPUT_DIR"
TEMP_DIR=$(mktemp -d)
RELEASE_DIR="$TEMP_DIR/tu_admin"
mkdir -p "$RELEASE_DIR"

echo -e "${YELLOW}▶ Copie des fichiers...${NC}"
rsync -a --exclude='.git' --exclude='data/.db_credentials' --exclude='data/.tu_app_path' \
  --exclude='backups/*.sql' --exclude='logs/*.log' --exclude='.claude' \
  --exclude='*.backup_*' --exclude='*.original' --exclude='releases' \
  "$SCRIPT_DIR/" "$RELEASE_DIR/"
mkdir -p "$RELEASE_DIR/data" "$RELEASE_DIR/backups" "$RELEASE_DIR/logs"
touch "$RELEASE_DIR/data/.gitkeep" "$RELEASE_DIR/backups/.gitkeep" "$RELEASE_DIR/logs/.gitkeep"

echo -e "${YELLOW}▶ Création archive...${NC}"
cd "$TEMP_DIR"
tar czf "$OUTPUT_DIR/$OUTPUT_NAME" tu_admin/
rm -rf "$TEMP_DIR"

SIZE=$(du -h "$OUTPUT_DIR/$OUTPUT_NAME" | cut -f1)
COUNT=$(tar tzf "$OUTPUT_DIR/$OUTPUT_NAME" | wc -l)
ln -sf "$OUTPUT_DIR/$OUTPUT_NAME" "$OUTPUT_DIR/tu_admin-latest.tar.gz"

echo -e "\n${GREEN}✅ Release créée: $OUTPUT_DIR/$OUTPUT_NAME ($SIZE, $COUNT fichiers)${NC}"
echo -e "${YELLOW}Pour installer offline:${NC}"
echo -e "${CYAN}  scp $OUTPUT_DIR/$OUTPUT_NAME root@<IP>:/tmp/${NC}"
echo -e "${CYAN}  ssh root@<IP> \"cd /tmp && tar xzf $OUTPUT_NAME && bash tu_admin/install.sh --offline\"${NC}"
