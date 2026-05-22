#!/usr/bin/env bash
# Uninstall Script for cc-install (macOS/Linux)
# Removes container, image, volumes, and optionally the installation directory

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    log_error "docker-compose.yml not found"
    echo "Please run this script from the cc-install directory"
    exit 1
fi

echo ""
echo -e "${RED}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║                                                           ║${NC}"
echo -e "${RED}║   Claude Code Uninstaller                                 ║${NC}"
echo -e "${RED}║                                                           ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

log_warn "This will remove:"
echo "  • Docker container (cc-install)"
echo "  • Docker image (cc-install:latest)"
echo "  • Docker volumes (optional)"
echo "  • Installation directory (optional)"
echo ""

# Stop and remove container
log_info "Step 1/4: Stopping and removing container..."
if docker compose down 2>/dev/null; then
    log_success "Container removed"
else
    log_warn "Container may not exist or already removed"
fi

# Remove image
echo ""
log_info "Step 2/4: Removing Docker image..."
if docker rmi cc-install:latest 2>/dev/null; then
    log_success "Image removed"
else
    log_warn "Image may not exist or already removed"
fi

# Remove volumes (with confirmation)
echo ""
log_warn "Step 3/4: Remove Docker volumes?"
echo "  This will DELETE your Claude Code settings and configuration."
echo "  Your workspace/ directory will NOT be affected."
echo ""
echo -n "Remove volumes? (y/N): "
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    if docker volume rm cc-install_claude-config 2>/dev/null; then
        log_success "Volumes removed"
    else
        log_warn "Volumes may not exist or already removed"
    fi
else
    log_info "Volumes preserved"
fi

# Remove installation directory (with confirmation)
echo ""
log_warn "Step 4/4: Remove installation directory?"
echo "  This will DELETE the entire cc-install directory, including:"
echo "    • workspace/ (YOUR FILES)"
echo "    • All scripts and configuration"
echo ""
echo -n "Remove installation directory? (y/N): "
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    INSTALL_DIR=$(pwd)
    cd ..
    log_info "Removing $INSTALL_DIR..."
    rm -rf "$INSTALL_DIR"
    log_success "Installation directory removed"
    echo ""
    echo -e "${GREEN}Uninstallation complete. Claude Code has been fully removed.${NC}"
    echo ""
else
    log_info "Installation directory preserved"
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    echo -e "${GREEN}║   Uninstallation Complete                                 ║${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Docker resources removed:${NC}"
    echo "  • Container: cc-install"
    echo "  • Image: cc-install:latest"
    echo ""
    echo -e "${BLUE}Preserved:${NC}"
    echo "  • Installation directory (including workspace/)"
    echo "  • Scripts (install.sh, run_claude.sh, etc.)"
    echo ""
    echo -e "${YELLOW}To reinstall:${NC}"
    echo "  Run: ./install.sh"
    echo ""
fi
