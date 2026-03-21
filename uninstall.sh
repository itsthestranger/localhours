#!/usr/bin/env bash
# =============================================================================
# uninstall.sh — org.kde.plasma.localhours  (KDE Plasma 6)
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }

APPLET_ID="org.kde.plasma.localhours"
SERVICE_FILE="${HOME}/.config/systemd/user/localhours.service"
DATA_DIR="${HOME}/.local/share/localhours"

echo ""
echo "This will remove the KDE LocalHours daemon and applet."
read -r -p "Keep your tracked data? [Y/n] " keep_data
keep_data="${keep_data:-Y}"

# Stop & disable service
info "Stopping and disabling service…"
systemctl --user stop    localhours.service 2>/dev/null || true
systemctl --user disable localhours.service 2>/dev/null || true
[ -f "${SERVICE_FILE}" ] && rm -f "${SERVICE_FILE}" && info "Removed service file."
systemctl --user daemon-reload

# Remove applet (also removes the backend scripts inside the package)
info "Removing Plasma applet…"
kpackagetool6 --type=Plasma/Applet --remove "${APPLET_ID}" 2>/dev/null || \
    warn "Applet not found (already removed?)."

# Handle data
if [[ "${keep_data}" =~ ^[Nn] ]]; then
    info "Removing data directory ${DATA_DIR}…"
    rm -rf "${DATA_DIR}"
else
    info "Data preserved at: ${DATA_DIR}/data.json"
fi

echo ""
echo -e "${GREEN}Uninstall complete.${NC}"
echo "You may need to remove the widget from your panel manually in Plasma."
