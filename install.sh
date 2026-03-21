#!/usr/bin/env bash
# =============================================================================
# install.sh — org.kde.plasma.localhours  (KDE Plasma 6)
# =============================================================================
# This script:
#   1. Checks for required system dependencies.
#   2. Installs the Plasma applet package via kpackagetool6.
#      (The backend lives inside the plasmoid package at:
#       ~/.local/share/plasma/plasmoids/org.kde.plasma.localhours/contents/backend/)
#   3. Registers and enables the systemd user service.
#   4. Prints post-install instructions.
#
# Run as your normal user (NOT as root).
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()     { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLASMOID_SRC="${SCRIPT_DIR}/plasmoid/package"

APPLET_ID="org.kde.plasma.localhours"
PLASMOID_INSTALL_DIR="${HOME}/.local/share/plasma/plasmoids/${APPLET_ID}"
BACKEND_INSTALL_DIR="${PLASMOID_INSTALL_DIR}/contents/backend"
SYSTEMD_DIR="${HOME}/.config/systemd/user"
DATA_DIR="${HOME}/.local/share/localhours"

# ── Pre-flight checks ─────────────────────────────────────────────────────────
info "Checking dependencies…"

command -v python3       >/dev/null 2>&1 || die "python3 not found. Install Python 3.10+."
command -v kpackagetool6 >/dev/null 2>&1 || die "kpackagetool6 not found. Install kde-cli-tools / plasma-workspace."
command -v systemctl     >/dev/null 2>&1 || die "systemctl not found. This script requires systemd."

PY_VER=$(python3 -c "import sys; print(sys.version_info.minor + 100*sys.version_info.major)")
if [ "${PY_VER}" -lt 310 ]; then
    die "Python 3.10 or newer is required (found $(python3 --version))."
fi

# ── Install Python packages ───────────────────────────────────────────────────
info "Installing Python dependencies…"

if command -v pacman >/dev/null 2>&1; then
    info "Arch-based distro detected. Checking system packages…"
    MISSING_PKGS=()
    pacman -Q python-pydbus  >/dev/null 2>&1 || MISSING_PKGS+=("python-pydbus")
    pacman -Q python-gobject >/dev/null 2>&1 || MISSING_PKGS+=("python-gobject")
    if [ "${#MISSING_PKGS[@]}" -gt 0 ]; then
        warn "Missing system packages: ${MISSING_PKGS[*]}"
        warn "Install them with: sudo pacman -S ${MISSING_PKGS[*]}"
        warn "Falling back to pip install…"
        pip3 install --break-system-packages pydbus PyGObject 2>/dev/null || \
            warn "pip install failed. Please install pydbus and PyGObject manually."
    else
        info "System packages already present (python-pydbus, python-gobject). ✓"
    fi
elif command -v apt >/dev/null 2>&1; then
    info "Debian/Ubuntu detected. Checking system packages…"
    MISSING_PKGS=()
    dpkg -s python3-pydbus >/dev/null 2>&1 || MISSING_PKGS+=("python3-pydbus")
    dpkg -s python3-gi     >/dev/null 2>&1 || MISSING_PKGS+=("python3-gi")
    if [ "${#MISSING_PKGS[@]}" -gt 0 ]; then
        warn "Missing system packages: ${MISSING_PKGS[*]}"
        warn "Install them with: sudo apt install ${MISSING_PKGS[*]}"
        warn "Falling back to pip install…"
        pip3 install --break-system-packages pydbus PyGObject 2>/dev/null || \
            warn "pip install failed. Please install pydbus and PyGObject manually."
    fi
else
    if command -v pip3 >/dev/null 2>&1; then
        pip3 install --break-system-packages pydbus PyGObject 2>/dev/null || \
            warn "pip install failed. Please install pydbus and PyGObject manually."
    fi
fi

# ── Install Plasma applet (includes backend inside the package) ───────────────
info "Installing Plasma applet (${APPLET_ID})…"

# Remove old installation if present
kpackagetool6 --type=Plasma/Applet --remove "${APPLET_ID}" 2>/dev/null || true

kpackagetool6 --type=Plasma/Applet --install "${PLASMOID_SRC}" || \
    die "kpackagetool6 failed. Check the output above."

info "Plasma applet installed to ${PLASMOID_INSTALL_DIR} ✓"

# Mark backend scripts as executable (kpackagetool6 may not preserve +x)
chmod +x "${BACKEND_INSTALL_DIR}/daemon.py"
chmod +x "${BACKEND_INSTALL_DIR}/tracker-client.py"

# ── Ensure data directory exists ──────────────────────────────────────────────
mkdir -p "${DATA_DIR}"

# ── Install systemd user service ──────────────────────────────────────────────
info "Installing systemd user service…"
mkdir -p "${SYSTEMD_DIR}"
cp "${PLASMOID_INSTALL_DIR}/contents/backend/localhours.service" \
   "${SYSTEMD_DIR}/localhours.service"

systemctl --user daemon-reload
systemctl --user enable --now localhours.service || {
    warn "Could not enable/start service automatically."
    warn "Run manually: systemctl --user enable --now localhours"
}

# Verify daemon is responding
sleep 1.5
if gdbus introspect --session \
    --dest org.kde.plasma.localhours \
    --object-path /org/kde/plasma/localhours \
    >/dev/null 2>&1; then
    info "Daemon is running and responding on D-Bus. ✓"
else
    warn "Daemon D-Bus check failed. Check the service status:"
    warn "  systemctl --user status localhours"
    warn "  journalctl --user -u localhours -n 20"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  KDE LocalHours installed successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Next steps:"
echo "  1. Right-click your panel → 'Add Widgets'"
echo "  2. Search for 'LocalHours' and drag it to your panel."
echo "  3. Or right-click the System Tray → 'Configure System Tray'"
echo "     → 'Extra Items' → enable 'LocalHours'."
echo ""
echo "  Applet:    ${PLASMOID_INSTALL_DIR}"
echo "  Data file: ${DATA_DIR}/data.json"
echo "  Daemon log: journalctl --user -u localhours -f"
echo ""
echo "  To uninstall, run: ./uninstall.sh"
echo ""
