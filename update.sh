#!/usr/bin/env bash
# Update Script for cc-install (macOS/Linux)
# Rebuilds Docker image with latest versions

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
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                           ║${NC}"
echo -e "${BLUE}║   Claude Code Updater                                     ║${NC}"
echo -e "${BLUE}║                                                           ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

log_info "This will rebuild the Docker image with the latest versions of:"
echo "  - Claude Code"
echo "  - VS Code Server (code-server)"
echo "  - System packages"
echo ""
log_warn "Your workspace and settings will NOT be affected."
echo ""
echo -n "Continue? (y/N): "
read -r response

if [[ ! "$response" =~ ^[Yy]$ ]]; then
    log_info "Update cancelled"
    exit 0
fi

# Stop container if running
log_info "Stopping container..."
docker compose stop || true

# Rebuild image with no cache
log_info "Rebuilding Docker image (this may take a few minutes)..."
if ! docker compose build --no-cache --progress plain; then
    log_error "Failed to rebuild Docker image"
    exit 1
fi

# Restart container
log_info "Starting updated container..."
if ! docker compose up -d; then
    log_error "Failed to start container"
    exit 1
fi

# Wait for container to be ready
log_info "Waiting for container to be ready..."
sleep 5

# Verify Claude Code
if docker compose exec -T claude-code claude --version &> /dev/null; then
    CLAUDE_VERSION=$(docker compose exec -T claude-code claude --version 2>&1 | head -1)
    log_success "Claude Code updated: $CLAUDE_VERSION"
else
    log_warn "Could not verify Claude Code version"
fi

# Verify code-server
if docker compose exec -T claude-code code-server --version &> /dev/null; then
    CODE_SERVER_VERSION=$(docker compose exec -T claude-code code-server --version 2>&1 | head -1)
    log_success "code-server updated: $CODE_SERVER_VERSION"
else
    log_warn "Could not verify code-server version"
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}║   Update Complete!                                        ║${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}You can now use Claude Code with:${NC}"
echo -e "  ${YELLOW}./run_claude.sh${NC} or ${YELLOW}./run_vscode.sh${NC}"
echo ""
